package com.kora.messenger.notifications

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Kora's FCM Service — receives push notifications from the Kora backend.
 *
 * Mirrors WhatsApp's push notification architecture:
 * - Parses FCM payload into PushPayload via KoraPushPayloadParser
 * - Builds notification via KoraNotificationBuilder (MessagingStyle, CallStyle, etc.)
 * - Handles direct reply via RemoteInput
 * - Routes call actions (accept/decline/reply)
 *
 * Token refresh is persisted to SharedPreferences for the Dart side to pick up.
 */
class KoraFcmService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "KoraFcm"
        const val PREF_FCM_TOKEN = "kora_fcm_token"
        const val PREF_FCM_TOKEN_TIMESTAMP = "kora_fcm_token_ts"
        const val PREF_NAME = "kora_fcm"
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "FCM token refreshed: ${token.take(20)}...")

        // Persist token — Dart side will pick it up and register with backend
        val prefs = getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(PREF_FCM_TOKEN, token)
            .putLong(PREF_FCM_TOKEN_TIMESTAMP, System.currentTimeMillis())
            .apply()
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        Log.d(TAG, "FCM message received from: ${remoteMessage.from}")

        val data = remoteMessage.data
        if (data.isEmpty()) {
            Log.w(TAG, "Empty data payload, ignoring")
            return
        }

        val payload = KoraPushPayloadParser.parse(data)
        if (payload.type == KoraPushPayloadParser.PayloadType.UNKNOWN) {
            Log.w(TAG, "Unknown payload type, ignoring")
            return
        }

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        when (payload.type) {
            KoraPushPayloadParser.PayloadType.MESSAGE,
            KoraPushPayloadParser.PayloadType.GROUP_MESSAGE -> {
                val notif = KoraNotificationBuilder.buildMessageNotification(
                    context = this,
                    payload = payload
                )
                notificationManager.notify(payload.notificationId, notif)
            }

            KoraPushPayloadParser.PayloadType.CALL -> {
                val notif = KoraNotificationBuilder.buildCallNotification(
                    context = this,
                    payload = payload
                )
                notificationManager.notify(KoraNotificationChannels.NOTIF_ID_CALL, notif)
            }

            KoraPushPayloadParser.PayloadType.CALL_REJECT -> {
                // Call was rejected/ended — cancel the call notification
                notificationManager.cancel(KoraNotificationChannels.NOTIF_ID_CALL)
            }

            KoraPushPayloadParser.PayloadType.STATUS -> {
                val notif = KoraNotificationBuilder.buildStatusNotification(
                    context = this,
                    payload = payload
                )
                notificationManager.notify(payload.notificationId, notif)
            }

            KoraPushPayloadParser.PayloadType.CHANNEL_UPDATE -> {
                val notif = KoraNotificationBuilder.buildChannelUpdateNotification(
                    context = this,
                    payload = payload
                )
                notificationManager.notify(payload.notificationId, notif)
            }

            KoraPushPayloadParser.PayloadType.REMINDER -> {
                // Use foreground service notification style for reminders
                val notif = KoraNotificationBuilder.buildBootSetupNotification(this)
                notificationManager.notify(payload.notificationId, notif)
            }

            else -> {
                // Fallback — treat as message
                val notif = KoraNotificationBuilder.buildMessageNotification(
                    context = this,
                    payload = payload
                )
                notificationManager.notify(payload.notificationId, notif)
            }
        }
    }
}
