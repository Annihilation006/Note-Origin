import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import '../models/models.dart';
import 'db.dart';
import '../utils/fmt.dart';

/// 全局状态。一个ChangeNotifier装下所有页面要的东西，
/// 数据量小（个人记账撑死几千条），偷懒不分store了
class AppStore extends ChangeNotifier {
  AppStore(this._db);

  final Db _db;

  // ---------- 运行时状态 ----------
  DateTime month = DateTime.now(); // 当前查看的月份，首页统计都跟着它走

  List<Txn> monthTxns = [];
  List<Category> cats = [];
  List<Account> accs = [];
  List<Budget> budgetList = [];

  bool loading = false;

  // 缓存一下分类/账户的映射，界面好取
  Map<int, Category> catById = {};
  Map<int, Account> accById = {};

  // ---------- 生命周期 ----------

  Future<void> bootstrap() async {
    loading = true;
    notifyListeners();
    try {
      await _bootCheck();
      await reloadMonth();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 启动自检，哪步出问题记到 bootIssues。
  /// 数据库彻底打不开之外的事都不阻断启动
  List<String> bootIssues = [];

  Future<void> _bootCheck() async {
    bootIssues = [];
    try {
      await _db.get(); // 顺手触发建库
    } catch (e) {
      bootIssues.add('数据库打不开: $e');
      return; // 库都没起来，后面查了也白查
    }
    try {
      await _reloadCats();
      if (cats.isEmpty) bootIssues.add('分类为空');
    } catch (e) {
      bootIssues.add('分类读取失败: $e');
    }
    try {
      await _reloadAccs();
      if (accs.isEmpty) bootIssues.add('账户为空');
    } catch (e) {
      bootIssues.add('账户读取失败: $e');
    }
    try {
      await _reloadBudgets();
    } catch (e) {
      bootIssues.add('预算读取失败: $e');
    }
    if (bootIssues.isNotEmpty) {
      debugPrint('boot check: $bootIssues'); // 要不要上屏展示以后再说
    }
  }

  Future<void> _reloadCats() async {
    try {
      cats = await _db.categories();
    } catch (_) {
      cats = []; // 库坏了也别崩，空列表至少能渲染
    }
    catById = {for (final c in cats) if (c.id != null) c.id!: c};
  }

  Future<void> _reloadAccs() async {
    try {
      accs = await _db.accounts();
    } catch (_) {
      accs = [];
    }
    accById = {for (final a in accs) if (a.id != null) a.id!: a};
  }

  Future<void> _reloadBudgets() async {
    try {
      budgetList = await _db.budgets();
    } catch (_) {
      budgetList = [];
    }
  }

  String get monthKey {
    final m = month.month.toString().padLeft(2, '0');
    return '${month.year}-$m';
  }

  Future<void> reloadMonth() async {
    try {
      monthTxns = await _db.txnsOfMonth(monthKey);
    } catch (_) {
      monthTxns = [];
    }
    notifyListeners();
  }

  void prevMonth() {
    month = DateTime(month.year, month.month - 1, 1);
    reloadMonth();
  }

  void nextMonth() {
    month = DateTime(month.year, month.month + 1, 1);
    reloadMonth();
  }

  // ---------- 记账 ----------

  Future<void> saveTxn(Txn t) async {
    await _db.saveTxn(t);
    await reloadMonth(); // 简单粗暴，不做增量刷新了
  }

  Future<void> saveNote(DayNote n) async {
    try {
      await _db.saveNote(n);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> deleteTxn(int id) async {
    await _db.deleteTxn(id);
    await reloadMonth();
  }

  Future<void> addCategory(Category c) async {
    await _db.addCategory(c);
    await _reloadCats();
    notifyListeners();
  }

  Future<void> deleteCategory(int id) async {
    await _db.deleteCategory(id);
    await _reloadCats();
    notifyListeners();
  }

  Future<void> addAccount(String name) async {
    await _db.addAccount(name);
    await _reloadAccs();
    notifyListeners();
  }

  Future<void> saveBudget(Budget b) async {
    await _db.saveBudget(b);
    await _reloadBudgets();
    notifyListeners();
  }

  Budget? budgetOf(int categoryId) {
    for (final b in budgetList) {
      if (b.categoryId == categoryId) return b;
    }
    return null;
  }

  // ---------- 统计（都是现算，数据量小无所谓） ----------

  // 统计只计主币种CNY，外币单列（不折汇率没法加和）
  int get monthExpenseCents {
    var s = 0;
    for (final t in monthTxns) {
      if (t.type == 0 && t.currency == 'CNY') s += t.amountCents;
    }
    return s;
  }

  Map<String, int> get foreignSums {
    final m = <String, int>{};
    for (final t in monthTxns) {
      if (t.type == 0 && t.currency != 'CNY') {
        m[t.currency] = (m[t.currency] ?? 0) + t.amountCents;
      }
    }
    m.removeWhere((_, v) => v == 0);
    return m;
  }

  int get monthIncomeCents {
    var s = 0;
    for (final t in monthTxns) {
      if (t.type == 1 && t.currency == 'CNY') s += t.amountCents;
    }
    return s;
  }

  /// 按分类汇总支出，降序
  List<MapEntry<Category?, int>> expenseByCategory() {
    final sum = <int, int>{};
    for (final t in monthTxns) {
      if (t.type != 0) continue;
      sum[t.categoryId] = (sum[t.categoryId] ?? 0) + t.amountCents;
    }
    final out = sum.entries.map((e) => MapEntry(catById[e.key], e.value)).toList();
    out.sort((a, b) => b.value.compareTo(a.value));
    return out;
  }

  /// 每天支出序列，画柱状图
  List<int> dailyExpenseSeries() {
    final days = DateTime(month.year, month.month + 1, 0).day; // 算当月天数的老套路
    final list = List<int>.filled(days, 0);
    for (final t in monthTxns) {
      if (t.type != 0) continue;
      final d = int.tryParse(t.date.split('-').last) ?? 0;
      if (d >= 1 && d <= days) {
        list[d - 1] += t.amountCents;
      }
    }
    return list;
  }

  /// 今天的支出（分）。首页那块Metro条用
  int get todayExpenseCents {
    final key = todayStr(DateTime.now());
    var sum = 0;
    for (final t in monthTxns) {
      if (t.type == 0 && t.date == key) sum += t.amountCents;
    }
    return sum;
  }

  int get todayTxnCount {
    final key = todayStr(DateTime.now());
    return monthTxns.where((t) => t.date == key).length;
  }

  /// 按天分组给首页列表
  Map<String, List<Txn>> txnsGroupedByDay() {
    final map = <String, List<Txn>>{};
    for (final t in monthTxns) {
      map.putIfAbsent(t.date, () => []).add(t);
    }
    // keys本来就是有序的（查询时排过），但还是稳一下
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: map[k]!};
  }
}
