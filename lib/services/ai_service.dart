import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'secret_box.dart';

/// 业务协议格式。第三方中转一律默认 ChatCompletions，
/// 不要按服务商名字猜协议，用户选什么就是什么
enum ApiFormat { chatCompletions, anthropicMessages, responses }

extension ApiFormatX on ApiFormat {
  String get label => switch (this) {
        ApiFormat.chatCompletions => 'ChatCompletions',
        ApiFormat.anthropicMessages => 'AnthropicMessages',
        ApiFormat.responses => 'Responses',
      };

  String get baseHint => switch (this) {
        ApiFormat.chatCompletions => 'https://api.xxx.com/v1',
        // anthropic官方base不带/v1，网关路径在buildEndpoint里补
        ApiFormat.anthropicMessages => 'https://api.xxx.com',
        ApiFormat.responses => 'https://api.xxx.com/v1',
      };

  String get modelHint => switch (this) {
        ApiFormat.chatCompletions => 'Qwen/Qwen2.5-7B-Instruct',
        ApiFormat.anthropicMessages => 'claude-sonnet-4-5',
        ApiFormat.responses => 'gpt-4o',
      };

  /// 该协议的接口路径后缀
  String get pathSuffix => switch (this) {
        ApiFormat.chatCompletions => '/chat/completions',
        ApiFormat.anthropicMessages => '/messages',
        ApiFormat.responses => '/responses',
      };
}

/// 旧版本的格式标识映射到新枚举。
/// gemini原生协议这版不再内置，回落到chatCompletions，
/// 要继续用Gemini的话走它的OpenAI兼容端点
const _legacyFormatMap = {
  'openai': ApiFormat.chatCompletions,
  'anthropic': ApiFormat.anthropicMessages,
  'gemini': ApiFormat.chatCompletions,
};

/// AI 接入层。URL拼接/请求体/请求头/响应解析都是纯函数，方便单测
class AiConfig {
  static const kBaseUrl = 'ai_base_url';
  static const kApiKey = 'ai_api_key';
  static const kModel = 'ai_model';
  static const kFormat = 'ai_format';

  String baseUrl = 'https://api.siliconflow.cn/v1';
  String apiKey = '';
  String model = 'Qwen/Qwen2.5-7B-Instruct';
  ApiFormat format = ApiFormat.chatCompletions;

  bool get ready => apiKey.trim().isNotEmpty && baseUrl.trim().isNotEmpty;

  static Future<AiConfig> load() async {
    final cfg = AiConfig();
    try {
      final sp = await SharedPreferences.getInstance();
      cfg.baseUrl = sp.getString(kBaseUrl) ?? cfg.baseUrl;
      cfg.apiKey = SecretBox.unseal(sp.getString(kApiKey) ?? '');
      cfg.model = sp.getString(kModel) ?? cfg.model;
      final raw = sp.getString(kFormat);
      if (raw == null) {
        // 老到连format字段都没有的配置，就是chatCompletions
        cfg.format = ApiFormat.chatCompletions;
      } else if (_legacyFormatMap.containsKey(raw)) {
        cfg.format = _legacyFormatMap[raw]!;
      } else {
        for (final v in ApiFormat.values) {
          if (v.name == raw) cfg.format = v;
        }
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
  static const _version = '/v1';

  /// 统一的endpoint拼接。base可以是服务根地址、/v1结尾的版本根、
  /// 或者已经带完整接口路径的地址；反代前缀原样保留
  static String buildEndpoint(ApiFormat fmt, String base) {
    var b = base.trim();
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    if (b.isEmpty) return b;
    final suffix = fmt.pathSuffix;

    // 已经是完整接口路径，别再叠
    if (b.endsWith(suffix)) return b;
    // 版本根，直接挂后缀
    if (b.endsWith(_version)) return b + suffix;
    // 服务根，补版本再挂
    return b + _version + suffix;
  }

  // ---------- 请求体 ----------

  static Map<String, dynamic> buildChatCompletionsBody(
      String model, String? system, String user) {
    return {
      'model': model,
      'messages': [
        if (system != null && system.trim().isNotEmpty)
          {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      'temperature': 0.6,
      'max_tokens': 1024,
    };
  }

  static Map<String, dynamic> buildAnthropicBody(String model, String? system, String user) {
    return {
      'model': model,
      // anthropic要求max_tokens必填
      'max_tokens': 1024,
      if (system != null && system.trim().isNotEmpty) 'system': system,
      'messages': [
        {'role': 'user', 'content': user},
      ],
    };
  }

  static Map<String, dynamic> buildResponsesBody(String model, String? system, String user) {
    return {
      'model': model,
      'input': user,
      if (system != null && system.trim().isNotEmpty) 'instructions': system,
      'max_output_tokens': 1024,
    };
  }

  // ---------- 请求头 ----------

  static Map<String, String> buildHeaders(ApiFormat fmt, String apiKey) {
    final key = apiKey.trim();
    switch (fmt) {
      case ApiFormat.anthropicMessages:
        return {
          'x-api-key': key,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        };
      case ApiFormat.chatCompletions:
      case ApiFormat.responses:
        return {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        };
    }
  }

  // ---------- 响应解析 ----------

  static String parseChatCompletions(Map<String, dynamic> j) {
    final content = j['choices']?[0]?['message']?['content'];
    if (content == null || content.toString().isEmpty) {
      throw Exception('返回里没有内容，检查下模型名');
    }
    return content.toString();
  }

  static String parseAnthropic(Map<String, dynamic> j) {
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
    // stop_reason不是end_turn的也顺带报出来，方便排查
    final stop = j['stop_reason'];
    throw Exception('返回里没有内容${stop == null ? '' : '（stop_reason: $stop）'}');
  }

  static String parseResponses(Map<String, dynamic> j) {
    final output = j['output'];
    if (output is List) {
      final buf = StringBuffer();
      for (final item in output) {
        if (item is! Map || item['type'] != 'message') continue;
        final content = item['content'];
        if (content is! List) continue;
        for (final part in content) {
          if (part is Map && part['type'] == 'output_text' && part['text'] != null) {
            buf.write(part['text']);
          }
        }
      }
      if (buf.isNotEmpty) return buf.toString();
    }
    final status = j['status'];
    throw Exception('返回里没有内容${status == null ? '' : '（status: $status）'}');
  }

  // ---------- 主入口 ----------

  /// 单轮对话，非流式。失败抛异常，调用方自己展示
  static Future<String> chat(AiConfig cfg, String userContent,
      {String? system, http.Client? client, Duration timeout = const Duration(seconds: 30)}) async {
    final c = client ?? http.Client();
    try {
      final uri = Uri.parse(buildEndpoint(cfg.format, cfg.baseUrl));
      if (!uri.hasScheme) {
        throw ArgumentError('API地址不合法: ${cfg.baseUrl}');
      }

      final Map<String, dynamic> body;
      switch (cfg.format) {
        case ApiFormat.chatCompletions:
          body = buildChatCompletionsBody(cfg.model, system, userContent);
        case ApiFormat.anthropicMessages:
          body = buildAnthropicBody(cfg.model, system, userContent);
        case ApiFormat.responses:
          body = buildResponsesBody(cfg.model, system, userContent);
      }

      final resp = await c
          .post(uri,
              headers: buildHeaders(cfg.format, cfg.apiKey), body: jsonEncode(body))
          .timeout(timeout);

      final j = _decodeBody(resp);

      switch (cfg.format) {
        case ApiFormat.chatCompletions:
          return parseChatCompletions(j);
        case ApiFormat.anthropicMessages:
          return parseAnthropic(j);
        case ApiFormat.responses:
          return parseResponses(j);
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

  static Map<String, dynamic> _decodeBody(http.Response resp) {
    if (resp.statusCode != 200) {
      var detail = '';
      try {
        final j = jsonDecode(utf8.decode(resp.bodyBytes));
        detail =
            (j['error']?['message'] ?? j['error']?['type'] ?? j['message'] ?? '').toString();
      } catch (_) {}
      throw Exception('HTTP ${resp.statusCode}${detail.isEmpty ? '' : ' · $detail'}');
    }
    return jsonDecode(utf8.decode(resp.bodyBytes));
  }
}
