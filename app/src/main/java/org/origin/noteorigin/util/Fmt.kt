package org.origin.noteorigin.util

import android.content.Context
import java.io.File
import java.time.LocalDate

/** 金额/日期/导出工具，语义与Flutter版一致（按分存，不碰浮点累计） */

fun fmtMoney(cents: Long, symbol: Boolean = true): String {
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
    return "${if (neg) "-" else ""}${if (symbol) "¥" else ""}$s"
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
