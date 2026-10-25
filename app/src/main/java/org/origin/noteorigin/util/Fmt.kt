package org.origin.noteorigin.util

import android.content.Context
import java.io.File
import java.time.LocalDate

/** 金额/日期/导出工具，语义与Flutter版一致（按分存，不碰浮点累计） */

// 支持的币种。记账为主，够用就行，要加往表里塞
val CURRENCIES = linkedMapOf(
    "CNY" to "¥", "USD" to "$", "EUR" to "€",
    "GBP" to "£", "JPY" to "¥", "KRW" to "₩", "HKD" to "HK$",
)

fun symbolOf(currency: String): String = CURRENCIES[currency] ?: currency

fun fmtMoney(cents: Long, symbol: Boolean = true, currency: String = "CNY"): String {
    val neg = cents < 0
    val v = kotlin.math.abs(cents) / 100.0
    var s = String.format("%.2f", v)
    val dot = s.indexOf('.')
    val intPart = s.substring(0, dot)
    val sb = StringBuilder()
    for (i in intPart.indices) {
        sb.append(intPart[i])
        val remain = intPart.length - i - 1
        if (remain > 0 && remain % 3 == 0) sb.append(',')
    }
    s = sb.toString() + s.substring(dot)
    val sym = if (symbol) symbolOf(currency) else ""
    // 非人民币带上代码避免¥混淆
    return if (currency == "JPY") "${if (neg) "-" else ""}$sym$s"
    else "${if (neg) "-" else ""}$sym$s${if (currency != "CNY" && currency !in listOf("USD","EUR","GBP","KRW","HKD")) " $currency" else ""}"
}

fun parseMoneyToCents(input: String): Long? {
    val s = input.trim().replace(Regex("[,\\s]"), "")
    if (s.isEmpty()) return null
    val d = s.toDoubleOrNull() ?: return null
    if (d < 0 || d > 9_999_999_999.0) return null
    return Math.round(d * 100)
}

fun todayStr(): String = LocalDate.now().toString()

fun exportCsv(ctx: Context, lines: List<String>): File {
    val dir = File(ctx.filesDir, "exports").apply { mkdirs() }
    val f = File(dir, "note_origin_${todayStr().replace("-", "")}.csv")
    f.writeText("\uFEFF" + lines.joinToString("\n"), Charsets.UTF_8)
    return f
}
