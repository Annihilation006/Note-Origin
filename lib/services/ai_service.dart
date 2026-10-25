import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'secret_box.dart';

/// API协议格式。市面上主流就这三种，其它家基本都做了openai兼容
enum ApiFormat { openai, anthropic, gemini }

extension ApiFormatX on ApiFormat {
  String get label => switch (this) {
        ApiFormat.openai => 'OpenAI 兼容',
        ApiFormat.anthropic => 'Anthropic',
        ApiFormat.gemini => 'Gemini',
      };

  /// 设置页里给的base url提示，换格式跟着换
  String get baseHint => switch (this) {
        ApiFormat.openai => 'https://api.siliconflow.cn/v1',
        ApiFormat.anthropic => 'https://api.anthropic.com',
        ApiFormat.gemini => 'https://generativelanguage.googleapis.com',
      };

  String get modelHint => switch (this) {
        ApiFormat.openai => 'Qwen/Qwen2.5-7B-Instruct',
        ApiFormat.anthropic => 'claude-sonnet-4-5',
        ApiFormat.gemini => 'gemini-2.5-flash',
      };
}

/// AI 接入层，三种协议格式都走 chat() 这一个门
class AiConfig {
  static const kBaseUrl = 'ai_base_url';
  static const kApiKey = 'ai_api_key';
  static const kModel = 'ai_model';
  static const kFormat = 'ai_format';

  String baseUrl = 'https://api.siliconflow.cn/v1';
  String apiKey = '';
  String model = 'Qwen/Qwen2.5-7B-Instruct';
  ApiFormat format = ApiFormat.openai;

  bool get ready => apiKey.trim().isNotEmpty && baseUrl.trim().isNotEmpty;

  static Future<AiConfig> load() async {
    final cfg = AiConfig();
    try {
      final sp = await SharedPreferences.getInstance();
      cfg.baseUrl = sp.getString(kBaseUrl) ?? cfg.baseUrl;
      cfg.apiKey = SecretBox.unseal(sp.getString(kApiKey) ?? '');
      cfg.model = sp.getString(kModel) ?? cfg.model;
      final f = sp.getString(kFormat);
      for (final v in ApiFormat.values) {
        if (v.name == f) cfg.format = v;
      }
    } catch (_) {}
    return cfg;
  }

  Future<void> save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(kBaseUrl, baseUrl);
      await sp.setString(kApiKey, SecretBox.seal(apiKey));
      await sp.setString(kModel, model);
      await sp.setString(kFormat, format.name);
    } catch (_) {
      // 存不上就算了，内存里还有
    }
  }
}

class AiService {
  /// 单轮对话。失败抛异常，调用方自己展示
  static Future<String> chat(AiConfig cfg, String userContent,
      {String? system,
      http.Client? client,
      Duration timeout = const Duration(seconds: 30)}) async {
    final c = client ?? http.Client();
    try {
      switch (cfg.format) {
        case ApiFormat.openai:
          return await _chatOpenai(cfg, c, userContent, system, timeout);
        case ApiFormat.anthropic:
          return await _chatAnthropic(cfg, c, userContent, system, timeout);
        case ApiFormat.gemini:
          return await _chatGemini(cfg, c, userContent, system, timeout);
      }
    } finally {
      if (client == null) c.close();
    }
  }

  /// 连通性测试
  static Future<String> ping(AiConfig cfg) {
    return chat(cfg, '回复"OK"两个字母就行，不要任何别的内容',
        timeout: const Duration(seconds: 20));
  }

  static String _trimBase(String raw) => raw.trim().replaceAll(RegExp(r'/+$'), '');

  static Map<String, dynamic> _decodeBody(http.Response resp) {
    if (resp.statusCode != 200) {
      var detail = '';
      try {
        final j = jsonDecode(utf8.decode(resp.bodyBytes));
        detail = (j['error']?['message'] ?? j['error']?['type'] ?? j['message'] ?? '')
            .toString();
      } catch (_) {}
      throw Exception('HTTP ${resp.statusCode}${detail.isEmpty ? '' : ' · $detail'}');
    }
    return jsonDecode(utf8.decode(resp.bodyBytes));
  }

  // ---------- OpenAI: POST {base}/chat/completions ----------

  static Future<String> _chatOpenai(AiConfig cfg, http.Client c, String user,
      String? system, Duration timeout) async {
    var url = _trimBase(cfg.baseUrl);
    if (url.endsWith('/chat/completions')) {
      // 有人直接把完整地址填进来，宽容一点
    } else if (!url.endsWith('/v1')) {
      url = '$url/v1';
    }
    final body = jsonEncode({
      'model': cfg.model,
      'messages': [
        if (system != null && system.trim().isNotEmpty)
          {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      'temperature': 0.6,
      'max_tokens': 1024,
    });
    final resp = await c
        .post(Uri.parse('$url/chat/completions'),
            headers: {
              'Authorization': 'Bearer ${cfg.apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: body)
        .timeout(timeout);
    final j = _decodeBody(resp);
    final content = j['choices']?[0]?['message']?['content'];
    if (content == null) {
      throw Exception('返回里没有内容，检查下模型名');
    }
    return content.toString();
  }

  // ---------- Anthropic: POST {base}/v1/messages ----------

  static Future<String> _chatAnthropic(AiConfig cfg, http.Client c, String user,
      String? system, Duration timeout) async {
    var url = _trimBase(cfg.baseUrl);
    if (!url.endsWith('/v1')) {
      url = '$url/v1';
    }
    final body = jsonEncode({
      'model': cfg.model,
      'max_tokens': 1024,
      if (system != null && system.trim().isNotEmpty) 'system': system,
      'messages': [
        {'role': 'user', 'content': user},
      ],
    });
    final resp = await c
        .post(Uri.parse('$url/messages'),
            headers: {
              'x-api-key': cfg.apiKey.trim(),
              'anthropic-version': '2023-06-01',
              'Content-Type': 'application/json',
            },
            body: body)
        .timeout(timeout);
    final j = _decodeBody(resp);
    // content是个数组，把text块都拼起来
    final blocks = j['content'];
    if (blocks is List) {
      final buf = StringBuffer();
      for (final b in blocks) {
        if (b is Map && b['type'] == 'text' && b['text'] != null) {
          buf.write(b['text']);
        }
      }
      if (buf.isNotEmpty) return buf.toString();
    }
    throw Exception('返回里没有内容，检查下模型名');
  }

  // ---------- Gemini: POST {base}/v1beta/models/{model}:generateContent ----------

  static Future<String> _chatGemini(AiConfig cfg, http.Client c, String user,
      String? system, Duration timeout) async {
    var url = _trimBase(cfg.baseUrl);
    if (!url.contains('/v1beta')) {
      url = '$url/v1beta';
    }
    final model = cfg.model.trim();
    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': user},
          ],
        },
      ],
      if (system != null && system.trim().isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
      'generationConfig': {'maxOutputTokens': 1024},
    });
    final resp = await c
        .post(Uri.parse('$url/models/$model:generateContent'),
            headers: {
              'x-goog-api-key': cfg.apiKey.trim(),
              'Content-Type': 'application/json',
            },
            body: body)
        .timeout(timeout);
    final j = _decodeBody(resp);
    final parts = j['candidates']?[0]?['content']?['parts'];
    if (parts is List) {
      final buf = StringBuffer();
      for (final p in parts) {
        if (p is Map && p['text'] != null) {
          buf.write(p['text']);
        }
      }
      if (buf.isNotEmpty) return buf.toString();
    }
    throw Exception('返回里没有内容，检查下模型名');
  }
}
