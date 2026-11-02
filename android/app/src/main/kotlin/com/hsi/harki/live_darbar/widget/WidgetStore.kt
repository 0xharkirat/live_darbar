package com.hsi.harki.live_darbar.widget

import android.content.Context
import android.content.res.Configuration
import android.os.Process
import android.os.SystemClock
import com.hsi.harki.live_darbar.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import org.json.JSONObject

/**
 * What the widget draws, chosen for the day it is now.
 *
 * The top line is [title] and [meta]: `Hukamnama · 3 Nov · Ang 668`. [meta]
 * is the day of the Rahao line and its Ang, so a line from an earlier day
 * says which day it is from. With no line, [meta] is today's date.
 *
 * [playback] is already reconciled: it is what to believe about the player
 * at this moment, which is idle whenever no session of this process could
 * have written the state in the store. See [WidgetPlayback.reconcile].
 */
internal data class WidgetContent(
    val title: String,
    val meta: String,
    val line: String,
    val hasLine: Boolean,
    val openLabel: String,
    val playback: Playback,
    val labels: WidgetLabels,
)

/**
 * The words of the two buttons, in the app's language.
 *
 * Flutter writes them (`widgetLabels` in widget_data.dart): the name on each
 * button, and what a screen reader says for each button in each state,
 * because the widget changes state while the app is closed. A word that
 * Flutter has not written yet comes from this app's own resources, which
 * have the English and the Punjabi.
 */
internal class WidgetLabels(
    private val name: Map<String, String>,
    private val live: Map<String, String>,
    private val hukamnama: Map<String, String>,
    private val words: Context,
) {
    val liveName: String
        get() = name["live"] ?: words.getString(R.string.widget_live_kirtan)

    val hukamnamaName: String
        get() = name["hukamnama"] ?: words.getString(R.string.widget_hukamnama)

    fun liveDescription(state: PlayState): String =
        live[state.key] ?: live["idle"] ?: words.getString(R.string.widget_play_label)

    fun hukamnamaDescription(state: PlayState): String =
        hukamnama[state.key] ?: hukamnama["idle"] ?: words.getString(R.string.widget_hukamnama_label)
}

/**
 * Reads the text Flutter wrote (lib/src/home_screen_widget/widget_data.dart).
 *
 * Flutter writes with the home_widget package, which keeps its values in the
 * `HomeWidgetPreferences` file. Every value is a string. The keys below are
 * the same strings as `WidgetKeys` in widget_data.dart.
 *
 * Flutter cannot write the moment the day changes, and neither can anything
 * else while the phone sleeps. So this class does not trust the clock of the
 * last write. It works out SGPC's day from the clock now, and picks the
 * date for that day from the week Flutter wrote ahead.
 */
internal object WidgetStore {
    private const val PREFERENCES = "HomeWidgetPreferences"

    private const val LANGUAGE = "ld_language"
    private const val TITLE = "ld_title"
    private const val DATES = "ld_dates"
    private const val LINE = "ld_line"
    private const val HUKAMNAMA_META = "ld_hukamnama_meta"
    private const val OPEN_LABEL = "ld_open_label"
    private const val LABELS = "ld_labels"

    /** The player's state. Dart writes it, and the widget's taps write it too. */
    private const val PLAYBACK = "ld_playback"

    /**
     * What the background refresh may write: the text, never the playback.
     * The refresh runs in an engine with no media session, so it knows
     * nothing about playback.
     */
    private val KEYS = listOf(
        LANGUAGE, TITLE, DATES, LINE, HUKAMNAMA_META, OPEN_LABEL, LABELS,
    )

    /** India Standard Time, which has no daylight saving. SGPC's clock. */
    private const val IST_OFFSET_MS = 19_800_000L

    /** Between the parts of the top line. */
    const val SEPARATOR = " · "

    /** SGPC's day, as `yyyy-MM-dd`, for the instant [nowMs]. */
    fun sgpcDay(nowMs: Long): String =
        isoFormat().format(Date(nowMs + IST_OFFSET_MS))

    /** The language of the text on hand, which is the app's, or null before the first write. */
    fun language(context: Context): String? =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).getString(LANGUAGE, null)

    /**
     * Stores the text that the background Dart run built.
     *
     * [values] is the map Dart sent over the worker's channel. Only the keys
     * this class reads are taken, and only when the value is a string. Nothing
     * else in the map reaches the store. The app's own engine is the only
     * sender, and this keeps it that narrow anyway.
     */
    fun write(context: Context, values: Any?) {
        val map = values as? Map<*, *> ?: return
        val editor = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
        for (key in KEYS) {
            val value = map[key]
            if (value is String) editor.putString(key, value)
        }
        editor.apply()
    }

    fun read(context: Context, nowMs: Long = System.currentTimeMillis()): WidgetContent {
        val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val language = prefs.getString(LANGUAGE, null)
        val words = localized(context, language)

        val line = prefs.getString(LINE, null).orEmpty().trim()
        val hasLine = line.isNotEmpty()
        // The line's own day and Ang. Without a line, today's date, which
        // Flutter wrote a week ahead.
        val meta = prefs.getString(HUKAMNAMA_META, null).orEmpty()
            .takeIf { hasLine && it.isNotEmpty() }
            ?: dateFor(prefs.getString(DATES, null), sgpcDay(nowMs))
            ?: everydayDate(nowMs, language)

        return WidgetContent(
            title = prefs.getString(TITLE, null) ?: words.getString(R.string.widget_hukamnama),
            meta = meta,
            line = if (hasLine) line else words.getString(R.string.widget_empty),
            hasLine = hasLine,
            openLabel = prefs.getString(OPEN_LABEL, null)
                ?: words.getString(R.string.widget_open_label),
            playback = WidgetPlayback.reconcile(
                readPlayback(context),
                processStartMs(nowMs),
                nowMs,
            ),
            labels = labelsFrom(prefs.getString(LABELS, null), words),
        )
    }

    /**
     * The playback exactly as stored, believed or not. Idle when there is
     * none or it cannot be read.
     */
    fun readPlayback(context: Context): Playback {
        val text = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getString(PLAYBACK, null)
        if (text.isNullOrEmpty()) return Playback.IDLE
        return try {
            val json = JSONObject(text)
            val state = PlayState.of(json.optString("state")) ?: return Playback.IDLE
            Playback(
                state = state,
                source = Source.of(json.optString("source")),
                atMs = json.optLong("at", 0L),
                byWidget = json.optString("by") == "widget",
            )
        } catch (e: Exception) {
            Playback.IDLE
        }
    }

    /**
     * Writes the state a tap is about to cause, before the app has woken, so
     * that the widget answers at once. It is marked as the widget's own, and
     * it lapses if the app never confirms it.
     */
    fun writePlayback(
        context: Context,
        state: PlayState,
        source: Source?,
        nowMs: Long = System.currentTimeMillis(),
    ) {
        val json = JSONObject()
            .put("state", state.key)
            .put("source", source?.key ?: JSONObject.NULL)
            .put("at", nowMs)
            .put("by", "widget")
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putString(PLAYBACK, json.toString())
            .apply()
    }

    /**
     * When this process started, as an epoch time. A playback state written
     * before it belongs to a session that is gone.
     */
    fun processStartMs(nowMs: Long = System.currentTimeMillis()): Long =
        nowMs - (SystemClock.elapsedRealtime() - Process.getStartElapsedRealtime())

    private fun labelsFrom(text: String?, words: Context): WidgetLabels {
        val json = try {
            if (text.isNullOrEmpty()) null else JSONObject(text)
        } catch (e: Exception) {
            null
        }
        fun strings(name: String): Map<String, String> {
            val obj = json?.optJSONObject(name) ?: return emptyMap()
            return obj.keys().asSequence().associateWith { obj.optString(it) }
        }
        return WidgetLabels(
            name = strings("name"),
            live = strings("live"),
            hukamnama = strings("hukamnama"),
            words = words,
        )
    }

    /** The date Flutter wrote for [today], or null when it wrote none. */
    private fun dateFor(datesJson: String?, today: String): String? {
        if (datesJson.isNullOrEmpty()) return null
        return try {
            JSONObject(datesJson).optString(today, "").ifEmpty { null }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Today's date, for a phone that has not run the app for longer than the
     * week Flutter wrote ahead. Its digits follow the locale, so Punjabi may
     * show Latin digits here until the app runs again.
     */
    private fun everydayDate(nowMs: Long, language: String?): String {
        val format = SimpleDateFormat("d MMM", localeOf(language))
        format.timeZone = TimeZone.getTimeZone("UTC")
        return format.format(Date(nowMs + IST_OFFSET_MS))
    }

    /** Strings in the app's language, which is not always the phone's. */
    private fun localized(context: Context, language: String?): Context {
        if (language.isNullOrEmpty()) return context
        val config = Configuration(context.resources.configuration)
        config.setLocale(localeOf(language))
        return context.createConfigurationContext(config)
    }

    private fun localeOf(language: String?): Locale =
        if (language.isNullOrEmpty()) Locale.getDefault() else Locale.forLanguageTag(language)

    private fun isoFormat(): SimpleDateFormat {
        val format = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT)
        format.timeZone = TimeZone.getTimeZone("UTC")
        return format
    }
}
