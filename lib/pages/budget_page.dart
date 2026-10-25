import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../utils/fmt.dart';

/// 预算页：总预算 + 各分类预算，本月进度
class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cs = Theme.of(context).colorScheme;
    final totalBudget = store.budgetOf(0)?.amountCents ?? 0;
    final spent = store.monthExpenseCny;
    final over = totalBudget > 0 && spent > totalBudget;

    return Scaffold(
      appBar: AppBar(title: const Text('预算')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: over ? cs.errorContainer : cs.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('本月总预算', style: TextStyle(color: cs.outline)),
                  const SizedBox(height: 6),
                  Text(
                    totalBudget > 0 ? fmtMoney(totalBudget) : '未设置',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (totalBudget > 0) ...[
                    LinearProgressIndicator(
                      value: (spent / totalBudget).clamp(0.0, 1.0),
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      over
                          ? '已超支 ${fmtMoney(spent - totalBudget)} 💥'
                          : '已用 ${fmtMoney(spent)} / 剩余 ${fmtMoney(totalBudget - spent)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _editBudget(context, store, 0),
                    child: Text(totalBudget > 0 ? '修改总预算' : '设置总预算'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('分类预算', style: TextStyle(color: cs.outline, fontSize: 13)),
          const SizedBox(height: 4),
          for (final entry in store.expenseByCategory())
            ListTile(
              leading: Text(entry.key?.icon ?? '❓', style: const TextStyle(fontSize: 22)),
              title: Text(entry.key?.name ?? '?'),
              subtitle: _catProgress(store, entry),
              trailing: Text(
                store.budgetOf(entry.key?.id ?? -1) == null
                    ? '未设置'
                    : fmtMoney(store.budgetOf(entry.key!.id!)!.amountCents),
                style: const TextStyle(fontSize: 13),
              ),
              onTap: () => _editBudget(context, store, entry.key?.id ?? 0),
            ),
        ],
      ),
    );
  }

  Widget? _catProgress(AppStore store, MapEntry<dynamic, int> entry) {
    final b = store.budgetOf(entry.key?.id ?? -1);
    if (b == null || b.amountCents <= 0) return null;
    final ratio = (entry.value / b.amountCents).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 5,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Future<void> _editBudget(BuildContext context, AppStore store, int categoryId) async {
    final ctrl = TextEditingController(
      text: ((store.budgetOf(categoryId)?.amountCents ?? 0) / 100).toStringAsFixed(2),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(categoryId == 0 ? '设置总预算' : '设置分类预算'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '¥ ', hintText: '0.00'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    // dialog里的controller得等dialog关了再dispose，不然报错
    final cents = parseMoneyToCents(ctrl.text);
    ctrl.dispose();

    if (ok == true) {
      if (cents == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('金额不对')));
        return;
      }
      await store.saveBudget(Budget(categoryId: categoryId, amountCents: cents));
    }
  }
}
