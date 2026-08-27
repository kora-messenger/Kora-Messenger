package com.kora.messenger.notifications

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log

/**
 * Alarm-based scheduling for periodic background tasks.
 *
 * Modeled after WhatsApp's AlarmBroadcastReceiver which handles:
 * - DAILY_CRON: Daily maintenance tasks
 * - HOURLY_CRON: Hourly tasks (token refresh, cleanup)
 * - HEARTBEAT_WAKEUP: Keep-alive pings to server
 * - ROTATE_SIGNED_PREKEY: Security key rotation
 * - BACKUP_MESSAGES: Scheduled message backups
 *
 * Uses SCHEDULE_EXACT_ALARM permission for precise timing.
 */
object KoraAlarmScheduler {

    private const val TAG = "KoraAlarmScheduler"

    // Actions
    const val ACTION_DAILY_CRON = "com.kora.messenger.action.DAILY_CRON"
    const val ACTION_HOURLY_CRON = "com.kora.messenger.action.HOURLY_CRON"
    const val ACTION_HEARTBEAT = "com.kora.messenger.action.HEARTBEAT_WAKEUP"
    const val ACTION_KEY_ROTATION = "com.kora.messenger.action.ROTATE_SIGNED_PREKEY"
    const val ACTION_BACKUP = "com.kora.messenger.action.BACKUP_MESSAGES"

    // Intervals
    private const val HEARTBEAT_INTERVAL_MS = 60_000L * 5 // 5 minutes
    private const val HOURLY_INTERVAL_MS = 60_000L * 60 // 1 hour
    private const val DAILY_INTERVAL_MS = 86_400_000L // 24 hours
    private const val KEY_ROTATION_INTERVAL_MS = 86_400_000L * 2 // 2 days

    fun scheduleAll(context: Context) {
        scheduleHeartbeat(context)
        scheduleHourlyCron(context)
        scheduleDailyCron(context)
        scheduleKeyRotation(context)
    }

    fun scheduleHeartbeat(context: Context) {
        scheduleRepeating(
            context,
            ACTION_HEARTBEAT,
            SystemClock.elapsedRealtime() + HEARTBEAT_INTERVAL_MS,
            HEARTBEAT_INTERVAL_MS,
            "Heartbeat"
        )
    }

    fun scheduleHourlyCron(context: Context) {
        scheduleRepeating(
            context,
            ACTION_HOURLY_CRON,
            SystemClock.elapsedRealtime() + HOURLY_INTERVAL_MS,
            HOURLY_INTERVAL_MS,
            "Hourly cron"
        )
    }

    fun scheduleDailyCron(context: Context) {
        // Schedule for 3 AM
        val calendar = java.util.Calendar.getInstance().apply {
            add(java.util.Calendar.DAY_OF_MONTH, 1)
            set(java.util.Calendar.HOUR_OF_DAY, 3)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
        }
        scheduleRepeating(
            context,
            ACTION_DAILY_CRON,
            calendar.timeInMillis,
            DAILY_INTERVAL_MS,
            "Daily cron"
        )
    }

    fun scheduleKeyRotation(context: Context) {
        scheduleRepeating(
            context,
            ACTION_KEY_ROTATION,
            SystemClock.elapsedRealtime() + KEY_ROTATION_INTERVAL_MS,
            KEY_ROTATION_INTERVAL_MS,
            "Key rotation"
        )
    }

    private fun scheduleRepeating(
        context: Context,
        action: String,
        triggerAtMillis: Long,
        intervalMillis: Long,
        label: String
    ) {
        val alarmMgr = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, KoraAlarmReceiver::class.java).apply {
            this.action = action
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, action.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmMgr.canScheduleExactAlarms()) {
                    alarmMgr.setExactAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                } else {
                    // Fall back to inexact alarm
                    alarmMgr.setAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                }
            } else {
                alarmMgr.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            }

            Log.d(TAG, "Scheduled $label: trigger in ${(triggerAtMillis - SystemClock.elapsedRealtime()) / 1000}s")
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot schedule exact alarm for $label: ${e.message}")
            // Fall back to inexact
            alarmMgr.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        }
    }

    fun cancelAlarm(context: Context, action: String) {
        val alarmMgr = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, KoraAlarmReceiver::class.java).apply {
            this.action = action
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, action.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmMgr.cancel(pendingIntent)
        Log.d(TAG, "Cancelled alarm: $action")
    }

    fun cancelAll(context: Context) {
        cancelAlarm(context, ACTION_DAILY_CRON)
        cancelAlarm(context, ACTION_HOURLY_CRON)
        cancelAlarm(context, ACTION_HEARTBEAT)
        cancelAlarm(context, ACTION_KEY_ROTATION)
    }
}
