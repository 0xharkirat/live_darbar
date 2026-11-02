package com.hsi.harki.live_darbar.widget

/**
 * What the widget knows about playback, and the rules for what it believes
 * and what it draws.
 *
 * This file imports nothing from Android, so a plain JVM test can run every
 * rule in it (`WidgetPlaybackTest`). The words of the states are the ones
 * Dart writes: `WidgetPlayState` and `WidgetSource` in
 * lib/src/home_screen_widget/widget_playback.dart.
 */

/** Nothing is playing, a source is opening, sound is on, or sound is off in a live session. */
enum class PlayState(val key: String) {
    IDLE("idle"),
    LOADING("loading"),
    PLAYING("playing"),
    PAUSED("paused");

    companion object {
        fun of(key: String?): PlayState? = values().firstOrNull { it.key == key }
    }
}

/** The three things the app can play. The ids are the ones the media session lists. */
enum class Source(val key: String, val mediaId: String) {
    LIVE("live", "0"),
    HUKAMNAMA("hukamnama", "1"),
    KATHA("katha", "2");

    companion object {
        fun of(key: String?): Source? = values().firstOrNull { it.key == key }
    }
}

/**
 * The playback as stored: what the session was doing at [atMs], and who said so.
 *
 * [byWidget] is true when the widget itself wrote it, on a tap, before the app
 * had woken up to say anything. Such a state is a promise, not a report, and
 * [WidgetPlayback.reconcile] gives it a deadline.
 */
data class Playback(
    val state: PlayState,
    val source: Source?,
    val atMs: Long,
    val byWidget: Boolean,
) {
    companion object {
        val IDLE = Playback(PlayState.IDLE, null, 0L, false)
    }
}

/** What a tap on a control asks the media session to do. */
enum class Command(val action: String) {
    PLAY_LIVE("com.hsi.harki.live_darbar.widget.PLAY_LIVE"),
    STOP("com.hsi.harki.live_darbar.widget.STOP"),
    PLAY_HUKAMNAMA("com.hsi.harki.live_darbar.widget.PLAY_HUKAMNAMA"),
    PAUSE("com.hsi.harki.live_darbar.widget.PAUSE");

    /** The source a play command starts, or null for the commands that do not start one. */
    val source: Source?
        get() = when (this) {
            PLAY_LIVE -> Source.LIVE
            PLAY_HUKAMNAMA -> Source.HUKAMNAMA
            else -> null
        }

    companion object {
        /** The command for [action], or null for any other string. Compared as a whole. */
        fun of(action: String?): Command? = values().firstOrNull { it.action == action }
    }
}

/** The picture in a button. Loading is a still "…", because RemoteViews cannot spin. */
enum class Glyph { PLAY, STOP, PAUSE, LOADING }

/**
 * What the two buttons show and do for one [Playback].
 *
 * The buttons keep their names, "Live Kirtan" and "Hukamnama", in every
 * state. Only the picture beside the name changes, so the listener always
 * knows which button is which.
 */
data class Controls(
    /** The state the Live Kirtan button describes. Another source playing is idle to it. */
    val liveState: PlayState,
    val liveGlyph: Glyph,
    val liveCommand: Command,
    /** The state the Hukamnama button describes. */
    val hukamnamaState: PlayState,
    val hukamnamaGlyph: Glyph,
    val hukamnamaCommand: Command,
)

object WidgetPlayback {
    /**
     * How long a state that the widget wrote on a tap lasts with no word from
     * the app. A cold start takes 2 to 4 seconds on a slow phone. Past this,
     * the app is not coming, and the widget goes back to idle.
     */
    const val OPTIMISTIC_TTL_MS = 15_000L

    /**
     * The playback to believe, given the one in the store.
     *
     * - **A state older than this process is not true.** The session that
     *   wrote it lived in a process that has ended, by a crash, a force stop
     *   or a reboot, and a new process has no session until something starts
     *   one. So the widget never says "playing" for a process that is gone.
     *   A tap that starts playback writes its own state inside the new
     *   process, so it is never older than the process.
     * - **A promise from the widget expires.** A tap writes "loading" before
     *   the app wakes. If the app has not taken over within
     *   [OPTIMISTIC_TTL_MS], it never will.
     * - **A state with no source is not a state.** Playing something names it.
     *
     * [processStartMs] is when this process started, as an epoch time.
     */
    fun reconcile(stored: Playback, processStartMs: Long, nowMs: Long): Playback {
        if (stored.state == PlayState.IDLE) return Playback.IDLE
        if (stored.source == null) return Playback.IDLE
        if (stored.atMs < processStartMs) return Playback.IDLE
        if (stored.byWidget &&
            stored.state == PlayState.LOADING &&
            nowMs - stored.atMs > OPTIMISTIC_TTL_MS
        ) {
            return Playback.IDLE
        }
        return stored
    }

    /**
     * Whether a play of [source] has anything to start, given what is believed.
     *
     * Not when that source is already loading or playing. The button the
     * listener pressed was out of date, as it can be for a moment after a
     * change from the notification, and the play is already done. Writing
     * "loading" over it would be a state that Dart never confirms, because
     * the player's state does not change, so the widget would end up saying
     * idle over sound. A paused source does start: that is a resume.
     */
    fun needsStart(believed: Playback, source: Source): Boolean =
        !(believed.source == source &&
            (believed.state == PlayState.LOADING || believed.state == PlayState.PLAYING))

    /**
     * What the buttons show and do for [playback], which is already
     * reconciled.
     *
     * Each button has its own state: a source that is not its own is idle to
     * it. Live playing leaves the Hukamnama button on play, and the Hukamnama
     * playing leaves the Live Kirtan button on play, so a tap on either
     * switches to its source. Katha, which only the app starts, leaves both
     * on play.
     *
     * A tap on a button that is loading or playing undoes it: stop for live,
     * pause for the Hukamnama. Live has no pause, because the broadcast does
     * not wait, and the app's own player shows stop for it too.
     */
    fun controlsFor(playback: Playback): Controls {
        val live = if (playback.source == Source.LIVE) playback.state else PlayState.IDLE
        val hukamnama = if (playback.source == Source.HUKAMNAMA) playback.state else PlayState.IDLE

        val liveBusy = live == PlayState.LOADING || live == PlayState.PLAYING
        val hukamnamaBusy = hukamnama == PlayState.LOADING || hukamnama == PlayState.PLAYING

        return Controls(
            liveState = live,
            liveGlyph = when (live) {
                PlayState.LOADING -> Glyph.LOADING
                PlayState.PLAYING -> Glyph.STOP
                else -> Glyph.PLAY
            },
            liveCommand = if (liveBusy) Command.STOP else Command.PLAY_LIVE,
            hukamnamaState = hukamnama,
            hukamnamaGlyph = when (hukamnama) {
                PlayState.LOADING -> Glyph.LOADING
                PlayState.PLAYING -> Glyph.PAUSE
                else -> Glyph.PLAY
            },
            hukamnamaCommand = if (hukamnamaBusy) Command.PAUSE else Command.PLAY_HUKAMNAMA,
        )
    }
}
