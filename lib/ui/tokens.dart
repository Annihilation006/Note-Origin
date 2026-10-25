import 'package:flutter/material.dart';

/// 间距刻度，全局就这一套
class Sp {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 36.0;
  static const xxxl = 56.0;
}

/// 文字体系。
/// 没有引入外部字体：中文字体动辄十几兆、授权需要逐家核实、离线环境没法验证字形覆盖，
/// 引错不如不引。识别度靠字号字重和留白的节奏来做。
abstract final class Ty {
  // 首页大题
  static const display = TextStyle(
    fontSize: 44,
    height: 1.05,
    fontWeight: FontWeight.w200,
    letterSpacing: -1.5,
  );

  // 日期行，放在大题上面
  static const dateLine = TextStyle(fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.w500);

  // 分区标题
  static const section = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: .3, height: 1.4);

  // 特稿块标题（继续写那条）
  static const feature = TextStyle(fontSize: 21, fontWeight: FontWeight.w600, height: 1.4);

  // 正文
  static const body = TextStyle(fontSize: 15, height: 1.65);

  // 弱化的元信息
  static const meta = TextStyle(fontSize: 12, letterSpacing: .4, height: 1.4);

  // 数字（金额/计数）
  static const figure = TextStyle(fontSize: 25, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: -.5);
}
