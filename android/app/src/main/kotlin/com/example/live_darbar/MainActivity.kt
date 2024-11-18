package com.example.live_darbar


import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle


class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.yourapp/audio"

     private lateinit var methodChannel: MethodChannel

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize the MethodChannel once during engine configuration
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            // Handle Flutter method calls here, if needed
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleAppActionIntent(intent)
    }

    private fun handleAppActionIntent(intent: Intent) {
        if (intent.hasExtra("android.intent.extra.INTENT")) {
            val action = intent.getStringExtra("android.intent.extra.INTENT")
            if (action == "custom.actions.intent.PLAY_LIVE_DARBAR") {
                // Use the initialized methodChannel to send a message to Flutter
                methodChannel.invokeMethod("playLiveDarbar", null)
            }
        }
    }
}
