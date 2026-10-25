package org.origin.noteorigin

/**
 * 核心逻辑层，移植自原 Swift 内核 core/Logic.swift。
 *
 * Swift 版通过 @_cdecl("execute_data_purge") 暴露 C 接口，对
 * "Note for {date}: ..." 做逐字符 XOR 0x07 的可逆变换（混淆，非加密）。
 * 本类保持相同语义：executeDataPurge 产出混淆串，decrypt 还原。
 */
object CoreLogic {

    private const val XOR_KEY = 0x07

    fun secretMessage(date: String): String =
        "Note for $date: This is a hardware-level encrypted message."

    fun xorTransform(input: String): String = buildString {
        for (c in input) {
            append((c.code xor XOR_KEY).toChar())
        }
    }

    /** 对应原 Swift 内核的 execute_data_purge 入口。 */
    fun executeDataPurge(date: String, @Suppress("UNUSED_PARAMETER") lang: String): String =
        xorTransform(secretMessage(date))

    fun decrypt(obfuscated: String): String = xorTransform(obfuscated)
}
