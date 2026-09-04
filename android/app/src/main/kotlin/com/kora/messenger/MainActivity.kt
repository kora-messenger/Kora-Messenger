package com.kora.messenger

import android.os.Bundle

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import com.kora.messenger.notifications.KoraNotificationChannels
import com.kora.messenger.notifications.KoraAlarmScheduler
import com.kora.messenger.voice.KoraVoiceRecorder
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val ICON_CHANNEL = "com.kora.messenger/icon"
    private val SECURE_CHANNEL = "com.kora.messenger/secure"
    private val NOTIF_CHANNEL = "com.kora.messenger/notifications"
    private val VOICE_CHANNEL = "com.kora.messenger/voice"
    private var voiceRecorder: KoraVoiceRecorder? = null

    private val allAliases = listOf(
        "IconClassic", "IconAuroraCircle", "IconGoldElite"
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Real GPS location (chat "Send Location" + Live Location) ──
        LocationPlugin(this).register(flutterEngine.dartExecutor.binaryMessenger)

        // ── App icon switcher ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ICON_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setIcon" -> {
                        val aliasName = call.argument<String>("alias") ?: ""
                        try {
                            val pm = packageManager
                            val pkg = packageName
                            for (alias in allAliases) {
                                pm.setComponentEnabledSetting(
                                    ComponentName(pkg, "$pkg.$alias"),
                                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                    PackageManager.DONT_KILL_APP
                                )
                            }
                            pm.setComponentEnabledSetting(
                                ComponentName(pkg, "$pkg.$aliasName"),
                                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                                PackageManager.DONT_KILL_APP
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Screenshot prevention (FLAG_SECURE) ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableSecure" -> {
                        runOnUiThread {
                            window.setFlags(
                                WindowManager.LayoutParams.FLAG_SECURE,
                                WindowManager.LayoutParams.FLAG_SECURE
                            )
                        }
                        result.success(true)
                    }
                    "disableSecure" -> {
                        runOnUiThread {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Notification system ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "createChannels" -> {
                        KoraNotificationChannels.createAll(this)
                        result.success(true)
                    }
                    "upgradeChannels" -> {
                        KoraNotificationChannels.upgradeChannels(this)
                        result.success(true)
                    }
                    "scheduleAlarms" -> {
                        KoraAlarmScheduler.scheduleAll(this)
                        result.success(true)
                    }
                    "cancelAlarms" -> {
                        KoraAlarmScheduler.cancelAll(this)
                        result.success(true)
                    }
                    "getFcmToken" -> {
                        val prefs = getSharedPreferences("kora_notif", MODE_PRIVATE)
                        result.success(prefs.getString("fcm_token", null))
                    }
                    "needsTokenReregistration" -> {
                        val prefs = getSharedPreferences("kora_notif", MODE_PRIVATE)
                        val needs = prefs.getBoolean("needs_token_reregistration", false)
                        result.success(needs)
                    }
                    "clearTokenReregistration" -> {
                        val prefs = getSharedPreferences("kora_notif", MODE_PRIVATE)
                        prefs.edit().putBoolean("needs_token_reregistration", false).apply()
                        result.success(true)
                    }
                    "getPendingReplies" -> {
                        val prefs = getSharedPreferences("kora_pending_replies", MODE_PRIVATE)
                        val replies = mutableMapOf<String, String>()
                        val now = System.currentTimeMillis()
                        for (key in prefs.all.keys) {
                            if (key.startsWith("reply_") && !key.contains("chat_") && !key.contains("timestamp_")) {
                                val replyId = key.removePrefix("reply_")
                                val text = prefs.getString(key, "") ?: ""
                                val chatId = prefs.getString("reply_chat_$replyId", "") ?: ""
                                val timestamp = prefs.getLong("reply_timestamp_$replyId", 0)
                                if (now - timestamp < 60_000) { // Only replies from last minute
                                    replies[chatId] = text
                                }
                            }
                        }
                        result.success(replies)
                    }
                    "getPendingCalls" -> {
                        val prefs = getSharedPreferences("kora_pending_calls", MODE_PRIVATE)
                        val map = mutableMapOf<String, Any?>()
                        map["accepted_call_id"] = prefs.getString("accepted_call_id", null)
                        map["accepted_call_is_video"] = prefs.getBoolean("accepted_call_is_video", false)
                        map["rejected_call_id"] = prefs.getString("rejected_call_id", null)
                        map["hungup_call_id"] = prefs.getString("hungup_call_id", null)
                        result.success(map)
                    }
                    "clearPendingCalls" -> {
                        val prefs = getSharedPreferences("kora_pending_calls", MODE_PRIVATE)
                        prefs.edit().clear().apply()
                        result.success(true)
                    }
                    "getDismissedNotifications" -> {
                        val prefs = getSharedPreferences("kora_notif_dismissed", MODE_PRIVATE)
                        val dismissed = mutableListOf<Map<String, String>>()
                        for (key in prefs.all.keys) {
                            if (key.startsWith("dismissed_type_")) {
                                val timestamp = key.removePrefix("dismissed_type_")
                                val type = prefs.getString(key, "") ?: ""
                                val chatId = prefs.getString("dismissed_chat_id_$timestamp", "") ?: ""
                                dismissed.add(mapOf(
                                    "type" to type,
                                    "chat_id" to chatId,
                                    "timestamp" to timestamp
                                ))
                            }
                        }
                        result.success(dismissed)
                    }
                    "clearDismissedNotifications" -> {
                        val prefs = getSharedPreferences("kora_notif_dismissed", MODE_PRIVATE)
                        prefs.edit().clear().apply()
                        result.success(true)
                    }
                    "getAlarmStatus" -> {
                        val prefs = getSharedPreferences("kora_alarms", MODE_PRIVATE)
                        val status = mutableMapOf<String, Long>()
                        status["last_heartbeat"] = prefs.getLong("last_heartbeat", 0)
                        status["last_hourly_cron"] = prefs.getLong("last_hourly_cron", 0)
                        status["last_daily_cron"] = prefs.getLong("last_daily_cron", 0)
                        status["last_key_rotation"] = prefs.getLong("last_key_rotation", 0)
                        result.success(status)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Native voice recorder ──
        voiceRecorder = KoraVoiceRecorder(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val file = voiceRecorder?.start()
                        if (file != null) result.success(file.absolutePath)
                        else result.error("RECORD_FAILED", "Failed to start recording", null)
                    }
                    "stop" -> {
                        val file = voiceRecorder?.stop()
                        if (file != null) result.success(file.absolutePath)
                        else result.success(null)
                    }
                    "pause" -> {
                        voiceRecorder?.pause()
                        result.success(true)
                    }
                    "resume" -> {
                        voiceRecorder?.resume()
                        result.success(true)
                    }
                    "cancel" -> {
                        voiceRecorder?.cancel()
                        result.success(true)
                    }
                    "amplitude" -> {
                        result.success(voiceRecorder?.getAmplitude() ?: 0)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize notification channels on app start
        KoraNotificationChannels.createAll(this)

        // Schedule alarms if needed
        KoraAlarmScheduler.scheduleAll(this)

        // Check for pending call/notification intents
        handleIntentExtras(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntentExtras(intent)
    }

    private fun handleIntentExtras(intent: Intent?) {
        intent?.let {
            val callId = it.getStringExtra("call_id")
            val callerName = it.getStringExtra("caller_name")
            val isVideo = it.getBooleanExtra("is_video", false)
            val fromNotification = it.getBooleanExtra("from_notification", false)

            if (fromNotification && callId != null) {
                // App opened from call notification — trigger call UI via method channel
                // Flutter side will read this and navigate to call screen
                val prefs = getSharedPreferences("kora_pending_calls", MODE_PRIVATE)
                prefs.edit()
                    .putString("accepted_call_id", callId)
                    .putBoolean("accepted_call_is_video", isVideo)
                    .putLong("accepted_call_timestamp", System.currentTimeMillis())
                    .apply()
            }
        }
    }

    // Import needed for saved instance state
    override fun onSaveInstanceState(outState: android.os.Bundle) {
        super.onSaveInstanceState(outState)
    }
}

// Need to import Bundle
