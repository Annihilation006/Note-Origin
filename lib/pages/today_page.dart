import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/store.dart';
import '../models/models.dart';
import '../services/quote_service.dart';
import '../ui/tokens.dart';
import '../utils/fmt.dart';

/// 今日页。逐项对齐 Compose 版：
/// 氛围流动开场（沉浸状态栏）+ 大字排版 + 一言玻璃卡 + Metro色块条 + 最近列表。
class TodayPage extends StatefulWidget {
  final void Function(int tabIndex) onNavigate;

  const TodayPage({super.key, required this.onNavigate});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> with SingleTickerProviderStateMixin {
  late final AnimationController _flow;
  final QuoteProvider _quotes = LocalQuoteProvider();
  List<DayNote> _recent = [];

  @override
  void initState() {
    super.initState();
    // 26秒一轮，跟Compose节奏一致；系统关动画时由disableAnimations静止
    _flow = AnimationController(vsync: this, duration: const Duration(seconds: 26))..repeat();
    _loadRecent();
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final r = await Db.instance.recentNotes(limit: 4);
      if (mounted) setState(() => _recent = r);
    } catch (_) {}
  }

  static const _weekday = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final padTop = MediaQuery.of(context).padding.top;
    final animsOff = MediaQuery.of(context).disableAnimations;

    final expense = store.monthExpenseCny;
    final income = store.monthIncomeCny;
    final latest = _recent.isEmpty ? null : _recent.first;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 300 + padTop,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              child: AnimatedBuilder(
                animation: _flow,
                builder: (context, _) => CustomPaint(
                  painter: _AmbientPainter(
                    phase: animsOff ? 0.35 : _flow.value,
                    primary: cs.primary,
                    tertiary: cs.tertiary,
                    base: cs.surface,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Sp.l, Sp.s, Sp.l, Sp.xl),
              children: [
                Row(
                  children: [
                    Text(
                      '${now.month}月${now.day}日 星期${_weekday[now.weekday - 1]}',
                      style: Ty.dateLine.apply(color: cs.outline),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => widget.onNavigate(4),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('AI', style: const TextStyle(fontSize: 12, letterSpacing: .4, fontWeight: FontWeight.w600).apply(color: cs.primary)),
                      ),
                    ),
                    InkWell(
                      onTap: () => widget.onNavigate(3),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('设置', style: Ty.meta.apply(color: cs.outline)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.xs),
                const Text(
                  '今日',
                  style: TextStyle(fontSize: 42, height: 1.05, fontWeight: FontWeight.w200, letterSpacing: -1.5),
                ),
                const SizedBox(height: Sp.xl),
                FutureBuilder<Quote?>(
                  future: _quotes.pick(now),
                  builder: (context, snap) {
                    final q = snap.data;
                    if (q == null) return const SizedBox.shrink();
                    return _glassCard(
                      cs,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.text, style: Ty.body.apply(color: cs.onSurface)),
                          const SizedBox(height: Sp.xs),
                          Text(q.from, style: Ty.meta.apply(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: Sp.xxl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 58,
                      child: _massBlock(
                        cs.secondaryContainer,
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('本月支出',
                                  style: const TextStyle(fontSize: 12, height: 1.2)
                                      .apply(color: cs.onSecondaryContainer)),
                              const SizedBox(height: 2),
                              Text(
                                fmtMoney(expense),
                                style: const TextStyle(fontSize: 20, height: 1.2, fontWeight: FontWeight.w600)
                                    .apply(color: cs.onSecondaryContainer),
                              ),
                              Text(
                                '收入 ${fmtMoney(income)}',
                                style: const TextStyle(fontSize: 12, height: 1.2)
                                    .apply(color: cs.onSecondaryContainer.withValues(alpha: .75)),
                              ),
                              if (store.foreignSums.isNotEmpty)
                                Text(
                                  store.foreignSums.entries
                                      .map((e) => fmtMoney(e.value, currency: e.key))
                                      .join(' · '),
                                  style: const TextStyle(fontSize: 11, height: 1.2)
                                      .apply(color: cs.onSecondaryContainer.withValues(alpha: .6)),
                                ),
                            ],
                          ),
                        ),
                        onTap: () => widget.onNavigate(2),
                      ),
                    ),
                    const SizedBox(width: Sp.s),
                    Expanded(
                      flex: 42,
                      child: _massBlock(
                        cs.surfaceContainerHighest,
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('今天记了 ${store.todayTxnCount} 笔',
                                  style: Ty.meta.apply(color: cs.onSurfaceVariant)),
                              const SizedBox(height: 6),
                              Text('支出 ${fmtMoney(store.todayExpenseCents)}',
                                  style: Ty.meta.apply(color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        onTap: () => widget.onNavigate(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.xxl),
                Row(
                  children: [
                    Text('笔记', style: Ty.section.apply(color: cs.onSurface)),
                    const Spacer(),
                    TextButton(onPressed: () => widget.onNavigate(1), child: const Text('写笔记')),
                  ],
                ),
                if (latest == null)
                  _massBlock(
                    cs.surfaceContainer,
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('还没有写过。第一条从这里开始。',
                          style: Ty.body.apply(color: cs.onSurfaceVariant)),
                    ),
                  )
                else
                  _massBlock(
                    cs.surfaceContainer,
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(latest.content,
                              style: const TextStyle(fontSize: 21, height: 1.4, fontWeight: FontWeight.w600),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: Sp.xs),
                          Text('${latest.date} 的笔记', style: Ty.meta.apply(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    onTap: () => widget.onNavigate(1),
                  ),
                const SizedBox(height: Sp.xxl),
                Row(
                  children: [
                    Text('最近', style: Ty.section.apply(color: cs.onSurface)),
                    const Spacer(),
                    TextButton(onPressed: () => widget.onNavigate(1), child: const Text('全部')),
                  ],
                ),
                if (_recent.isEmpty)
                  Text('写点什么，都会留在这。', style: Ty.meta.apply(color: cs.outline))
                else
                  Column(
                    children: [
                      for (var i = 0; i < _recent.length; i++) ...[
                        InkWell(
                          onTap: () => widget.onNavigate(1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: Sp.m),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                SizedBox(
                                    width: 64,
                                    child: Text(_recent[i].date.substring(5),
                                        style: Ty.meta.apply(color: cs.outline))),
                                Expanded(
                                    child: Text(_recent[i].content,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Ty.body.apply(color: cs.onSurface))),
                              ],
                            ),
                          ),
                        ),
                        if (i != _recent.length - 1)
                          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: .4)),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: prefer_const_constructors_in_immutables
  Widget _glassCard(ColorScheme cs, Widget child) {
    // 玻璃配方：半透容器+高光渐变描边，与Compose GlassCard同参数
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(18),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: GradientBoxBorder(
          gradient: LinearGradient(
            colors: [
              cs.onSurface.withValues(alpha: .28),
              cs.onSurface.withValues(alpha: .04),
              cs.onSurface.withValues(alpha: .16),
            ],
          ),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _massBlock(Color bg, Widget child, {VoidCallback? onTap}) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: child,
      ),
    );
  }
}

class GradientBoxBorder extends BoxBorder {
  final LinearGradient gradient;
  GradientBoxBorder({required this.gradient});

  @override
  EdgeInsets get dimensions => const EdgeInsets.all(1);

  @override
  BorderSide get top => BorderSide.none;

  @override
  BorderSide get bottom => BorderSide.none;

  @override
  GradientBoxBorder scale(double t) => this;

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection, BorderRadius? borderRadius, BoxShape shape = BoxShape.rectangle}) {
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rr = borderRadius ?? const BorderRadius.all(Radius.circular(18));
    canvas.drawRRect(RRect.fromRectAndCorners(rect,
        topLeft: rr.topLeft, topRight: rr.topRight,
        bottomLeft: rr.bottomLeft, bottomRight: rr.bottomRight), paint);
  }

  @override
  void paintInterior(Canvas canvas, Rect rect, Paint paint, {TextDirection? textDirection}) {
    paint.shader = gradient.createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)), paint);
  }

  @override
  bool get isUniform => false;
}

class _AmbientPainter extends CustomPainter {
  final double phase;
  final Color primary;
  final Color tertiary;
  final Color base;

  _AmbientPainter({required this.phase, required this.primary, required this.tertiary, required this.base});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final w = size.width, h = size.height;
    final sweep = phase * 2 * math.pi;
    final c1 = Offset(w * (0.30 + 0.18 * math.sin(sweep)), h * (0.28 + 0.12 * math.cos(sweep)));
    final c2 = Offset(w * (0.74 + 0.14 * math.cos(sweep * 0.8)), h * (0.66 + 0.16 * math.sin(sweep * 1.1)));
    canvas.drawCircle(
        c1,
        w * 0.75,
        Paint()
          ..shader = RadialGradient(colors: [
            primary.withValues(alpha: .20),
            primary.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: c1, radius: w * 0.75)));
    canvas.drawCircle(
        c2,
        w * 0.65,
        Paint()
          ..shader = RadialGradient(colors: [
            tertiary.withValues(alpha: .16),
            tertiary.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: c2, radius: w * 0.65)));
  }

  @override
  bool shouldRepaint(_AmbientPainter old) =>
      old.phase != phase || old.primary != primary || old.tertiary != tertiary;
}
