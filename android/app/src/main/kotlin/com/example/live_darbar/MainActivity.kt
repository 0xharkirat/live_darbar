package com.hsi.harki.live_darbar

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.hsi.harki.live_darbar/audio"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MainActivity", "Custom MainActivity created")

        // Handle the initial intent
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)

        // Handle subsequent intents
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        val action = intent.action
        if (action == "custom.actions.intent.PLAY_LIVE_DARBAR") {
            Log.d("MainActivity", "Custom intent received: $action")

            // Safely check for non-null binaryMessenger
            val messenger = flutterEngine?.dartExecutor?.binaryMessenger
            if (messenger != null) {
                MethodChannel(messenger, CHANNEL).invokeMethod("playLiveDarbar", null)
            } else {
                Log.e("MainActivity", "FlutterEngine or BinaryMessenger is null")
            }
        }
    }

    override fun provideFlutterEngine(@NonNull context: Context): FlutterEngine {
        return AudioServicePlugin.getFlutterEngine(context)
    }
}
