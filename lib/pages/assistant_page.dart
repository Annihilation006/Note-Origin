import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../services/ai_service.dart';
import '../services/assistant.dart';
import '../ui/tokens.dart';
import '../utils/fmt.dart';

/// AI助手页：自然语言记账/写笔记/查账（跨平台版入口）
class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _result;
  Color? _resultColor;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy) return;
    final store = context.read<AppStore>();
    final cfg = await AiConfig.load();
    if (!cfg.ready) {
      setState(() { _result = '先在设置里填 API Key'; _resultColor = null; });
      return;
    }
    setState(() { _busy = true; _result = null; });
    try {
      final now = DateTime.now();
      final raw = await AiService.chat(
        cfg,
        Assistant.userPayload(text, fmtMoney(store.monthExpenseCents), store.monthTxns.length),
        system: Assistant.systemPrompt(
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          store.cats.map((c) => c.name).toList(),
          store.accs.map((a) => a.name).toList(),
        ),
      );
      final act = Assistant.interpret(raw, store.cats.map((c) => c.name).toList(), now);
      String out;
      Color? color;
      switch (act) {
        case AddTxnAction(:final type, :final amountCents, :final date, :final categoryName, :final accountName, :final note, :final currency):
          final cat = store.cats.firstWhere((c) => c.name == categoryName, orElse: () => store.cats.first);
          final acc = accountName == null
              ? store.accs.first
              : store.accs.firstWhere(
                  (a) => a.name.contains(accountName) || accountName.contains(a.name),
                  orElse: () => store.accs.first);
          await store.saveTxn(Txn(
            type: type, amountCents: amountCents, date: date,
            categoryId: cat.id ?? 0, accountId: acc.id ?? 0,
            note: note.isEmpty ? 'AI记' : note,
            createdAt: DateTime.now().millisecondsSinceEpoch, currency: currency,
          ));
          out = '$date ${type == 0 ? '支出' : '收入'} ${fmtMoney(amountCents, currency: currency)}（$categoryName${note.isEmpty ? '' : '·${note.substring(0, note.length > 12 ? 12 : note.length)}'}）已入账 ✓';
          color = null;
        case AddNoteAction(:final date, :final content):
          await store.saveNote(DayNote(
            date: date, content: content, createdAt: DateTime.now().millisecondsSinceEpoch,
          ));
          out = '「${content.length > 40 ? content.substring(0, 40) : content}」已写入 $date ✓';
          color = null;
        case ReplyAction():
          out = act.text;
          color = null;
      }
      setState(() { _result = out; _resultColor = color; _ctrl.clear(); });
    } catch (e) {
      setState(() { _result = '请求失败 · $e'; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI 助手')),
      body: ListView(
        padding: const EdgeInsets.all(Sp.l),
        children: [
          Text('试试："记一笔午饭25块"、"写笔记 今天把报告交了"、"这个月花了多少"',
              style: Ty.meta.apply(color: cs.outline)),
          const SizedBox(height: Sp.l),
          TextField(
            controller: _ctrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '想干什么直接说…', border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _run(),
          ),
          const SizedBox(height: Sp.m),
          FilledButton(
            onPressed: _busy ? null : _run,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(_busy ? '正在处理…' : '执行'),
          ),
          if (_result != null) ...[
            const SizedBox(height: Sp.l),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(Sp.l),
                child: Text(_result!, style: Ty.body),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
