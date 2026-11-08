package com.hsi.harki.live_darbar.widget

/** A pause after a word: short (light) or long (medium or heavy). */
internal enum class PauseKind {
    SHORT,
    LONG;

    companion object {
        /** The kind as Dart writes it (`widgetPauses` in widget_data.dart). */
        fun of(key: String?): PauseKind? = when (key) {
            "short" -> SHORT
            "long" -> LONG
            else -> null
        }
    }
}

/** The letters [start] up to [end] of the line take the colour of [kind]. */
internal data class PauseRange(val start: Int, val end: Int, val kind: PauseKind)

/**
 * Which words of the widget's line take a pause colour, as in the reader:
 * green before a short pause, kesri before a long one.
 *
 * Dart counts the words of the line split at white space, and so does this.
 * Plain Kotlin, so it runs in a unit test with no phone.
 */
internal object WidgetPauses {
    private val WORD = Regex("\\S+")

    /** The letters to colour in [line] for [pauses], by word index. */
    fun ranges(line: String, pauses: Map<Int, PauseKind>): List<PauseRange> {
        if (pauses.isEmpty()) return emptyList()
        val ranges = mutableListOf<PauseRange>()
        for ((index, word) in WORD.findAll(line).withIndex()) {
            val kind = pauses[index] ?: continue
            ranges.add(PauseRange(word.range.first, word.range.last + 1, kind))
        }
        return ranges
    }
}
