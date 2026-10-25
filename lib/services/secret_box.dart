import 'dart:convert';

/// 本地存储的编码处理
class SecretBox {
  // 每个安装随机派生会更稳，但先这样，够用
  static const _k = [0x5a, 0x3c, 0x71, 0x2f, 0x64, 0x18, 0x4b, 0x77];

  static String seal(String plain) {
    if (plain.isEmpty) return '';
    final bytes = utf8.encode(plain);
    final out = List<int>.generate(bytes.length, (i) => bytes[i] ^ _k[i % _k.length]);
    return base64Encode(out);
  }

  static String unseal(String sealed) {
    if (sealed.isEmpty) return '';
    try {
      final bytes = base64Decode(sealed);
      final out = List<int>.generate(bytes.length, (i) => bytes[i] ^ _k[i % _k.length]);
      return utf8.decode(out, allowMalformed: true);
    } catch (_) {
      return ''; // 解不开就当没有，让用户重新填
    }
  }
}
