package com.kora.messenger.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationManagerCompat

/**
 * Handles call accept/reject/hangup actions from call notifications.
 *
 * Modeled after WhatsApp's DeclineIntentReceiver:
 * - CALL_ACCEPT: Launches the call screen (handled by Flutter)
 * - CALL_REJECT: Cancels the call notification + notifies backend
 * - CALL_HANGUP: Ends an active call
 */
class KoraCallActionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "KoraCallAction"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            KoraNotificationBuilder.ACTION_CALL_ACCEPT -> handleAccept(context, intent)
            KoraNotificationBuilder.ACTION_CALL_REJECT -> handleReject(context, intent)
            KoraNotificationBuilder.ACTION_CALL_HANGUP -> handleHangup(context, intent)
        }
    }

    private fun handleAccept(context: Context, intent: Intent) {
        val callId = intent.getStringExtra("call_id")
        val isVideo = intent.getBooleanExtra("is_video", false)
        Log.d(TAG, "Call accepted: callId=$callId, isVideo=$isVideo")

        // Cancel the incoming call notification
        NotificationManagerCompat.from(context)
            .cancel(KoraNotificationChannels.NOTIF_ID_CALL)

        // Persist for Flutter to pick up and launch call UI
        val prefs = context.getSharedPreferences("kora_pending_calls", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("accepted_call_id", callId)
            .putBoolean("accepted_call_is_video", isVideo)
            .putLong("accepted_call_timestamp", System.currentTimeMillis())
            .apply()
    }

    private fun handleReject(context: Context, intent: Intent) {
        val callId = intent.getStringExtra("call_id")
        Log.d(TAG, "Call rejected: callId=$callId")

        // Cancel the incoming call notification
        NotificationManagerCompat.from(context)
            .cancel(KoraNotificationChannels.NOTIF_ID_CALL)

        // Persist for Flutter to notify backend
        val prefs = context.getSharedPreferences("kora_pending_calls", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("rejected_call_id", callId)
            .putLong("rejected_call_timestamp", System.currentTimeMillis())
            .apply()
    }

    private fun handleHangup(context: Context, intent: Intent) {
        val callId = intent.getStringExtra("call_id")
        Log.d(TAG, "Call hangup: callId=$callId")

        // Cancel any call-related notifications
        NotificationManagerCompat.from(context)
            .cancel(KoraNotificationChannels.NOTIF_ID_CALL)

        val prefs = context.getSharedPreferences("kora_pending_calls", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("hungup_call_id", callId)
            .putLong("hungup_call_timestamp", System.currentTimeMillis())
            .apply()
    }
}
