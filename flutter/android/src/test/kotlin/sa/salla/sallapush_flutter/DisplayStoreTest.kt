package sa.salla.sallapush_flutter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DisplayStoreTest {
    private var now = 1_000L
    private val store = DisplayStore { now }
    private val shown = mutableListOf<Int>()

    @Test
    fun showsTheNotificationUnderItsHandleOnce() {
        val first = store.put { shown += 1 }
        val second = store.put { shown += 2 }

        assertNotEquals(first, second)
        assertTrue(store.display(second))
        assertFalse(store.display(second))
        assertTrue(store.display(first))
        assertEquals(listOf(2, 1), shown)
    }

    @Test
    fun anUnknownHandleShowsNothing() {
        store.put { shown += 1 }

        assertFalse(store.display("unknown"))
        assertEquals(emptyList<Int>(), shown)
    }

    @Test
    fun aNotificationCanBeShownFor600Seconds() {
        val kept = store.put { shown += 1 }
        val expired = store.put { shown += 2 }

        now += 600_000
        assertTrue(store.display(kept))
        now += 1
        assertFalse(store.display(expired))
        assertEquals(listOf(1), shown)
    }

    @Test
    fun keepsMoreThanIosLimitAsSallaPushAndroidHasNoCount() {
        val handles = (1..21).map { index -> store.put { shown += index } }

        handles.forEach { assertTrue(store.display(it)) }
        assertEquals((1..21).toList(), shown)
    }

    @Test
    fun the501stNotificationDropsTheOldest() {
        val handles = (1..501).map { index -> store.put { shown += index } }

        assertFalse(store.display(handles.first()))
        assertTrue(store.display(handles[1]))
        assertTrue(store.display(handles.last()))
        assertEquals(listOf(2, 501), shown)
    }

    @Test
    fun clearForgetsEveryNotification() {
        val handle = store.put { shown += 1 }

        store.clear()

        assertFalse(store.display(handle))
        assertEquals(emptyList<Int>(), shown)
    }
}
