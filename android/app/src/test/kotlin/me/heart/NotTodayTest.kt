package me.heart

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.ZoneOffset

/// "Not today" asked for outside the app (#445), on the JVM: the moment is
/// kept for Dart, the day is marked at once, and nothing is offered while
/// nothing is published.
class NotTodayTest {
    private val words = NotToday.Words("Not today", "Today is set aside", null)
    private val today = "2026-11-26"

    @Test
    fun `with nothing published it is off and keeps nothing`() {
        val asked = NotToday.ask(null, emptyList(), 1_000, today)

        assertEquals(NotToday.Outcome.OFF, asked.outcome)
        assertEquals(emptyList<Long>(), asked.pending)
    }

    @Test
    fun `an ask keeps the moment and marks the day`() {
        val asked = NotToday.ask(words, emptyList(), 1_000, today)

        assertEquals(NotToday.Outcome.SET_ASIDE, asked.outcome)
        assertEquals(today, asked.words?.day)
        assertEquals(listOf(1_000L), asked.pending)
    }

    @Test
    fun `a second ask the same day keeps nothing more`() {
        val first = NotToday.ask(words, emptyList(), 1_000, today)

        val again = NotToday.ask(first.words, first.pending, 2_000, today)

        assertEquals(NotToday.Outcome.ALREADY, again.outcome)
        assertEquals(listOf(1_000L), again.pending)
    }

    @Test
    fun `the next day can be set aside again`() {
        val first = NotToday.ask(words, emptyList(), 1_000, today)

        val next = NotToday.ask(first.words, first.pending, 2_000, "2026-11-27")

        assertEquals(NotToday.Outcome.SET_ASIDE, next.outcome)
        assertEquals(listOf(1_000L, 2_000L), next.pending)
    }

    @Test
    fun `what Dart publishes keeps the day of a moment it has not taken`() {
        val published = mapOf("label" to "Not today", "done" to "Today is set aside")

        val waiting = NotToday.published(published, listOf(1_000L), today) { today }
        assertEquals(today, waiting?.day)

        // once taken, Dart's word stands
        assertNull(NotToday.published(published, emptyList(), today) { today }?.day)
        // a moment of another day marks nothing today
        assertNull(NotToday.published(published, listOf(1_000L), today) { "2026-11-25" }?.day)
    }

    @Test
    fun `publishing nothing, or words without both halves, is nothing to ask`() {
        assertNull(NotToday.published(null, emptyList(), today) { today })
        assertNull(NotToday.published(mapOf("label" to "Not today"), emptyList(), today) { today })
    }

    @Test
    fun `the words and the moments read back as they were kept`() {
        val stored = JSONObject(mapOf("label" to "Not today", "done" to "Today is set aside", "day" to today))

        assertEquals(words.copy(day = today), NotToday.words(stored))
        assertNull(NotToday.words(JSONObject(mapOf("label" to "Not today"))))
        assertEquals(listOf(1_000L, 2_000L), NotToday.pending(JSONArray(listOf(1_000L, 2_000L))))
        assertEquals(emptyList<Long>(), NotToday.pending(null))
    }

    @Test
    fun `a moment's day is the device's own`() {
        // 2026-11-26T07:30Z is still the 25th eight hours behind, and already
        // the 26th seven behind. Fixed offsets, not a named zone: what a zone
        // is behind by is the JVM's time zone data to say, and it changes —
        // British Columbia stopped changing its clocks, so "America/Vancouver"
        // is -08:00 on one JDK and -07:00 on a newer one, a day apart here
        val moment = 1_795_678_200_000L
        assertEquals("2026-11-26", NotToday.dayOf(moment, ZoneOffset.UTC))
        assertEquals("2026-11-25", NotToday.dayOf(moment, ZoneOffset.ofHours(-8)))
        assertEquals("2026-11-26", NotToday.dayOf(moment, ZoneOffset.ofHours(-7)))
        assertEquals("2026-11-26", NotToday.dayOf(moment, ZoneOffset.ofHours(9)))
    }

    @Test
    fun `the wide widget gives its last tile to Not today`() {
        assertEquals(3, StartWidget.room(notToday = false))
        assertEquals(2, StartWidget.room(notToday = true))
    }
}
