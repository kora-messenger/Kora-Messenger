package com.kora.messenger.notifications

import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationManagerCompat

/**
 * Foreground service for push notification processing.
 *
 * Modeled after WhatsApp's GcmFGService:
 * - Started when a push is received
 * - Runs as a foreground service (data_sync type) to prevent being killed
 * - Builds and displays the notification
 * - Releases itself after processing
 * - Uses FOREGROUND_SERVICE_DATA_SYNC permission (like WhatsApp)
 */
class KoraForegroundService : Service() {

    companion object {
        private const val TAG = "KoraFGService"
        private const val WAKE_LOCK_TAG = "Kora:FGPushProcessing"
        private const val WAKE_LOCK_TIMEOUT_MS = 15_000L
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Foreground service started for push processing")

        // Start as foreground service immediately (required for Android 12+)
        val fgNotif = KoraNotificationBuilder.buildForegroundServiceNotification(
            this, "Kora", "Syncing messages…"
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                KoraNotificationChannels.NOTIF_ID_FOREGROUND_SERVICE,
                fgNotif,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(KoraNotificationChannels.NOTIF_ID_FOREGROUND_SERVICE, fgNotif)
        }

        // Acquire wake lock for processing
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        val wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            WAKE_LOCK_TAG
        )
        wakeLock.acquire(WAKE_LOCK_TIMEOUT_MS)

        try {
            if (intent != null) {
                processPushPayload(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in foreground push processing", e)
        } finally {
            wakeLock.release()
            // Stop the foreground service after processing
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }

        return START_NOT_STICKY
    }

    private fun processPushPayload(intent: Intent) {
        // Reconstruct payload from intent extras
        val payload = KoraPushPayloadParser.PushPayload(
            type = KoraPushPayloadParser.PayloadType.valueOf(
                intent.getStringExtra("payload_type") ?: "UNKNOWN"
            ),
            chatId = intent.getStringExtra("chat_id"),
            senderName = intent.getStringExtra("sender_name"),
            senderJid = intent.getStringExtra("sender_jid"),
            messageText = intent.getStringExtra("message_text"),
            messagePreview = intent.getStringExtra("message_preview"),
            isGroup = intent.getBooleanExtra("is_group", false),
            groupName = intent.getStringExtra("group_name"),
            callId = intent.getStringExtra("call_id"),
            callType = intent.getStringExtra("call_type"),
            isVideo = intent.getBooleanExtra("is_video", false),
            reaction = intent.getStringExtra("reaction"),
            timestamp = intent.getLongExtra("timestamp", System.currentTimeMillis()),
            notificationId = intent.getIntExtra("notification_id", System.currentTimeMillis().hashCode()),
            deepLink = intent.getStringExtra("deep_link")
        )

        Log.d(TAG, "Processing payload: type=${payload.type}, chatId=${payload.chatId}")

        val mgr = NotificationManagerCompat.from(this)
        val notifId = payload.notificationId

        // Build and show notification based on type
        when (payload.type) {
            KoraPushPayloadParser.PayloadType.MESSAGE -> {
                val notif = KoraNotificationBuilder.buildMessageNotification(this, payload)
                mgr.notify(notifId, notif)
            }
            KoraPushPayloadParser.PayloadType.GROUP_MESSAGE -> {
                val notif = KoraNotificationBuilder.buildMessageNotification(this, payload)
                mgr.notify(notifId, notif)
            }
            KoraPushPayloadParser.PayloadType.CALL -> {
                val notif = KoraNotificationBuilder.buildCallNotification(this, payload)
                mgr.notify(KoraNotificationChannels.NOTIF_ID_CALL, notif)
            }
            KoraPushPayloadParser.PayloadType.CALL_REJECT -> {
                mgr.cancel(KoraNotificationChannels.NOTIF_ID_CALL)
            }
            KoraPushPayloadParser.PayloadType.STATUS -> {
                val notif = KoraNotificationBuilder.buildStatusNotification(this, payload)
                mgr.notify(notifId, notif)
            }
            KoraPushPayloadParser.PayloadType.CHANNEL_UPDATE -> {
                val notif = KoraNotificationBuilder.buildChannelUpdateNotification(this, payload)
                mgr.notify(notifId, notif)
            }
            KoraPushPayloadParser.PayloadType.REACTION -> {
                // Reactions are subtle — update existing notification or show brief toast
                val notif = KoraNotificationBuilder.buildMessageNotification(this, payload)
                mgr.notify(notifId, notif)
            }
            KoraPushPayloadParser.PayloadType.SECURITY -> {
                val notif = KoraNotificationBuilder.buildChannelUpdateNotification(this, payload)
                mgr.notify(notifId, notif)
            }
            KoraPushPayloadParser.PayloadType.REMINDER -> {
                val notif = KoraNotificationBuilder.buildMessageNotification(this, payload)
                mgr.notify(notifId, notif)
            }
            KoraPushPayloadParser.PayloadType.UNKNOWN -> {
                Log.w(TAG, "Unknown payload type, using fallback channel")
                val notif = KoraNotificationBuilder.buildChannelUpdateNotification(this, payload)
                mgr.notify(notifId, notif)
            }
        }

        // Persist notification state (like WhatsApp's database tracking)
        persistNotificationState(payload)
    }

    private fun persistNotificationState(payload: KoraPushPayloadParser.PushPayload) {
        val prefs = getSharedPreferences("kora_notif_state", Context.MODE_PRIVATE)
        prefs.edit()
            .putLong("last_notif_timestamp", payload.timestamp)
            .putString("last_notif_chat_id", payload.chatId)
            .putString("last_notif_type", payload.type.name)
            .putInt("last_notif_id", payload.notificationId)
            .apply()
    }
}
