// 数据模型。都是给 sqflite 用的，字段名跟表列名保持一致，省得映射来映射去
library;

class Txn {
  final int? id;
  final int type; // 0支出 1收入，别用enum，数据库里存int方便
  final int amountCents; // 金额按分存，浮点数记账迟早出事
  final int categoryId;
  final int accountId;
  final String date; // YYYY-MM-DD
  final String note;
  final int createdAt;

  Txn({
    this.id,
    required this.type,
    required this.amountCents,
    required this.categoryId,
    required this.accountId,
    required this.date,
    this.note = '',
    required this.createdAt,
  });

  Txn copyWith({
    int? id,
    int? type,
    int? amountCents,
    int? categoryId,
    int? accountId,
    String? date,
    String? note,
    int? createdAt,
  }) {
    return Txn(
      id: id ?? this.id,
      type: type ?? this.type,
      amountCents: amountCents ?? this.amountCents,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static Txn fromMap(Map<String, Object?> m) {
    // 防御一下，老数据里可能有null
    return Txn(
      id: m['id'] as int?,
      type: (m['type'] as int?) ?? 0,
      amountCents: (m['amount_cents'] as int?) ?? 0,
      categoryId: (m['category_id'] as int?) ?? 0,
      accountId: (m['account_id'] as int?) ?? 0,
      date: (m['date'] as String?) ?? '',
      note: (m['note'] as String?) ?? '',
      createdAt: (m['created_at'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'type': type,
      'amount_cents': amountCents,
      'category_id': categoryId,
      'account_id': accountId,
      'date': date,
      'note': note,
      'created_at': createdAt,
    };
  }
}

class Category {
  final int? id;
  final int type; // 跟Txn.type对应
  final String name;
  final String icon; // emoji直接存字符串

  Category({this.id, required this.type, required this.name, required this.icon});

  static Category fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int?,
        type: (m['type'] as int?) ?? 0,
        name: (m['name'] as String?) ?? '??',
        icon: (m['icon'] as String?) ?? '❓',
      );

  Map<String, Object?> toMap() => {'id': id, 'type': type, 'name': name, 'icon': icon};
}

class Account {
  final int? id;
  final String name;

  Account({this.id, required this.name});

  static Account fromMap(Map<String, Object?> m) =>
      Account(id: m['id'] as int?, name: (m['name'] as String?) ?? '未知账户');

  Map<String, Object?> toMap() => {'id': id, 'name': name};
}

/// 日历笔记，一天可以有多条
class DayNote {
  final int? id;
  final String date; // YYYY-MM-DD
  final String content;
  final int createdAt;

  DayNote({this.id, required this.date, required this.content, required this.createdAt});

  static DayNote fromMap(Map<String, Object?> m) => DayNote(
        id: m['id'] as int?,
        date: (m['date'] as String?) ?? '',
        content: (m['content'] as String?) ?? '',
        createdAt: (m['created_at'] as int?) ?? 0,
      );

  Map<String, Object?> toMap() =>
      {'id': id, 'date': date, 'content': content, 'created_at': createdAt};
}

/// 预算。categoryId为0表示当月总预算
class Budget {
  final int? id;
  final int categoryId;
  final int amountCents;

  Budget({this.id, required this.categoryId, required this.amountCents});

  static Budget fromMap(Map<String, Object?> m) => Budget(
        id: m['id'] as int?,
        categoryId: (m['category_id'] as int?) ?? 0,
        amountCents: (m['amount_cents'] as int?) ?? 0,
      );

  Map<String, Object?> toMap() => {'id': id, 'category_id': categoryId, 'amount_cents': amountCents};
}
