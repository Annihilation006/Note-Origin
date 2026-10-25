package org.origin.noteorigin

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!BuildConfig.DEBUG) {
            // release下过一遍检查，debug构建不受影响
            Guard.run(applicationContext)
        }
    }
}
