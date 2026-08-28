import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

/// KoraVoiceNoteRecorder
///
/// Flutter port of the native Kotlin KoraVoiceNoteComposer.
/// Implements the same gesture model:
///   1. Tap mic -> recording starts
///   2. Press & hold -> record, release to send
///   3. Swipe up -> lock recording
///   4. Swipe left -> cancel
///   5. Locked -> pause/resume/delete/send
///   6. Waveform + duration timer
///
/// Uses VOICE_COMMUNICATION audio source (mic only, no system audio).

enum _RecorderMode { idle, holding, locked, paused }

class KoraVoiceNoteRecorder extends StatefulWidget {
  final void Function(File audioFile, int durationSeconds) onVoiceNoteReady;
  final VoidCallback? onRecordingError;

  const KoraVoiceNoteRecorder({
    super.key,
    required this.onVoiceNoteReady,
    this.onRecordingError,
  });

  @override
  State<KoraVoiceNoteRecorder> createState() => _KoraVoiceNoteRecorderState();
}

class _KoraVoiceNoteRecorderState extends State<KoraVoiceNoteRecorder> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _recorderInitialized = false;

  _RecorderMode _mode = _RecorderMode.idle;
  int _seconds = 0;
  Timer? _timer;
  String? _audioPath;

  // Gesture tracking
  double _dragStartY = 0;
  double _dragStartX = 0;

  // Kora colors
  static const Color _koraPurple = Color(0xFF6C63FF);
  static const Color _koraDarkPurple = Color(0xFF6C35DE);
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _textDark = Color(0xFF151515);
  static const Color _controlLight = Color(0xFFF2F1F4);
  static const Color _deleteBg = Color(0xFFFFE7EC);
  static const Color _deleteRed = Color(0xFFE4003B);

  Future<void> _initRecorder() async {
    if (_recorderInitialized) return;
    await _recorder.openRecorder();
    _recorderInitialized = true;
  }

  Future<bool> _checkPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<void> _startRecording() async {
    final hasPermission = await _checkPermission();
    if (!hasPermission) {
      widget.onRecordingError?.call();
      return;
    }

    await _initRecorder();

    try {
      final dir = Directory('${Directory.systemTemp.path}/kora_voice_notes');
      if (!dir.existsSync()) dir.createSync(recursive: true);

      _audioPath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _recorder.startRecorder(
        toFile: _audioPath,
        codec: Codec.aacADTS,
        numChannels: 1,
        sampleRate: 44100,
        audioSource: AudioSource.voice_communication,
      );

      _seconds = 0;
      _mode = _RecorderMode.holding;

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_mode == _RecorderMode.holding || _mode == _RecorderMode.locked) {
          setState(() => _seconds++);
        }
      });

      setState(() {});
    } catch (_) {
      widget.onRecordingError?.call();
    }
  }

  Future<void> _stopAndSend() async {
    try {
      final path = await _recorder.stopRecorder();
      _timer?.cancel();
      _timer = null;

      final file = File(path ?? _audioPath ?? '');
      _mode = _RecorderMode.idle;
      final duration = _seconds;
      _seconds = 0;
      setState(() {});

      if (file.existsSync() && file.lengthSync() > 0) {
        widget.onVoiceNoteReady(file, duration);
      } else {
        widget.onRecordingError?.call();
      }
    } catch (_) {
      _mode = _RecorderMode.idle;
      _seconds = 0;
      setState(() {});
      widget.onRecordingError?.call();
    }
  }

  Future<void> _cancelRecording() async {
    try {
      await _recorder.stopRecorder();
    } catch (_) {}

    _timer?.cancel();
    _timer = null;

    if (_audioPath != null) {
      try {
        final f = File(_audioPath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }

    _mode = _RecorderMode.idle;
    _seconds = 0;
    setState(() {});
  }

  void _pauseRecording() {
    try {
      _recorder.pauseRecorder();
    } catch (_) {}
    setState(() => _mode = _RecorderMode.paused);
  }

  void _resumeRecording() {
    try {
      _recorder.resumeRecorder();
    } catch (_) {}
    setState(() => _mode = _RecorderMode.locked);
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_recorderInitialized) {
      try {
        _recorder.closeRecorder();
      } catch (_) {}
    }
    super.dispose();
  }

  String _formatDuration(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == _RecorderMode.idle) {
      return _MicButton(
        onTap: _startRecording,
        onHoldStart: _startRecording,
        onHoldRelease: () {
          if (_mode == _RecorderMode.holding) {
            _stopAndSend();
          }
        },
        onSwipeUp: () {
          if (_mode == _RecorderMode.holding) {
            setState(() => _mode = _RecorderMode.locked);
          }
        },
        onSwipeCancel: () {
          if (_mode == _RecorderMode.holding) {
            _cancelRecording();
          }
        },
      );
    }

    return _RecordingPanel(
      duration: _seconds,
      locked: _mode == _RecorderMode.locked || _mode == _RecorderMode.paused,
      paused: _mode == _RecorderMode.paused,
      formatDuration: _formatDuration,
      onDelete: _cancelRecording,
      onPause: _pauseRecording,
      onResume: _resumeRecording,
      onSend: _stopAndSend,
    );
  }
}

// ── Mic Button (idle state) ─────────────────────────────────

class _MicButton extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldRelease;
  final VoidCallback onSwipeUp;
  final VoidCallback onSwipeCancel;

  const _MicButton({
    required this.onTap,
    required this.onHoldStart,
    required this.onHoldRelease,
    required this.onSwipeUp,
    required this.onSwipeCancel,
  });

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> {
  double _startY = 0;
  double _startX = 0;
  bool _isHolding = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onPanStart: (details) {
        _startY = details.localPosition.dy;
        _startX = details.localPosition.dx;
        _isHolding = true;
        widget.onHoldStart();
      },
      onPanUpdate: (details) {
        if (!_isHolding) return;

        final distanceUp = _startY - details.localPosition.dy;
        final distanceLeft = _startX - details.localPosition.dx;

        if (distanceUp > 90) {
          widget.onSwipeUp();
          _isHolding = false;
        } else if (distanceLeft > 120) {
          widget.onSwipeCancel();
          _isHolding = false;
        }
      },
      onPanEnd: (_) {
        if (_isHolding) {
          widget.onHoldRelease();
          _isHolding = false;
        }
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: _koraDarkPurple,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.mic,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

// ── Recording Panel (holding/locked/paused state) ───────────

class _RecordingPanel extends StatelessWidget {
  final int duration;
  final bool locked;
  final bool paused;
  final String Function(int) formatDuration;
  final VoidCallback onDelete;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSend;

  const _RecordingPanel({
    required this.duration,
    required this.locked,
    required this.paused,
    required this.formatDuration,
    required this.onDelete,
    required this.onPause,
    required this.onResume,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = brightness == Brightness.light ? _surfaceLight : const Color(0xFF1A1A2E);
    final text = brightness == Brightness.light ? _textDark : Colors.white;
    final control = brightness == Brightness.light ? _controlLight : const Color(0xFF2A2A3E);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: waveform + timer
          SizedBox(
            height: 70,
            child: Row(
              children: [
                Expanded(
                  child: _KoraWaveform(active: !paused),
                ),
                const SizedBox(width: 10),
                Text(
                  formatDuration(duration),
                  style: TextStyle(
                    color: text,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Delete
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: _deleteBg,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, color: _deleteRed, size: 31),
                ),
              ),
              const SizedBox(width: 14),
              // Pause/Resume
              Expanded(
                child: Container(
                  height: 66,
                  decoration: BoxDecoration(
                    color: control,
                    borderRadius: BorderRadius.circular(34),
                  ),
                  child: TextButton.icon(
                    onPressed: paused ? onResume : onPause,
                    icon: Icon(
                      paused ? Icons.play_arrow : Icons.pause,
                      color: text,
                      size: 30,
                    ),
                    label: Text(
                      paused ? 'Resume' : 'Pause',
                      style: TextStyle(color: text, fontSize: 19),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Send
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: _koraPurple,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: onSend,
                  icon: const Icon(Icons.send, color: Colors.white, size: 31),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Waveform visualization ──────────────────────────────────

class _KoraWaveform extends StatefulWidget {
  final bool active;
  const _KoraWaveform({required this.active});

  @override
  State<_KoraWaveform> createState() => _KoraWaveformState();
}

class _KoraWaveformState extends State<_KoraWaveform>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _pulse = Tween(begin: 0.92, end: 1.10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed && widget.active) {
          _controller.forward();
        }
      });
    if (widget.active) _controller.forward();
  }

  @override
  void didUpdateWidget(_KoraWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward();
    } else if (!widget.active && oldWidget.active) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return CustomPaint(
          painter: _WaveformPainter(
            pulseValue: widget.active ? _pulse.value : 1.0,
            active: widget.active,
          ),
          child: const SizedBox(height: 52),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double pulseValue;
  final bool active;

  _WaveformPainter({required this.pulseValue, required this.active});

  static const _pattern = [
    0.25, 0.55, 0.35, 0.80,
    0.42, 0.70, 0.32, 0.90,
    0.50, 0.75, 0.38, 0.62,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 34;
    final gap = size.width / (barCount + 1);
    final center = size.height / 2;
    final paint = Paint()
      ..color = active ? const Color(0xFF6C63FF) : const Color(0xFFD0D0D0)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      final value = _pattern[i % _pattern.length];
      final height = size.height * value * pulseValue;
      final x = gap * (i + 1);

      canvas.drawLine(
        Offset(x, center - height / 2),
        Offset(x, center + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      pulseValue != oldDelegate.pulseValue || active != oldDelegate.active;
}
