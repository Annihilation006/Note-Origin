package org.origin.noteorigin.service

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/** AI接入层，三协议，与Flutter版行为一致 */
enum class ApiFormat { chatCompletions, anthropicMessages, responses;

    val label: String
        get() = when (this) {
            chatCompletions -> "ChatCompletions"
            anthropicMessages -> "AnthropicMessages"
            responses -> "Responses"
        }

    val baseHint: String
        get() = when (this) {
            chatCompletions -> "https://api.xxx.com/v1"
            anthropicMessages -> "https://api.xxx.com"
            responses -> "https://api.xxx.com/v1"
        }

    val modelHint: String
        get() = when (this) {
            chatCompletions -> "Qwen/Qwen2.5-7B-Instruct"
            anthropicMessages -> "claude-sonnet-4-5"
            responses -> "gpt-4o"
        }
}

class AiConfig {
    var baseUrl: String = "https://api.siliconflow.cn/v1"
    var apiKey: String = ""
    var model: String = "Qwen/Qwen2.5-7B-Instruct"
    var format: ApiFormat = ApiFormat.chatCompletions

    val ready: Boolean get() = apiKey.isNotBlank() && baseUrl.isNotBlank()

    companion object {
        private const val K_BASE = "ai_base_url"
        private const val K_KEY = "ai_api_key"
        private const val K_MODEL = "ai_model"
        private const val K_FORMAT = "ai_format"

        // 老配置迁移，gemini回落chatCompletions
        private val legacy = mapOf(
            "openai" to ApiFormat.chatCompletions,
            "anthropic" to ApiFormat.anthropicMessages,
            "gemini" to ApiFormat.chatCompletions,
        )

        fun load(ctx: Context): AiConfig = AiConfig().apply {
            try {
                val sp = ctx.getSharedPreferences("secure_config", Context.MODE_PRIVATE)
                baseUrl = sp.getString(K_BASE, baseUrl) ?: baseUrl
                apiKey = SecretBox.unseal(sp.getString(K_KEY, "") ?: "")
                model = sp.getString(K_MODEL, model) ?: model
                val raw = sp.getString(K_FORMAT, null)
                format = when {
                    raw == null -> ApiFormat.chatCompletions
                    legacy.containsKey(raw) -> legacy[raw]!!
                    else -> ApiFormat.entries.firstOrNull { it.name == raw } ?: ApiFormat.chatCompletions
                }
            } catch (_: Exception) {
            }
        }
    }

    fun save(ctx: Context) {
        try {
            ctx.getSharedPreferences("secure_config", Context.MODE_PRIVATE).edit()
                .putString(K_BASE, baseUrl)
                .putString(K_KEY, SecretBox.seal(apiKey))
                .putString(K_MODEL, model)
                .putString(K_FORMAT, format.name)
                .apply()
        } catch (_: Exception) {
        }
    }
}

object Ai {
    private const val VERSION = "/v1"

    private val JSON = "application/json; charset=utf-8".toMediaType()
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(40, TimeUnit.SECONDS)
        .build()

    /** 统一endpoint拼接，规则同Flutter版：完整路径>v1结尾>补v1 */
    fun buildEndpoint(fmt: ApiFormat, base: String): String {
        var b = base.trim().trimEnd('/')
        if (b.isEmpty()) return b
        val suffix = when (fmt) {
            ApiFormat.chatCompletions -> "/chat/completions"
            ApiFormat.anthropicMessages -> "/messages"
            ApiFormat.responses -> "/responses"
        }
        return when {
            b.endsWith(suffix) -> b
            b.endsWith(VERSION) -> b + suffix
            else -> b + VERSION + suffix
        }
    }

    private fun body(fmt: ApiFormat, model: String, system: String?, user: String): String {
        val j = JSONObject()
        when (fmt) {
            ApiFormat.chatCompletions -> {
                val msgs = JSONArray()
                if (!system.isNullOrBlank()) msgs.put(JSONObject().put("role", "system").put("content", system))
                msgs.put(JSONObject().put("role", "user").put("content", user))
                j.put("model", model).put("messages", msgs)
                    .put("temperature", 0.6).put("max_tokens", 1024)
            }
            ApiFormat.anthropicMessages -> {
                j.put("model", model).put("max_tokens", 1024)
                if (!system.isNullOrBlank()) j.put("system", system)
                j.put("messages", JSONArray().put(JSONObject().put("role", "user").put("content", user)))
            }
            ApiFormat.responses -> {
                j.put("model", model).put("input", user).put("max_output_tokens", 1024)
                if (!system.isNullOrBlank()) j.put("instructions", system)
            }
        }
        return j.toString()
    }

    private fun headers(fmt: ApiFormat, key: String): Map<String, String> = when (fmt) {
        ApiFormat.anthropicMessages -> mapOf(
            "x-api-key" to key, "anthropic-version" to "2023-06-01", "Content-Type" to "application/json",
        )
        else -> mapOf("Authorization" to "Bearer $key", "Content-Type" to "application/json")
    }

    private fun parse(fmt: ApiFormat, payload: String): String {
        val j = JSONObject(payload)
        return when (fmt) {
            ApiFormat.chatCompletions -> {
                val c = j.optJSONArray("choices")?.optJSONObject(0)?.optJSONObject("message")?.optString("content")
                if (c.isNullOrBlank()) throw IllegalStateException("返回里没有内容，检查下模型名")
                c
            }
            ApiFormat.anthropicMessages -> {
                val sb = StringBuilder()
                val blocks = j.optJSONArray("content") ?: JSONArray()
                for (i in 0 until blocks.length()) {
                    val b = blocks.optJSONObject(i) ?: continue
                    if (b.optString("type") == "text") sb.append(b.optString("text"))
                }
                if (sb.isBlank()) throw IllegalStateException("返回里没有内容（stop_reason: ${j.opt("stop_reason")}）")
                sb.toString()
            }
            ApiFormat.responses -> {
                val sb = StringBuilder()
                val out = j.optJSONArray("output") ?: JSONArray()
                for (i in 0 until out.length()) {
                    val item = out.optJSONObject(i) ?: continue
                    if (item.optString("type") != "message") continue
                    val parts = item.optJSONArray("content") ?: continue
                    for (k in 0 until parts.length()) {
                        val p = parts.optJSONObject(k) ?: continue
                        if (p.optString("type") == "output_text") sb.append(p.optString("text"))
                    }
                }
                if (sb.isBlank()) throw IllegalStateException("返回里没有内容（status: ${j.opt("status")}）")
                sb.toString()
            }
        }
    }

    /** 非流式单轮，失败抛异常。错误信息尽量带原因，别让用户对着"不通"两个字猜 */
    suspend fun chat(cfg: AiConfig, user: String, system: String? = null): String = withContext(Dispatchers.IO) {
        val url = try {
            buildEndpoint(cfg.format, cfg.baseUrl)
        } catch (e: Exception) {
            throw IllegalStateException("地址不对: ${cfg.baseUrl}")
        }
        if (!url.startsWith("http")) {
            throw IllegalStateException("地址不合法: $url")
        }
        val req = try {
            Request.Builder()
                .url(url)
                .headers(okhttp3.Headers.headersOf(*headers(cfg.format, cfg.apiKey.trim()).flatMap { listOf(it.key, it.value) }.toTypedArray()))
                .post(body(cfg.format, cfg.model, system, user).toRequestBody(JSON))
                .build()
        } catch (e: IllegalArgumentException) {
            throw IllegalStateException("URL解析失败: $url（检查有没有多余字符）")
        }
        try {
            client.newCall(req).execute().use { resp ->
                val text = resp.body?.string().orEmpty()
                if (!resp.isSuccessful) {
                    var detail = ""
                    try {
                        val j = JSONObject(text)
                        detail = j.optJSONObject("error")?.optString("message")
                            ?: j.optJSONObject("error")?.optString("type")
                            ?: j.optString("message")
                    } catch (_: Exception) {
                    }
                    if (detail.isBlank()) detail = text.take(120)
                    throw IllegalStateException("HTTP ${resp.code}${if (detail.isBlank()) "" else " · $detail"}")
                }
                parse(cfg.format, text)
            }
        } catch (e: java.net.SocketTimeoutException) {
            throw IllegalStateException("连接超时（服务器没在时限内响应）")
        } catch (e: java.net.UnknownHostException) {
            throw IllegalStateException("域名解析失败: ${e.message ?: "检查Base URL拼写"}")
        } catch (e: java.net.ConnectException) {
            throw IllegalStateException("连不上服务器: ${e.message ?: "网络不通或端口关闭"}")
        } catch (e: javax.net.ssl.SSLException) {
            throw IllegalStateException("SSL握手失败: ${e.message?.take(120) ?: "证书问题"}")
        } catch (e: IllegalStateException) {
            throw e
        } catch (e: Exception) {
            throw IllegalStateException("${e::class.java.simpleName}: ${e.message ?: "未知网络错误"}")
        }
    }

    suspend fun ping(cfg: AiConfig): String =
        chat(cfg, "回复\"OK\"两个字母就行，不要任何别的内容")
}
