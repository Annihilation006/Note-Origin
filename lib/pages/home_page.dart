import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../utils/fmt.dart';
import 'add_txn_page.dart';

/// 首页：月份切换 + 收支概览 + 按天分组的流水列表
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cs = Theme.of(context).colorScheme;

    final grouped = store.txnsGroupedByDay();
    final expense = store.monthExpenseCents;
    final income = store.monthIncomeCents;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: store.prevMonth,
            ),
            Text('${store.month.year}年${store.month.month}月'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: store.nextMonth,
            ),
          ],
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // 记完一笔回来刷新，add页里面自己会调store
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddTxnPage()),
          );
        },
        icon: const Icon(Icons.edit_note),
        label: const Text('记一笔'),
      ),
      body: store.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                // 概览卡
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('支出', style: TextStyle(color: cs.outline)),
                              const SizedBox(height: 4),
                              Text(
                                fmtMoney(expense),
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold, color: cs.error),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('收入', style: TextStyle(color: cs.outline)),
                              const SizedBox(height: 4),
                              Text(
                                fmtMoney(income),
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold, color: cs.primary),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('结余', style: TextStyle(color: cs.outline)),
                              const SizedBox(height: 4),
                              Text(
                                fmtMoney(income - expense),
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: (income - expense) >= 0 ? cs.tertiary : cs.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (grouped.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('这个月还没有记录～', style: TextStyle(color: Colors.grey))),
                  ),
                for (final entry in grouped.entries) _daySection(context, store, entry.key, entry.value),
              ],
            ),
    );
  }

  Widget _daySection(BuildContext context, AppStore store, String date, List<Txn> txns) {
    var dayExp = 0;
    for (final t in txns) {
      if (t.type == 0) dayExp += t.amountCents;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('支出 ${fmtMoney(dayExp)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        for (final t in txns)
          ListTile(
            leading: Text(
              store.catById[t.categoryId]?.icon ?? '❓',
              style: const TextStyle(fontSize: 24),
            ),
            title: Text(store.catById[t.categoryId]?.name ?? '已删除分类'),
            subtitle: (t.note as String).isEmpty
                ? null
                : Text(t.note, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(
              '${t.type == 0 ? '-' : '+'}${fmtMoney(t.amountCents)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: t.type == 0 ? null : Theme.of(context).colorScheme.primary,
              ),
            ),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AddTxnPage(editing: t),
              ));
            },
            onLongPress: () {
              // 长按删除，二话不说弹确认
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('删除这条记录？'),
                  content: const Text('删了就找不回来了'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                    FilledButton(
                      onPressed: () {
                        store.deleteTxn(t.id!);
                        Navigator.pop(ctx);
                      },
                      child: const Text('删除'),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
