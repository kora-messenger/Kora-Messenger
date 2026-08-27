package com.kora.messenger.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Boot completed receiver — re-initializes notification system after device reboot.
 *
 * Modeled after WhatsApp's BootReceiver:
 * 1. Re-registers FCM push token
 * 2. Recreates all notification channels (channels are cleared on reboot on some devices)
 * 3. Reschedules all alarm-based tasks (heartbeats, key rotation, backups)
 * 4. Re-establishes the foreground service if needed
 */
class KoraBootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "KoraBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                Log.d(TAG, "Boot completed — re-initializing notification system")
                initializeAfterBoot(context)
            }
        }
    }

    private fun initializeAfterBoot(context: Context) {
        // 1. Recreate notification channels (survive reboot, but be safe)
        KoraNotificationChannels.createAll(context)

        // 2. Schedule alarm-based tasks
        KoraAlarmScheduler.scheduleAll(context)

        // 3. Mark that we need to re-register push token
        val prefs = context.getSharedPreferences("kora_notif", Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean("needs_token_reregistration", true)
            .putLong("last_boot_timestamp", System.currentTimeMillis())
            .apply()

        // 4. Schedule a heartbeat alarm (immediate + recurring)
        KoraAlarmScheduler.scheduleHeartbeat(context)

        Log.d(TAG, "Boot initialization complete — channels created, alarms scheduled")
    }
}
