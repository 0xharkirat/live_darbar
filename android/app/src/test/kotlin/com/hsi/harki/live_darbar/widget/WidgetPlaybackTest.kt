package com.hsi.harki.live_darbar.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The widget's rules for what to believe and what to draw. They are plain
 * Kotlin, so no phone is needed. Run with `./gradlew :app:testDebugUnitTest`
 * from the android directory.
 */
class WidgetPlaybackTest {
    // This process started at 10_000. A state at 5_000 is from the one before.
    private val processStart = 10_000L
    private val now = 20_000L

    private fun stored(
        state: PlayState,
        source: Source? = Source.LIVE,
        at: Long = 15_000L,
        byWidget: Boolean = false,
    ) = Playback(state, source, at, byWidget)

    private fun believe(p: Playback, at: Long = now) =
        WidgetPlayback.reconcile(p, processStart, at)

    // --- reset to idle ---------------------------------------------------

    @Test
    fun aStateFromThisProcessIsBelieved() {
        for (state in listOf(PlayState.LOADING, PlayState.PLAYING, PlayState.PAUSED)) {
            val p = stored(state)
            assertEquals(p, believe(p))
        }
    }

    @Test
    fun aPlayingStateFromBeforeThisProcessResetsToIdle() {
        // The service that wrote it died with the old process: a crash, a
        // force stop, a reboot. A widget update finds no live session.
        val old = stored(PlayState.PLAYING, at = 5_000L)
        assertEquals(Playback.IDLE, believe(old))
    }

    @Test
    fun everyNonIdleStateFromBeforeThisProcessResetsToIdle() {
        for (state in listOf(PlayState.LOADING, PlayState.PLAYING, PlayState.PAUSED)) {
            for (source in Source.values()) {
                val old = stored(state, source, at = 9_999L)
                assertEquals("$state $source", Playback.IDLE, believe(old))
            }
        }
    }

    @Test
    fun aStateWrittenTheMomentTheProcessStartedIsBelieved() {
        // A tap that wakes a dead app writes its state inside the new process.
        val p = stored(PlayState.LOADING, byWidget = true, at = processStart)
        assertEquals(p, believe(p))
    }

    @Test
    fun idleStaysIdleWhateverItsAge() {
        assertEquals(Playback.IDLE, believe(stored(PlayState.IDLE, source = null, at = 1L)))
        assertEquals(Playback.IDLE, believe(Playback.IDLE))
    }

    @Test
    fun aStateWithNoSourceIsNotBelieved() {
        assertEquals(Playback.IDLE, believe(stored(PlayState.PLAYING, source = null)))
    }

    @Test
    fun aPromiseFromTheWidgetLapsesWhenTheAppNeverAnswers() {
        val promise = stored(PlayState.LOADING, byWidget = true, at = 15_000L)
        val within = 15_000L + WidgetPlayback.OPTIMISTIC_TTL_MS
        val past = within + 1

        assertEquals(promise, believe(promise, at = within))
        assertEquals(Playback.IDLE, believe(promise, at = past))
    }

    @Test
    fun theAppsOwnLoadingDoesNotLapse() {
        // A live stream can take a long while to reconnect. The app says so,
        // and the widget keeps saying so.
        val loading = stored(PlayState.LOADING, byWidget = false, at = 15_000L)
        assertEquals(loading, believe(loading, at = 15_000L + 10 * 60_000L))
    }

    @Test
    fun onlyLoadingFromTheWidgetLapses() {
        val playing = stored(PlayState.PLAYING, byWidget = true, at = 15_000L)
        assertEquals(playing, believe(playing, at = 15_000L + 60_000L))
    }

    // --- what the widget draws ---------------------------------------------

    @Test
    fun idleOffersPlayOnBothButtons() {
        val c = WidgetPlayback.controlsFor(Playback.IDLE)
        assertEquals(Glyph.PLAY, c.liveGlyph)
        assertEquals(Command.PLAY_LIVE, c.liveCommand)
        assertEquals(PlayState.IDLE, c.liveState)
        assertEquals(Glyph.PLAY, c.hukamnamaGlyph)
        assertEquals(Command.PLAY_HUKAMNAMA, c.hukamnamaCommand)
        assertEquals(PlayState.IDLE, c.hukamnamaState)
    }

    @Test
    fun livePlayingShowsStop() {
        val c = WidgetPlayback.controlsFor(stored(PlayState.PLAYING, Source.LIVE))
        assertEquals(Glyph.STOP, c.liveGlyph)
        assertEquals(Command.STOP, c.liveCommand)
        assertEquals(PlayState.PLAYING, c.liveState)
        // The Hukamnama button is untouched, and a tap on it switches source.
        assertEquals(Glyph.PLAY, c.hukamnamaGlyph)
        assertEquals(Command.PLAY_HUKAMNAMA, c.hukamnamaCommand)
    }

    @Test
    fun liveLoadingShowsADimmedDotsGlyphAndATapCancels() {
        val c = WidgetPlayback.controlsFor(stored(PlayState.LOADING, Source.LIVE))
        assertEquals(Glyph.LOADING, c.liveGlyph)
        assertEquals(Command.STOP, c.liveCommand)
        assertEquals(PlayState.LOADING, c.liveState)
    }

    @Test
    fun livePausedOffersPlay() {
        val c = WidgetPlayback.controlsFor(stored(PlayState.PAUSED, Source.LIVE))
        assertEquals(Glyph.PLAY, c.liveGlyph)
        assertEquals(Command.PLAY_LIVE, c.liveCommand)
        assertEquals(PlayState.PAUSED, c.liveState)
    }

    @Test
    fun hukamnamaPlayingShowsPause() {
        val c = WidgetPlayback.controlsFor(stored(PlayState.PLAYING, Source.HUKAMNAMA))
        assertEquals(Glyph.PAUSE, c.hukamnamaGlyph)
        assertEquals(Command.PAUSE, c.hukamnamaCommand)
        assertEquals(PlayState.PLAYING, c.hukamnamaState)
        // The Live Kirtan button offers live, and a tap on it switches to live.
        assertEquals(Glyph.PLAY, c.liveGlyph)
        assertEquals(Command.PLAY_LIVE, c.liveCommand)
        assertEquals(PlayState.IDLE, c.liveState)
    }

    @Test
    fun hukamnamaLoadingDimsTheGlyphAndATapCancels() {
        val c = WidgetPlayback.controlsFor(stored(PlayState.LOADING, Source.HUKAMNAMA))
        assertEquals(Glyph.LOADING, c.hukamnamaGlyph)
        assertEquals(Command.PAUSE, c.hukamnamaCommand)
    }

    @Test
    fun hukamnamaPausedOffersPlay() {
        val c = WidgetPlayback.controlsFor(stored(PlayState.PAUSED, Source.HUKAMNAMA))
        assertEquals(Glyph.PLAY, c.hukamnamaGlyph)
        assertEquals(Command.PLAY_HUKAMNAMA, c.hukamnamaCommand)
        assertEquals(PlayState.PAUSED, c.hukamnamaState)
    }

    @Test
    fun neitherButtonClaimsKatha() {
        for (state in listOf(PlayState.LOADING, PlayState.PLAYING, PlayState.PAUSED)) {
            val c = WidgetPlayback.controlsFor(stored(state, Source.KATHA))
            assertEquals(PlayState.IDLE, c.liveState)
            assertEquals(PlayState.IDLE, c.hukamnamaState)
            assertEquals(Command.PLAY_LIVE, c.liveCommand)
            assertEquals(Command.PLAY_HUKAMNAMA, c.hukamnamaCommand)
        }
    }

    @Test
    fun everyStateOfEverySourceHasControls() {
        for (state in PlayState.values()) {
            for (source in Source.values()) {
                val p = if (state == PlayState.IDLE) Playback.IDLE else stored(state, source)
                // Does not throw, and a tap always has a command.
                val c = WidgetPlayback.controlsFor(p)
                assertTrue(c.liveCommand == Command.PLAY_LIVE || c.liveCommand == Command.STOP)
                assertTrue(
                    c.hukamnamaCommand == Command.PLAY_HUKAMNAMA || c.hukamnamaCommand == Command.PAUSE
                )
            }
        }
    }

    // --- a play that has nothing to start ---------------------------------------

    @Test
    fun aPlayOfASourceThatIsAlreadyOnStartsNothing() {
        for (state in listOf(PlayState.LOADING, PlayState.PLAYING)) {
            for (source in Source.values()) {
                assertFalse(
                    "$state $source",
                    WidgetPlayback.needsStart(stored(state, source), source),
                )
            }
        }
    }

    @Test
    fun aPlayStartsWhenNothingElseIsOn() {
        for (source in Source.values()) {
            assertTrue(WidgetPlayback.needsStart(Playback.IDLE, source))
        }
    }

    @Test
    fun aPlayOfAPausedSourceIsAResume() {
        assertTrue(WidgetPlayback.needsStart(stored(PlayState.PAUSED, Source.LIVE), Source.LIVE))
        assertTrue(
            WidgetPlayback.needsStart(stored(PlayState.PAUSED, Source.HUKAMNAMA), Source.HUKAMNAMA)
        )
    }

    @Test
    fun aPlayOfAnotherSourceSwitchesToIt() {
        assertTrue(
            WidgetPlayback.needsStart(stored(PlayState.PLAYING, Source.HUKAMNAMA), Source.LIVE)
        )
        assertTrue(
            WidgetPlayback.needsStart(stored(PlayState.PLAYING, Source.LIVE), Source.HUKAMNAMA)
        )
        assertTrue(
            WidgetPlayback.needsStart(stored(PlayState.PLAYING, Source.KATHA), Source.LIVE)
        )
    }

    // --- the words Dart writes ------------------------------------------------

    @Test
    fun theStateWordsAreTheOnesDartWrites() {
        assertEquals(
            listOf("idle", "loading", "playing", "paused"),
            PlayState.values().map { it.key },
        )
        assertEquals(
            listOf("live", "hukamnama", "katha"),
            Source.values().map { it.key },
        )
        assertEquals(PlayState.PLAYING, PlayState.of("playing"))
        assertNull(PlayState.of("nope"))
        assertNull(Source.of(null))
    }

    @Test
    fun theSourcesCarryTheIdsAndroidAutoUses() {
        // MediaCatalog.idFor in Dart is the source index as a string.
        assertEquals("0", Source.LIVE.mediaId)
        assertEquals("1", Source.HUKAMNAMA.mediaId)
        assertEquals("2", Source.KATHA.mediaId)
    }

    @Test
    fun aCommandIsFoundByItsWholeActionAndNothingElse() {
        for (c in Command.values()) assertEquals(c, Command.of(c.action))
        assertNull(Command.of(null))
        assertNull(Command.of("com.hsi.harki.live_darbar.widget.PLAY_LIVE "))
        assertNull(Command.of("android.intent.action.MEDIA_BUTTON"))
        assertNull(Command.of(""))
    }

    @Test
    fun onlyPlayCommandsStartASource() {
        assertEquals(Source.LIVE, Command.PLAY_LIVE.source)
        assertEquals(Source.HUKAMNAMA, Command.PLAY_HUKAMNAMA.source)
        assertNull(Command.STOP.source)
        assertNull(Command.PAUSE.source)
    }
}
