package me.heart

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/// The Goals widget (#368), on the JVM: what Dart publishes, and which goal
/// the small widget shows.
class GoalsWidgetTest {
    private val json = """{"version":1,"goals":[
        {"id":"g1","title":"Workouts","status":"3 / 4 · per week","progress":0.75},
        {"id":"g2","title":"Bench Press (Barbell) — Top set","status":"80 / 100 kg","progress":1.4}
    ]}"""

    @Test
    fun `reads what Dart sends, the share kept to the bar`() {
        val goals = GoalsWidget.parse(json)
        assertEquals(listOf("g1", "g2"), goals.map { it.id })
        assertEquals("3 / 4 · per week", goals[0].status)
        assertEquals(1.0, goals[1].progress, 0.0)
    }

    @Test
    fun `nothing published, or nothing readable, is no goal`() {
        assertEquals(emptyList<GoalsWidget.Goal>(), GoalsWidget.parse(null))
        assertEquals(emptyList<GoalsWidget.Goal>(), GoalsWidget.parse("not json"))
    }

    @Test
    fun `the small widget shows the pick while it is active, else the closest`() {
        val goals = GoalsWidget.parse(json)
        assertEquals("g2", GoalsWidget.picked("g2", goals)?.id)
        assertEquals("g1", GoalsWidget.picked("gone", goals)?.id)
        assertEquals("g1", GoalsWidget.picked(null, goals)?.id)
        assertNull(GoalsWidget.picked(null, emptyList()))
    }
}
