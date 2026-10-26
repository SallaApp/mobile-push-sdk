package sa.salla.sallapush.reactnative

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class ConversionsTest {

  @Test
  fun keepsStringsAndWritesMapsAndListsAsJsonText() {
    val data = Conversions.messageData(
      mapOf(
        "sp_v" to "1",
        "custom" to mapOf("i" to "os-id", "a" to mapOf("push_ref" to "msg_1a2b", "count" to 2.0)),
        "tags" to listOf("vip", 3.0),
      )
    )

    assertEquals("1", data["sp_v"])
    val custom = JSONObject(data.getValue("custom"))
    assertEquals("os-id", custom.getString("i"))
    assertEquals("msg_1a2b", custom.getJSONObject("a").getString("push_ref"))
    assertEquals(2, custom.getJSONObject("a").getInt("count"))
    val tags = JSONArray(data.getValue("tags"))
    assertEquals("vip", tags.getString(0))
    assertEquals(3, tags.getInt(1))
  }

  @Test
  fun writesOtherValuesAsTextAndDropsNulls() {
    val data = Conversions.messageData(mapOf("count" to 3.0, "vip" to true, "none" to null))

    assertEquals(mapOf("count" to "3.0", "vip" to "true"), data)
  }

  @Test
  fun nativeRecognizesConvertedPayloads() {
    val compat = mapOf("alert" to "Hi", "custom" to mapOf("i" to "os-id", "a" to mapOf("push_ref" to "msg_1a2b")))
    val native = mapOf("sp_v" to "1", "sp_id" to "msg_1a2b", "sp_title" to "Hi")
    val foreign = mapOf("alert" to "Hi", "custom" to mapOf("i" to "os-id", "a" to mapOf("campaign" to "spring")))

    assertTrue(LiveNativeSallaPush.isSallaPushMessage(Conversions.messageData(compat)))
    assertTrue(LiveNativeSallaPush.isSallaPushMessage(Conversions.messageData(native)))
    assertFalse(LiveNativeSallaPush.isSallaPushMessage(Conversions.messageData(foreign)))
  }

  @Test
  fun buildsTheTrackOpenedObjectFromTheData() {
    val data = Conversions.jsonObject(mapOf("push_ref" to "msg_1a2b", "offer" to mapOf("id" to 7.0)))

    assertEquals("msg_1a2b", data?.getString("push_ref"))
    assertEquals(7, data?.getJSONObject("offer")?.getInt("id"))
    assertNull(Conversions.jsonObject(null))
  }
}
