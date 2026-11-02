package com.hsi.harki.live_darbar.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

/**
 * The home screen widget: one line that names today's Hukamnama, its Rahao
 * line, and two buttons that play the Hukamnama and live kirtan without
 * opening the app.
 *
 * It holds no state. Every draw reads the store (see [WidgetStore]), which
 * Flutter writes, and works out from the clock which day it is and from the
 * process which playback state is still true. That is why a draw is also how
 * a stale "playing" is put right: the draw runs in a new process, finds no
 * session, and says idle. See [WidgetPlayback.reconcile].
 *
 * The class name is a public contract: Dart's `kWidgetProviderClass` in
 * widget_data.dart names it, and the manifest names it. Rename all three
 * together.
 */
class LiveDarbarWidgetProvider : AppWidgetProvider() {
    /**
     * Draws, and makes sure the background refresh is booked. Booking is
     * harmless to repeat, and this runs at least hourly, so a booking that
     * went missing comes back.
     */
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) WidgetRenderer.update(context, appWidgetManager, id)
        WidgetRefresh.schedule(context)
    }

    /**
     * The first widget was added. Fetch the Hukamnama now, so the widget is
     * not empty until someone opens the app.
     */
    override fun onEnabled(context: Context) {
        WidgetRefresh.schedule(context)
        WidgetRefresh.runNow(context)
    }

    /** The last widget was removed. Nothing needs refreshing any more. */
    override fun onDisabled(context: Context) {
        WidgetRefresh.cancel(context)
    }
}
