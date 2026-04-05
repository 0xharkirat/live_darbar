package com.hsi.harki.live_darbar

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    companion object {
        private const val AUDIO_CHANNEL = "com.hsi.harki.live_darbar/audio"
        private const val OACP_CHANNEL = "com.hsi.harki.live_darbar/oacp"
        private const val METHOD_HANDLE_OACP_COMMAND = "handleOacpCommand"
        private const val TAG = "LiveDarbar"
    }

    private var oacpChannel: MethodChannel? = null
    private val handler = Handler(Looper.getMainLooper())
    private var pendingOacpPayload: HashMap<String, Any>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        oacpChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OACP_CHANNEL
        )

        // Drain any command that arrived before the channel was ready
        pendingOacpPayload?.let { payload ->
            pendingOacpPayload = null
            Log.d(TAG, "Draining pending OACP command: ${payload["command"]}")
            sendOacpCommandWithRetry(payload, retriesLeft = 40)
        }

        // Dispatch any OACP intent that launched the app
        dispatchOacpIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity created")

        // Handle legacy intent
        handleLegacyIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        handleLegacyIntent(intent)
        dispatchOacpIntent(intent)
    }

    override fun onDestroy() {
        // Cancel any pending retry callbacks to prevent Activity leak
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    // --- Legacy intent (custom.actions.intent.PLAY_LIVE_DARBAR) ---

    private fun handleLegacyIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        if (action == "custom.actions.intent.PLAY_LIVE_DARBAR") {
            Log.d(TAG, "Legacy intent received: $action")
            val messenger = flutterEngine?.dartExecutor?.binaryMessenger
            if (messenger != null) {
                MethodChannel(messenger, AUDIO_CHANNEL).invokeMethod("playLiveDarbar", null)
            } else {
                Log.e(TAG, "FlutterEngine or BinaryMessenger is null")
            }
        }
    }

    // --- OACP intent handling ---

    private fun dispatchOacpIntent(intent: Intent?) {
        val payload = buildOacpPayload(intent) ?: return
        // Clear consumed action to prevent re-dispatch on resume
        intent?.action = null

        // Cancel any in-flight retry chain from a previous command
        handler.removeCallbacksAndMessages(null)

        Log.d(TAG, "OACP command: ${payload["command"]}")

        val channel = oacpChannel
        if (channel == null) {
            // Channel not ready yet — queue for drain in configureFlutterEngine
            pendingOacpPayload = payload
            Log.d(TAG, "OACP channel not ready, queuing command")
            return
        }

        sendOacpCommandWithRetry(payload, retriesLeft = 40)
    }

    private fun buildOacpPayload(intent: Intent?): HashMap<String, Any>? {
        val action = intent?.action ?: return null
        val payload = hashMapOf<String, Any>(
            "requestId" to UUID.randomUUID().toString()
        )

        when {
            action.endsWith(".oacp.ACTION_PLAY_LIVE_KIRTAN") -> {
                payload["command"] = "play_live_kirtan"
            }
            action.endsWith(".oacp.ACTION_PLAY_MUKHWAK") -> {
                payload["command"] = "play_mukhwak"
            }
            action.endsWith(".oacp.ACTION_PLAY_KATHA") -> {
                payload["command"] = "play_katha"
            }
            action.endsWith(".oacp.ACTION_VIEW_MUKHWAK_PDF") -> {
                payload["command"] = "view_mukhwak_pdf"
            }
            else -> return null
        }

        return payload
    }

    private fun sendOacpCommandWithRetry(payload: HashMap<String, Any>, retriesLeft: Int) {
        val channel = oacpChannel ?: run {
            Log.w(TAG, "OACP channel became null during retry")
            return
        }

        channel.invokeMethod(METHOD_HANDLE_OACP_COMMAND, payload, object : MethodChannel.Result {
            override fun success(result: Any?) {
                Log.d(TAG, "OACP command delivered: ${payload["command"]}")
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                if (retriesLeft > 0) {
                    handler.postDelayed({
                        sendOacpCommandWithRetry(payload, retriesLeft - 1)
                    }, 250)
                } else {
                    Log.e(TAG, "OACP command failed after retries: $errorMessage")
                }
            }

            override fun notImplemented() {
                if (retriesLeft > 0) {
                    handler.postDelayed({
                        sendOacpCommandWithRetry(payload, retriesLeft - 1)
                    }, 250)
                } else {
                    Log.e(TAG, "OACP handler not implemented in Dart after retries")
                }
            }
        })
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine {
        return AudioServicePlugin.getFlutterEngine(context)
    }
}
