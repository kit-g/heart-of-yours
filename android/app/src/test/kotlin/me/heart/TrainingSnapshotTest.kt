package me.heart

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate

/// The training widget (#161), on the JVM: what Dart publishes, and the bars
/// drawn from it — the same cases the iOS widget's tests hold it to.
class TrainingSnapshotTest {
    /// A Monday.
    private val monday = LocalDate.of(2026, 10, 12)

    private fun snapshot(days: String) = TrainingSnapshot.parse(
        JSONObject("""{"version":1,"unit":"imperial","accent":4280241864,"accentDark":4287868415,"days":$days}"""),
    )!!

    @Test
    fun `reads what Dart sends`() {
        val snapshot = snapshot("""{"2026-10-11":[1234.5,1,3600,12,96]}""")
        assertEquals(true, snapshot.imperial)
        assertEquals(0xFF1F4EC8.toInt(), snapshot.accent)
        assertEquals(listOf(1234.5, 1.0, 3600.0, 12.0, 96.0), snapshot.days["2026-10-11"])
    }

    @Test
    fun `nonsense is nobody's training`() {
        assertNull(TrainingSnapshot.parse(JSONObject("""{"unit":"furlongs","accent":0,"accentDark":0,"days":{}}""")))
        assertNull(TrainingSnapshot.parse(JSONObject("""{"unit":"metric"}""")))
    }

    @Test
    fun `a week is seven days ending today`() {
        val snapshot = snapshot("""{"2026-10-05":[999,1,0,0,0],"2026-10-06":[100,1,0,0,0],"2026-10-12":[250,2,0,0,0]}""")
        val bars = snapshot.bars(TrainingMetric.VOLUME, TrainingRange.WEEK, monday)
        assertEquals(listOf(100.0, 0.0, 0.0, 0.0, 0.0, 0.0, 250.0), bars.map { it.value })
        assertEquals(LocalDate.of(2026, 10, 6), bars.first().start)
        assertEquals(2.0, snapshot.bars(TrainingMetric.WORKOUTS, TrainingRange.WEEK, monday).last().value, 0.0)
    }

    @Test
    fun `a quarter is thirteen weeks from Monday`() {
        val snapshot = snapshot(
            """{"2026-10-12":[0,1,0,0,0],"2026-10-05":[0,1,0,0,0],"2026-10-11":[0,1,0,0,0],
               "2026-07-20":[0,1,0,0,0],"2026-07-19":[0,1,0,0,0]}""",
        )
        // a Wednesday: the week still starts on the Monday
        val bars = snapshot.bars(TrainingMetric.WORKOUTS, TrainingRange.QUARTER, LocalDate.of(2026, 10, 14))
        assertEquals(13, bars.size)
        assertEquals(LocalDate.of(2026, 7, 20), bars.first().start)
        assertEquals(1.0, bars.first().value, 0.0)
        assertEquals(listOf(2.0, 1.0), bars.takeLast(2).map { it.value })
        assertEquals(4.0, bars.sumOf { it.value }, 0.0)
    }

    @Test
    fun `a missing total counts as nothing`() {
        val snapshot = snapshot("""{"2026-10-12":[10]}""")
        assertEquals(0.0, snapshot.bars(TrainingMetric.REPS, TrainingRange.WEEK, monday).last().value, 0.0)
    }
}
