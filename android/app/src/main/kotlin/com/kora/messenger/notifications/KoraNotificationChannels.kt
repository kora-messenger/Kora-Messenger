package com.kora.messenger.notifications

import android.app.NotificationChannel
import android.app.NotificationChannelGroup
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Kora's versioned notification channel system.
 *
 * Modeled after WhatsApp's approach:
 * - Per-type channels (messages, group messages, calls, status, etc.)
 * - Versioned schema for upgrades across app versions
 * - Separate group for chat-level settings
 * - Each channel has configurable importance, vibration, light, sound
 */
object KoraNotificationChannels {
    // Schema versioning (like WhatsApp's notification_channels_schema_version)
    const val SCHEMA_VERSION = 1
    const val PREF_KEY_SCHEMA_VERSION = "kora_notif_channels_schema_version"
    const val PREF_KEY_NUM_CHANNELS = "kora_num_notification_channels_created"

    // Channel group
    const val GROUP_MESSAGES = "kora_group_messages"
    const val GROUP_CALLS = "kora_group_calls"
    const val GROUP_GENERAL = "kora_group_general"

    // Channel IDs
    const val MESSAGES = "kora_messages"
    const val GROUP_MSG = "kora_group_messages"
    const val CALLS = "kora_calls"
    const val MISSED_CALLS = "kora_missed_calls"
    const val STATUS = "kora_status"
    const val CHANNELS = "kora_channels"
    const val REMINDERS = "kora_reminders"
    const val GENERAL = "kora_general"
    const val FCM_FALLBACK = "kora_fcm_fallback"

    // Notification IDs (fixed for specific types)
    const val NOTIF_ID_CALL = 9000
    const val NOTIF_ID_MISSED_CALL_BASE = 9100
    const val NOTIF_ID_FOREGROUND_SERVICE = 8000
    const val NOTIF_ID_BOOT_SETUP = 8500

    fun createAll(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val prefs = context.getSharedPreferences("kora_notif", Context.MODE_PRIVATE)
        val lastVersion = prefs.getInt(PREF_KEY_SCHEMA_VERSION, 0)

        // Create channel groups first
        val groups = listOf(
            NotificationChannelGroup(GROUP_MESSAGES, "Messages"),
            NotificationChannelGroup(GROUP_CALLS, "Calls"),
            NotificationChannelGroup(GROUP_GENERAL, "General")
        )
        for (g in groups) mgr.createNotificationChannelGroup(g)

        // Message channels — high importance
        createChannel(mgr, MESSAGES, "Messages", "New message notifications",
            NotificationManager.IMPORTANCE_HIGH, GROUP_MESSAGES,
            enableVibration = true, enableLights = true, lightColor = 0xFF6C63FF.toInt(),
            sound = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION))

        createChannel(mgr, GROUP_MSG, "Group messages", "Notifications for group chats",
            NotificationManager.IMPORTANCE_HIGH, GROUP_MESSAGES,
            enableVibration = true, enableLights = true, lightColor = 0xFF4A90D9.toInt(),
            sound = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION))

        // Call channels — max importance
        createChannel(mgr, CALLS, "Incoming calls", "Incoming voice and video call notifications",
            NotificationManager.IMPORTANCE_HIGH, GROUP_CALLS,
            enableVibration = true, enableLights = true, lightColor = 0xFF6C63FF.toInt(),
            sound = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_RINGTONE))

        createChannel(mgr, MISSED_CALLS, "Missed calls", "Missed call notifications",
            NotificationManager.IMPORTANCE_HIGH, GROUP_CALLS,
            enableVibration = true, enableLights = true, lightColor = 0xFF6C63FF.toInt())

        // Status updates
        createChannel(mgr, STATUS, "Status updates", "Status update notifications",
            NotificationManager.IMPORTANCE_DEFAULT, GROUP_GENERAL,
            enableVibration = true, enableLights = false)

        // Channel/community notifications
        createChannel(mgr, CHANNELS, "Channels", "Channel update notifications",
            NotificationManager.IMPORTANCE_DEFAULT, GROUP_GENERAL)

        // Reminders (drafts, follow-ups)
        createChannel(mgr, REMINDERS, "Reminders", "Message and draft reminders",
            NotificationManager.IMPORTANCE_LOW, GROUP_GENERAL)

        // General catch-all
        createChannel(mgr, GENERAL, "General", "General Kora notifications",
            NotificationManager.IMPORTANCE_DEFAULT, GROUP_GENERAL)

        // FCM fallback (like WhatsApp's fcm_fallback_notification_channel)
        createChannel(mgr, FCM_FALLBACK, "Other", "Other notifications from Kora",
            NotificationManager.IMPORTANCE_DEFAULT, GROUP_GENERAL)

        // Mark schema version
        prefs.edit()
            .putInt(PREF_KEY_SCHEMA_VERSION, SCHEMA_VERSION)
            .putInt(PREF_KEY_NUM_CHANNELS, mgr.notificationChannels.size)
            .apply()
    }

    private fun createChannel(
        mgr: NotificationManager,
        id: String,
        name: String,
        description: String,
        importance: Int,
        groupId: String,
        enableVibration: Boolean = true,
        enableLights: Boolean = false,
        lightColor: Int = 0,
        sound: android.net.Uri? = null,
        vibrationPattern: LongArray? = null
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        // Don't recreate if exists (preserves user modifications)
        if (mgr.getNotificationChannel(id) != null) return

        val channel = NotificationChannel(id, name, importance)
        channel.description = description
        channel.group = groupId
        channel.enableVibration(enableVibration)
        channel.enableLights(enableLights)
        // lightColor is val in SDK 36 — LED color not settable after construction
        // if (lightColor != 0) channel.lightColor = lightColor
        channel.sound = sound ?: android.media.RingtoneManager.getDefaultUri(
            android.media.RingtoneManager.TYPE_NOTIFICATION)
        if (vibrationPattern != null) channel.vibrationPattern = vibrationPattern
        channel.lockscreenVisibility = NotificationManager.IMPORTANCE_HIGH
        mgr.createNotificationChannel(channel)
    }

    fun upgradeChannels(context: Context) {
        val prefs = context.getSharedPreferences("kora_notif", Context.MODE_PRIVATE)
        val lastVersion = prefs.getInt(PREF_KEY_SCHEMA_VERSION, 0)
        if (lastVersion < SCHEMA_VERSION) {
            createAll(context)
        }
    }
}
