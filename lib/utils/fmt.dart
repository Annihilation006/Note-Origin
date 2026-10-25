import '../models/models.dart';

/// 零碎的格式化函数都扔这
library;

String fmtMoney(int cents, {bool symbol = true}) {
  final neg = cents < 0;
  final v = (cents.abs()) / 100.0;
  var s = v.toStringAsFixed(2);
  // 千分位，金额大点看着舒服
  final parts = s.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    final remaining = intPart.length - i;
    buf.write(intPart[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      // 只有超过4位才需要逗号
      if (remaining > 3) buf.write(',');
    }
  }
  s = buf.toString();
  if (parts.length > 1) s += '.${parts[1]}';
  return '${neg ? '-' : ''}${symbol ? '¥' : ''}$s';
}

/// 解析用户输入的金额字符串成分。解析不了返回null，让上层提示。
int? parseMoneyToCents(String input) {
  final s = input.trim().replaceAll(RegExp(r'[,\s]'), '');
  if (s.isEmpty) return null;
  final d = double.tryParse(s);
  if (d == null || d < 0) return null;
  if (d > 9999999999) return null; // 别输个天文数字把库搞炸
  return (d * 100).round();
}

String todayStr([DateTime? now]) {
  final d = now ?? DateTime.now();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

String ymOf(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

/// 首页列表用，把txns转成给AI的月度账单文本
String buildMonthSummaryText(int year, int month, List<Txn> txns) {
  final buf = StringBuffer();
  buf.writeln('$year年$month月账单：');
  var expense = 0, income = 0;
  for (final t in txns) {
    if (t.type == 0) {
      expense += t.amountCents;
    } else {
      income += t.amountCents;
    }
  }
  buf.writeln('总支出：${fmtMoney(expense)}，总收入：${fmtMoney(income)}');
  buf.writeln('明细（日期 | 类型 | 金额 | 备注）：');
  for (final t in txns.take(200)) {
    // 太长模型也看不完，截200条
    final typeStr = t.type == 0 ? '支出' : '收入';
    final notePart = t.note.isEmpty ? '' : ' | ${t.note}';
    buf.writeln('${t.date} | $typeStr | ${fmtMoney(t.amountCents)}$notePart');
  }
  return buf.toString();
}
