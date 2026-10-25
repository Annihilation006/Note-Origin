package org.origin.noteorigin

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Debug
import android.os.Process
import java.io.File
import java.security.MessageDigest

/**
 * 运行环境检查。只在 release 生效，debug 构建直接跳过（不然自己都没法调）。
 */
internal object Guard {

    // 签名证书摘要。换正式签名的时候记得同步改这里
    private const val SIG_SHA256 =
        "CC:C2:4C:B0:D5:1E:92:B6:2D:49:85:37:B1:D8:80:99:C6:BE:8A:53:12:A2:D3:EC:97:61:45:44:99:D3:79:7B"

    private const val TAG = "NOG"

    fun run(ctx: Context): Boolean {
        // 签名对不上 = 被二次打包
        if (!checkSignature(ctx)) {
            kill()
            return false
        }
        // 包名被改 = 扒皮换壳分发
        if (ctx.packageName != "org.origin.noteorigin") {
            kill()
            return false
        }
        if (checkDebugger()) {
            kill()
            return false
        }
        if (checkInjected()) {
            kill()
            return false
        }
        if (checkRoot()) {
            kill()
            return false
        }
        return true
    }

    /** root环境检测。误伤root机就误伤吧，这app就作者自己用 */
    private fun checkRoot(): Boolean {
        val paths = listOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su",
            "/system/app/Superuser.apk", "/system/bin/magisk",
            "/data/adb/magisk", "/system/xbin/busybox",
        )
        return paths.any { File(it).exists() }
    }

    private fun kill() {
        // 不做任何提示，直接退。给分析的人多留一点迷惑
        try {
            Process.killProcess(Process.myPid())
        } catch (_: Throwable) {
        }
    }

    private fun checkSignature(ctx: Context): Boolean {
        return try {
            val pm = ctx.packageManager
            val info = if (Build.VERSION.SDK_INT >= 28) {
                pm.getPackageInfo(ctx.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(ctx.packageName, PackageManager.GET_SIGNATURES)
            }
            val sigs = if (Build.VERSION.SDK_INT >= 28) {
                info.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                info.signatures
            }
            if (sigs == null || sigs.isEmpty()) {
                return false
            }
            val md = MessageDigest.getInstance("SHA-256")
            for (s in sigs) {
                val hex = md.digest(s.toByteArray()).joinToString(":") {
                    String.format("%02X", it)
                }
                if (hex == SIG_SHA256) {
                    return true
                }
            }
            false
        } catch (_: Throwable) {
            // 取不到签名信息，保守处理
            false
        }
    }

    private fun checkDebugger(): Boolean {
        if (Debug.isDebuggerConnected() || Debug.waitingForDebugger()) {
            return true
        }
        // tracer pid，反编译工具爱用这个
        return try {
            File("/proc/self/status").useLines { lines ->
                lines.firstOrNull { it.startsWith("TracerPid:") }
                    ?.substringAfter(":")?.trim()?.toIntOrNull()?.let { it != 0 } == true
            }
        } catch (_: Throwable) {
            false
        }
    }

    /**
     * 常见注入框架的痕迹检查。都是明摆着的特征，挡脚本小子的程度，
     * 高手挡不住（也确实没必要追求挡住）
     */
    private fun checkInjected(): Boolean {
        // 1) 内存映射里的 frida 特征
        try {
            val maps = File("/proc/self/maps").readText()
            for (needle in listOf("frida", "gum-js-loop", "gmain", "linjector")) {
                if (needle in maps) {
                    return true
                }
            }
        } catch (_: Throwable) {
        }

        // 2) xposed
        try {
            Class.forName("de.robv.android.xposed.XposedBridge")
            return true
        } catch (_: Throwable) {
        }

        // 3) frida-server 常见驻留路径
        for (p in listOf(
            "/data/local/tmp/frida-server",
            "/data/local/tmp/re.frida.server",
            "/data/local/tmp/fs"
        )) {
            if (File(p).exists()) {
                return true
            }
        }
        return false
    }
}
