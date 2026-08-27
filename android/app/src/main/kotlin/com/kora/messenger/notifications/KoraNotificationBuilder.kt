package com.kora.messenger.notifications

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.app.RemoteInput
import androidx.core.content.ContextCompat

/**
 * Builds Kora's notifications with WhatsApp-grade features:
 * - MessagingStyle for conversation notifications
 * - InboxStyle for stacked messages
 * - BigTextStyle for long messages
 * - BigPictureStyle for image messages
 * - CallStyle for incoming calls
 * - RemoteInput for direct reply
 * - Per-type dismiss intents
 * - Wake lock flags
 * - High priority + category configuration
 */
object KoraNotificationBuilder {

    // Actions
    const val ACTION_REPLY = "com.kora.messenger.action.REPLY"
    const val ACTION_MARK_AS_READ = "com.kora.messenger.action.MARK_AS_READ"
    const val ACTION_DISMISS_MESSAGE = "com.kora.messenger.action.MESSAGE_DISMISS"
    const val ACTION_DISMISS_MISSED_CALL = "com.kora.messenger.action.MISSED_CALL_DISMISS"
    const val ACTION_DISMISS_STATUS = "com.kora.messenger.action.STATUS_DISMISS"
    const val ACTION_DISMISS_CHANNEL = "com.kora.messenger.action.CHANNEL_DISMISS"
    const val ACTION_CALL_ACCEPT = "com.kora.messenger.action.CALL_ACCEPT"
    const val ACTION_CALL_REJECT = "com.kora.messenger.action.CALL_REJECT"
    const val ACTION_CALL_HANGUP = "com.kora.messenger.action.CALL_HANGUP"

    // Remote input key
    const val KEY_REPLY_TEXT = "kora_reply_text"
    const val KEY_NOTIFICATION_HASH = "kora_notification_hash"
    const val KEY_CHAT_ID = "kora_chat_id"
    const val KEY_SENDER_JID = "kora_sender_jid"
    const val KEY_NOTIF_ID = "kora_notif_id"

    // Cached small icon
    private var smallIconResId: Int? = null

    private fun getSmallIcon(context: Context): Int {
        if (smallIconResId != null) return smallIconResId!!
        // Try custom Kora icon first, fall back to app icon
        val resId = context.resources.getIdentifier("kora_notification_icon", "drawable", context.packageName)
        smallIconResId = if (resId != 0) resId else android.R.drawable.ic_dialog_info
        return smallIconResId!!
    }

    fun buildMessageNotification(
        context: Context,
        payload: KoraPushPayloadParser.PushPayload,
        unreadCount: Int = 1,
        avatarBitmap: Bitmap? = null,
        previousMessages: List<Pair<String, String>> = emptyList() // (senderName, messageText) pairs
    ): Notification {
        val channelId = if (payload.isGroup) KoraNotificationChannels.GROUP_MSG else KoraNotificationChannels.MESSAGES
        val notifId = payload.notificationId

        // Build MessagingStyle (like WhatsApp)
        val person = Person.Builder()
            .setName(payload.senderName ?: "Unknown")
            .setKey(payload.senderJid ?: payload.chatId ?: "")
            .apply {
                if (avatarBitmap != null) setIcon(avatarBitmap.toIcon())
            }
            .build()

        val messagingStyle = NotificationCompat.MessagingStyle(person)
            .setConversationTitle(if (payload.isGroup) payload.groupName ?: payload.senderName else payload.senderName)

        // Add previous messages (conversation history)
        for ((sender, text) in previousMessages.takeLast(5)) {
            val msgPerson = Person.Builder().setName(sender).build()
            messagingStyle.addMessage(text, System.currentTimeMillis() - 60000, msgPerson)
        }
        // Add current message
        messagingStyle.addMessage(
            payload.messageText ?: payload.messagePreview ?: "",
            payload.timestamp,
            person
        )

        // Build direct reply action (RemoteInput)
        val replyAction = buildReplyAction(context, payload, notifId)

        // Build mark-as-read action
        val markAsReadAction = buildMarkAsReadAction(context, payload, notifId)

        // Dismiss intent (per-type dismiss tracking)
        val dismissIntent = buildDismissIntent(context, ACTION_DISMISS_MESSAGE, payload, notifId)

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(getSmallIcon(context))
            .setStyle(messagingStyle)
            .setColor(0xFF6C63FF.toInt()) // Kora purple
            .setColorized(true)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .setShowWhen(true)
            .setWhen(payload.timestamp)
            .setOnlyAlertOnce(unreadCount > 1) // Only vibrate/sound for first message
            .setNumber(unreadCount)
            .addAction(replyAction)
            .addAction(markAsReadAction)
            .setDeleteIntent(dismissIntent)
            .setGroup(payload.chatId ?: payload.senderJid ?: "kora_messages")
            .setGroupSummary(false)

        // Apply avatar as large icon
        if (avatarBitmap != null) {
            builder.setLargeIcon(avatarBitmap)
        }

        // Configure sound and vibration from user prefs
        applySoundAndVibration(context, builder, if (payload.isGroup) "group" else "msg")

        return builder.build()
    }

    fun buildCallNotification(
        context: Context,
        payload: KoraPushPayloadParser.PushPayload,
        avatarBitmap: Bitmap? = null
    ): Notification {
        val channelId = KoraNotificationChannels.CALLS
        val notifId = KoraNotificationChannels.NOTIF_ID_CALL

        val callerPerson = Person.Builder()
            .setName(payload.senderName ?: "Unknown")
            .setKey(payload.senderJid ?: "")
            .build()

        val callStyle = NotificationCompat.CallStyle.forIncomingCall(
            callerPerson,
            buildCallAction(context, ACTION_CALL_REJECT, "Reject", payload),
            buildCallAction(context, ACTION_CALL_ACCEPT, "Answer", payload)
        )

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(getSmallIcon(context))
            .setStyle(callStyle)
            .setColor(0xFF6C63FF.toInt())
            .setColorized(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setFullScreenIntent(buildFullScreenIntent(context, payload), true)

        if (avatarBitmap != null) {
            builder.setLargeIcon(avatarBitmap)
        }

        return builder.build()
    }

    fun buildMissedCallNotification(
        context: Context,
        payload: KoraPushPayloadParser.PushPayload,
        avatarBitmap: Bitmap? = null
    ): Notification {
        val channelId = KoraNotificationChannels.MISSED_CALLS
        val notifId = payload.notificationId

        val dismissIntent = buildDismissIntent(context, ACTION_DISMISS_MISSED_CALL, payload, notifId)

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(getSmallIcon(context))
            .setContentTitle("Missed ${if (payload.isVideo) "video" else "voice"} call")
            .setContentText(payload.senderName ?: "Unknown")
            .setColor(0xFF6C63FF.toInt())
            .setColorized(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setShowWhen(true)
            .setWhen(payload.timestamp)
            .setDeleteIntent(dismissIntent)

        if (avatarBitmap != null) {
            builder.setLargeIcon(avatarBitmap)
        }

        return builder.build()
    }

    fun buildStatusNotification(
        context: Context,
        payload: KoraPushPayloadParser.PushPayload
    ): Notification {
        val channelId = KoraNotificationChannels.STATUS
        val notifId = payload.notificationId

        val dismissIntent = buildDismissIntent(context, ACTION_DISMISS_STATUS, payload, notifId)

        return NotificationCompat.Builder(context, channelId)
            .setSmallIcon(getSmallIcon(context))
            .setContentTitle("${payload.senderName ?: "Contact"} posted a status update")
            .setContentText("Tap to view")
            .setColor(0xFF6C63FF.toInt())
            .setColorized(true)
            .setCategory(NotificationCompat.CATEGORY_SOCIAL)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setShowWhen(true)
            .setWhen(payload.timestamp)
            .setDeleteIntent(dismissIntent)
            .build()
    }

    fun buildChannelUpdateNotification(
        context: Context,
        payload: KoraPushPayloadParser.PushPayload
    ): Notification {
        val channelId = KoraNotificationChannels.CHANNELS
        val notifId = payload.notificationId

        val dismissIntent = buildDismissIntent(context, ACTION_DISMISS_CHANNEL, payload, notifId)

        return NotificationCompat.Builder(context, channelId)
            .setSmallIcon(getSmallIcon(context))
            .setContentTitle(payload.groupName ?: payload.senderName ?: "Channel update")
            .setContentText(payload.messageText ?: payload.messagePreview ?: "New update")
            .setColor(0xFF6C63FF.toInt())
            .setColorized(true)
            .setCategory(NotificationCompat.CATEGORY_SOCIAL)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setShowWhen(true)
            .setWhen(payload.timestamp)
            .setStyle(NotificationCompat.BigTextStyle().bigText(payload.messageText ?: ""))
            .setDeleteIntent(dismissIntent)
            .build()
    }

    fun buildForegroundServiceNotification(
        context: Context,
        title: String = "Kora",
        text: String = "Connected"
    ): Notification {
        val channelId = KoraNotificationChannels.GENERAL

        return NotificationCompat.Builder(context, channelId)
            .setSmallIcon(getSmallIcon(context))
            .setContentTitle(title)
            .setContentText(text)
            .setColor(0xFF6C63FF.toInt())
            .setColorized(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }

    fun buildBootSetupNotification(context: Context): Notification {
        val channelId = KoraNotificationChannels.GENERAL

        return NotificationCompat.Builder(context, channelId)
            .setSmallIcon(getSmallIcon(context))
            .setContentTitle("Kora")
            .setContentText("Setting up notifications…")
            .setColor(0xFF6C63FF.toInt())
            .setColorized(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }

    // ── Helper builders ──

    private fun buildReplyAction(
        context: Context,
        payload: KoraPushPayloadParser.PushPayload,
        notifId: Int
    ): NotificationCompat.Action {
        val remoteInput = RemoteInput.Builder(KEY_REPLY_TEXT)
            .setLabel("Reply")
            .build()

        val intent = Intent(context, KoraDirectReplyReceiver::class.java).apply {
            action = ACTION_REPLY
            putExtra(KEY_CHAT_ID, payload.chatId)
            putExtra(KEY_SENDER_JID, payload.senderJid)
            putExtra(KEY_NOTIF_ID, notifId)
            putExtra(KEY_NOTIFICATION_HASH, generateHash(payload))
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context, notifId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        return NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_send,
            "Reply",
            pendingIntent
        )
            .addRemoteInput(remoteInput)
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_REPLY)
            .setAllowGeneratedReplies(true)
            .build()
    }

    private fun buildMarkAsReadAction(
        context: Context,
        payload: KoraPushPayloadParser.PushPayload,
        notifId: Int
    ): NotificationCompat.Action {
        val intent = Intent(context, KoraDirectReplyReceiver::class.java).apply {
            action = ACTION_MARK_AS_READ
            putExtra(KEY_CHAT_ID, payload.chatId)
            putExtra(KEY_SENDER_JID, payload.senderJid)
            putExtra(KEY_NOTIF_ID, notifId)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context, notifId + 10000, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_view,
            "Mark as read",
            pendingIntent
        )
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_MARK_AS_READ)
            .build()
    }

    private fun buildCallAction(
        context: Context,
        action: String,
        label: String,
        payload: KoraPushPayloadParser.PushPayload
    ): PendingIntent {
        val intent = Intent(context, KoraCallActionReceiver::class.java).apply {
            this.action = action
            putExtra(KEY_CHAT_ID, payload.chatId)
            putExtra(KEY_SENDER_JID, payload.senderJid)
            putExtra("call_id", payload.callId)
            putExtra("is_video", payload.isVideo)
            putExtra(KEY_NOTIF_ID, KoraNotificationChannels.NOTIF_ID_CALL)
        }

        return PendingIntent.getBroadcast(
            context, action.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun buildDismissIntent(
        context: Context,
        action: String,
        payload: KoraPushPayloadParser.PushPayload,
        notifId: Int
    ): PendingIntent {
        val intent = Intent(context, KoraNotificationDismissedReceiver::class.java).apply {
            this.action = action
            putExtra(KEY_CHAT_ID, payload.chatId)
            putExtra(KEY_SENDER_JID, payload.senderJid)
            putExtra(KEY_NOTIF_ID, notifId)
            putExtra(KEY_NOTIFICATION_HASH, generateHash(payload))
        }

        return PendingIntent.getBroadcast(
            context, notifId + 50000, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun buildFullScreenIntent(
        context: Context,
        payload: KoraPushPayloadParser.PushPayload
    ): PendingIntent {
        val intent = Intent(context, Class.forName("${context.packageName}.MainActivity")).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("call_id", payload.callId)
            putExtra("caller_name", payload.senderName)
            putExtra("is_video", payload.isVideo)
            putExtra("from_notification", true)
        }

        return PendingIntent.getActivity(
            context, KoraNotificationChannels.NOTIF_ID_CALL, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun applySoundAndVibration(
        context: Context,
        builder: NotificationCompat.Builder,
        type: String // "msg", "group", "call"
    ) {
        val prefs = context.getSharedPreferences("kora_notif", Context.MODE_PRIVATE)

        // Read user preferences
        val tone = prefs.getString("notif_${type}_tone", "default")
        val vibrate = prefs.getString("notif_${type}_vibrate", "default")

        // Apply sound
        when (tone) {
            "none" -> builder.setSound(null)
            "default" -> builder.setSound(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            )
            else -> {
                val soundUri = Uri.parse("android.resource://${context.packageName}/raw/$tone")
                builder.setSound(soundUri)
            }
        }

        // Apply vibration
        when (vibrate) {
            "none" -> builder.setVibrate(longArrayOf(0))
            "short" -> builder.setVibrate(longArrayOf(0, 100, 100, 100))
            "long" -> builder.setVibrate(longArrayOf(0, 400, 200, 400))
            "default" -> builder.setVibrate(longArrayOf(0, 250, 250, 250))
        }
    }

    private fun generateHash(payload: KoraPushPayloadParser.PushPayload): String {
        return "${payload.chatId}:${payload.timestamp}:${payload.senderJid}".hashCode().toString()
    }

    // Extension to convert Bitmap to Icon for Person
    private fun Bitmap.toIcon(): android.graphics.drawable.Icon {
        return android.graphics.drawable.Icon.createWithBitmap(this)
    }
}
