import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// AI 接入层。OpenAI兼容的chat接口，硅基流动/DeepSeek/OpenAI都能填
/// 配置存在SharedPreferences里，key下面这几个
class AiConfig {
  static const kBaseUrl = 'ai_base_url';
  static const kApiKey = 'ai_api_key';
  static const kModel = 'ai_model';

  String baseUrl = 'https://api.siliconflow.cn/v1';
  String apiKey = '';
  String model = 'Qwen/Qwen2.5-7B-Instruct';

  bool get ready => apiKey.trim().isNotEmpty && baseUrl.trim().isNotEmpty;

  static Future<AiConfig> load() async {
    final cfg = AiConfig();
    try {
      final sp = await SharedPreferences.getInstance();
      cfg.baseUrl = sp.getString(kBaseUrl) ?? cfg.baseUrl;
      cfg.apiKey = sp.getString(kApiKey) ?? '';
      cfg.model = sp.getString(kModel) ?? cfg.model;
    } catch (_) {}
    return cfg;
  }

  Future<void> save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(kBaseUrl, baseUrl);
      await sp.setString(kApiKey, apiKey);
      await sp.setString(kModel, model);
    } catch (_) {
      // 存不上就算了，内存里还有
    }
  }
}

class AiService {
  /// 单条chat调用。失败直接抛异常，页面那边catch了显示。
  static Future<String> chat(AiConfig cfg, String userContent,
      {String? system, http.Client? client, Duration timeout = const Duration(seconds: 30)}) async {
    final c = client ?? http.Client();
    final messages = <Map<String, String>>[
      if (system != null && system.trim().isNotEmpty) {'role': 'system', 'content': system},
      {'role': 'user', 'content': userContent},
    ];
    final body = jsonEncode({
      'model': cfg.model,
      'messages': messages,
      'temperature': 0.6,
      // max_tokens给一点，防止话痨模型把token烧光
      'max_tokens': 1024,
    });

    var url = cfg.baseUrl.trim();
    if (!url.endsWith('/')) url += '/';
    url += 'chat/completions';

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw ArgumentError('API地址不合法: $url');
    }

    try {
      final resp = await c.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${cfg.apiKey.trim()}',
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(timeout);

      if (resp.statusCode != 200) {
        var detail = '';
        try {
          final j = jsonDecode(utf8.decode(resp.bodyBytes));
          detail = (j['error']?['message'] ?? j['message'] ?? '').toString();
        } catch (_) {}
        throw Exception('HTTP ${resp.statusCode}${detail.isEmpty ? '' : ' · $detail'}');
      }

      final j = jsonDecode(utf8.decode(resp.bodyBytes));
      final content = j['choices']?[0]?['message']?['content'];
      if (content == null) {
        throw Exception('返回里没有内容，检查下模型名');
      }
      return content.toString();
    } finally {
      if (client == null) c.close();
    }
  }

  /// 连通性测试，随便问一句
  static Future<String> ping(AiConfig cfg) {
    return chat(cfg, '回复"OK"两个字母就行，不要任何别的内容',
        timeout: const Duration(seconds: 20));
  }
}
