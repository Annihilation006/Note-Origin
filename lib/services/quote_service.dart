/// 每日一句。
/// Provider抽象留着，以后接一言或自建服务实现一个就行，首页不用动。
library;

class Quote {
  final String text;
  final String from;

  const Quote(this.text, this.from);
}

abstract class QuoteProvider {
  /// 传日期进来，同一个自然日返回同一条，别每帧变
  Future<Quote?> pick(DateTime day);
}

/// 本地兜底的句子池。短句，中文为主
class LocalQuoteProvider implements QuoteProvider {
  static const _pool = [
    Quote('生活是种律动，须有光有影，有左有右，有晴有雨。', '老舍'),
    Quote('凡是过往，皆为序章。', '莎士比亚'),
    Quote('凌晨四点钟，看到海棠花未眠。', '川端康成'),
    Quote('从前的日色变得慢，车、马、邮件都慢。', '木心'),
    Quote('满地都是六便士，他却抬头看见了月亮。', '毛姆'),
    Quote('我们都在阴沟里，但仍有人仰望星空。', '王尔德'),
    Quote('日日重复同样的事，遵循着与昨日相同的惯例。', '太宰治'),
  ];

  @override
  Future<Quote?> pick(DateTime day) async {
    // 按年内第几天取模，一天一条稳定的
    final start = DateTime(day.year, 1, 1);
    final dayOfYear = day.difference(start).inDays;
    if (dayOfYear < 0) return null; // 日期不对就算了
    return _pool[dayOfYear % _pool.length];
  }
}
