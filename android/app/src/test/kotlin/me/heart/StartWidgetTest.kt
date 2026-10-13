package me.heart

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/// The Start widget (#367), on the JVM: what the small widget starts.
class StartWidgetTest {
    private val push = StartWidget.Template("t1", "Push Day")
    private val legs = StartWidget.Template("t2", "Leg Day")

    @Test
    fun `unpicked starts the first template`() {
        assertEquals(push, StartWidget.picked(null, listOf(push, legs)))
    }

    @Test
    fun `a picked template is the one it starts`() {
        assertEquals(legs, StartWidget.picked("t2", listOf(push, legs)))
    }

    @Test
    fun `a template the app no longer publishes falls back to the first`() {
        assertEquals(push, StartWidget.picked("gone", listOf(push, legs)))
    }

    @Test
    fun `the empty workout is picked as such, and is all there is without templates`() {
        assertNull(StartWidget.picked(StartWidget.EMPTY, listOf(push, legs)))
        assertNull(StartWidget.picked(null, emptyList()))
    }
}
