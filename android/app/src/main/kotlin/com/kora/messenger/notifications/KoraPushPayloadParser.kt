package com.kora.messenger.notifications

import org.json.JSONObject

/**
 * Parses incoming FCM/FBNS push payloads.
 *
 * Modeled after WhatsApp's PushPayloadParser/fromJSON:
 * - PAYLOAD_TYPE_MESSAGE
 * - PAYLOAD_TYPE_GROUP_MESSAGE
 * - PAYLOAD_TYPE_CALL
 * - PAYLOAD_TYPE_CALL_REJECT
 * - PAYLOAD_TYPE_STATUS
 * - PAYLOAD_TYPE_CHANNEL_UPDATE
 * - PAYLOAD_TYPE_REACTION
 * - PAYLOAD_TYPE_SECURITY
 */
object KoraPushPayloadParser {

    enum class PayloadType {
        MESSAGE,
        GROUP_MESSAGE,
        CALL,
        CALL_REJECT,
        STATUS,
        CHANNEL_UPDATE,
        REACTION,
        SECURITY,
        REMINDER,
        UNKNOWN
    }

    data class PushPayload(
        val type: PayloadType,
        val chatId: String?,
        val senderName: String?,
        val senderJid: String?,
        val messageText: String?,
        val messagePreview: String?,
        val isGroup: Boolean,
        val groupName: String?,
        val callId: String?,
        val callType: String?,  // "voice" or "video"
        val isVideo: Boolean,
        val reaction: String?,
        val timestamp: Long,
        val notificationId: Int,
        val deepLink: String?
    )

    fun parse(data: Map<String, String>): PushPayload {
        val typeStr = data["type"] ?: data["payload_type"] ?: ""
        val type = when (typeStr.lowercase()) {
            "message" -> PayloadType.MESSAGE
            "group_message" -> PayloadType.GROUP_MESSAGE
            "call" -> PayloadType.CALL
            "call_reject" -> PayloadType.CALL_REJECT
            "status" -> PayloadType.STATUS
            "channel_update" -> PayloadType.CHANNEL_UPDATE
            "reaction" -> PayloadType.REACTION
            "security" -> PayloadType.SECURITY
            "reminder" -> PayloadType.REMINDER
            else -> {
                // Try to infer from keys
                if (data.containsKey("call_id")) PayloadType.CALL
                else if (data.containsKey("group_name")) PayloadType.GROUP_MESSAGE
                else if (data.containsKey("reaction")) PayloadType.REACTION
                else if (data.containsKey("status_id")) PayloadType.STATUS
                else PayloadType.UNKNOWN
            }
        }

        val chatId = data["chat_id"] ?: data["jid"]
        val senderName = data["sender_name"] ?: data["name"]
        val senderJid = data["sender_jid"] ?: data["from"]
        val messageText = data["message"] ?: data["body"] ?: data["text"]
        val isGroup = type == PayloadType.GROUP_MESSAGE || data["is_group"] == "true"
        val groupName = data["group_name"]
        val callId = data["call_id"]
        val callType = data["call_type"] ?: "voice"
        val isVideo = callType == "video" || data["is_video"] == "true"
        val reaction = data["reaction"]
        val timestamp = (data["timestamp"]?.toLongOrNull()) ?: System.currentTimeMillis()
        val notificationId = data["notification_id"]?.toIntOrNull()
            ?: (chatId?.hashCode() ?: senderJid?.hashCode() ?: timestamp.hashCode())
        val deepLink = data["deep_link"] ?: data["click_action"]

        // Generate message preview (truncated, like WhatsApp)
        val messagePreview = when {
            messageText == null -> ""
            messageText.length > 50 -> messageText.substring(0, 50) + "…"
            else -> messageText
        }

        return PushPayload(
            type = type,
            chatId = chatId,
            senderName = senderName,
            senderJid = senderJid,
            messageText = messageText,
            messagePreview = messagePreview,
            isGroup = isGroup,
            groupName = groupName,
            callId = callId,
            callType = callType,
            isVideo = isVideo,
            reaction = reaction,
            timestamp = timestamp,
            notificationId = notificationId,
            deepLink = deepLink
        )
    }

    fun parseFromJson(jsonString: String): PushPayload {
        return try {
            val json = JSONObject(jsonString)
            val data = mutableMapOf<String, String>()
            for (key in json.keys()) {
                data[key] = json.optString(key)
            }
            parse(data)
        } catch (e: Exception) {
            PushPayload(
                type = PayloadType.UNKNOWN,
                chatId = null,
                senderName = null,
                senderJid = null,
                messageText = null,
                messagePreview = null,
                isGroup = false,
                groupName = null,
                callId = null,
                callType = null,
                isVideo = false,
                reaction = null,
                timestamp = System.currentTimeMillis(),
                notificationId = System.currentTimeMillis().hashCode(),
                deepLink = null
            )
        }
    }
}
