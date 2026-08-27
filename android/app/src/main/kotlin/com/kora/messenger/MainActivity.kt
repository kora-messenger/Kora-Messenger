package com.kora.messenger

import android.content.ComponentName
import android.content.pm.PackageManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val ICON_CHANNEL = "com.kora.messenger/icon"
    private val SECURE_CHANNEL = "com.kora.messenger/secure"

    // All activity-alias names — must match AndroidManifest.xml
    private val allAliases = listOf(
        "IconClassic", "IconAuroraCircle", "IconGoldElite"
    )

    private val voiceNoteRecorder = VoiceNoteRecorderPlugin()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Voice note recorder (native VOICE_COMMUNICATION source) ──
        voiceNoteRecorder.setContext(this)
        voiceNoteRecorder.setup(flutterEngine.dartExecutor.binaryMessenger)

        // ── App icon switcher ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ICON_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setIcon" -> {
                        val aliasName = call.argument<String>("alias") ?: ""
                        try {
                            val pm = packageManager
                            val pkg = packageName

                            // Disable all aliases first
                            for (alias in allAliases) {
                                pm.setComponentEnabledSetting(
                                    ComponentName(pkg, "$pkg.$alias"),
                                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                    PackageManager.DONT_KILL_APP
                                )
                            }

                            // Enable the selected alias
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
    }
}
