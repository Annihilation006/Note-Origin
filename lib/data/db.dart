import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as p;

import '../models/models.dart';

/// 数据库一层。单例，懒加载。
/// 桌面端（linux/win/mac）得用ffi的factory，那个在main.dart里处理，
/// 这里只管拿 db 实例，拿不到就抛，调用方自己看着办。
class Db {
  static final Db _i = Db._();
  static Db get instance => _i;
  Db._();

  sqflite.Database? _db;

  Future<sqflite.Database> get() async {
    final d = _db;
    if (d != null && d.isOpen) {
      return d;
    }
    try {
      _db = await _open();
      return _db!;
    } catch (e) {
      // 表要是炸了最惨也就是数据没了，不能让整个app起不来
      // todo: 想想怎么备份旧库再重建
      rethrow;
    }
  }

  Future<sqflite.Database> _open() async {
    final dir = await sqflite.getDatabasesPath();
    final file = p.join(dir, 'note_origin.db');
    return sqflite.databaseFactory.openDatabase(
      file,
      options: sqflite.OpenDatabaseOptions(
        version: 1,
        onCreate: (db, v) async {
          // 一把建完，省得以后升级迁移写得痛苦（虽然迟早要写）
          await db.execute('''
            CREATE TABLE txns(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type INTEGER NOT NULL,
              amount_cents INTEGER NOT NULL,
              category_id INTEGER NOT NULL,
              account_id INTEGER NOT NULL,
              date TEXT NOT NULL,
              note TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute('CREATE INDEX idx_txns_date ON txns(date)');
          await db.execute('''
            CREATE TABLE categories(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type INTEGER NOT NULL,
              name TEXT NOT NULL,
              icon TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE accounts(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE day_notes(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              content TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute('CREATE INDEX idx_notes_date ON day_notes(date)');
          await db.execute('''
            CREATE TABLE budgets(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              category_id INTEGER NOT NULL DEFAULT 0,
              amount_cents INTEGER NOT NULL
            )
          ''');
          await _seed(db);
        },
      ),
    );
  }

  Future<void> _seed(sqflite.Database db) async {
    // 默认分类，够了。用户要加自己加
    const expense = [
      ['餐饮', '🍜'],
      ['交通', '🚌'],
      ['购物', '🛍️'],
      ['娱乐', '🎮'],
      ['医疗', '💊'],
      ['居住', '🏠'],
      ['通讯', '📱'],
      ['教育', '📚'],
      ['人情', '🎁'],
      ['其他', '📦'],
    ];
    const income = [
      ['工资', '💰'],
      ['奖金', '🎉'],
      ['红包', '🧧'],
      ['理财', '📈'],
      ['退款', '↩️'],
      ['其他收入', '➕'],
    ];
    for (final c in expense) {
      await db.insert('categories', {'type': 0, 'name': c[0], 'icon': c[1]});
    }
    for (final c in income) {
      await db.insert('categories', {'type': 1, 'name': c[0], 'icon': c[1]});
    }
    for (final name in ['现金', '支付宝', '微信', '银行卡']) {
      await db.insert('accounts', {'name': name});
    }
  }

  // ---- txns ----

  Future<List<Txn>> txnsOfMonth(String ym) async {
    final db = await get();
    final rows = await db.query('txns',
        where: 'date LIKE ?',
        whereArgs: ['$ym-%'],
        orderBy: 'date DESC, created_at DESC');
    return rows.map(Txn.fromMap).toList();
  }

  Future<List<Txn>> allTxns() async {
    final db = await get();
    return (await db.query('txns', orderBy: 'date DESC, created_at DESC')).map(Txn.fromMap).toList();
  }

  Future<void> saveTxn(Txn t) async {
    final db = await get();
    final m = t.toMap()..remove('id');
    if (t.id == null) {
      await db.insert('txns', m);
    } else {
      await db.update('txns', m, where: 'id=?', whereArgs: [t.id]);
    }
  }

  Future<void> deleteTxn(int id) async {
    final db = await get();
    await db.delete('txns', where: 'id=?', whereArgs: [id]);
  }

  // ---- categories / accounts ----

  Future<List<Category>> categories({int? type}) async {
    final db = await get();
    final rows = type == null
        ? await db.query('categories', orderBy: 'type, id')
        : await db.query('categories', where: 'type=?', whereArgs: [type], orderBy: 'id');
    return rows.map(Category.fromMap).toList();
  }

  Future<void> addCategory(Category c) async {
    final db = await get();
    await db.insert('categories', c.toMap()..remove('id'));
  }

  Future<void> deleteCategory(int id) async {
    final db = await get();
    // 分类下的旧账不删，查询的时候兜底显示就行
    await db.delete('categories', where: 'id=?', whereArgs: [id]);
  }

  Future<List<Account>> accounts() async {
    final db = await get();
    return (await db.query('accounts', orderBy: 'id')).map(Account.fromMap).toList();
  }

  Future<void> addAccount(String name) async {
    final db = await get();
    await db.insert('accounts', {'name': name});
  }

  // ---- notes ----

  Future<List<DayNote>> notesOfDate(String date) async {
    final db = await get();
    final rows = await db
        .query('day_notes', where: 'date=?', whereArgs: [date], orderBy: 'created_at DESC');
    return rows.map(DayNote.fromMap).toList();
  }

  /// 某月有笔记的日期，给日历上打点用
  Future<Set<String>> noteDatesOfMonth(String ym) async {
    final db = await get();
    final rows = await db.query('day_notes',
        columns: ['date'], where: 'date LIKE ?', whereArgs: ['$ym-%'], groupBy: 'date');
    return rows.map((r) => (r['date'] as String?) ?? '').where((s) => s.isNotEmpty).toSet();
  }

  Future<void> saveNote(DayNote n) async {
    final db = await get();
    final m = n.toMap()..remove('id');
    if (n.id == null) {
      await db.insert('day_notes', m);
    } else {
      await db.update('day_notes', m, where: 'id=?', whereArgs: [n.id]);
    }
  }

  Future<void> deleteNote(int id) async {
    final db = await get();
    await db.delete('day_notes', where: 'id=?', whereArgs: [id]);
  }

  /// 最近编辑的笔记，给首页"继续写"用
  Future<List<DayNote>> recentNotes({int limit = 5}) async {
    final db = await get();
    final rows = await db.query('day_notes', orderBy: 'created_at DESC', limit: limit);
    return rows.map(DayNote.fromMap).toList();
  }

  // ---- budgets ----

  Future<List<Budget>> budgets() async {
    final db = await get();
    return (await db.query('budgets')).map(Budget.fromMap).toList();
  }

  Future<void> saveBudget(Budget b) async {
    final db = await get();
    final exist = b.id ??
        sqflite.Sqflite.firstIntValue(await db
            .query('budgets', where: 'category_id=?', whereArgs: [b.categoryId], columns: ['id'], limit: 1));
    final m = b.toMap();
    if (exist == null) {
      await db.insert('budgets', m..remove('id'));
    } else {
      m['id'] = exist;
      await db.update('budgets', m, where: 'id=?', whereArgs: [exist]);
    }
  }
}
