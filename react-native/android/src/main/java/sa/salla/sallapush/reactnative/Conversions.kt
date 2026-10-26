package sa.salla.sallapush.reactnative

import org.json.JSONArray
import org.json.JSONObject

/** JavaScript values, as ReadableMap.toHashMap() gives them, turned into what native's calls take. */
internal object Conversions {

  /** An FCM-style data map: strings kept, maps and lists as JSON text, other values as text, nulls dropped. */
  fun messageData(payload: Map<String, Any?>): Map<String, String> = buildMap {
    for ((key, value) in payload) {
      if (value != null) put(key, text(value))
    }
  }

  /** The object native's trackOpened reads push_ref from; null stays null. */
  fun jsonObject(additionalData: Map<String, Any?>?): JSONObject? = additionalData?.let { JSONObject(it) }

  private fun text(value: Any): String = when (value) {
    is String -> value
    is Map<*, *> -> JSONObject(value).toString()
    is List<*> -> JSONArray(value).toString()
    else -> value.toString()
  }
}
