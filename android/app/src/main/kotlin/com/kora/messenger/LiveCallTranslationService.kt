package com.kora.messenger

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/// Foreground service that keeps the live translation engine alive
/// during an active WebRTC call, even when the user switches apps.
///
/// Android 14+ (API 34) compliance:
/// - Declares foregroundServiceType="microphone|phoneCall"
/// - Lifecycle is bound to a visible notification (Kora Call Notification)
/// - The OS will not terminate the translation engine while the
///   notification is visible and the call is active.
///
/// The notification is dismissed when the call ends (stopSelf()).
class LiveCallTranslationService : Service() {
    companion object {
        private const val CHANNEL_ID = "kora_call_translation"
        private const val NOTIFICATION_ID = 2024
        private const val EXTRA_CALL_ID = "call_id"
        private const val EXTRA_CALLER_NAME = "caller_name"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val callId = intent?.getStringExtra(EXTRA_CALL_ID) ?: "active_call"
        val callerName = intent?.getStringExtra(EXTRA_CALLER_NAME) ?: "Kora Call"

        val notification = buildCallNotification(callerName, callId)

        // Start foreground with microphone + phone call type (Android 14+ compliance)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        return START_NOT_STICKY
    }

    private fun buildCallNotification(callerName: String, callId: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Kora Call Active")
            .setContentText("Live translation in progress with $callerName")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Kora Call Translation",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Keeps live call translation active during calls"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Called when user swipes away from recent apps
        // Keep the service alive if call is still active
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        super.onDestroy()
        stopForeground(STOP_FOREGROUND_REMOVE)
    }
}
