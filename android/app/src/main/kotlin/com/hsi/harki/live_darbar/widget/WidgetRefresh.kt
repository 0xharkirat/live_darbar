package com.hsi.harki.live_darbar.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * When the widget refreshes by itself, with the app closed.
 *
 * Two runs a day, both in India time, because the Hukamnama is SGPC's:
 *
 * - [Slot.MIDNIGHT] at 00:10. The new SGPC day has begun. The text is not
 *   posted yet, so this run mostly moves the widget on to the new date. It
 *   asks for the text anyway, which costs one small request.
 * - [Slot.MORNING] at 09:00. SGPC has posted by about 06:00. This run fetches
 *   today's Hukamnama. If the phone is offline it tries again, up to 3 runs.
 *
 * Each run books the next one before it starts, under a name that holds the
 * day it is for. So a run that dies still leaves the next one booked, and
 * booking twice does nothing. WorkManager keeps the bookings across a reboot.
 *
 * Android decides when a booked run really starts. In Doze it can be late by
 * hours, and some phone makers stop background work for apps that are not
 * opened for days. Nothing here can force it. That is why the widget does not
 * depend on it for the date: Flutter writes a week of dates ahead, and the
 * widget picks the one for today from the clock. Only a fresh Hukamnama waits
 * on this run, and until it comes the widget says which day its text is from.
 */
internal object WidgetRefresh {
    private const val TAG = "LiveDarbarWidget"

    /** Marks every request, so one call can cancel them all. */
    const val WORK_TAG = "ld_widget_refresh"

    const val INPUT_SLOT = "slot"

    /** The channel to widget_background.dart. The same name is in Dart. */
    const val CHANNEL = "com.hsi.harki.live_darbar/widget_worker"

    /**
     * The Dart entry point. It is a function in lib/main.dart, which is
     * where the compiler looks when no library is named. It must live there
     * so that the compiler keeps it in the program.
     */
    const val DART_ENTRY = "widgetRefreshEntry"

    private const val IST_OFFSET_MS = 19_800_000L
    private const val DAY_MS = 86_400_000L

    /** How long a run may hold the Flutter engine before it is given up. */
    private const val ENGINE_TIMEOUT_SECONDS = 90L

    /** The most runs a morning slot makes, counting the first. */
    private const val MAX_ATTEMPTS = 3

    enum class Slot(val key: String, val minuteOfDayIst: Int) {
        MIDNIGHT("midnight", 10),
        MORNING("morning", 9 * 60),
    }

    /** The first instant after [nowMs] that is [minuteOfDayIst] in India time. */
    fun nextRunAt(nowMs: Long, minuteOfDayIst: Int): Long {
        val istNow = nowMs + IST_OFFSET_MS
        val dayStart = Math.floorDiv(istNow, DAY_MS) * DAY_MS
        var target = dayStart + minuteOfDayIst * 60_000L
        if (target <= istNow) target += DAY_MS
        return target - IST_OFFSET_MS
    }

    /** Books the next run of each slot. Safe to call as often as you like. */
    fun schedule(context: Context) {
        val now = System.currentTimeMillis()
        for (slot in Slot.values()) {
            val at = nextRunAt(now, slot.minuteOfDayIst)
            val name = "${WORK_TAG}_${slot.key}_${istDay(at)}"
            enqueue(context, name, slot.key, at - now)
        }
    }

    /** One run as soon as there is a network. For a widget that was just added. */
    fun runNow(context: Context) {
        enqueue(context, "${WORK_TAG}_now", "now", 0L)
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelAllWorkByTag(WORK_TAG)
    }

    fun hasWidgets(context: Context): Boolean {
        val ids = AppWidgetManager.getInstance(context).getAppWidgetIds(
            ComponentName(context, LiveDarbarWidgetProvider::class.java)
        )
        return ids.isNotEmpty()
    }

    private fun enqueue(context: Context, name: String, slot: String, delayMs: Long) {
        val request = OneTimeWorkRequest.Builder(WidgetRefreshWorker::class.java)
            .setInitialDelay(maxOf(delayMs, 0L), TimeUnit.MILLISECONDS)
            .setConstraints(
                Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
            )
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 10, TimeUnit.MINUTES)
            .setInputData(Data.Builder().putString(INPUT_SLOT, slot).build())
            .addTag(WORK_TAG)
            .build()
        // KEEP: if this run is already booked, leave it as it is.
        WorkManager.getInstance(context)
            .enqueueUniqueWork(name, ExistingWorkPolicy.KEEP, request)
    }

    private fun istDay(utcMs: Long): String = WidgetStore.sgpcDay(utcMs)

    /**
     * Runs the Dart refresh in an engine of its own and waits for it.
     *
     * The engine is started with plugin registration off. A second engine that
     * registered every plugin would register audio_service a second time, and
     * ending it would clear the statics that the playing app uses. See
     * widget_background.dart.
     *
     * Returns true when the Hukamnama that was published is today's.
     */
    fun refreshInDart(context: Context): Boolean {
        val done = CountDownLatch(1)
        val current = AtomicBoolean(false)
        val engineRef = AtomicReference<FlutterEngine?>(null)
        val main = Handler(Looper.getMainLooper())

        main.post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(context)
                loader.ensureInitializationCompleteAsync(context, null, main) {
                    val engine = FlutterEngine(context, null, false)
                    engineRef.set(engine)

                    MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                        .setMethodCallHandler { call, result ->
                            when (call.method) {
                                "publish" -> {
                                    WidgetStore.write(context, call.arguments)
                                    WidgetRenderer.updateAll(context)
                                    result.success(null)
                                }
                                "done" -> {
                                    current.set(call.arguments == true)
                                    result.success(null)
                                    done.countDown()
                                }
                                else -> result.notImplemented()
                            }
                        }

                    val language = WidgetStore.language(context).orEmpty()
                    engine.dartExecutor.executeDartEntrypoint(
                        DartExecutor.DartEntrypoint(loader.findAppBundlePath(), DART_ENTRY),
                        listOf(language, context.filesDir.path),
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Could not start the refresh engine", e)
                done.countDown()
            }
        }

        val finished = done.await(ENGINE_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        // An engine must be destroyed on the main thread.
        main.post { engineRef.getAndSet(null)?.destroy() }
        return finished && current.get()
    }

    fun mayTryAgain(slot: String?, attempt: Int): Boolean =
        slot != Slot.MIDNIGHT.key && attempt + 1 < MAX_ATTEMPTS
}

/** One refresh of the widget while the app may be closed. See [WidgetRefresh]. */
class WidgetRefreshWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {
    override fun doWork(): Result {
        val context = applicationContext
        // The widget was removed after this run was booked. Do nothing, and
        // book nothing. Adding a widget books the runs again.
        if (!WidgetRefresh.hasWidgets(context)) return Result.success()

        // Book the next runs first, so that a crash below cannot end the chain.
        WidgetRefresh.schedule(context)

        val gotToday = try {
            WidgetRefresh.refreshInDart(context)
        } catch (e: Exception) {
            Log.e("LiveDarbarWidget", "Widget refresh failed", e)
            false
        }
        val slot = inputData.getString(WidgetRefresh.INPUT_SLOT)
        return if (!gotToday && WidgetRefresh.mayTryAgain(slot, runAttemptCount)) {
            Result.retry()
        } else {
            Result.success()
        }
    }
}
