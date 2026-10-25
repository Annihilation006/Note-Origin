import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/store.dart';
import '../models/models.dart';
import '../utils/fmt.dart';

/// 日历笔记页：手搓月历（不想引日历库了）+ 当日笔记列表
class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  DateTime _month = DateTime.now();
  DateTime _selected = DateTime.now();
  List<DayNote> _notes = [];
  Set<String> _marked = {}; // 有笔记的日子

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = Db.instance;
      _notes = await db.notesOfDate(todayStr(_selected));
      _marked = await db.noteDatesOfMonth(ymOf(_month));
    } catch (e) {
      _notes = [];
      _marked = {};
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _shiftMonth(-1),
            ),
            Text('${_month.year}年${_month.month}月'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _shiftMonth(1),
            ),
          ],
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editNote(null),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _calendar(cs),
          const Divider(height: 1),
          Expanded(
            child: _notes.isEmpty
                ? const Center(child: Text('这一天还没有笔记', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _notes.length,
                    itemBuilder: (_, i) {
                      final n = _notes[i];
                      return ListTile(
                        leading: const Icon(Icons.notes_outlined),
                        title: Text(n.content, maxLines: 3, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          DateTime.fromMillisecondsSinceEpoch(n.createdAt).toString().substring(0, 16),
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => _editNote(n),
                        onLongPress: () => _deleteNote(n),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
      // 翻月之后选中日可能不在本月，归到1号
      if (_selected.year != _month.year || _selected.month != _month.month) {
        _selected = DateTime(_month.year, _month.month, 1);
      }
    });
    _load();
  }

  Widget _calendar(ColorScheme cs) {
    final first = DateTime(_month.year, _month.month, 1);
    // 周一开头。周一=1...周日=7 -> 空格数
    final lead = (first.weekday - 1);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox.shrink());
    }
    final today = DateTime.now();
    final selKey = todayStr(_selected);
    for (var d = 1; d <= days; d++) {
      final key = todayStr(DateTime(_month.year, _month.month, d));
      final isSel = key == selKey;
      final isToday = key == todayStr(today);
      final hasNote = _marked.contains(key);
      cells.add(GestureDetector(
        onTap: () {
          setState(() => _selected = DateTime(_month.year, _month.month, d));
          _load();
        },
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSel ? cs.primary : null,
            border: isToday && !isSel ? Border.all(color: cs.primary, width: 1.5) : null,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$d',
                style: TextStyle(
                  fontSize: 14,
                  color: isSel ? cs.onPrimary : null,
                  fontWeight: isToday || isSel ? FontWeight.bold : null,
                ),
              ),
              if (hasNote)
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: isSel ? cs.onPrimary : cs.primary),
                ),
            ],
          ),
        ),
      ));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              for (final w in ['一', '二', '三', '四', '五', '六', '日'])
                Expanded(child: Center(child: Text(w, style: const TextStyle(fontSize: 12, color: Colors.grey)))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.0,
            children: cells,
          ),
        ),
      ],
    );
  }

  Future<void> _editNote(DayNote? old) async {
    final ctrl = TextEditingController(text: old?.content ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(old == null ? '记笔记 · $todayStr(_selected)' : '编辑笔记'),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          autofocus: old == null,
          decoration: const InputDecoration(hintText: '这一天发生了什么…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (ok == true && text.isNotEmpty) {
      try {
        await Db.instance.saveNote(DayNote(
          id: old?.id,
          date: todayStr(_selected),
          content: text,
          createdAt: old?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
        ));
      } catch (_) {}
      _load();
    }
  }

  Future<void> _deleteNote(DayNote n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条笔记？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await Db.instance.deleteNote(n.id!);
      } catch (_) {}
      _load();
    }
  }
}
