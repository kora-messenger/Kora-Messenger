package com.kora.messenger

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Timer
import java.util.TimerTask

/// Native Android voice-note recorder using MediaRecorder with
/// VOICE_COMMUNICATION audio source.
///
/// Audio source: MediaRecorder.AudioSource.VOICE_COMMUNICATION
///   - Captures ONLY the device microphone (never system audio / REMOTE_SUBMIX)
///   - Enables Android's built-in echo cancellation
///   - Enables automatic gain control (AGC)
///   - Enables noise suppression
///
/// Output: MPEG_4 container, AAC encoder, 44100 Hz, 128 kbps, mono
///
/// Amplitude data for the live waveform is polled via getMaxAmplitude()
/// at 50ms intervals and streamed back through an EventChannel.
class VoiceNoteRecorderPlugin {

    companion object {
        private const val TAG = "VoiceNoteRecorder"
        private const val METHOD_CHANNEL = "com.kora.messenger/voice_recorder"
        private const val EVENT_CHANNEL = "com.kora.messenger/voice_recorder_events"
        private const val POLL_INTERVAL_MS = 50L
    }

    private var recorder: MediaRecorder? = null
    private var isRecording = false
    private var isPaused = false
    private var currentPath: String? = null
    private var amplitudeTimer: Timer? = null
    private var eventSink: EventChannel.EventSink? = null
    private var handler: Handler = Handler(Looper.getMainLooper())
    private var appContext: Context? = null

    fun setup(binaryMessenger: BinaryMessenger) {
        MethodChannel(binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> {
                    val path = startRecording()
                    result.success(path)
                }
                "stopRecording" -> {
                    val path = stopRecording()
                    result.success(path)
                }
                "pauseRecording" -> {
                    pauseRecording()
                    result.success(true)
                }
                "resumeRecording" -> {
                    resumeRecording()
                    result.success(true)
                }
                "cancelRecording" -> {
                    cancelRecording()
                    result.success(true)
                }
                "isRecording" -> result.success(isRecording)
                "setContext" -> {
                    // Context is set via the activity, not from Dart
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    stopAmplitudePolling()
                }
            }
        )
    }

    /// Set the app context (called from MainActivity)
    fun setContext(context: Context) {
        appContext = context
    }

    private fun startRecording(): String {
        if (isRecording) {
            Log.w(TAG, "Already recording")
            return currentPath ?: ""
        }

        try {
            val ctx = appContext
            val cacheDir = if (ctx != null) {
                ctx.cacheDir.absolutePath
            } else {
                "/data/data/com.kora.messenger/cache"
            }

            val timestamp = System.currentTimeMillis()
            val path = "$cacheDir/kora_voice_$timestamp.m4a"

            // Use VOICE_COMMUNICATION audio source:
            // - Captures microphone only (never system audio)
            // - Enables echo cancellation, noise suppression, AGC
            val mr = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(ctx as android.content.Context)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            mr.setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
            mr.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            mr.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            mr.setAudioEncodingBitRate(128000)
            mr.setAudioSamplingRate(44100)
            mr.setAudioChannels(1)
            mr.setOutputFile(path)
            mr.prepare()
            mr.start()

            recorder = mr
            isRecording = true
            isPaused = false
            currentPath = path

            startAmplitudePolling()

            return path
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording", e)
            isRecording = false
            return ""
        }
    }

    private fun stopRecording(): String? {
        if (!isRecording) return null

        stopAmplitudePolling()

        return try {
            recorder?.stop()
            recorder?.release()
            recorder = null
            isRecording = false
            isPaused = false
            val path = currentPath
            currentPath = null

            if (path != null && File(path).exists()) path else null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recording", e)
            recorder?.release()
            recorder = null
            isRecording = false
            isPaused = false
            currentPath = null
            null
        }
    }

    private fun pauseRecording() {
        if (!isRecording || isPaused) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                recorder?.pause()
            }
            isPaused = true
            stopAmplitudePolling()
        } catch (e: Exception) {
            Log.w(TAG, "Pause not supported on this device", e)
        }
    }

    private fun resumeRecording() {
        if (!isRecording || !isPaused) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                recorder?.resume()
            }
            isPaused = false
            startAmplitudePolling()
        } catch (e: Exception) {
            Log.w(TAG, "Resume not supported", e)
            isPaused = false
        }
    }

    private fun cancelRecording() {
        stopAmplitudePolling()
        if (isRecording) {
            try { recorder?.stop() } catch (e: Exception) { }
            recorder?.release()
            recorder = null
            isRecording = false
            isPaused = false
        }
        currentPath?.let { path ->
            try {
                val file = File(path)
                if (file.exists()) file.delete()
            } catch (e: Exception) {
                Log.w(TAG, "Could not delete temp file", e)
            }
        }
        currentPath = null
    }

    // ── Amplitude polling for live waveform ──
    private fun startAmplitudePolling() {
        stopAmplitudePolling()
        amplitudeTimer = Timer("kora-amplitude", true)
        amplitudeTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                if (!isRecording || isPaused || recorder == null) return
                try {
                    val maxAmp = recorder?.maxAmplitude ?: 0
                    // Normalize: maxAmplitude returns 0-32767
                    val normalized = (maxAmp.toFloat() / 32767f).coerceIn(0.0f, 1.0f)
                    val amplitude = normalized.toDouble()
                    handler.post { eventSink?.success(amplitude) }
                } catch (e: Exception) {
                    // Recorder might be in a transitional state
                }
            }
        }, 0, POLL_INTERVAL_MS)
    }

    private fun stopAmplitudePolling() {
        amplitudeTimer?.cancel()
        amplitudeTimer = null
    }
}
