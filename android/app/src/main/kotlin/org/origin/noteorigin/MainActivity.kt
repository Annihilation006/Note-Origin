package org.origin.noteorigin

import android.content.pm.ApplicationInfo
import android.os.Bundle

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // debuggable标志位判断，debug构建跳过检查
        val release = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) == 0
        if (release) {
            Guard.run(applicationContext)
        }
    }
}
