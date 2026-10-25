package org.origin.noteorigin

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * 调用 SiliconFlow 的 Qwen 模型对笔记内容做总结。
 * 对应原 Python 版 main.py 里的 ask_qwen()。
 */
object AiClient {

    private val JSON = "application/json; charset=utf-8".toMediaType()

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()

    /** 返回模型回复文本；失败抛异常，由调用方展示。 */
    suspend fun askQwen(apiKey: String, noteText: String): String = withContext(Dispatchers.IO) {
        val body = JSONObject().apply {
            put("model", "Qwen/Qwen2.5-7B-Instruct")
            put("messages", JSONObject().put("role", "user").put("content", noteText)
                .let { org.json.JSONArray().put(it) })
        }

        val request = Request.Builder()
            .url("https://api.siliconflow.cn/v1/chat/completions")
            .header("Authorization", "Bearer $apiKey")
            .post(body.toString().toRequestBody(JSON))
            .build()

        client.newCall(request).execute().use { resp ->
            if (!resp.isSuccessful) {
                throw RuntimeException("HTTP ${resp.code}")
            }
            val payload = resp.body?.string().orEmpty()
            JSONObject(payload)
                .getJSONArray("choices")
                .getJSONObject(0)
                .getJSONObject("message")
                .getString("content")
        }
    }
}
