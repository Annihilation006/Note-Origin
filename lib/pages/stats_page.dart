import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/store.dart';
import '../services/ai_service.dart';
import '../utils/fmt.dart';

/// 统计页：分类饼图 + 每日柱状 + 分类排行 + AI月报
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cs = Theme.of(context).colorScheme;
    final byCat = store.expenseByCategory();
    final daily = store.dailyExpenseSeries();
    final total = store.monthExpenseCents;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: store.prevMonth),
            Text('${store.month.year}年${store.month.month}月'),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: store.nextMonth),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'AI 月报',
            onPressed: () => _aiReport(context, store),
          ),
        ],
      ),
      body: store.monthTxns.isEmpty
          ? const Center(child: Text('本月暂无数据', style: TextStyle(color: Colors.grey)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(
                  height: 220,
                  child: byCat.isEmpty
                      ? const Center(child: Text('本月没有支出'))
                      : PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 44,
                            sections: _pieSections(context, byCat, total),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                if (byCat.isNotEmpty)
                  Text('支出构成 · 共 ${fmtMoney(total)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                Text('每日支出', style: TextStyle(color: cs.outline, fontSize: 13)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (v, _) {
                              // 隔几天标一个，不然挤成狗
                              final i = v.toInt();
                              if (i % 5 != 0 && i != daily.length - 1) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('${i + 1}', style: const TextStyle(fontSize: 10)),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < daily.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: daily[i] / 100.0,
                                width: 8,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('分类排行', style: TextStyle(color: cs.outline, fontSize: 13)),
                for (var i = 0; i < byCat.length; i++)
                  ListTile(
                    dense: true,
                    leading: SizedBox(
                      width: 60,
                      child: Text('${byCat[i].key?.icon ?? '❓'} ${byCat[i].key?.name ?? '?'}',
                          overflow: TextOverflow.ellipsis),
                    ),
                    title: LinearProgressIndicator(
                      value: total <= 0 ? 0 : byCat[i].value / total,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    trailing: Text(fmtMoney(byCat[i].value)),
                  ),
              ],
            ),
    );
  }

  List<PieChartSectionData> _pieSections(
      BuildContext ctx, List<MapEntry<dynamic, int>> byCat, int total) {
    // 颜色就按顺序给，不搞语义化映射了
    const palette = [
      Color(0xFF4F6CF5), Color(0xFFEF6C00), Color(0xFF43A047), Color(0xFFE53935),
      Color(0xFF8E24AA), Color(0xFF00ACC1), Color(0xFFFDD835), Color(0xFF6D4C41),
      Color(0xFF546E7A), Color(0xFFD81B60),
    ];
    final out = <PieChartSectionData>[];
    for (var i = 0; i < byCat.length && i < palette.length; i++) {
      final e = byCat[i];
      final ratio = total <= 0 ? 0.0 : e.value / total;
      out.add(PieChartSectionData(
        value: e.value / 100.0,
        color: palette[i % palette.length],
        title: ratio >= 0.08 ? '${(ratio * 100).toStringAsFixed(0)}%' : '',
        radius: 22 + (i == 0 ? 8 : 0),
      ));
    }
    return out;
  }

  Future<void> _aiReport(BuildContext context, AppStore store) async {
    final cfg = await AiConfig.load();
    if (!cfg.ready) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先去设置里填 API Key')),
      );
      return;
    }
    if (store.monthTxns.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本月没有账单数据')),
      );
      return;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('AI正在看你的账单…'),
          ],
        ),
      ),
    );

    try {
      final bill = buildMonthSummaryText(store.month.year, store.month.month, store.monthTxns);
      final reply = await AiService.chat(
        cfg,
        bill,
        system: '你是一个个人财务助手。根据用户的月度账单，用简洁的中文给出：1)消费习惯总结 '
            '2)2-3条省钱建议 3)下月预算建议金额。控制在300字内，别客套。',
      );
      if (!context.mounted) return;
      Navigator.pop(context); // 关loading
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI 月报'),
          content: SingleChildScrollView(child: Text(reply)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('好的')),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI请求失败: $e')),
      );
    }
  }
}
