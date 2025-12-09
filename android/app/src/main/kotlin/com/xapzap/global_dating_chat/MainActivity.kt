package com.xapzap.global_dating_chat

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Opt the app into edge-to-edge using WindowCompat (not deprecated)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
}
