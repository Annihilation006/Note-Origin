import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../utils/fmt.dart';

/// 记一笔 / 编辑一笔
class AddTxnPage extends StatefulWidget {
  final Txn? editing;

  const AddTxnPage({super.key, this.editing});

  @override
  State<AddTxnPage> createState() => _AddTxnPageState();
}

class _AddTxnPageState extends State<AddTxnPage> {
  late int _type; // 0支出 1收入
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late DateTime _date;
  int? _catId;
  int? _accId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _type = e.type;
      _amountCtrl.text = (e.amountCents / 100).toStringAsFixed(2);
      _noteCtrl.text = e.note;
      _date = DateTime.tryParse(e.date) ?? DateTime.now();
      _catId = e.categoryId;
      _accId = e.accountId;
    } else {
      _type = 0;
      _date = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return; // 手快点两下会插两条，挡一下
    final cents = parseMoneyToCents(_amountCtrl.text);
    if (cents == null || cents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金额不对，检查一下')),
      );
      return;
    }
    if (_catId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('选个分类')),
      );
      return;
    }
    final store = context.read<AppStore>();
    // 账户不选默认第一个
    final acc = _accId ?? (store.accs.isNotEmpty ? store.accs.first.id : 0);
    if (acc == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可用账户，去设置里加一个')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final old = widget.editing;
      final t = Txn(
        id: old?.id,
        type: _type,
        amountCents: cents,
        categoryId: _catId!,
        accountId: acc,
        date: todayStr(_date),
        note: _noteCtrl.text.trim(),
        createdAt: old?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      );
      await store.saveTxn(t);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cs = Theme.of(context).colorScheme;
    final cats = store.cats.where((c) => c.type == _type).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.editing == null ? '记一笔' : '编辑')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 支出/收入切换
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('支出')),
              ButtonSegment(value: 1, label: Text('收入')),
            ],
            selected: {_type},
            onSelectionChanged: (s) {
              setState(() {
                _type = s.first;
                _catId = null; // 类型变了分类要重选
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              // 只放数字和一个小数点，最多两位小数
              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,9}\.?\d{0,2}')),
            ],
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: '¥ ',
              hintText: '0.00',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          // 分类网格
          Text('分类', style: TextStyle(color: cs.outline, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cats)
                ChoiceChip(
                  label: Text('${c.icon} ${c.name}'),
                  selected: _catId == c.id,
                  onSelected: (_) => setState(() => _catId = c.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 账户
          Row(
            children: [
              Text('账户', style: TextStyle(color: cs.outline, fontSize: 13)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<int?>(
                  value: _accId ?? (store.accs.isNotEmpty ? store.accs.first.id : null),
                  isExpanded: true,
                  items: [
                    for (final a in store.accs)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => _accId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 日期
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(todayStr(_date)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickDate,
          ),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '备注（可空）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      ),
    );
  }
}
