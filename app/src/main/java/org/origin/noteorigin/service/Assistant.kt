package org.origin.noteorigin.service

import org.json.JSONObject
import java.time.LocalDate

/**
 * AI操作代理：让AI直接在应用里干事，不只是分析。
 * 用严格的JSON协议：模型读上下文，返回动作；本地校验后执行。
 * 解析容错：模型偶尔会在JSON外面包话，抠出第一个{...}块。
 */

sealed class AssistantAction {
    /** 记一笔：type 0支出 1收入，金额按分 */
    data class AddTxn(
        val type: Int,
        val amountCents: Long,
        val date: String,
        val categoryName: String,
        val accountName: String?,
        val note: String,
    ) : AssistantAction()

    /** 写笔记 */
    data class AddNote(val date: String, val content: String) : AssistantAction()

    /** 查账：给一段文字总结 */
    data class Query(val question: String) : AssistantAction()

    /** 没弄明白要干嘛 */
    data class Unknown(val reply: String) : AssistantAction()
}

object Assistant {

    fun systemPrompt(today: String, categories: List<String>, accounts: List<String>): String {
        return """
你是一个记账与笔记应用里的操作助手。今天是 $today。
用户会用自然语言让你记账、写笔记或查账。你必须只回复一个JSON对象，不要任何多余文字、不要markdown代码块标记。

可用分类名: ${categories.joinToString("、")}
可用账户名: ${accounts.joinToString("、")}

动作定义：
1) 记账: {"action":"add_txn","type":"expense"或"income","amount":数字单位元,"date":"YYYY-MM-DD","category":"分类名","account":"账户名","note":"备注"}
   - 金额从用户话里解析，"25"或"25块"=25元
   - date用户说"今天"就用$today，"昨天"用前一天
   - category必须从可用列表里选最贴近的；account可选，不确定就省略
2) 写笔记: {"action":"add_note","date":"YYYY-MM-DD","content":"笔记正文"}
   - content按用户口吻整理成1-3句话
3) 查账/闲聊: {"action":"reply","text":"回答文字"}

只输出JSON。数字金额不要带单位。
        """.trimIndent()
    }

    /** 从模型回复里抠JSON（容忍包裹文字和代码块标记） */
    fun extractJson(raw: String): JSONObject? {
        var s = raw.trim()
        // 剥掉```json ```壳
        if (s.startsWith("```")) {
            s = s.removePrefix("```json").removePrefix("```").removeSuffix("```").trim()
        }
        val start = s.indexOf('{')
        val end = s.lastIndexOf('}')
        if (start < 0 || end <= start) return null
        return try {
            JSONObject(s.substring(start, end + 1))
        } catch (_: Exception) {
            null
        }
    }

    /** 把模型回复转成本地动作。解析不了返回Unknown，绝不瞎执行 */
    fun interpret(raw: String, categories: List<String>, today: LocalDate): AssistantAction {
        val j = extractJson(raw) ?: return AssistantAction.Unknown(raw.take(200))
        return when (j.optString("action")) {
            "add_txn" -> {
                val amountYuan = j.optDouble("amount", -1.0)
                if (amountYuan <= 0) return AssistantAction.Unknown("金额没解析出来，跟用户说清楚一点")
                val type = if (j.optString("type") == "income") 1 else 0
                val cat = j.optString("category").trim()
                // 模型给的分类名做一次宽松匹配，对不上就兜到"其他"
                val matched = categories.firstOrNull { it.equals(cat, ignoreCase = true) || it.contains(cat) || cat.contains(it) }
                    ?: if (type == 0) "其他" else "其他收入"
                val acc = j.optString("account", "").trim().ifEmpty { null }
                val date = j.optString("date", today.toString()).trim().ifEmpty { today.toString() }
                AssistantAction.AddTxn(
                    type = type,
                    amountCents = Math.round(amountYuan * 100),
                    date = if (date.matches(Regex("\\d{4}-\\d{2}-\\d{2}"))) date else today.toString(),
                    categoryName = matched,
                    accountName = acc,
                    note = j.optString("note", "").trim(),
                )
            }
            "add_note" -> {
                val content = j.optString("content", "").trim()
                if (content.isEmpty()) return AssistantAction.Unknown("笔记内容是空的")
                val date = j.optString("date", today.toString()).trim().ifEmpty { today.toString() }
                AssistantAction.AddNote(
                    date = if (date.matches(Regex("\\d{4}-\\d{2}-\\d{2}"))) date else today.toString(),
                    content = content,
                )
            }
            "reply" -> AssistantAction.Unknown(j.optString("text", "").trim().ifEmpty { "（空回复）" })
            else -> AssistantAction.Unknown(j.optString("text", "").trim().ifEmpty { raw.take(200) })
        }
    }

    /** 用户的话 + 最近账单摘要，一起给模型当上下文 */
    fun userPayload(input: String, monthExpense: String, txnCount: Int): String {
        return "用户输入：$input\n\n（当前月支出 $monthExpense，共 $txnCount 笔，供参考）"
    }
}
