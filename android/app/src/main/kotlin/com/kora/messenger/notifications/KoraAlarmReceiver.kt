package com.kora.messenger.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log

/**
 * Alarm broadcast receiver — handles periodic scheduled tasks.
 *
 * Modeled after WhatsApp's AlarmBroadcastReceiver:
 * - HEARTBEAT: Server keep-alive ping
 * - HOURLY_CRON: Hourly maintenance
 * - DAILY_CRON: Daily maintenance (cleanup, stats)
 * - KEY_ROTATION: Security prekey rotation
 */
class KoraAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "KoraAlarm"
        private const val WAKE_LOCK_TAG = "Kora:AlarmProcessing"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.d(TAG, "Alarm fired: $action")

        // Acquire wake lock
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            WAKE_LOCK_TAG
        )
        wakeLock.acquire(10_000L) // 10 second timeout

        try {
            when (action) {
                KoraAlarmScheduler.ACTION_HEARTBEAT -> handleHeartbeat(context)
                KoraAlarmScheduler.ACTION_HOURLY_CRON -> handleHourlyCron(context)
                KoraAlarmScheduler.ACTION_DAILY_CRON -> handleDailyCron(context)
                KoraAlarmScheduler.ACTION_KEY_ROTATION -> handleKeyRotation(context)
                else -> Log.w(TAG, "Unknown alarm action: $action")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling alarm $action", e)
        } finally {
            wakeLock.release()
        }
    }

    private fun handleHeartbeat(context: Context) {
        Log.d(TAG, "Heartbeat — server keep-alive ping")

        // Persist for Flutter to process on next startup
        val prefs = context.getSharedPreferences("kora_alarms", Context.MODE_PRIVATE)
        prefs.edit()
            .putLong("last_heartbeat", System.currentTimeMillis())
            .apply()

        // Re-schedule next heartbeat
        KoraAlarmScheduler.scheduleHeartbeat(context)
    }

    private fun handleHourlyCron(context: Context) {
        Log.d(TAG, "Hourly cron — maintenance tasks")

        // Refresh notification channels schema (version check)
        KoraNotificationChannels.upgradeChannels(context)

        // Update last hourly timestamp
        val prefs = context.getSharedPreferences("kora_alarms", Context.MODE_PRIVATE)
        prefs.edit()
            .putLong("last_hourly_cron", System.currentTimeMillis())
            .apply()

        // Re-schedule
        KoraAlarmScheduler.scheduleHourlyCron(context)
    }

    private fun handleDailyCron(context: Context) {
        Log.d(TAG, "Daily cron — daily maintenance")

        // Clean up old notification state
        val statePrefs = context.getSharedPreferences("kora_notif_state", Context.MODE_PRIVATE)
        val dismissedPrefs = context.getSharedPreferences("kora_notif_dismissed", Context.MODE_PRIVATE)

        // Clean dismiss events older than 7 days
        val weekAgo = System.currentTimeMillis() - (7 * 86_400_000L)
        val dismissKeys = dismissedPrefs.all.keys.filter { it.startsWith("dismissed_type_") }
        for (key in dismissKeys) {
            val timestamp = key.removePrefix("dismissed_type_").toLongOrNull() ?: continue
            if (timestamp < weekAgo) {
                dismissedPrefs.edit()
                    .remove(key)
                    .remove("dismissed_chat_id_$timestamp")
                    .remove("dismissed_hash_$timestamp")
                    .remove("dismissed_timestamp_$timestamp")
                    .apply()
            }
        }

        val prefs = context.getSharedPreferences("kora_alarms", Context.MODE_PRIVATE)
        prefs.edit()
            .putLong("last_daily_cron", System.currentTimeMillis())
            .apply()

        // Re-schedule
        KoraAlarmScheduler.scheduleDailyCron(context)
    }

    private fun handleKeyRotation(context: Context) {
        Log.d(TAG, "Key rotation — security prekey rotation")

        val prefs = context.getSharedPreferences("kora_alarms", Context.MODE_PRIVATE)
        prefs.edit()
            .putLong("last_key_rotation", System.currentTimeMillis())
            .apply()

        // Re-schedule
        KoraAlarmScheduler.scheduleKeyRotation(context)
    }
}
