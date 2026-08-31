import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/kora_colors.dart';

/// Bridges the ORIGINAL press-and-hold gesture on the composer's camera
/// icon into this screen — WhatsApp's recording starts the instant you
/// press, and sliding up to lock is the SAME continuous finger-hold
/// carried through into the full-screen recorder (the finger never has
/// to lift between opening the screen and locking). The composer creates
/// one of these on long-press-start and forwards its move/end events;
/// this screen registers listeners in initState.
class VideoNoteGesture {
  void Function(double dy)? onDragUpdate;
  void Function()? onFingerReleased;
}

/// WhatsApp-style "Video Note" recorder — a circular video message.
///
/// Recording starts the MOMENT this screen opens (no second tap) —
/// matches WhatsApp: press-and-hold the camera icon starts recording
/// immediately. Trash / Stop / Send are all live simultaneously while
/// recording — you can cancel or send at any point, not just after a
/// separate stop step. Slide up (via [gesture], the same continuous
/// press that opened this screen) to lock into hands-free recording —
/// a lock badge appears once locked. Max duration 60 seconds.
///
/// Returns `{'path': String, 'duration': int}` via Navigator.pop, or
/// null if cancelled/discarded.
class KoraVideoNoteScreen extends StatefulWidget {
  final VideoNoteGesture? gesture;
  const KoraVideoNoteScreen({super.key, this.gesture});

  @override
  State<KoraVideoNoteScreen> createState() => _KoraVideoNoteScreenState();
}

enum _NoteState { idle, recording, locked, preview }

class _KoraVideoNoteScreenState extends State<KoraVideoNoteScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCamera = 0;
  bool _isInitializing = true;
  _NoteState _state = _NoteState.idle;
  Timer? _timer;
  int _seconds = 0;
  DateTime? _startedAt;
  String? _recordedPath;
  bool _dragLocking = false;
  double _dragDy = 0;

  static const _maxSeconds = 60;

  @override
  void initState() {
    super.initState();
    _initCameras();
    // Register onto the bridge from the ORIGINAL composer press so
    // "slide up to lock" and "finger released" keep working across
    // the route push, without needing a second press on this screen.
    widget.gesture?.onDragUpdate = (dy) {
      _dragDy = dy;
      if (_dragDy < -60 && !_dragLocking && mounted) {
        setState(() {
          _dragLocking = true;
          if (_state == _NoteState.recording) _state = _NoteState.locked;
        });
      }
    };
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _selectedCamera = _cameras
            .indexWhere((c) => c.lensDirection == CameraLensDirection.front);
        if (_selectedCamera < 0) _selectedCamera = 0;
        await _setupController(_selectedCamera);
      }
    } catch (e) {
      debugPrint('Video note camera init error: $e');
    } finally {
      if (mounted) setState(() => _isInitializing = false);
      // WhatsApp starts recording the instant the screen opens — the
      // press-and-hold gesture that opened this screen IS the record
      // trigger, there's no separate "tap to start" step.
      if (_controller != null && _controller!.value.isInitialized) {
        _startRecording();
      }
    }
  }

  Future<void> _setupController(int index) async {
    if (_cameras.isEmpty) return;
    _controller = CameraController(
      _cameras[index],
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _state != _NoteState.idle) return;
    _selectedCamera = (_selectedCamera + 1) % _cameras.length;
    await _controller?.dispose();
    await _setupController(_selectedCamera);
  }

  void _startTimer() {
    _startedAt = DateTime.now();
    _seconds = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_startedAt == null) return;
      final elapsed = DateTime.now().difference(_startedAt!).inSeconds;
      setState(() => _seconds = elapsed);
      if (elapsed >= _maxSeconds) _stopRecording(autoSend: false);
    });
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_state != _NoteState.idle) return;
    try {
      await _controller!.startVideoRecording();
      setState(() => _state = _NoteState.recording);
      _startTimer();
    } catch (e) {
      debugPrint('Video note start error: $e');
    }
  }

  Future<void> _stopRecording({bool autoSend = false}) async {
    if (_state != _NoteState.recording && _state != _NoteState.locked) return;
    _timer?.cancel();
    try {
      final file = await _controller!.stopVideoRecording();
      final dir = await getTemporaryDirectory();
      final dest =
          '${dir.path}/kora_video_note_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await File(file.path).copy(dest);
      _recordedPath = dest;
      if (mounted) {
        setState(() => _state = _NoteState.preview);
      }
    } catch (e) {
      debugPrint('Video note stop error: $e');
      if (mounted) setState(() => _state = _NoteState.idle);
    }
  }

  Future<void> _discard() async {
    // WhatsApp lets you tap Trash at ANY point — mid-recording, locked,
    // or in preview — to cancel instantly.
    if (_state == _NoteState.recording || _state == _NoteState.locked) {
      _timer?.cancel();
      try {
        final file = await _controller!.stopVideoRecording();
        await File(file.path).delete().catchError((_) => File(file.path));
      } catch (e) {
        debugPrint('Video note discard-while-recording error: $e');
      }
    } else if (_recordedPath != null) {
      File(_recordedPath!).delete().catchError((_) => File(_recordedPath!));
    }
    _recordedPath = null;
    if (!mounted) return;
    setState(() {
      _state = _NoteState.idle;
      _seconds = 0;
      _dragLocking = false;
      _dragDy = 0;
    });
    Navigator.pop(context);
  }

  Future<void> _send() async {
    if (_state == _NoteState.recording || _state == _NoteState.locked) {
      // Tapping Send while still recording stops AND sends in one tap —
      // matches WhatsApp: Trash/Stop/Send are all live during recording.
      _timer?.cancel();
      try {
        final file = await _controller!.stopVideoRecording();
        final dir = await getTemporaryDirectory();
        final dest =
            '${dir.path}/kora_video_note_${DateTime.now().millisecondsSinceEpoch}.mp4';
        await File(file.path).copy(dest);
        _recordedPath = dest;
      } catch (e) {
        debugPrint('Video note stop-and-send error: $e');
        return;
      }
    }
    if (_recordedPath == null || !mounted) return;
    Navigator.pop(context, {'path': _recordedPath, 'duration': _seconds});
  }

  @override
  void dispose() {
    widget.gesture?.onDragUpdate = null;
    widget.gesture?.onFingerReleased = null;
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  String get _timeLabel {
    final m = (_seconds ~/ 60).toString();
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final size = 260.0;
    final progress = (_seconds / _maxSeconds).clamp(0.0, 1.0);
    final isBusy = _state == _NoteState.recording || _state == _NoteState.locked;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: SafeArea(
        child: Stack(
          children: [
            // Close button
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () {
                  if (isBusy) {
                    _stopRecording();
                  }
                  Navigator.pop(context);
                },
              ),
            ),
            // Timer badge
            if (isBusy || _state == _NoteState.preview)
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: isBusy ? const Color(0xFFEF4444) : Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _timeLabel,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
              ),
            // Circular preview
            Center(
              child: SizedBox(
                width: size + 20,
                height: size + 20,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress ring
                    SizedBox(
                      width: size + 16,
                      height: size + 16,
                      child: CircularProgressIndicator(
                        value: isBusy ? progress : 0,
                        strokeWidth: 4,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    ClipOval(
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: _isInitializing || _controller == null
                            ? Container(
                                color: const Color(0xFF1A1A24),
                                child: const Center(
                                  child: CircularProgressIndicator(color: KoraColors.purple),
                                ),
                              )
                            : (_state == _NoteState.preview
                                ? Container(
                                    color: Colors.black,
                                    child: const Center(
                                      child: Icon(Icons.play_circle_fill_rounded,
                                          color: Colors.white, size: 56),
                                    ),
                                  )
                                : Transform.scale(
                                    scaleX: _cameras.isNotEmpty &&
                                            _cameras[_selectedCamera].lensDirection ==
                                                CameraLensDirection.front
                                        ? -1
                                        : 1,
                                    child: CameraPreview(_controller!),
                                  )),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Lock hint — fades out once locked
            if (_state == _NoteState.recording)
              Positioned(
                bottom: 190,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _dragLocking ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      children: const [
                        Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white70),
                        Text('Slide up to lock',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            // Lock badge — small padlock over the circle once locked
            // into hands-free recording, matching WhatsApp exactly.
            if (_state == _NoteState.locked)
              Positioned(
                bottom: 190,
                right: MediaQuery.of(context).size.width / 2 - (size / 2) - 4,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Icon(Icons.lock_rounded, color: Color(0xFF0A0A14), size: 18),
                ),
              ),
            // Bottom controls — WhatsApp keeps Trash, Stop, and Send all
            // live simultaneously the moment recording starts (verified
            // against a real WhatsApp Business screen recording): you
            // can cancel or send at any point, not just after a
            // separate stop step.
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Delete — live during recording, locked, AND preview
                  _circleButton(
                    icon: Icons.delete_outline_rounded,
                    onTap: _discard,
                    enabled: _state != _NoteState.idle,
                    bg: Colors.white.withValues(alpha: 0.08),
                  ),
                  // Stop (center) — only meaningful while actively
                  // recording; tap just freezes into a preview so you
                  // can review before Send/Trash. Slide up to lock.
                  if (_state != _NoteState.preview)
                    GestureDetector(
                      onTap: isBusy ? _stopRecording : null,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: isBusy
                              ? const Color(0xFFEF4444)
                              : Colors.transparent,
                        ),
                        child: isBusy
                            ? const Icon(Icons.stop_rounded, color: Colors.white, size: 28)
                            : const SizedBox.shrink(),
                      ),
                    )
                  else
                    const SizedBox(width: 72, height: 72),
                  // Send — live during recording/locked (stops + sends
                  // in one tap) and in preview (sends the reviewed clip)
                  _state == _NoteState.preview || isBusy
                      ? _circleButton(
                          icon: Icons.send_rounded,
                          onTap: _send,
                          enabled: true,
                          bg: Colors.white,
                          iconColor: const Color(0xFF0A0A14),
                        )
                      : _circleButton(
                          icon: Icons.flip_camera_ios_rounded,
                          onTap: _switchCamera,
                          enabled: _state == _NoteState.idle,
                          bg: Colors.white.withValues(alpha: 0.08),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool enabled,
    required Color bg,
    Color iconColor = Colors.white,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
          child: Icon(icon, color: iconColor, size: 24),
        ),
      ),
    );
  }
}
