package com.hsi.harki.live_darbar.widget

/**
 * What the widget shows at each height.
 *
 * Hark, 7 November 2026: the widget was "too big". On his Moto g56 it went on
 * the home screen 2 rows high, 285 dp, for about 145 dp of content. It now
 * goes on 1 row (res/xml/live_darbar_widget_info.xml), about 133 dp there.
 * Then he asked why the 1 row widget lost its top line, "Hukamnama · 7 Nov ·
 * Ang 946". So a short widget keeps every part and draws them closer
 * together ([tight]). Below 120 dp it drops the meaning first, and below
 * 100 dp the top line. The buttons stay 48 dp in every form, because they
 * are what the widget is for, and a smaller target is hard to tap.
 *
 * Stretched to 2 rows, the widget shows everything with the full spacing of
 * widget_medium.xml, as before.
 */
internal enum class WidgetForm(
    /** The least height, in dp, at which the launcher shows this form. */
    val minHeightDp: Float,
    /** The top line: "Hukamnama · 7 Nov · Ang 946". */
    val showsHeading: Boolean,
    /** The 1 line of English meaning, when the line has one. */
    val showsMeaning: Boolean,
    /** How many lines the Rahao line may take before its ellipsis. */
    val lineMaxLines: Int,
    /** Draws the parts closer together: see [Tight]. */
    val tight: Boolean,
) {
    /** The Rahao line and the buttons, for the smallest row. */
    LINE(0f, showsHeading = false, showsMeaning = false, lineMaxLines = 1, tight = true),

    /** The top line, the Rahao line, and the buttons. */
    SHORT(100f, showsHeading = true, showsMeaning = false, lineMaxLines = 1, tight = true),

    /** Every part: 1 row on most phones, and on a Moto g56. */
    ROW(120f, showsHeading = true, showsMeaning = true, lineMaxLines = 1, tight = true),

    /** Every part, the Rahao line in up to 2 lines, with the full spacing. */
    FULL(160f, showsHeading = true, showsMeaning = true, lineMaxLines = 2, tight = false);

    /**
     * The height, in dp, that this form needs with the Rahao line at 1 line.
     * The parts are the sizes in widget_medium.xml, or in [Tight].
     */
    val neededDp: Float
        get() {
            val spacing = if (tight) Tight else Full
            var dp = spacing.paddingTop + spacing.lineMargins + RAHAO_LINE_DP +
                BUTTONS_DP + spacing.paddingBottom
            if (showsHeading) dp += spacing.heading
            if (showsMeaning) dp += MEANING_DP + spacing.meaningMargin
            return dp
        }

    /** The spacing of a form, in dp. */
    open class Spacing(
        val paddingTop: Float,
        val paddingBottom: Float,
        val heading: Float,
        val lineMarginTop: Float,
        val lineMarginBottom: Float,
        val meaningMargin: Float,
    ) {
        /** The Rahao line's top and bottom margins together. */
        val lineMargins: Float get() = lineMarginTop + lineMarginBottom
    }

    /** The spacing that widget_medium.xml sets. Keep the 2 in step. */
    object Full : Spacing(
        paddingTop = 14f,
        paddingBottom = 10f,
        heading = 24f,
        lineMarginTop = 2f,
        lineMarginBottom = 4f,
        meaningMargin = 6f,
    )

    /**
     * The spacing of a short widget. WidgetRenderer sets it over the layout's.
     * The top line at 18 dp still holds Gurmukhi at 11 sp, the least that
     * its autosizing goes to.
     */
    object Tight : Spacing(
        paddingTop = 8f,
        paddingBottom = 4f,
        heading = 18f,
        lineMarginTop = 0f,
        lineMarginBottom = 2f,
        meaningMargin = 2f,
    )

    companion object {
        /** The Rahao line at 1 line, at about 15 sp. */
        const val RAHAO_LINE_DP = 20f

        /** The meaning: 1 line at 12 sp. */
        const val MEANING_DP = 16f

        /** The buttons: 48 dp targets. */
        const val BUTTONS_DP = 48f

        /**
         * The biggest form that fits [heightDp]. A height of 0 or less means
         * the launcher did not say, and the widget shows everything, as it
         * always did.
         */
        fun forHeight(heightDp: Float): WidgetForm =
            if (heightDp <= 0f) FULL else entries.last { heightDp >= it.minHeightDp }
    }
}
