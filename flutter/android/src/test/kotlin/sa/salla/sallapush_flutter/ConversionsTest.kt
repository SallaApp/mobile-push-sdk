package sa.salla.sallapush_flutter

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class ConversionsTest {
    @Test
    fun keepsTextAndDropsNullsInTheFcmDataForm() {
        assertEquals(
            mapOf("sp_v" to "1", "sp_title" to "Order shipped"),
            mapOf("sp_v" to "1", "sp_title" to "Order shipped", "sp_body" to null).toFcmData(),
        )
    }

    @Test
    fun turnsMapsAndListsIntoJsonTextAsFcmDataCarriesThem() {
        val data = mapOf(
            "custom" to mapOf("i" to "f6b1", "a" to mapOf("push_ref" to "msg_1", "tier" to null)),
            "ids" to listOf(1, "two", null),
        ).toFcmData()

        val custom = JSONObject(checkNotNull(data["custom"]))
        assertEquals("f6b1", custom.getString("i"))
        assertEquals("msg_1", custom.getJSONObject("a").getString("push_ref"))
        assertSame(JSONObject.NULL, custom.getJSONObject("a").get("tier"))
        val ids = JSONArray(checkNotNull(data["ids"]))
        assertEquals(listOf(1, "two", JSONObject.NULL), List(ids.length()) { ids.get(it) })
    }

    @Test
    fun writesOtherValuesAsTheirText() {
        assertEquals(
            mapOf("count" to "2", "big" to "9007199254740993", "ratio" to "1.5", "on" to "true"),
            mapOf("count" to 2, "big" to 9_007_199_254_740_993L, "ratio" to 1.5, "on" to true).toFcmData(),
        )
    }

    @Test
    fun buildsTheJsonObjectOfTheAdditionalData() {
        val json = mapOf(
            "push_ref" to "msg_1",
            "order" to mapOf("id" to 42, 7 to "seven"),
            "tags" to listOf("a", null),
            "note" to null,
        ).toJsonObject()

        assertEquals("msg_1", json.getString("push_ref"))
        assertEquals(42, json.getJSONObject("order").getInt("id"))
        assertEquals("seven", json.getJSONObject("order").getString("7"))
        assertEquals(2, json.getJSONArray("tags").length())
        assertSame(JSONObject.NULL, json.getJSONArray("tags").get(1))
        assertSame(JSONObject.NULL, json.get("note"))
    }
}
