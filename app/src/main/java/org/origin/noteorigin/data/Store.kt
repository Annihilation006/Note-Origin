package org.origin.noteorigin.data

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.origin.noteorigin.util.fmtMoney
import java.time.LocalDate
import java.time.YearMonth

/** 全局状态。一个类装下，跟Flutter版的AppStore对位 */
class Store(private val ctx: Context) {
    private val db = Db.get(ctx)

    var month by mutableStateOf(YearMonth.now())
    var monthTxns by mutableStateOf(listOf<Txn>())
        private set
    var cats by mutableStateOf(listOf<Category>())
        private set
    var accs by mutableStateOf(listOf<Account>())
        private set
    var budgets by mutableStateOf(listOf<Budget>())
        private set
    var recentNotes by mutableStateOf(listOf<DayNote>())
        private set
    var bootIssues by mutableStateOf(listOf<String>())
        private set
    var loading by mutableStateOf(false)
        private set

    val catById: Map<Long, Category> get() = cats.filter { it.id != null }.associateBy { it.id!! }
    val accById: Map<Long, Account> get() = accs.filter { it.id != null }.associateBy { it.id!! }

    suspend fun bootstrap() {
        loading = true
        val issues = mutableListOf<String>()
        try {
            withContext(Dispatchers.IO) {
                try {
                    cats = db.categories()
                } catch (e: Exception) {
                    issues += "分类读取失败: ${e.message}"
                }
                try {
                    accs = db.accounts()
                } catch (e: Exception) {
                    issues += "账户读取失败: ${e.message}"
                }
                try {
                    budgets = db.budgets()
                } catch (e: Exception) {
                    issues += "预算读取失败: ${e.message}"
                }
                if (cats.isEmpty()) issues += "分类为空"
                recentNotes = try { db.recentNotes(4) } catch (_: Exception) { emptyList() }
                reloadMonthLocked()
            }
        } finally {
            bootIssues = issues
            loading = false
        }
    }

    val monthKey: String get() = "%04d-%02d".format(month.year, month.monthValue)

    suspend fun reloadMonth() = withContext(Dispatchers.IO) { reloadMonthLocked() }

    private fun reloadMonthLocked() {
        monthTxns = try { db.txnsOfMonth(monthKey) } catch (_: Exception) { emptyList() }
    }

    fun prevMonth() { month = month.minusMonths(1); kickReload() }
    fun nextMonth() { month = month.plusMonths(1); kickReload() }

    private val scope = MainScope()
    private var reloadJob: Job? = null
    private fun kickReload() {
        reloadJob?.cancel()
        reloadJob = scope.launch { reloadMonth() }
    }

    // ---- 写操作 ----

    suspend fun saveTxn(t: Txn) = withContext(Dispatchers.IO) {
        db.saveTxn(t); reloadMonthLocked()
    }

    suspend fun deleteTxn(id: Long) = withContext(Dispatchers.IO) {
        db.deleteTxn(id); reloadMonthLocked()
    }

    suspend fun addAccount(name: String) = withContext(Dispatchers.IO) {
        db.addAccount(name); accs = db.accounts()
    }

    suspend fun saveBudget(b: Budget) = withContext(Dispatchers.IO) {
        db.saveBudget(b); budgets = db.budgets()
    }

    suspend fun refreshRecent() = withContext(Dispatchers.IO) {
        recentNotes = try { db.recentNotes(4) } catch (_: Exception) { emptyList() }
    }

    suspend fun saveNote(n: DayNote) = withContext(Dispatchers.IO) {
        db.saveNote(n); recentNotes = try { db.recentNotes(4) } catch (_: Exception) { emptyList() }
    }

    suspend fun deleteNote(id: Long) = withContext(Dispatchers.IO) {
        db.deleteNote(id); recentNotes = try { db.recentNotes(4) } catch (_: Exception) { emptyList() }
    }

    suspend fun notesOfDate(date: String): List<DayNote> = withContext(Dispatchers.IO) {
        try { db.notesOfDate(date) } catch (_: Exception) { emptyList() }
    }

    suspend fun noteDatesOfMonth(ym: String): Set<String> = withContext(Dispatchers.IO) {
        try { db.noteDatesOfMonth(ym) } catch (_: Exception) { emptySet() }
    }

    // ---- 统计 ----

    // 统计默认只计主币种（CNY），外币单独列一笔，不然汇率不折算没法加
    private val primary = "CNY"
    val monthExpense: Long get() = monthTxns.filter { it.type == 0 && it.currency == primary }.sumOf { it.amountCents }
    val monthIncome: Long get() = monthTxns.filter { it.type == 1 && it.currency == primary }.sumOf { it.amountCents }
    val foreignSums: Map<String, Long>
        get() = monthTxns.filter { it.currency != primary }
            .groupBy { it.currency }
            .mapValues { (_, l) -> l.filter { it.type == 0 }.sumOf { it.amountCents } }
            .filterValues { it > 0 }
    val today: String get() = LocalDate.now().toString()

    val todayExpense: Long
        get() = monthTxns.filter { it.type == 0 && it.date == today && it.currency == primary }.sumOf { it.amountCents }
    val todayTxnCount: Int get() = monthTxns.count { it.date == today }

    fun expenseByCategory(): List<Pair<Category?, Long>> =
        monthTxns.filter { it.type == 0 && it.currency == primary }
            .groupBy { it.categoryId }
            .map { (cid, list) -> catById[cid] to list.sumOf { it.amountCents } }
            .sortedByDescending { it.second }

    fun dailyExpense(): List<Long> {
        val days = month.lengthOfMonth()
        val out = LongArray(days)
        for (t in monthTxns) if (t.type == 0 && t.currency == primary) {
            val d = t.date.takeLast(2).toIntOrNull() ?: continue
            if (d in 1..days) out[d - 1] += t.amountCents
        }
        return out.toList()
    }

    fun groupedByDay(): Map<String, List<Txn>> = monthTxns.groupBy { it.date }.toSortedMap(compareByDescending { it })

    fun budgetOf(categoryId: Long): Budget? = budgets.firstOrNull { it.categoryId == categoryId }

    fun monthSummaryText(): String = buildString {
        appendLine("${month.year}年${month.monthValue}月账单：")
        appendLine("总支出：${fmtMoney(monthExpense)}，总收入：${fmtMoney(monthIncome)}")
        foreignSums.forEach { (c, v) -> appendLine("另有 $c 支出 ${fmtMoney(v, currency = c)}（未计入上图）") }
        appendLine("明细（日期 | 类型 | 金额 | 备注）：")
        monthTxns.take(200).forEach {
            appendLine("${it.date} | ${if (it.type == 0) "支出" else "收入"} | ${fmtMoney(it.amountCents, currency = it.currency)}${if (it.note.isEmpty()) "" else " | ${it.note}"}")
        }
    }
}
