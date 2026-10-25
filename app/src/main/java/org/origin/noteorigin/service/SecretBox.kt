package org.origin.noteorigin.service

/** 本地敏感串编码，跟Flutter版SecretBox同算法，存储格式互通 */
object SecretBox {
    private val k = intArrayOf(0x5a, 0x3c, 0x71, 0x2f, 0x64, 0x18, 0x4b, 0x77)

    fun seal(plain: String): String {
        if (plain.isEmpty()) return ""
        val b = plain.toByteArray(Charsets.UTF_8)
        val out = ByteArray(b.size) { (b[it].toInt() xor k[it % k.size]).toByte() }
        return android.util.Base64.encodeToString(out, android.util.Base64.NO_WRAP)
    }

    fun unseal(sealed: String): String {
        if (sealed.isEmpty()) return ""
        return try {
            val b = android.util.Base64.decode(sealed, android.util.Base64.NO_WRAP)
            val out = ByteArray(b.size) { (b[it].toInt() xor k[it % k.size]).toByte() }
            String(out, Charsets.UTF_8)
        } catch (_: Exception) {
            ""
        }
    }
}
