package com.kora.messenger.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Handles notification dismiss events for analytics and state cleanup.
 *
 * Modeled after WhatsApp's per-type dismiss receivers:
 * - MessageNotificationDismissedReceiver
 * - MissedCallNotificationDismissedReceiver
 * - StatusNotificationDismissReceiver
 * - NewsletterNotificationDismissedReceiver
 * - DraftReminderNotificationDismissedReceiver
 *
 * Each dismiss event:
 * 1. Records the notification_hash for deduplication
 * 2. Logs analytics (message notification dismissed, funnel tracking)
 * 3. Cleans up notification state in SharedPreferences
 * 4. Notifies the Flutter side to update unread counts
 */
class KoraNotificationDismissedReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "KoraNotifDismiss"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val chatId = intent.getStringExtra(KoraNotificationBuilder.KEY_CHAT_ID)
        val notifId = intent.getIntExtra(KoraNotificationBuilder.KEY_NOTIF_ID, -1)
        val notifHash = intent.getStringExtra(KoraNotificationBuilder.KEY_NOTIFICATION_HASH)

        Log.d(TAG, "Notification dismissed: action=$action, chatId=$chatId, hash=$notifHash")

        // Determine dismiss type
        val dismissType = when (action) {
            KoraNotificationBuilder.ACTION_DISMISS_MESSAGE -> "message"
            KoraNotificationBuilder.ACTION_DISMISS_MISSED_CALL -> "missed_call"
            KoraNotificationBuilder.ACTION_DISMISS_STATUS -> "status"
            KoraNotificationBuilder.ACTION_DISMISS_CHANNEL -> "channel"
            else -> "unknown"
        }

        // Persist dismiss event for Flutter analytics sync
        val prefs = context.getSharedPreferences("kora_notif_dismissed", Context.MODE_PRIVATE)
        val timestamp = System.currentTimeMillis()
        prefs.edit()
            .putString("dismissed_type_$timestamp", dismissType)
            .putString("dismissed_chat_id_$timestamp", chatId)
            .putString("dismissed_hash_$timestamp", notifHash)
            .putLong("dismissed_timestamp_$timestamp", timestamp)
            .apply()

        // Clean up notification state
        val statePrefs = context.getSharedPreferences("kora_notif_state", Context.MODE_PRIVATE)
        if (statePrefs.getInt("last_notif_id", -1) == notifId) {
            statePrefs.edit().remove("last_notif_id").remove("last_notif_chat_id").apply()
        }
    }
}
