import 'package:flutter_test/flutter_test.dart';
import 'package:note_origin/services/ai_service.dart';
import 'package:note_origin/services/secret_box.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('buildEndpoint 拼接', () {
    test('base不带/v1 → 补版本+路径', () {
      expect(
        AiService.buildEndpoint(ApiFormat.chatCompletions, 'https://api.xxx.com'),
        'https://api.xxx.com/v1/chat/completions',
      );
      expect(
        AiService.buildEndpoint(ApiFormat.anthropicMessages, 'https://api.anthropic.com'),
        'https://api.anthropic.com/v1/messages',
      );
      expect(
        AiService.buildEndpoint(ApiFormat.responses, 'https://api.openai.com'),
        'https://api.openai.com/v1/responses',
      );
    });

    test('base已带/v1 → 不重复补', () {
      expect(
        AiService.buildEndpoint(ApiFormat.chatCompletions, 'https://api.xxx.com/v1'),
        'https://api.xxx.com/v1/chat/completions',
      );
      expect(
        AiService.buildEndpoint(ApiFormat.anthropicMessages, 'https://gw.xxx.com/v1'),
        'https://gw.xxx.com/v1/messages',
      );
      expect(
        AiService.buildEndpoint(ApiFormat.responses, 'https://api.xxx.com/v1'),
        'https://api.xxx.com/v1/responses',
      );
    });

    test('base已是完整接口路径 → 不再追加', () {
      expect(
        AiService.buildEndpoint(
            ApiFormat.chatCompletions, 'https://api.xxx.com/v1/chat/completions'),
        'https://api.xxx.com/v1/chat/completions',
      );
      expect(
        AiService.buildEndpoint(ApiFormat.anthropicMessages, 'https://api.xxx.com/v1/messages'),
        'https://api.xxx.com/v1/messages',
      );
    });

    test('尾斜杠和反代前缀', () {
      expect(
        AiService.buildEndpoint(ApiFormat.chatCompletions, 'https://api.xxx.com/v1/'),
        'https://api.xxx.com/v1/chat/completions',
      );
      expect(
        AiService.buildEndpoint(ApiFormat.chatCompletions, 'https://api.xxx.com/v1///'),
        'https://api.xxx.com/v1/chat/completions',
      );
      // 反代带路径前缀的，前缀保留
      expect(
        AiService.buildEndpoint(ApiFormat.chatCompletions, 'https://gw.xxx.com/proxy/api'),
        'https://gw.xxx.com/proxy/api/v1/chat/completions',
      );
    });
  });

  group('请求体', () {
    test('chatCompletions用messages', () {
      final b = AiService.buildChatCompletionsBody('m1', '你是助手', '你好');
      expect(b['messages'], [
        {'role': 'system', 'content': '你是助手'},
        {'role': 'user', 'content': '你好'},
      ]);
      expect(b['max_tokens'], 1024);
      expect(b.containsKey('input'), false);
    });

    test('anthropic的system在顶层且必填max_tokens', () {
      final b = AiService.buildAnthropicBody('claude-x', '你是助手', '你好');
      expect(b['system'], '你是助手');
      expect(b['max_tokens'], 1024);
      expect(b['messages'], [
        {'role': 'user', 'content': '你好'},
      ]);
      // 没有system时不应出现空字段
      final b2 = AiService.buildAnthropicBody('claude-x', null, '你好');
      expect(b2.containsKey('system'), false);
    });

    test('responses用input/instructions，不带messages', () {
      final b = AiService.buildResponsesBody('gpt-4o', '你是助手', '你好');
      expect(b['input'], '你好');
      expect(b['instructions'], '你是助手');
      expect(b['max_output_tokens'], 1024);
      expect(b.containsKey('messages'), false);
      final b2 = AiService.buildResponsesBody('gpt-4o', null, '你好');
      expect(b2.containsKey('instructions'), false);
    });
  });

  group('请求头', () {
    test('anthropic用x-api-key，其余用Bearer', () {
      final a = AiService.buildHeaders(ApiFormat.anthropicMessages, 'sk-1');
      expect(a['x-api-key'], 'sk-1');
      expect(a['anthropic-version'], '2023-06-01');
      expect(a.containsKey('Authorization'), false);

      final o = AiService.buildHeaders(ApiFormat.chatCompletions, 'sk-1');
      expect(o['Authorization'], 'Bearer sk-1');
      final r = AiService.buildHeaders(ApiFormat.responses, 'sk-1');
      expect(r['Authorization'], 'Bearer sk-1');
    });
  });

  group('响应解析', () {
    test('chatCompletions', () {
      const j = {
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'hello'}
          }
        ]
      };
      expect(AiService.parseChatCompletions(j), 'hello');
    });

    test('anthropic多个text块拼接', () {
      const j = {
        'content': [
          {'type': 'text', 'text': 'a'},
          {'type': 'text', 'text': 'b'},
        ],
        'stop_reason': 'end_turn',
      };
      expect(AiService.parseAnthropic(j), 'ab');
    });

    test('responses取output里的output_text', () {
      const j = {
        'status': 'completed',
        'output': [
          {'type': 'reasoning', 'summary': []},
          {
            'type': 'message',
            'role': 'assistant',
            'content': [
              {'type': 'output_text', 'text': '答案是42'}
            ]
          },
        ],
      };
      expect(AiService.parseResponses(j), '答案是42');
    });

    test('空回复抛异常并带状态信息', () {
      expect(() => AiService.parseResponses({'status': 'incomplete', 'output': []}),
          throwsException);
      expect(() => AiService.parseAnthropic({'content': [], 'stop_reason': 'max_tokens'}),
          throwsException);
    });
  });

  group('旧配置迁移', () {
    test('gemini旧值回落到chatCompletions且其它配置保留', () async {
      SharedPreferences.setMockInitialValues({
        'ai_format': 'gemini',
        'ai_base_url': 'https://keep.me/v1',
        'ai_model': 'gemini-2.5-flash',
        'ai_api_key': SecretBox.seal('sk-legacy'),
      });
      final cfg = await AiConfig.load();
      expect(cfg.format, ApiFormat.chatCompletions);
      expect(cfg.baseUrl, 'https://keep.me/v1');
      expect(cfg.model, 'gemini-2.5-flash');
      expect(cfg.apiKey, 'sk-legacy');
    });

    test('openai/anthropic旧名照常映射', () async {
      SharedPreferences.setMockInitialValues({'ai_format': 'anthropic'});
      final cfg = await AiConfig.load();
      expect(cfg.format, ApiFormat.anthropicMessages);

      SharedPreferences.setMockInitialValues({'ai_format': 'openai'});
      final cfg2 = await AiConfig.load();
      expect(cfg2.format, ApiFormat.chatCompletions);
    });

    test('没有format字段的远古配置默认chatCompletions', () async {
      SharedPreferences.setMockInitialValues({});
      final cfg = await AiConfig.load();
      expect(cfg.format, ApiFormat.chatCompletions);
      expect(cfg.baseUrl, 'https://api.siliconflow.cn/v1');
    });
  });
}
