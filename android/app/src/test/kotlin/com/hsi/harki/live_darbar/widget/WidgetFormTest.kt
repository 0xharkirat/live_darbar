package com.hsi.harki.live_darbar.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * What the widget shows at each height. Hark, 7 November: the widget was
 * "too big". On his Moto g56 it went on the home screen 2 rows high, 285 dp,
 * for about 145 dp of content. It now goes on 1 row, about 133 dp there.
 * Then he asked why the 1 row widget lost "Hukamnama · date · Ang": it must
 * keep that line, and the meaning too. Run with
 * `./gradlew :app:testDebugUnitTest` from the android directory.
 */
class WidgetFormTest {
    @Test
    fun oneRowOnAMotoG56ShowsEveryPart() {
        val form = WidgetForm.forHeight(133f)
        assertEquals(WidgetForm.ROW, form)
        assertTrue(form.showsHeading)
        assertTrue(form.showsMeaning)
        assertTrue(form.tight)
        assertEquals(1, form.lineMaxLines)
    }

    @Test
    fun twoRowsShowEverythingWithTheFullSpacing() {
        val form = WidgetForm.forHeight(285f)
        assertEquals(WidgetForm.FULL, form)
        assertTrue(form.showsHeading)
        assertTrue(form.showsMeaning)
        assertFalse(form.tight)
        assertEquals(2, form.lineMaxLines)
    }

    @Test
    fun aShortRowKeepsTheTopLineBeforeTheMeaning() {
        val form = WidgetForm.forHeight(110f)
        assertEquals(WidgetForm.SHORT, form)
        assertTrue(form.showsHeading)
        assertFalse(form.showsMeaning)
    }

    @Test
    fun theSmallestRowKeepsTheLineAndTheButtons() {
        val form = WidgetForm.forHeight(90f)
        assertEquals(WidgetForm.LINE, form)
        assertFalse(form.showsHeading)
        assertFalse(form.showsMeaning)
        assertEquals(1, form.lineMaxLines)
    }

    @Test
    fun theTopLineShowsFrom100Dp() {
        for (form in WidgetForm.entries) {
            assertEquals(form.name, form.minHeightDp >= 100f, form.showsHeading)
        }
    }

    @Test
    fun eachFormStartsAtItsOwnHeight() {
        assertEquals(WidgetForm.LINE, WidgetForm.forHeight(99.9f))
        assertEquals(WidgetForm.SHORT, WidgetForm.forHeight(100f))
        assertEquals(WidgetForm.SHORT, WidgetForm.forHeight(119.9f))
        assertEquals(WidgetForm.ROW, WidgetForm.forHeight(120f))
        assertEquals(WidgetForm.ROW, WidgetForm.forHeight(159.9f))
        assertEquals(WidgetForm.FULL, WidgetForm.forHeight(160f))
    }

    @Test
    fun eachFormFitsTheHeightItStartsAt() {
        // The parts of each form, with the Rahao line at 1 line, fit in the
        // least height at which the launcher shows that form.
        for (form in WidgetForm.entries.filter { it.minHeightDp > 0f }) {
            assertTrue(
                "${form.name} needs ${form.neededDp} dp",
                form.neededDp <= form.minHeightDp,
            )
        }
    }

    @Test
    fun anUnknownHeightShowsEverything() {
        // A launcher before Android 12 can leave the size out. The widget then
        // draws as it always did.
        assertEquals(WidgetForm.FULL, WidgetForm.forHeight(0f))
    }

    @Test
    fun theFormsGrowInOrder() {
        // Android 12 picks the biggest form that fits from a list of sizes, so
        // each form must need more room than the one before it.
        val heights = WidgetForm.entries.map { it.minHeightDp }
        assertEquals(heights.sorted(), heights)
        assertEquals(0f, heights.first())
    }
}
