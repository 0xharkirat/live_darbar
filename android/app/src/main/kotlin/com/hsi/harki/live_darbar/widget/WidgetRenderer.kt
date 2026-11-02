package com.hsi.harki.live_darbar.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.util.Log
import android.widget.RemoteViews
import com.hsi.harki.live_darbar.MainActivity
import com.hsi.harki.live_darbar.R

/**
 * Draws the widget: picks the layout for its size, fills in the text and the
 * state of the two buttons, and hooks up the taps.
 *
 * The widget says what it is in its top line: `Hukamnama · 3 Nov · Ang 668`.
 * Under it is the Rahao line, and under that two buttons that keep their
 * names in every state, Hukamnama and Live Kirtan. The picture beside each
 * name shows what a tap does: play, pause, stop, or a dimmed "…" while a
 * source opens.
 *
 * No letter spacing is set on any text. Gurmukhi must never have it, and
 * every line may be Gurmukhi.
 *
 * ## Size
 *
 * The widget has one layout. It is always 4 cells wide, and resizes in
 * height only (res/xml/live_darbar_widget_info.xml). At 3 cells the button
 * names are cut, and at 2 there is no room for the Rahao line.
 *
 * ## Taps
 *
 * - The two buttons go to [WidgetControlReceiver], which plays, pauses and
 *   stops through the media session with no screen opening.
 * - Anywhere else opens the Hukamnama reader, through MainActivity by
 *   [WidgetActions].
 */
internal object WidgetRenderer {
    private const val TAG = "LiveDarbarWidget"

    private const val REQUEST_LIVE = 1
    private const val REQUEST_HUKAMNAMA = 2
    private const val REQUEST_READER = 3

    // The tokens of lib/src/core/palette.dart. Keep them in step.
    private val FOREGROUND = Color.parseColor("#F5F1EB")
    private val GOLD = Color.parseColor("#E8B04B")
    private val MUTED = Color.parseColor("#ADA398")

    /** Draws every widget of ours that is on a home screen. */
    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, LiveDarbarWidgetProvider::class.java)
        )
        for (id in ids) update(context, manager, id)
    }

    fun update(context: Context, manager: AppWidgetManager, appWidgetId: Int) {
        try {
            manager.updateAppWidget(appWidgetId, build(context))
        } catch (e: Exception) {
            // A widget that fails to draw keeps what it showed. It must never
            // take the app's process down with it.
            Log.e(TAG, "Could not draw widget $appWidgetId", e)
        }
    }

    private fun build(context: Context): RemoteViews {
        val content = WidgetStore.read(context)
        val views = RemoteViews(context.packageName, R.layout.widget_medium)
        val controls = WidgetPlayback.controlsFor(content.playback)

        views.setTextViewText(R.id.widget_heading, topLine(content))
        views.setTextViewText(R.id.widget_line, content.line)
        // Gurbani is full strength. The empty state is a note to the
        // listener, so it is muted.
        views.setTextColor(R.id.widget_line, if (content.hasLine) FOREGROUND else MUTED)

        drawButton(
            context, views,
            button = R.id.widget_live_button,
            icon = R.id.widget_live_icon,
            word = R.id.widget_live_word,
            name = content.labels.liveName,
            description = content.labels.liveDescription(controls.liveState),
            glyph = controls.liveGlyph,
            command = controls.liveCommand,
            requestCode = REQUEST_LIVE,
            gold = true,
        )
        drawButton(
            context, views,
            button = R.id.widget_hukamnama_button,
            icon = R.id.widget_hukamnama_icon,
            word = R.id.widget_hukamnama_word,
            name = content.labels.hukamnamaName,
            description = content.labels.hukamnamaDescription(controls.hukamnamaState),
            glyph = controls.hukamnamaGlyph,
            command = controls.hukamnamaCommand,
            requestCode = REQUEST_HUKAMNAMA,
            gold = false,
        )

        views.setContentDescription(R.id.widget_root, content.openLabel)
        views.setOnClickPendingIntent(R.id.widget_root, open(context, REQUEST_READER, WidgetActions.OPEN_HUKAMNAMA))
        return views
    }

    /**
     * One button: its picture for the state, its fixed name, and its tap.
     *
     * While its source opens, the button dims: the gold one to half strength,
     * and the name on the dark one to the muted colour. A RemoteViews cannot
     * spin, so the dimmed button and the still "…" are the whole animation.
     */
    private fun drawButton(
        context: Context,
        views: RemoteViews,
        button: Int,
        icon: Int,
        word: Int,
        name: String,
        description: String,
        glyph: Glyph,
        command: Command,
        requestCode: Int,
        gold: Boolean,
    ) {
        val loading = glyph == Glyph.LOADING
        if (gold) {
            views.setInt(
                button,
                "setBackgroundResource",
                if (loading) R.drawable.widget_button_gold_loading else R.drawable.widget_button_gold,
            )
        } else {
            views.setTextColor(word, if (loading) MUTED else FOREGROUND)
        }
        views.setImageViewResource(icon, glyph(glyph))
        views.setTextViewText(word, name)
        views.setContentDescription(button, description)
        views.setOnClickPendingIntent(button, control(context, requestCode, command))
    }

    private fun glyph(glyph: Glyph): Int = when (glyph) {
        Glyph.PLAY -> R.drawable.ic_widget_play
        Glyph.STOP -> R.drawable.ic_widget_stop
        Glyph.PAUSE -> R.drawable.ic_widget_pause
        Glyph.LOADING -> R.drawable.ic_widget_loading
    }

    /** The title in gold, then the date and Ang in the muted colour, on one line. */
    private fun topLine(content: WidgetContent): CharSequence =
        SpannableStringBuilder(content.title).apply {
            setSpan(ForegroundColorSpan(GOLD), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            if (content.meta.isNotEmpty()) {
                val start = length
                append(WidgetStore.SEPARATOR).append(content.meta)
                setSpan(ForegroundColorSpan(MUTED), start, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
        }

    /**
     * A tap that plays, pauses or stops, with no screen. It is a broadcast to
     * [WidgetControlReceiver] that names its target and carries one fixed
     * action. It is immutable, so nothing can redirect it or add to it on the
     * way.
     */
    private fun control(context: Context, requestCode: Int, command: Command): PendingIntent {
        val intent = Intent(context, WidgetControlReceiver::class.java).apply {
            action = command.action
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    /**
     * A tap that opens MainActivity with one of the fixed [WidgetActions].
     *
     * The intent names its target, carries no extras, and is immutable, so
     * nothing can redirect it or add to it on the way.
     */
    private fun open(context: Context, requestCode: Int, action: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = action
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
