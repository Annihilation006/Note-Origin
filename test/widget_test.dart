import 'package:flutter_test/flutter_test.dart';

import 'package:note_origin/main.dart';

void main() {
  testWidgets('首页渲染出今日开场', (WidgetTester tester) async {
    await tester.pumpWidget(const NoteOriginApp());

    expect(find.text('今日'), findsWidgets); // 大题和导航标签各一个
  });
}
