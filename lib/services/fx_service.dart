import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 汇率。fawazahmed0/currency-api：免费无Key，CDN直发，按日更新。
/// 结构: {"date":"2026-10-25","cny":{"usd":0.14,...}}
/// 我们统一以CNY为基准：1 CNY = rate[c] 外币；折算时 外币金额 / rate[c] = CNY。
class FxRate {
  final String date;
  final Map<String, double> perCny; // code -> 1 CNY 兑多少该币

  FxRate(this.date, this.perCny);

  /// 外币金额折CNY。没汇率返回null，让调用方走降级
  double? toCny(int cents, String code) {
    if (code == 'CNY') return cents / 100.0;
    final r = perCny[code];
    if (r == null || r == 0) return null;
    return cents / 100.0 / r;
  }

  static const supported = ['USD', 'EUR', 'GBP', 'JPY', 'KRW', 'HKD'];
}

class FxService {
  static const _cacheKey = 'fx_cache';
  static const _cacheDateKey = 'fx_cache_date';
  static FxRate? _memory;

  /// 内存命中 -> 当日缓存 -> 网络 -> 旧缓存兜底。全失败返回null
  static Future<FxRate?> load() async {
    final m = _memory;
    if (m != null && m.date == _today()) return m;

    try {
      final sp = await SharedPreferences.getInstance();
      final cachedDate = sp.getString(_cacheDateKey);
      if (cachedDate != null && cachedDate == _today()) {
        final raw = sp.getString(_cacheKey);
        if (raw != null) {
          _memory = _parse(cachedDate, raw);
          return _memory;
        }
      }
    } catch (_) {}

    try {
      final resp = await http
          .get(Uri.parse('https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/cny.json'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final body = utf8.decode(resp.bodyBytes);
        _memory = _parse(_today(), body);
        try {
          final sp = await SharedPreferences.getInstance();
          await sp.setString(_cacheKey, body);
          await sp.setString(_cacheDateKey, _today());
        } catch (_) {}
        return _memory;
      }
    } catch (_) {
      // 主CDN挂了试备用域名
      try {
        final resp = await http
            .get(Uri.parse('https://latest.currency-api.pages.dev/v1/currencies/cny.json'))
            .timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) {
          final body = utf8.decode(resp.bodyBytes);
          _memory = _parse(_today(), body);
          return _memory;
        }
      } catch (_) {}
    }

    // 网络全挂，拿旧缓存凑合（汇率按日变，旧一天影响很小）
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_cacheKey);
      final d = sp.getString(_cacheDateKey);
      if (raw != null && d != null) {
        _memory = _parse(d, raw);
        return _memory;
      }
    } catch (_) {}
    return null;
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static FxRate _parse(String date, String body) {
    final j = jsonDecode(body);
    final date2 = (j['date'] ?? date).toString();
    final cny = (j['cny'] as Map?) ?? const {};
    final out = <String, double>{};
    for (final code in FxRate.supported) {
      final v = cny[code.toLowerCase()];
      if (v is num && v > 0) out[code] = v.toDouble();
    }
    return FxRate(date2, out);
  }
}
