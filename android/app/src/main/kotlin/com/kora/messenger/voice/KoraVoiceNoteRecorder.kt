package com.kora.messenger.voice

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.File

/**
 * KoraVoiceNoteRecorder.kt
 *
 * A Kora-native voice-note controller inspired by the interaction model
 * observed in the supplied reference APK:
 *
 * 1. Tap microphone -> recording UI.
 * 2. Press and hold -> record immediately.
 * 3. Release -> send.
 * 4. Swipe upward while holding -> lock recording.
 * 5. Swipe toward cancel area -> cancel.
 * 6. Locked mode -> pause/resume/delete/send.
 *
 * IMPORTANT:
 * This is an independent Kora implementation. It does not copy proprietary
 * WhatsApp source code or assets.
 *
 * Add RECORD_AUDIO permission to AndroidManifest.xml.
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
                setAudioSource(MediaRecorder.AudioSource.MIC)
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

private enum class KoraRecordingMode {
    Idle,
    Holding,
    Locked,
    Paused
}

@Composable
fun KoraVoiceNoteComposer(
    modifier: Modifier = Modifier,
    onVoiceNoteReady: (File) -> Unit,
    onRecordingError: () -> Unit = {}
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val recorder = remember { KoraVoiceRecorder(context) }

    var mode by remember { mutableStateOf(KoraRecordingMode.Idle) }
    var seconds by remember { mutableIntStateOf(0) }
    var isPreviewing by remember { mutableStateOf(false) }

    val permissionLauncher =
        rememberLauncherForActivityResult(
            ActivityResultContracts.RequestPermission()
        ) { granted ->
            if (!granted) onRecordingError()
        }

    fun hasPermission(): Boolean =
        androidx.core.content.ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

    fun beginRecording() {
        if (!hasPermission()) {
            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
            return
        }

        val file = recorder.start()
        if (file == null) {
            onRecordingError()
            return
        }

        seconds = 0
        mode = KoraRecordingMode.Holding
        isPreviewing = false

        scope.launch {
            while (
                mode == KoraRecordingMode.Holding ||
                mode == KoraRecordingMode.Locked
            ) {
                delay(1000)
                seconds++
            }
        }
    }

    fun finishAndSend() {
        val file = recorder.stop()
        mode = KoraRecordingMode.Idle
        seconds = 0

        if (file != null) {
            onVoiceNoteReady(file)
        } else {
            onRecordingError()
        }
    }

    fun cancelRecording() {
        recorder.cancel()
        mode = KoraRecordingMode.Idle
        seconds = 0
        isPreviewing = false
    }

    fun pauseRecording() {
        recorder.pause()
        mode = KoraRecordingMode.Paused
    }

    fun resumeRecording() {
        recorder.resume()
        mode = KoraRecordingMode.Locked

        scope.launch {
            while (mode == KoraRecordingMode.Locked) {
                delay(1000)
                seconds++
            }
        }
    }

    if (mode == KoraRecordingMode.Idle) {
        KoraMicrophoneButton(
            modifier = modifier,
            onTap = { beginRecording() },
            onHoldStart = { beginRecording() },
            onHoldRelease = {
                if (mode == KoraRecordingMode.Holding) {
                    finishAndSend()
                }
            },
            onSwipeUp = {
                if (mode == KoraRecordingMode.Holding) {
                    mode = KoraRecordingMode.Locked
                }
            },
            onSwipeCancel = {
                if (mode == KoraRecordingMode.Holding) {
                    cancelRecording()
                }
            }
        )
    } else {
        KoraRecordingPanel(
            modifier = modifier,
            duration = seconds,
            locked = mode == KoraRecordingMode.Locked ||
                    mode == KoraRecordingMode.Paused,
            paused = mode == KoraRecordingMode.Paused,
            previewing = isPreviewing,
            onDelete = { cancelRecording() },
            onPause = { pauseRecording() },
            onResume = { resumeRecording() },
            onSend = { finishAndSend() },
            onPreview = {
                // Connect this to your audio-player implementation.
                isPreviewing = !isPreviewing
            }
        )
    }
}

@Composable
private fun KoraMicrophoneButton(
    modifier: Modifier = Modifier,
    onTap: () -> Unit,
    onHoldStart: () -> Unit,
    onHoldRelease: () -> Unit,
    onSwipeUp: () -> Unit,
    onSwipeCancel: () -> Unit
) {
    var startY by remember { mutableFloatStateOf(0f) }
    var gestureStarted by remember { mutableStateOf(false) }

    Box(
        modifier = modifier
            .size(58.dp)
            .clip(CircleShape)
            .background(Color(0xFF6C35DE))
            .pointerInput(Unit) {
                detectTapGestures(
                    onTap = { onTap() },
                    onPress = {
                        gestureStarted = true
                        startY = 0f
                        onHoldStart()

                        try {
                            awaitRelease()
                        } finally {
                            if (gestureStarted) {
                                onHoldRelease()
                                gestureStarted = false
                            }
                        }
                    }
                )
            }
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragStart = { offset ->
                        startY = offset.y
                    },
                    onDrag = { change, _ ->
                        val distanceUp = startY - change.position.y
                        val distanceLeft = startY - change.position.x

                        when {
                            distanceUp > 90f -> {
                                onSwipeUp()
                                change.consume()
                            }

                            distanceLeft > 120f -> {
                                onSwipeCancel()
                                change.consume()
                            }
                        }
                    },
                    onDragEnd = {
                        gestureStarted = false
                    }
                )
            },
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = Icons.Default.Mic,
            contentDescription = "Voice note",
            tint = Color.White,
            modifier = Modifier.size(30.dp)
        )
    }
}

@Composable
private fun KoraRecordingPanel(
    modifier: Modifier = Modifier,
    duration: Int,
    locked: Boolean,
    paused: Boolean,
    previewing: Boolean,
    onDelete: () -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onSend: () -> Unit,
    onPreview: () -> Unit
) {
    val surface = Color.White
    val text = Color(0xFF151515)
    val control = Color(0xFFF2F1F4)
    val kora = Color(0xFF6C35DE)
    val deleteBg = Color(0xFFFFE7EC)
    val delete = Color(0xFFE4003B)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(
                RoundedCornerShape(
                    topStart = 30.dp,
                    topEnd = 30.dp
                )
            )
            .background(surface)
            .padding(
                start = 18.dp,
                end = 18.dp,
                top = 18.dp,
                bottom = 18.dp
            )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(70.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(
                onClick = onPreview,
                modifier = Modifier.size(54.dp)
            ) {
                Icon(
                    imageVector =
                        if (previewing)
                            Icons.Default.Pause
                        else
                            Icons.Default.PlayArrow,
                    contentDescription = "Preview voice note",
                    tint = text,
                    modifier = Modifier.size(34.dp)
                )
            }

            Spacer(Modifier.width(6.dp))

            KoraWaveform(
                modifier = Modifier
                    .weight(1f)
                    .height(52.dp),
                active = !paused
            )

            Spacer(Modifier.width(10.dp))

            Text(
                text = formatDuration(duration),
                color = text,
                fontSize = 22.sp
            )
        }

        Spacer(Modifier.height(14.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Box(
                modifier = Modifier
                    .size(68.dp)
                    .clip(CircleShape)
                    .background(deleteBg),
                contentAlignment = Alignment.Center
            ) {
                IconButton(
                    onClick = onDelete,
                    modifier = Modifier.size(68.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Delete,
                        contentDescription = "Delete",
                        tint = delete,
                        modifier = Modifier.size(31.dp)
                    )
                }
            }

            Spacer(Modifier.width(14.dp))

            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(66.dp)
                    .clip(RoundedCornerShape(34.dp))
                    .background(control),
                contentAlignment = Alignment.Center
            ) {
                IconButton(
                    onClick = {
                        if (paused) onResume() else onPause()
                    },
                    modifier = Modifier.size(56.dp)
                ) {
                    Icon(
                        imageVector =
                            if (paused)
                                Icons.Default.PlayArrow
                            else
                                Icons.Default.Pause,
                        contentDescription =
                            if (paused) "Resume" else "Pause",
                        tint = text,
                        modifier = Modifier.size(30.dp)
                    )
                }

                Text(
                    text = if (paused) "Resume" else "Pause",
                    color = text,
                    fontSize = 19.sp
                )
            }

            Spacer(Modifier.width(14.dp))

            Box(
                modifier = Modifier
                    .size(68.dp)
                    .clip(CircleShape)
                    .background(kora),
                contentAlignment = Alignment.Center
            ) {
                IconButton(
                    onClick = onSend,
                    modifier = Modifier.size(68.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Send,
                        contentDescription = "Send",
                        tint = Color.White,
                        modifier = Modifier.size(31.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun KoraWaveform(
    modifier: Modifier = Modifier,
    active: Boolean
) {
    val bars = remember {
        List(34) { index ->
            val pattern = listOf(
                0.25f, 0.55f, 0.35f, 0.80f,
                0.42f, 0.70f, 0.32f, 0.90f,
                0.50f, 0.75f, 0.38f, 0.62f
            )
            pattern[index % pattern.size]
        }
    }

    val pulse = remember { Animatable(1f) }

    LaunchedEffect(active) {
        if (active) {
            while (true) {
                pulse.animateTo(
                    1.10f,
                    tween(420, easing = FastOutSlowInEasing)
                )
                pulse.animateTo(
                    0.92f,
                    tween(420, easing = FastOutSlowInEasing)
                )
            }
        } else {
            pulse.snapTo(1f)
        }
    }

    Canvas(modifier = modifier) {
        val gap = size.width / (bars.size + 1)
        val center = size.height / 2f

        bars.forEachIndexed { index, value ->
            val height = size.height * value * pulse.value
            val x = gap * (index + 1)

            drawLine(
                color = Color(0xFFD0D0D0),
                start = androidx.compose.ui.geometry.Offset(
                    x,
                    center - height / 2
                ),
                end = androidx.compose.ui.geometry.Offset(
                    x,
                    center + height / 2
                ),
                strokeWidth = 4.dp.toPx(),
                cap = StrokeCap.Round
            )
        }
    }
}

private fun formatDuration(seconds: Int): String {
    val minutes = seconds / 60
    val remaining = seconds % 60
    return "%d:%02d".format(minutes, remaining)
}
