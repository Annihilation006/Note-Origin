import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/store.dart';
import '../models/models.dart';
import '../services/quote_service.dart';
import '../ui/tokens.dart';
import '../utils/fmt.dart';

/// 首页。编辑部式的开场，信息从用户真实数据来，没有东西就不硬凑
class TodayPage extends StatefulWidget {
  final void Function(int tabIndex) onNavigate;

  const TodayPage({super.key, required this.onNavigate});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final _quotes = QuoteService();
  List<DayNote> _recent = [];
  Future<Quote?>? _quoteFuture;
  int _todayNoteCount = 0;

  @override
  void initState() {
    super.initState();
    // future放initState里建好，别在build里反复发请求
    _quoteFuture = _quotes.quoteFor(DateTime.now());
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    try {
      final r = await Db.instance.recentNotes(limit: 4);
      final today = await Db.instance.notesOfDate(todayStr());
      if (mounted) {
        setState(() {
          _recent = r;
          _todayNoteCount = today.length;
        });
      }
    } catch (_) {
      // 首页列表加载失败就空着，不打扰
    }
  }

  static const _weekday = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Sp.l, Sp.xxl, Sp.l, Sp.xl),
          children: [
            // ---- 开场 ----
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${now.month}月${now.day}日 星期${_weekday[now.weekday - 1]}',
                    style: Ty.dateLine.apply(color: cs.outline),
                  ),
                  const SizedBox(height: Sp.xs),
                  Text('今日', style: Ty.display.apply(color: cs.onSurface)),
                ],
              ),
            ),
            const SizedBox(height: Sp.xl),

            // ---- 每日一句 ----
            FutureBuilder<Quote?>(
              future: _quoteFuture,
              builder: (context, snap) {
                final q = snap.data;
                if (q == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.text, style: Ty.body.apply(color: cs.onSurfaceVariant)),
                    const SizedBox(height: Sp.xs),
                    Text(q.from, style: Ty.meta.apply(color: cs.outline)),
                  ],
                );
              },
            ),
            const SizedBox(height: Sp.xxl),

            // ---- 写这条 / 继续写 ----
            _writingSection(cs, store),
            const SizedBox(height: Sp.xxl),

            // ---- 支出条（Metro，但不做均匀卡片阵） ----
            _moneyBand(cs, store),
            const SizedBox(height: Sp.xxl),

            // ---- 最近笔记 ----
            _recentSection(cs),
          ],
        ),
      ),
    );
  }

  Widget _writingSection(ColorScheme cs, AppStore store) {
    final latest = _recent.isEmpty ? null : _recent.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('笔记', style: Ty.section.apply(color: cs.onSurface))),
            TextButton(
              onPressed: () => widget.onNavigate(1),
              child: const Text('写笔记'),
            ),
          ],
        ),
        if (latest == null)
          Padding(
            padding: const EdgeInsets.only(top: Sp.s, bottom: Sp.s),
            child: Text('还没有写过。第一条从这里开始。',
                style: Ty.body.apply(color: cs.outline)),
          )
        else
          InkWell(
            onTap: () => widget.onNavigate(1),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Sp.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    latest.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.feature.apply(color: cs.onSurface),
                  ),
                  const SizedBox(height: Sp.xs),
                  Text('${latest.date} 的笔记', style: Ty.meta.apply(color: cs.outline)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _moneyBand(ColorScheme cs, AppStore store) {
    // 7:5两块，不等宽。左边大数字，右边两个小计数
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 7,
            child: InkWell(
              onTap: () => widget.onNavigate(2),
              child: Container(
                padding: const EdgeInsets.all(Sp.l),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('本月支出', style: Ty.meta.apply(color: cs.onSecondaryContainer)),
                    const SizedBox(height: Sp.xs),
                    Text(
                      fmtMoney(store.monthExpenseCents),
                      style: Ty.figure.apply(color: cs.onSecondaryContainer),
                    ),
                    const SizedBox(height: Sp.xs),
                    Text(
                      '收入 ${fmtMoney(store.monthIncomeCents)}',
                      style: Ty.meta.apply(color: cs.onSecondaryContainer.withValues(alpha: .7)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: Sp.s),
          Expanded(
            flex: 5,
            child: InkWell(
              onTap: () => widget.onNavigate(2),
              child: Container(
                padding: const EdgeInsets.all(Sp.l),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text('今天记了 ${store.todayTxnCount} 笔',
                        style: Ty.meta.apply(color: cs.onSurfaceVariant)),
                    Text('今天 $_todayNoteCount 条笔记',
                        style: Ty.meta.apply(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('最近', style: Ty.section.apply(color: cs.onSurface))),
            TextButton(
              onPressed: () => widget.onNavigate(1),
              child: const Text('全部'),
            ),
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
                              style: Ty.meta.apply(color: cs.outline)),
                        ),
                        Expanded(
                          child: Text(
                            _recent[i].content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ty.body.apply(color: cs.onSurface),
                          ),
                        ),
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
    );
  }
}
