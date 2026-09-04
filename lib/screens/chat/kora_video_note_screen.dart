import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/kora_colors.dart';

/// Bridges the ORIGINAL press-and-hold gesture on the composer's camera
/// icon into this screen. WhatsApp's recording is tied to the hold:
/// - HOLD → recording starts
/// - SLIDE LEFT → cancel (slide to cancel)
/// - SLIDE UP → lock into hands-free
/// - RELEASE → sends immediately (no preview step)
///
/// The composer creates one of these on long-press-start and forwards
/// move/end events; this screen registers listeners in initState.
class VideoNoteGesture {
  /// dy < 0 = sliding up, dx < 0 = sliding left
  void Function(double dx, double dy)? onDragUpdate;
  void Function()? onFingerReleased;
}

/// WhatsApp-style "Video Note" recorder — a circular video message.
///
/// Flow (verified against WhatsApp Business APK):
/// 1. User HOLDs the camera icon in the chat composer → this screen
///    opens and recording starts immediately (tied to the hold).
/// 2. While holding: SLIDE LEFT to cancel, SLIDE UP to lock.
/// 3. RELEASE finger → SENDS instantly (no preview/review step).
/// 4. If locked: finger lifts, hands-free recording continues. Tap
///    Send to send, Trash to cancel.
/// 5. Max 60 seconds. Auto-sends at 60s.
///
/// Returns `{'path': String, 'duration': int}` via Navigator.pop, or
/// null if cancelled/discarded.
class KoraVideoNoteScreen extends StatefulWidget {
  final VideoNoteGesture? gesture;
  const KoraVideoNoteScreen({super.key, this.gesture});

  @override
  State<KoraVideoNoteScreen> createState() => _KoraVideoNoteScreenState();
}

enum _NoteState { idle, recording, locked }

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
  bool _dragCancelling = false;
  double _dragDx = 0;
  double _dragDy = 0;

  static const _maxSeconds = 60;
  static const _lockThreshold = -60.0;
  static const _cancelThreshold = -80.0;

  @override
  void initState() {
    super.initState();
    _initCameras();
    // Wire the gesture bridge from the original composer press.
    widget.gesture?.onDragUpdate = (dx, dy) {
      _dragDx = dx;
      _dragDy = dy;
      if (!mounted) return;

      // Slide UP to lock
      if (_dragDy < _lockThreshold && !_dragLocking) {
        setState(() {
          _dragLocking = true;
          _dragCancelling = false;
          if (_state == _NoteState.recording) _state = _NoteState.locked;
        });
      }

      // Slide LEFT to cancel (only while actively recording, not locked)
      if (_dragDx < _cancelThreshold &&
          !_dragCancelling &&
          _state == _NoteState.recording) {
        setState(() => _dragCancelling = true);
      }
      // Sliding back right un-cancels
      if (_dragDx > _cancelThreshold && _dragCancelling) {
        setState(() => _dragCancelling = false);
      }
    };

    // RELEASE finger → send (unless locked, in which case do nothing —
    // the user is now in hands-free mode and taps Send/Trash instead).
    widget.gesture?.onFingerReleased = () {
      if (!mounted) return;
      if (_state == _NoteState.recording && _dragCancelling) {
        _cancelRecording();
      } else if (_state == _NoteState.recording) {
        _stopAndSend();
      }
      // If locked, finger release does nothing — hands-free continues.
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
      // Recording starts the instant the camera is ready — the hold
      // gesture on the composer's camera icon IS the trigger.
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
      if (elapsed >= _maxSeconds) _stopAndSend();
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

  /// Stop recording and SEND immediately. This is what happens on:
  /// - Finger release (while recording, not locked)
  /// - Tap Send (while locked)
  /// - Auto-send at 60s
  Future<void> _stopAndSend() async {
    if (_state != _NoteState.recording && _state != _NoteState.locked) return;
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
      if (mounted) Navigator.pop(context);
      return;
    }
    if (mounted && _recordedPath != null) {
      Navigator.pop(context, {'path': _recordedPath, 'duration': _seconds});
    }
  }

  /// Cancel recording and discard. This is what happens on:
  /// - Slide left past threshold + release
  /// - Tap Trash (while locked)
  Future<void> _cancelRecording() async {
    if (_state != _NoteState.recording && _state != _NoteState.locked) return;
    _timer?.cancel();
    try {
      final file = await _controller!.stopVideoRecording();
      await File(file.path).delete().catchError((_) => File(file.path));
    } catch (e) {
      debugPrint('Video note cancel error: $e');
    }
    _recordedPath = null;
    if (mounted) Navigator.pop(context);
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
    final isRecording =
        _state == _NoteState.recording || _state == _NoteState.locked;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: SafeArea(
        child: Stack(
          children: [
            // Close button (only visible when not actively recording,
            // or when locked — user can exit after locking)
            if (!isRecording || _state == _NoteState.locked)
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 28),
                  onPressed: () {
                    if (_state == _NoteState.locked) {
                      _cancelRecording();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            // Timer badge
            if (isRecording)
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _timeLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                  ),
                ),
              ),
            // Circular camera preview + progress ring
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
                        value: isRecording ? progress : 0,
                        strokeWidth: 4,
                        backgroundColor: Colors.transparent,
                        valueColor:
                            const AlwaysStoppedAnimation(Colors.white),
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
                                  child: CircularProgressIndicator(
                                      color: KoraColors.purple),
                                ),
                              )
                            : Transform.scale(
                                scaleX: _cameras.isNotEmpty &&
                                        _cameras[_selectedCamera].lensDirection ==
                                            CameraLensDirection.front
                                    ? -1
                                    : 1,
                                child: CameraPreview(_controller!),
                              ),
                      ),
                    ),
                    // Cancel overlay — fades in as user slides left
                    if (_dragCancelling)
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withValues(alpha: 0.5),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                color: Colors.white, size: 48),
                            SizedBox(height: 8),
                            Text('Slide to cancel',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Lock hint — "Slide up to lock recording" (only while recording,
            // not locked, and not currently dragging to cancel)
            if (_state == _NoteState.recording && !_dragCancelling)
              Positioned(
                bottom: 200,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _dragLocking ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: const Column(
                      children: [
                        Icon(Icons.keyboard_arrow_up_rounded,
                            color: Colors.white70),
                        Text('Slide up to lock recording',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            // Cancel hint — "Slide to cancel" (shows while recording)
            if (_state == _NoteState.recording && !_dragLocking)
              Positioned(
                bottom: 120,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _dragCancelling ? 1 : 0.5,
                    duration: const Duration(milliseconds: 150),
                    child: const Column(
                      children: [
                        Icon(Icons.keyboard_arrow_left_rounded,
                            color: Colors.white70),
                        Text('Slide to cancel',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            // Lock badge — padlock appears once locked
            if (_state == _NoteState.locked)
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: Color(0xFF0A0A14), size: 18),
                ),
              ),
            // Bottom controls
            // While RECORDING (not locked): NO on-screen buttons — the
            // hold gesture controls everything:
            //   release = send, slide left = cancel, slide up = lock.
            //
            // While LOCKED: show Trash (cancel) + Send buttons.
            if (_state == _NoteState.locked)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _circleButton(
                      icon: Icons.delete_outline_rounded,
                      onTap: _cancelRecording,
                      enabled: true,
                      bg: Colors.white.withValues(alpha: 0.08),
                    ),
                    _circleButton(
                      icon: Icons.send_rounded,
                      onTap: _stopAndSend,
                      enabled: true,
                      bg: Colors.white,
                      iconColor: const Color(0xFF0A0A14),
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
