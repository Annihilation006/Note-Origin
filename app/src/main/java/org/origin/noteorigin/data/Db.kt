package org.origin.noteorigin.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/** 表结构与Flutter版sqflite库逐列一致，以后两版数据可互通 */
class Db(ctx: Context) : SQLiteOpenHelper(ctx.applicationContext, "note_origin.db", null, 2) {

    companion object {
        @Volatile private var inst: Db? = null
        fun get(ctx: Context): Db =
            inst ?: synchronized(this) { inst ?: Db(ctx).also { inst = it } }
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("""
            CREATE TABLE txns(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type INTEGER NOT NULL,
              amount_cents INTEGER NOT NULL,
              category_id INTEGER NOT NULL,
              account_id INTEGER NOT NULL,
              date TEXT NOT NULL,
              note TEXT,
              created_at INTEGER NOT NULL,
              currency TEXT NOT NULL DEFAULT 'CNY'
            )
        """)
        db.execSQL("CREATE INDEX idx_txns_date ON txns(date)")
        db.execSQL("""
            CREATE TABLE categories(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type INTEGER NOT NULL, name TEXT NOT NULL, icon TEXT
            )
        """)
        db.execSQL("CREATE TABLE accounts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)")
        db.execSQL("""
            CREATE TABLE day_notes(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL, content TEXT NOT NULL, created_at INTEGER NOT NULL
            )
        """)
        db.execSQL("CREATE INDEX idx_notes_date ON day_notes(date)")
        db.execSQL("""
            CREATE TABLE budgets(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              category_id INTEGER NOT NULL DEFAULT 0,
              amount_cents INTEGER NOT NULL
            )
        """)
        seed(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, o: Int, n: Int) {
        if (o < 2) {
            // v2: 加币种列，老数据默认CNY
            db.execSQL("ALTER TABLE txns ADD COLUMN currency TEXT NOT NULL DEFAULT 'CNY'")
        }
    }

    private fun seed(db: SQLiteDatabase) {
        listOf(
            "餐饮" to "🍜", "交通" to "🚌", "购物" to "🛍️", "娱乐" to "🎮",
            "医疗" to "💊", "居住" to "🏠", "通讯" to "📱", "教育" to "📚",
            "人情" to "🎁", "其他" to "📦",
        ).forEach { (n, i) -> db.insert("categories", null, cv("type" to 0, "name" to n, "icon" to i)) }
        listOf(
            "工资" to "💰", "奖金" to "🎉", "红包" to "🧧", "理财" to "📈",
            "退款" to "↩️", "其他收入" to "➕",
        ).forEach { (n, i) -> db.insert("categories", null, cv("type" to 1, "name" to n, "icon" to i)) }
        listOf("现金", "支付宝", "微信", "银行卡").forEach {
            db.insert("accounts", null, cv("name" to it))
        }
    }

    private fun cv(vararg pairs: Pair<String, Any?>): ContentValues = ContentValues().apply {
        for ((k, v) in pairs) when (v) {
            null -> putNull(k)
            is String -> put(k, v)
            is Int -> put(k, v)
            is Long -> put(k, v)
            is Boolean -> put(k, v)
            is Double -> put(k, v)
            else -> put(k, v.toString())
        }
    }

    // ---- txns ----

    fun txnsOfMonth(ym: String): List<Txn> = read("SELECT * FROM txns WHERE date LIKE ? ORDER BY date DESC, created_at DESC", arrayOf("$ym-%")) { c ->
        Txn(c.getLong(0), c.getInt(1), c.getLong(2), c.getLong(3), c.getLong(4), c.getString(5), c.getString(6) ?: "", c.getLong(7), if (c.columnCount > 8) c.getString(8) ?: "CNY" else "CNY")
    }

    fun allTxns(): List<Txn> = read("SELECT * FROM txns ORDER BY date DESC, created_at DESC", arrayOf()) { c ->
        Txn(c.getLong(0), c.getInt(1), c.getLong(2), c.getLong(3), c.getLong(4), c.getString(5), c.getString(6) ?: "", c.getLong(7), if (c.columnCount > 8) c.getString(8) ?: "CNY" else "CNY")
    }

    fun saveTxn(t: Txn) {
        val v = cv(
            "type" to t.type, "amount_cents" to t.amountCents, "category_id" to t.categoryId,
            "account_id" to t.accountId, "date" to t.date, "note" to t.note, "created_at" to t.createdAt,
            "currency" to t.currency,
        )
        if (t.id == null) writableDatabase.insert("txns", null, v)
        else writableDatabase.update("txns", v, "id=?", arrayOf(t.id.toString()))
    }

    fun deleteTxn(id: Long) = writableDatabase.delete("txns", "id=?", arrayOf(id.toString()))

    // ---- categories / accounts ----

    fun categories(type: Int? = null): List<Category> {
        val (sql, args) = if (type == null)
            "SELECT id,type,name,icon FROM categories ORDER BY type,id" to arrayOf<String>()
        else
            "SELECT id,type,name,icon FROM categories WHERE type=? ORDER BY id" to arrayOf(type.toString())
        return read(sql, args) { c -> Category(c.getLong(0), c.getInt(1), c.getString(2), c.getString(3) ?: "❓") }
    }

    fun accounts(): List<Account> =
        read("SELECT id,name FROM accounts ORDER BY id", arrayOf()) { c -> Account(c.getLong(0), c.getString(1)) }

    fun addAccount(name: String) = writableDatabase.insert("accounts", null, cv("name" to name))

    // ---- notes ----

    fun notesOfDate(date: String): List<DayNote> =
        read("SELECT id,date,content,created_at FROM day_notes WHERE date=? ORDER BY created_at DESC", arrayOf(date)) { c ->
            DayNote(c.getLong(0), c.getString(1), c.getString(2), c.getLong(3))
        }

    fun noteDatesOfMonth(ym: String): Set<String> =
        read("SELECT DISTINCT date FROM day_notes WHERE date LIKE ?", arrayOf("$ym-%")) { c -> c.getString(0) }.toSet()

    fun recentNotes(limit: Int = 4): List<DayNote> =
        read("SELECT id,date,content,created_at FROM day_notes ORDER BY created_at DESC LIMIT $limit", arrayOf()) { c ->
            DayNote(c.getLong(0), c.getString(1), c.getString(2), c.getLong(3))
        }

    fun saveNote(n: DayNote) {
        val v = cv("date" to n.date, "content" to n.content, "created_at" to n.createdAt)
        if (n.id == null) writableDatabase.insert("day_notes", null, v)
        else writableDatabase.update("day_notes", v, "id=?", arrayOf(n.id.toString()))
    }

    fun deleteNote(id: Long) = writableDatabase.delete("day_notes", "id=?", arrayOf(id.toString()))

    // ---- budgets ----

    fun budgets(): List<Budget> =
        read("SELECT id,category_id,amount_cents FROM budgets", arrayOf()) { c ->
            Budget(c.getLongOrNull(0) ?: 0L, c.getLong(1), c.getLong(2))
        }

    fun saveBudget(b: Budget) {
        val exist = readableDatabase.rawQuery(
            "SELECT id FROM budgets WHERE category_id=? LIMIT 1", arrayOf(b.categoryId.toString())
        ).use { if (it.moveToFirst()) it.getLong(0) else null }
        val v = cv("category_id" to b.categoryId, "amount_cents" to b.amountCents)
        if (exist == null) writableDatabase.insert("budgets", null, v)
        else writableDatabase.update("budgets", v, "id=?", arrayOf(exist.toString()))
    }

    // ---- helper ----

    private fun <T> read(sql: String, args: Array<String>, map: (android.database.Cursor) -> T): List<T> =
        readableDatabase.rawQuery(sql, args).use { c ->
            val out = ArrayList<T>(c.count)
            while (c.moveToNext()) out.add(map(c))
            out
        }
}

private fun android.database.Cursor.getLongOrNull(idx: Int): Long? =
    if (isNull(idx)) null else getLong(idx)
