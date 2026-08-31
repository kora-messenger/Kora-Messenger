package com.kora.messenger

import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Method channel handler for starting/stopping the LiveCallTranslationService
/// from Flutter when a WebRTC call begins/ends.
///
/// This bridges Flutter → native foreground service lifecycle management
/// for Android 14+ compliance.
class CallServicePlugin(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "com.kora.messenger/call_service"

        fun registerWith(flutterEngine: FlutterEngine, context: Context): CallServicePlugin {
            val plugin = CallServicePlugin(context)
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler(plugin)
            return plugin
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startTranslationService" -> {
                val callId = call.argument<String>("callId") ?: "active_call"
                val callerName = call.argument<String>("callerName") ?: "Kora Call"
                val intent = Intent(context, LiveCallTranslationService::class.java).apply {
                    putExtra("call_id", callId)
                    putExtra("caller_name", callerName)
                }
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                result.success(true)
            }
            "stopTranslationService" -> {
                val intent = Intent(context, LiveCallTranslationService::class.java)
                context.stopService(intent)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
}
