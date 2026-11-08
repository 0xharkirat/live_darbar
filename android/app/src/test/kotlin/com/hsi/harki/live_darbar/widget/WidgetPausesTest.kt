package com.hsi.harki.live_darbar.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Which letters of the widget's line take a pause colour. Hark, 7 November:
 * the widget's line should have "same color formatting of hukumnama" as the
 * reader. Run with `./gradlew :app:testDebugUnitTest` from the android
 * directory.
 */
class WidgetPausesTest {
    // ਹਰਿ ਬਿਨੁ ਰਹਿ ਨ ਸਕਉ ਇਕ ਰਾਤੀ ॥: a short pause after ਬਿਨੁ (word 1) and a
    // long one after ਸਕਉ (word 4), as the reader colours it.
    private val line = "ਹਰਿ ਬਿਨੁ ਰਹਿ ਨ ਸਕਉ ਇਕ ਰਾਤੀ ॥"

    private fun words(ranges: List<PauseRange>) =
        ranges.map { line.substring(it.start, it.end) to it.kind }

    @Test
    fun coloursTheWordBeforeEachPause() {
        val ranges = WidgetPauses.ranges(
            line,
            mapOf(1 to PauseKind.SHORT, 4 to PauseKind.LONG),
        )
        assertEquals(
            listOf("ਬਿਨੁ" to PauseKind.SHORT, "ਸਕਉ" to PauseKind.LONG),
            words(ranges),
        )
    }

    @Test
    fun countsWordsAcrossRunsOfSpace() {
        val spaced = "ਹਰਿ  ਬਿਨੁ\tਰਹਿ"
        val ranges = WidgetPauses.ranges(spaced, mapOf(2 to PauseKind.LONG))
        assertEquals(listOf("ਰਹਿ"), ranges.map { spaced.substring(it.start, it.end) })
    }

    @Test
    fun ignoresAPauseAfterTheLastWord() {
        // A stale mark from another line must never throw or colour a sign.
        assertTrue(WidgetPauses.ranges(line, mapOf(40 to PauseKind.LONG)).isEmpty())
    }

    @Test
    fun leavesALineWithNoPausesPlain() {
        assertTrue(WidgetPauses.ranges(line, emptyMap()).isEmpty())
    }

    @Test
    fun readsTheKindsThatDartWrites() {
        assertEquals(PauseKind.SHORT, PauseKind.of("short"))
        assertEquals(PauseKind.LONG, PauseKind.of("long"))
        assertEquals(null, PauseKind.of("heavy"))
    }
}
