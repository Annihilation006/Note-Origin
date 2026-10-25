/// 每日一句。一言(hitokoto.cn)优先，挂了走本地句池。
/// Provider抽象保留，以后换源实现一个就行，首页不用动。
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

class Quote {
  final String text;
  final String from;

  const Quote(this.text, this.from);
}

abstract class QuoteProvider {
  Future<Quote?> pick(DateTime day);
}

/// 一言 https://v1.hitokoto.cn
class HitokotoProvider implements QuoteProvider {
  final http.Client? client;

  HitokotoProvider({this.client});

  @override
  Future<Quote?> pick(DateTime day) async {
    final c = client ?? http.Client();
    try {
      // maxlength卡一下，太长的句子放首页排版会炸
      final resp = await c
          .get(Uri.parse('https://v1.hitokoto.cn/?encode=json&maxlength=36'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(resp.bodyBytes));
      final text = (j['hitokoto'] ?? '').toString().trim();
      if (text.isEmpty) return null; // 空响应当失败处理

      final who = (j['from_who'] ?? '').toString().trim();
      final src = (j['from'] ?? '').toString().trim();
      String from;
      if (who.isNotEmpty && src.isNotEmpty) {
        from = '$who《$src》';
      } else if (who.isNotEmpty) {
        from = who;
      } else if (src.isNotEmpty) {
        from = '《$src》';
      } else {
        from = '一言';
      }
      return Quote(text, from);
    } catch (_) {
      return null; // 超时/断网/解析失败，统统走本地兜底
    } finally {
      if (client == null) c.close();
    }
  }
}

/// 本地兜底的句子池。短句为主
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
    if (dayOfYear < 0) return null;
    return _pool[dayOfYear % _pool.length];
  }
}

/// 门面：先试远程，不行就本地
class QuoteService {
  QuoteService({QuoteProvider? remote}) : _remote = remote ?? HitokotoProvider();

  final QuoteProvider _remote;
  final _local = LocalQuoteProvider();

  Future<Quote?> quoteFor(DateTime day) async {
    try {
      final r = await _remote.pick(day);
      if (r != null) return r;
    } catch (_) {}
    return _local.pick(day);
  }
}
