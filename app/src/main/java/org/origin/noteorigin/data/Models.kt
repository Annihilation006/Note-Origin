package org.origin.noteorigin.data

/** 与Flutter版完全同构的数据模型，金额一律按分存Int */
data class Txn(
    val id: Long? = null,
    val type: Int,           // 0支出 1收入
    val amountCents: Long,
    val categoryId: Long,
    val accountId: Long,
    val date: String,        // yyyy-MM-dd
    val note: String = "",
    val createdAt: Long,
    val currency: String = "CNY",
)

data class Category(
    val id: Long? = null,
    val type: Int,
    val name: String,
    val icon: String,
)

data class Account(val id: Long? = null, val name: String)

data class DayNote(
    val id: Long? = null,
    val date: String,
    val content: String,
    val createdAt: Long,
)

data class Budget(
    val id: Long? = null,
    val categoryId: Long,    // 0=当月总预算
    val amountCents: Long,
)
