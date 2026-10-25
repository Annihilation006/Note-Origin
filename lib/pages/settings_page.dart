import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/store.dart';
import '../services/ai_service.dart';
import '../utils/fmt.dart';

/// 设置页：AI配置 / 账户管理 / 分类管理 / 导出 / 关于
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<AiConfig> _cfgFuture;

  @override
  void initState() {
    super.initState();
    _cfgFuture = AiConfig.load();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _section('AI 助手'),
          FutureBuilder<AiConfig>(
            future: _cfgFuture,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const ListTile(title: Text('加载中…'));
              }
              final cfg = snap.data!;
              final ok = cfg.ready;
              return ListTile(
                leading: Icon(Icons.auto_awesome_outlined,
                    color: ok ? Colors.green : Colors.grey),
                title: const Text('API 配置'),
                subtitle: Text(ok ? '${cfg.model}\n${cfg.baseUrl}' : '未配置（点击填写）'),
                isThreeLine: true,
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiConfigPage(cfg: cfg)));
                  // 回来刷新状态
                  setState(() => _cfgFuture = AiConfig.load());
                },
              );
            },
          ),
          const Divider(),
          _section('账户'),
          for (final a in store.accs)
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(a.name),
              dense: true,
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('添加账户'),
            dense: true,
            onTap: () => _addAccount(context, store),
          ),
          const Divider(),
          _section('数据'),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('导出全部流水 (CSV)'),
            subtitle: const Text('存到应用目录，连电脑可取'),
            onTap: () => _exportCsv(context),
          ),
          const Divider(),
          _section('关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Note Origin'),
            subtitle: Text('v0.3.2 · Flutter 跨平台版\n安卓/iOS/鸿蒙/Windows/macOS/Linux'),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
    );
  }

  Future<void> _addAccount(BuildContext context, AppStore store) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新账户名称'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '比如：招行卡')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('添加')),
        ],
      ),
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (ok == true && name.isNotEmpty) {
      try {
        await store.addAccount(name);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加不上: $e')));
      }
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    try {
      final txns = await Db.instance.allTxns();
      if (txns.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('没有数据可导')));
        return;
      }
      final store = context.read<AppStore>();
      final buf = StringBuffer('date,type,category,account,amount_yuan,note\n');
      for (final t in txns) {
        final cat = store.catById[t.categoryId]?.name ?? '';
        final acc = store.accById[t.accountId]?.name ?? '';
        // csv里逗号引号转义，粗暴处理但够用
        final note = t.note.replaceAll('"', '""');
        buf.writeln(
            '"${t.date}",${t.type == 0 ? 'expense' : 'income'},"$cat","$acc",${(t.amountCents / 100).toStringAsFixed(2)},"$note"');
      }
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/note_origin_export_${todayStr()}.csv');
      await file.writeAsString('\uFEFF${buf.toString()}'); // BOM，excel打开不乱码
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导出成功'),
          content: Text('文件在：\n${file.path}'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道啦'))],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }
}

/// AI配置编辑页
class AiConfigPage extends StatefulWidget {
  final AiConfig cfg;
  const AiConfigPage({super.key, required this.cfg});

  @override
  State<AiConfigPage> createState() => _AiConfigPageState();
}

class _AiConfigPageState extends State<AiConfigPage> {
  late final TextEditingController _base;
  late final TextEditingController _key;
  late final TextEditingController _model;
  ApiFormat _fmt = ApiFormat.chatCompletions;
  bool _testing = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _base = TextEditingController(text: widget.cfg.baseUrl);
    _key = TextEditingController(text: widget.cfg.apiKey);
    _model = TextEditingController(text: widget.cfg.model);
    _fmt = widget.cfg.format;
  }

  @override
  void dispose() {
    _base.dispose();
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    if (_testing) return;
    setState(() => _testing = true);
    final probe = AiConfig()
      ..baseUrl = _base.text
      ..apiKey = _key.text
      ..model = _model.text
      ..format = _fmt;
    try {
      final r = await AiService.ping(probe);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('通了，模型说：$r')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('不通: $e')));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    widget.cfg
      ..baseUrl = _base.text.trim()
      ..apiKey = _key.text.trim()
      ..model = _model.text.trim()
      ..format = _fmt;
    await widget.cfg.save();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 配置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ApiFormat>(
            segments: [
              for (final f in ApiFormat.values) ButtonSegment(value: f, label: Text(f.label)),
            ],
            selected: {_fmt},
            // 只切协议，用户已填的地址/key/模型一概不动
            onSelectionChanged: (s) => setState(() => _fmt = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _base,
            decoration: InputDecoration(
                labelText: 'API Base URL', hintText: _fmt.baseHint, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'API Key',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _model,
            decoration: InputDecoration(
                labelText: '模型名', hintText: _fmt.modelHint, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_tethering),
                  label: const Text('测试连通'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
