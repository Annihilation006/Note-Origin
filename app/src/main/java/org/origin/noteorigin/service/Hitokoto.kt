package org.origin.noteorigin.service

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

data class Quote(val text: String, val from: String)

/** 一言，失败走本地句池 */
object Hitokoto {
    private val client = OkHttpClient.Builder()
        .connectTimeout(4, TimeUnit.SECONDS)
        .readTimeout(5, TimeUnit.SECONDS)
        .build()

    private val local = listOf(
        Quote("生活是种律动，须有光有影，有左有右，有晴有雨。", "老舍"),
        Quote("凡是过往，皆为序章。", "莎士比亚"),
        Quote("凌晨四点钟，看到海棠花未眠。", "川端康成"),
        Quote("从前的日色变得慢，车、马、邮件都慢。", "木心"),
        Quote("满地都是六便士，他却抬头看见了月亮。", "毛姆"),
        Quote("我们都在阴沟里，但仍有人仰望星空。", "王尔德"),
        Quote("日日重复同样的事，遵循着与昨日相同的惯例。", "太宰治"),
    )

    suspend fun fetch(): Quote = withContext(Dispatchers.IO) {
        try {
            val req = Request.Builder()
                .url("https://v1.hitokoto.cn/?encode=json&maxlength=36")
                .get()
                .build()
            client.newCall(req).execute().use { resp ->
                if (!resp.isSuccessful) return@withContext fallback()
                val j = JSONObject(resp.body?.string().orEmpty())
                val text = j.optString("hitokoto").trim()
                if (text.isEmpty()) return@withContext fallback()
                val who = j.optString("from_who").trim()
                val src = j.optString("from").trim()
                val from = when {
                    who.isNotEmpty() && src.isNotEmpty() -> "$who《$src》"
                    who.isNotEmpty() -> who
                    src.isNotEmpty() -> "《$src》"
                    else -> "一言"
                }
                Quote(text, from)
            }
        } catch (_: Exception) {
            fallback()
        }
    }

    private fun fallback(): Quote {
        val dayOfYear = java.time.LocalDate.now().dayOfYear
        return local[dayOfYear % local.size]
    }
}
