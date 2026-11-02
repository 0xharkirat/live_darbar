package com.hsi.harki.live_darbar.widget

/**
 * The things a tap on the widget can ask the app to open.
 *
 * The widget's two controls, which play and stop, do not come here. They go
 * to the media session without opening the app (see [WidgetControl]). What
 * is left is to open a screen: the Hukamnama reader, from a tap anywhere
 * else on the widget.
 *
 * The action is a fixed string. [commandFor] compares it for equality
 * and nothing else, and no extra on the intent is ever read. MainActivity is
 * exported, so any app can send it an intent. This action can only open a
 * screen, whoever sends it. The screen comes to the front, and nothing
 * plays.
 *
 * The widget sends it with an explicit intent, so it needs no intent filter
 * in the manifest. Adding one would make it reachable by implicit intents.
 */
object WidgetActions {
    const val OPEN_HUKAMNAMA = "com.hsi.harki.live_darbar.OPEN_HUKAMNAMA"

    /**
     * The command Dart understands for [action], or null for any other string.
     *
     * The names are the ones `_handleOacpCommand` in lib/main.dart switches on.
     */
    fun commandFor(action: String?): String? = when (action) {
        OPEN_HUKAMNAMA -> "open_hukamnama"
        else -> null
    }
}
