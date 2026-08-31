import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/kora_colors.dart';

/// WhatsApp-style "Video Note" recorder — a circular video message.
///
/// Front camera by default. Press-and-hold the record button to capture
/// (or tap once to start/stop — both are supported here since Flutter's
/// long-press-drag doesn't map perfectly to the raw pointer gestures
/// used by the voice recorder). Swipe the record button up to lock into
/// hands-free recording. Max duration 60 seconds, matching WhatsApp.
///
/// Returns `{'path': String, 'duration': int}` via Navigator.pop, or
/// null if cancelled/discarded.
class KoraVideoNoteScreen extends StatefulWidget {
  const KoraVideoNoteScreen({super.key});

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

  void _discard() {
    if (_recordedPath != null) {
      File(_recordedPath!).delete().catchError((_) => File(_recordedPath!));
    }
    _recordedPath = null;
    setState(() {
      _state = _NoteState.idle;
      _seconds = 0;
      _dragLocking = false;
      _dragDy = 0;
    });
  }

  void _send() {
    if (_recordedPath == null) return;
    Navigator.pop(context, {'path': _recordedPath, 'duration': _seconds});
  }

  @override
  void dispose() {
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
            // Lock hint
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
            // Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Delete
                  _circleButton(
                    icon: Icons.delete_outline_rounded,
                    onTap: _state == _NoteState.preview
                        ? _discard
                        : (isBusy ? null : null),
                    enabled: _state == _NoteState.preview,
                    bg: Colors.white.withValues(alpha: 0.08),
                  ),
                  // Record / stop
                  if (_state != _NoteState.preview)
                    GestureDetector(
                      onLongPressStart: (_) => _startRecording(),
                      onLongPressMoveUpdate: (d) {
                        _dragDy = d.offsetFromOrigin.dy;
                        if (_dragDy < -60 && !_dragLocking) {
                          setState(() {
                            _dragLocking = true;
                            _state = _NoteState.locked;
                          });
                        }
                      },
                      onLongPressEnd: (_) {
                        if (!_dragLocking) _stopRecording();
                      },
                      onTap: () {
                        if (_state == _NoteState.idle) {
                          _startRecording();
                        } else if (isBusy) {
                          _stopRecording();
                        }
                      },
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
                            : Center(
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                      ),
                    )
                  else
                    const SizedBox(width: 72, height: 72),
                  // Send / flip camera
                  _state == _NoteState.preview
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
