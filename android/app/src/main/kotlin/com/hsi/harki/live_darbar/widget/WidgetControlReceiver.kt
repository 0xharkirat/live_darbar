package com.hsi.harki.live_darbar.widget

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.session.MediaControllerCompat
import android.util.Log
import com.ryanheise.audioservice.AudioService

/**
 * The two buttons on the widget: Live Kirtan, in gold, and Hukamnama.
 *
 * A tap arrives here as a broadcast from the launcher, with no app screen
 * opening and, often, no app process alive. This receiver is not exported.
 * Only the widget's own PendingIntents reach it, and each carries one of the
 * four fixed actions in [Command]. No extra on the intent is ever read.
 */
class WidgetControlReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val command = Command.of(intent.action) ?: return
        // The work waits on the media session, which may not exist yet. Hold
        // the broadcast open until it has the command, or has given up.
        val pending = goAsync()
        WidgetControl.handle(context.applicationContext, command) { pending.finish() }
    }
}

/**
 * Sends a widget tap to the media session, the way Android Auto does.
 *
 * ## How a tap reaches the player with the app dead
 *
 * 1. **The widget answers first.** For a play, the receiver writes
 *    "loading" for that source into the store and redraws. The button
 *    changes to a dimmed "…" at once, long before audio. The press ripple has
 *    already answered on touch-down, in the launcher.
 * 2. **The service starts as a foreground service.** A tap on a widget is one
 *    of the actions that Android 12 and newer allow to start one from the
 *    background. The receiver calls `startForegroundService` on audio_service's
 *    [AudioService] right then, while that permission is fresh. A start from
 *    inside the service a second later would have to rely on it still being
 *    there.
 * 3. **The command goes to the media session.** The receiver binds to the
 *    service with a `MediaBrowserCompat`, takes the session's controller, and
 *    calls `playFromMediaId`, `pause` or `stop`. Those are the same calls
 *    Android Auto makes, with the same ids (`MediaCatalog.idFor` in Dart).
 *    audio_service holds a call until the Dart handler has started, so
 *    the command is not lost on a cold start.
 * 4. **Dart takes over.** The handler plays, and `WidgetPlaybackSync` writes
 *    each state it reaches. The first one replaces the widget's own.
 *
 * ## If the app never answers
 *
 * `startForegroundService` obliges the service to call `startForeground`
 * within 10 seconds, or the system ends the app. audio_service calls it
 * when playback starts. If the app has not reported by [WATCHDOG_MS], the
 * receiver stops the service and puts the widget back to idle, which is
 * well inside the limit.
 */
internal object WidgetControl {
    private const val TAG = "LiveDarbarWidget"

    /** Longer than a cold start on a slow phone, shorter than the system's 10 seconds. */
    const val WATCHDOG_MS = 7_000L

    /** How long the bind may take before the command is given up. */
    private const val CONNECT_TIMEOUT_MS = 6_000L

    /** Lets the one-way binder call cross before the bind is let go. */
    private const val SETTLE_MS = 300L

    private val main = Handler(Looper.getMainLooper())

    fun handle(context: Context, command: Command, done: () -> Unit) {
        val now = System.currentTimeMillis()
        val shown = WidgetStore.readPlayback(context)
        val believed = WidgetPlayback.reconcile(shown, WidgetStore.processStartMs(now), now)

        val source = command.source
        if (source == null) {
            // Stop or pause. If the session is not there, the widget was
            // showing a state that has ended. Say so, and do not start the
            // service just to tell it to stop.
            if (believed.state == PlayState.IDLE) {
                if (shown.state != PlayState.IDLE) {
                    WidgetStore.writePlayback(context, PlayState.IDLE, null, now)
                    WidgetRenderer.updateAll(context)
                }
                done()
                return
            }
            send(context, command) { done() }
            return
        }

        // The source is already on. The button was a moment out of date, so
        // the play is done. Draw the true state, and start nothing.
        if (!WidgetPlayback.needsStart(believed, source)) {
            WidgetRenderer.updateAll(context)
            done()
            return
        }

        // Play. The widget answers now, then the app does the rest.
        WidgetStore.writePlayback(context, PlayState.LOADING, source, now)
        WidgetRenderer.updateAll(context)
        val started = startService(context)
        send(context, command) { delivered ->
            if (!delivered && !started) giveUp(context)
            done()
        }
        main.postDelayed({ checkTheAppAnswered(context) }, WATCHDOG_MS)
    }

    /**
     * Starts audio_service's service as a foreground service. A widget tap is
     * on Android's list of actions that may do so from the background.
     */
    private fun startService(context: Context): Boolean {
        val intent = Intent(context, AudioService::class.java)
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            true
        } catch (e: Exception) {
            // Refused, for a reason this build cannot know. Binding below
            // still creates the service, and the app plays if it can.
            Log.w(TAG, "Could not start the service from the widget", e)
            false
        }
    }

    /** Binds to the session, sends [command], and lets go. [done] gets whether it was sent. */
    private fun send(context: Context, command: Command, done: (Boolean) -> Unit) {
        var browser: MediaBrowserCompat? = null
        var finished = false
        fun finish(sent: Boolean) {
            if (finished) return
            finished = true
            try {
                browser?.disconnect()
            } catch (e: Exception) {
                Log.w(TAG, "Could not let go of the media session", e)
            }
            done(sent)
        }
        val timeout = Runnable { finish(false) }

        browser = MediaBrowserCompat(
            context,
            ComponentName(context, AudioService::class.java),
            object : MediaBrowserCompat.ConnectionCallback() {
                override fun onConnected() {
                    main.removeCallbacks(timeout)
                    val sent = try {
                        val controls = MediaControllerCompat(context, browser!!.sessionToken)
                            .transportControls
                        when (command) {
                            Command.PLAY_LIVE -> controls.playFromMediaId(Source.LIVE.mediaId, null)
                            Command.PLAY_HUKAMNAMA ->
                                controls.playFromMediaId(Source.HUKAMNAMA.mediaId, null)
                            Command.PAUSE -> controls.pause()
                            Command.STOP -> controls.stop()
                        }
                        true
                    } catch (e: Exception) {
                        Log.e(TAG, "Could not send ${command.name} to the media session", e)
                        false
                    }
                    main.postDelayed({ finish(sent) }, SETTLE_MS)
                }

                override fun onConnectionFailed() {
                    main.removeCallbacks(timeout)
                    finish(false)
                }
            },
            null,
        )
        main.postDelayed(timeout, CONNECT_TIMEOUT_MS)
        try {
            browser.connect()
        } catch (e: Exception) {
            Log.e(TAG, "Could not bind to the media session", e)
            main.removeCallbacks(timeout)
            finish(false)
        }
    }

    /**
     * Runs [WATCHDOG_MS] after a play. If Dart has not written a state of its
     * own by now, the app is not coming: end the service before the system's
     * limit for a foreground start, and say idle.
     */
    private fun checkTheAppAnswered(context: Context) {
        val stored = WidgetStore.readPlayback(context)
        if (stored.byWidget && stored.state == PlayState.LOADING) {
            Log.w(TAG, "The app did not answer a widget tap. Stopping the service.")
            giveUp(context)
        } else {
            // The app answered. Redraw anyway: it costs nothing and settles
            // any state that was written while a draw was in flight.
            WidgetRenderer.updateAll(context)
        }
    }

    private fun giveUp(context: Context) {
        try {
            context.stopService(Intent(context, AudioService::class.java))
        } catch (e: Exception) {
            Log.w(TAG, "Could not stop the service", e)
        }
        WidgetStore.writePlayback(context, PlayState.IDLE, null)
        WidgetRenderer.updateAll(context)
    }
}
