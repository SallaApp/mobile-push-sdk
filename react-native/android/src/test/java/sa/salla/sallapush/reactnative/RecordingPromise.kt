package sa.salla.sallapush.reactnative

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.WritableMap

/** Records how a module call settled its promise. */
internal class RecordingPromise : Promise {
  var resolved = false
    private set
  var value: Any? = null
    private set
  var rejectionCode: String? = null
    private set

  override fun resolve(value: Any?) {
    resolved = true
    this.value = value
  }

  override fun reject(code: String?, message: String?) = rejected(code)

  override fun reject(code: String?, throwable: Throwable?) = rejected(code)

  override fun reject(code: String?, message: String?, throwable: Throwable?) = rejected(code)

  override fun reject(throwable: Throwable) = rejected(null)

  override fun reject(throwable: Throwable, userInfo: WritableMap) = rejected(null)

  override fun reject(code: String?, userInfo: WritableMap) = rejected(code)

  override fun reject(code: String?, throwable: Throwable?, userInfo: WritableMap) = rejected(code)

  override fun reject(code: String?, message: String?, userInfo: WritableMap) = rejected(code)

  override fun reject(code: String?, message: String?, throwable: Throwable?, userInfo: WritableMap?) = rejected(code)

  @Deprecated("Deprecated in Promise")
  override fun reject(message: String) = rejected(null)

  private fun rejected(code: String?) {
    rejectionCode = code ?: UNSPECIFIED
  }

  private companion object {
    const val UNSPECIFIED = "EUNSPECIFIED"
  }
}
