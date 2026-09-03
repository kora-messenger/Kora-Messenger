package com.kora.messenger.voice

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import java.io.File

/**
 * KoraVoiceNoteRecorder.kt
 *
 * A Kora-native voice-note recorder using Android's MediaRecorder.
 *
 * Captures microphone input only (MediaRecorder.AudioSource.VOICE_COMMUNICATION) —
 * tuned for voice capture with built-in echo cancellation, automatic
 * gain control and noise suppression, and isolated from system audio,
 * notifications, and other app media.
 *
 * Interaction model (handled on the Flutter/Dart side):
 * 1. Tap microphone -> recording UI.
 * 2. Press and hold -> record immediately.
 * 3. Release -> send.
 * 4. Swipe upward while holding -> lock recording.
 * 5. Swipe toward cancel area -> cancel.
 * 6. Locked mode -> pause/resume/delete/send.
 *
 * Output: AAC / MPEG4, 44100 Hz, 64kbps, mono
 */
class KoraVoiceRecorder(
    private val context: Context
) {
    private var recorder: MediaRecorder? = null
    private var outputFile: File? = null

    fun start(): File? {
        return try {
            val dir = File(context.cacheDir, "kora_voice_notes")
            if (!dir.exists()) dir.mkdirs()

            val file = File(
                dir,
                "voice_${System.currentTimeMillis()}.m4a"
            )

            val r = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(context)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            r.apply {
                setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(64_000)
                setAudioSamplingRate(44_100)
                setOutputFile(file.absolutePath)
                prepare()
                start()
            }

            recorder = r
            outputFile = file
            file
        } catch (_: Exception) {
            recorder?.release()
            recorder = null
            outputFile = null
            null
        }
    }

    fun pause() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try { recorder?.pause() } catch (_: Exception) {}
        }
    }

    /// Current mic input level (0-32767 raw), for the live waveform.
    /// Real amplitude straight from the hardware — not a decorative
    /// simulation — so the waveform actually reacts to how loud the
    /// user is speaking or how noisy their surroundings are.
    fun getAmplitude(): Int {
        return try {
            recorder?.maxAmplitude ?: 0
        } catch (_: Exception) {
            0
        }
    }

    fun resume() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try { recorder?.resume() } catch (_: Exception) {}
        }
    }

    fun stop(): File? {
        val file = outputFile
        try { recorder?.stop() } catch (_: Exception) {}
        try { recorder?.release() } catch (_: Exception) {}
        recorder = null
        outputFile = null
        return file?.takeIf { it.exists() && it.length() > 0 }
    }

    fun cancel() {
        val file = outputFile
        try { recorder?.stop() } catch (_: Exception) {}
        try { recorder?.release() } catch (_: Exception) {}
        recorder = null
        outputFile = null
        file?.delete()
    }
}
