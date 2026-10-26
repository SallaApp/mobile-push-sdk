package sa.salla.sallapush_flutter

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import java.nio.ByteBuffer

/** The engine's messenger, faked: keeps the handlers set on it, delivers messages to them, and keeps what is sent. */
internal class FakeBinaryMessenger : BinaryMessenger {
    val handlers = mutableMapOf<String, BinaryMessenger.BinaryMessageHandler>()

    /** The messages sent to Dart, by channel, each positioned at its end as the engine expects. */
    private val sent = mutableListOf<Pair<String, ByteBuffer?>>()

    override fun send(channel: String, message: ByteBuffer?) = send(channel, message, null)

    override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {
        sent += channel to message
    }

    override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
        if (handler == null) handlers.remove(channel) else handlers[channel] = handler
    }

    /** Sends [arguments] to the host API method [method] as Dart does; [onReply] gets the decoded reply. */
    fun sendToHostApi(method: String, arguments: List<Any?>?, onReply: (List<Any?>?) -> Unit) {
        val codec = SallaPushHostApi.codec
        val handler = checkNotNull(handlers["$HOST_API.$method"]) { "No handler for $method" }
        // The codec leaves a buffer positioned after what it wrote; the engine hands it over from the start.
        handler.onMessage(codec.encodeMessage(arguments)?.also { it.flip() }) { bytes ->
            onReply(codec.decodeMessage(bytes?.also { it.flip() }) as List<*>?)
        }
    }

    /** As [sendToHostApi], for a method that answers at once: returns the decoded reply. */
    fun callHostApi(method: String, arguments: List<Any?>? = null): List<Any?>? {
        var reply: List<Any?>? = null
        sendToHostApi(method, arguments) { reply = it }
        return reply
    }

    /** Sends Dart's listen or cancel to the event channel named [stream]. */
    fun streamCall(method: String, stream: String) {
        val handler = checkNotNull(handlers[eventChannel(stream)]) { "No handler for $stream" }
        handler.onMessage(MessagesPigeonMethodCodec.encodeMethodCall(MethodCall(method, null)).also { it.flip() }) {}
    }

    /** The events sent to Dart on the event channel named [stream], decoded. */
    fun events(stream: String): List<Any?> = sent.filter { it.first == eventChannel(stream) }.map { (_, message) ->
        MessagesPigeonMethodCodec.decodeEnvelope(checkNotNull(message).duplicate().also { it.flip() })
    }

    companion object {
        const val HOST_API = "dev.flutter.pigeon.mobile_push.SallaPushHostApi"

        fun eventChannel(stream: String) = "dev.flutter.pigeon.mobile_push.SallaPushEventChannelApi.$stream"
    }
}
