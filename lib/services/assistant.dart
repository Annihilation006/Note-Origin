import 'dart:convert';

/// AI操作代理，跟Compose版Assistant.kt同协议
sealed class AssistantAction {}

class AddTxnAction extends AssistantAction {
  final int type; // 0支出 1收入
  final int amountCents;
  final String date;
  final String categoryName;
  final String? accountName;
  final String note;
  final String currency;

  AddTxnAction(this.type, this.amountCents, this.date, this.categoryName, this.accountName, this.note, this.currency);
}

class AddNoteAction extends AssistantAction {
  final String date;
  final String content;

  AddNoteAction(this.date, this.content);
}

class ReplyAction extends AssistantAction {
  final String text;

  ReplyAction(this.text);
}

class Assistant {
  static String systemPrompt(String today, List<String> categories, List<String> accounts) {
    return '''
你是一个记账与笔记应用里的操作助手。今天是 $today。
用户会用自然语言让你记账、写笔记或查账。你必须只回复一个JSON对象，不要任何多余文字、不要markdown代码块标记。

可用分类名: ${categories.join('、')}
可用账户名: ${accounts.join('、')}

动作定义：
1) 记账: {"action":"add_txn","type":"expense"或"income","amount":数字单位元,"date":"YYYY-MM-DD","category":"分类名","account":"账户名","note":"备注","currency":"CNY"}
   - 金额从用户话里解析，"25"或"25块"=25元；提到美元用USD、欧元EUR、英镑GBP、日元JPY、韩元KRW、港币HKD
   - date用户说"今天"就用$today，"昨天"用前一天
   - category必须从可用列表里选最贴近的；account可选，不确定就省略
2) 写笔记: {"action":"add_note","date":"YYYY-MM-DD","content":"笔记正文"}
   - content按用户口吻整理成1-3句话
3) 查账/闲聊: {"action":"reply","text":"回答文字"}

只输出JSON。数字金额不要带单位。
''';
  }

  /// 容错解析：模型爱包壳，抠出第一个{...}
  static Map<String, dynamic>? extractJson(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      s = s.replaceAll('```json', '').replaceAll('```', '').trim();
    }
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      return jsonDecode(s.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static AssistantAction interpret(String raw, List<String> categories, DateTime now) {
    final j = extractJson(raw);
    if (j == null) return ReplyAction(raw.trim());
    final today = DateTime(now.year, now.month, now.day);
    String dateOr(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    switch (j['action']) {
      case 'add_txn':
        final amount = (j['amount'] as num?)?.toDouble() ?? -1;
        if (amount <= 0) return ReplyAction('金额没解析出来，说清楚一点，比如"午饭25块"');
        final type = j['type'] == 'income' ? 1 : 0;
        final cat = (j['category'] ?? '').toString().trim();
        final matched = categories.firstWhere(
          (c) => c.toLowerCase() == cat.toLowerCase() || c.contains(cat) || cat.contains(c),
          orElse: () => type == 0 ? '其他' : '其他收入',
        );
        final rawCur = (j['currency'] ?? 'CNY').toString().toUpperCase();
        const known = ['CNY', 'USD', 'EUR', 'GBP', 'JPY', 'KRW', 'HKD'];
        final currency = known.contains(rawCur) ? rawCur : 'CNY';
        var date = (j['date'] ?? '').toString();
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) date = dateOr(today);
        return AddTxnAction(
          type, (amount * 100).round(), date, matched,
          (j['account'] ?? '').toString().trim().isEmpty ? null : j['account'].toString(),
          (j['note'] ?? '').toString().trim(), currency,
        );
      case 'add_note':
        final content = (j['content'] ?? '').toString().trim();
        if (content.isEmpty) return ReplyAction('笔记内容是空的');
        var date = (j['date'] ?? '').toString();
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) date = dateOr(today);
        return AddNoteAction(date, content);
      default:
        return ReplyAction((j['text'] ?? raw).toString().trim());
    }
  }

  static String userPayload(String input, String monthExpense, int txnCount) {
    return '用户输入：$input\n\n（当前月支出 $monthExpense，共 $txnCount 笔，供参考）';
  }
}
