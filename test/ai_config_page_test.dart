import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_origin/pages/settings_page.dart';
import 'package:note_origin/services/ai_service.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, AiConfig cfg) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AiConfigPage(cfg: cfg))));
  }

  testWidgets('三个协议选项齐全', (tester) async {
    await pumpPage(tester, AiConfig());
    expect(find.text('ChatCompletions'), findsOneWidget);
    expect(find.text('AnthropicMessages'), findsOneWidget);
    expect(find.text('Responses'), findsOneWidget);
  });

  testWidgets('切协议只换hint，已填的地址/模型/key不动', (tester) async {
    final cfg = AiConfig()
      ..baseUrl = 'https://aqua.relay.com/v1'
      ..apiKey = 'sk-keep'
      ..model = 'gpt-test';

    await pumpPage(tester, cfg);

    // 先填一个自定义地址
    await tester.enterText(
      find.widgetWithText(TextField, 'API Base URL'),
      'https://my.proxy.com/v1',
    );
    await tester.pump();

    // 切到AnthropicMessages
    await tester.tap(find.text('AnthropicMessages'));
    await tester.pumpAndSettle();

    // hint换成无/v1的形态
    expect(find.text('https://api.xxx.com'), findsOneWidget);
    // 之前填的地址还在
    expect(find.text('https://my.proxy.com/v1'), findsOneWidget);
    // 模型和key没被动过
    expect(find.text('sk-keep'), findsOneWidget);
    expect(find.text('gpt-test'), findsOneWidget);

    // 切回ChatCompletions，hint带/v1
    await tester.tap(find.text('ChatCompletions'));
    await tester.pumpAndSettle();
    expect(find.text('https://api.xxx.com/v1'), findsWidgets);
    expect(find.text('https://my.proxy.com/v1'), findsOneWidget);
  });

  testWidgets('默认协议是ChatCompletions', (tester) async {
    final cfg = AiConfig();
    await pumpPage(tester, cfg);
    // 默认hint应该带/v1
    expect(find.text('https://api.xxx.com/v1'), findsWidgets);
  });
}
