package com.kora.messenger.notifications

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Kora's FCM (Firebase Cloud Messaging) service.
 *
 * Modeled after WhatsApp's GcmListenerService + GcmFGService:
 * 1. Receives FCM data messages (even when app is killed)
 * 2. Parses the payload using KoraPushPayloadParser
 * 3. Acquires a partial wake lock to ensure processing completes
 * 4. Starts KoraForegroundService for push processing
 * 5. Builds and displays the appropriate notification
 * 6. Notifies the Flutter side via background channel (if app is running)
 *
 * Key difference from basic FCM: we use a foreground service + wake lock
 * to guarantee notification delivery, just like WhatsApp's GcmFGService.
 */
class KoraFcmService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "KoraFcmService"
        private const val WAKE_LOCK_TAG = "Kora:PushProcessing"
        private const val WAKE_LOCK_TIMEOUT_MS = 30_000L

        // Background channel to notify Flutter when it's running
        const val FLUTTER_BACKGROUND_CHANNEL = "com.kora.messenger/push_background"

        // Store latest token for Flutter to read
        @Volatile
        private var latestToken: String? = null

        fun getLatestToken(): String? = latestToken
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "FCM token refreshed: ${token.take(20)}...")
        latestToken = token

        // Store in SharedPreferences for Flutter to pick up
        val prefs = getSharedPreferences("kora_notif", Context.MODE_PRIVATE)
        prefs.edit().putString("fcm_token", token).apply()

        // Boot receiver also handles re-registration on app restart
        // Flutter side will read this token on next startup and sync to server
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        Log.d(TAG, "Push received from: ${remoteMessage.from}")

        // Acquire wake lock to ensure we finish processing
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        val wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            WAKE_LOCK_TAG
        )
        wakeLock.acquire(WAKE_LOCK_TIMEOUT_MS)

        try {
            // Parse the payload
            val data = remoteMessage.data
            val payload = KoraPushPayloadParser.parse(data)

            Log.d(TAG, "Parsed payload: type=${payload.type}, chatId=${payload.chatId}")

            // Start foreground service (like WhatsApp's GcmFGService)
            val fgIntent = Intent(this, KoraForegroundService::class.java).apply {
                putExtra("payload_type", payload.type.name)
                putExtra("chat_id", payload.chatId)
                putExtra("sender_name", payload.senderName)
                putExtra("sender_jid", payload.senderJid)
                putExtra("message_text", payload.messageText)
                putExtra("message_preview", payload.messagePreview)
                putExtra("is_group", payload.isGroup)
                putExtra("group_name", payload.groupName)
                putExtra("call_id", payload.callId)
                putExtra("call_type", payload.callType)
                putExtra("is_video", payload.isVideo)
                putExtra("reaction", payload.reaction)
                putExtra("timestamp", payload.timestamp)
                putExtra("notification_id", payload.notificationId)
                putExtra("deep_link", payload.deepLink)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(fgIntent)
            } else {
                startService(fgIntent)
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error processing push", e)
        } finally {
            // Release wake lock after a small delay to let foreground service take over
            wakeLock.release()
        }
    }
}
