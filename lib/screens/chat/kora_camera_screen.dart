import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// WhatsApp-style in-app camera for Kora Messenger.
///
/// Full-screen viewfinder with:
/// - Shutter button: tap for photo, hold to record video
/// - Flash toggle (top right)
/// - Front/back camera switch (top right)
/// - Photo/Video mode switch (swipe or tap)
/// - Captured media goes to MediaEditorScreen for editing before sending
class KoraCameraScreen extends StatefulWidget {
  const KoraCameraScreen({super.key});

  @override
  State<KoraCameraScreen> createState() => _KoraCameraScreenState();
}

enum _CameraMode { photo, video }

class _KoraCameraScreenState extends State<KoraCameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCamera = 0;
  _CameraMode _mode = _CameraMode.photo;
  bool _isFlashOn = false;
  bool _isRecording = false;
  bool _isInitializing = true;
  double _recordProgress = 0.0;
  DateTime? _recordStart;

  static const _maxVideoDuration = Duration(seconds: 180);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  void _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _selectedCamera = _cameras.indexWhere(
            (c) => c.lensDirection == CameraLensDirection.back);
        if (_selectedCamera < 0) _selectedCamera = 0;
        await _setupController(_selectedCamera);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _setupController(int cameraIndex) async {
    if (_cameras.isEmpty) return;
    final desc = _cameras[cameraIndex];
    _controller = CameraController(
      desc,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    if (_isFlashOn && _mode == _CameraMode.photo) {
      await _controller!.setFlashMode(FlashMode.torch);
    } else {
      await _controller!.setFlashMode(FlashMode.off);
    }
    if (mounted) setState(() {});
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCamera = (_selectedCamera + 1) % _cameras.length;
    await _controller?.dispose();
    await _setupController(_selectedCamera);
  }

  void _toggleFlash() async {
    _isFlashOn = !_isFlashOn;
    if (_controller != null) {
      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
    }
    setState(() {});
  }

  void _switchMode(_CameraMode newMode) {
    if (_isRecording) return;
    setState(() => _mode = newMode);
  }

  void _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final XFile file = await _controller!.takePicture();
      if (!mounted) return;
      _finishCapture(file.path, false);
    } catch (e) {
      debugPrint('Take photo error: $e');
    }
  }

  void _startVideoRecording() async {
    if (_controller == null || _isRecording) return;
    try {
      await _controller!.startVideoRecording();
      _recordStart = DateTime.now();
      setState(() {
        _isRecording = true;
        _recordProgress = 0.0;
      });
      _updateProgress();
    } catch (e) {
      debugPrint('Start recording error: $e');
    }
  }

  void _updateProgress() async {
    if (!_isRecording || _recordStart == null) return;
    final elapsed = DateTime.now().difference(_recordStart!);
    final progress = elapsed.inMilliseconds / _maxVideoDuration.inMilliseconds;
    if (mounted) {
      setState(() => _recordProgress = progress.clamp(0.0, 1.0));
    }
    if (elapsed >= _maxVideoDuration) {
      _stopVideoRecording();
      return;
    }
    await Future.delayed(const Duration(milliseconds: 100));
    _updateProgress();
  }

  void _stopVideoRecording() async {
    if (_controller == null || !_isRecording) return;
    try {
      final XFile file = await _controller!.stopVideoRecording();
      _recordStart = null;
      setState(() => _isRecording = false);
      if (!mounted) return;
      _finishCapture(file.path, true);
    } catch (e) {
      debugPrint('Stop recording error: $e');
      setState(() => _isRecording = false);
    }
  }

  void _finishCapture(String filePath, bool isVideo) {
    Navigator.pop(context, {
      'path': filePath,
      'isVideo': isVideo,
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupController(_selectedCamera);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: KoraColors.purple),
        ),
      );
    }

    final scale = _controller!.value.aspectRatio;
    final aspect = scale < 1 ? scale : 1 / scale;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: aspect,
              child: CameraPreview(_controller!),
            ),
          ),

          // Top controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _topButton(Icons.close, () => Navigator.pop(context)),
                    if (_isRecording)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_manual_record,
                                  color: KoraColors.red, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${(_recordProgress * 180).toInt() ~/ 60}:${((_recordProgress * 180).toInt() % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ]),
                      ),
                    Row(children: [
                      if (!_isRecording) ...[
                        _topButton(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          _toggleFlash,
                        ),
                        const SizedBox(width: 8),
                      ],
                      _topButton(Icons.cameraswitch_outlined, _switchCamera),
                    ]),
                  ],
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.only(bottom: 24, top: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isRecording)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _modeTab('Photo', _CameraMode.photo),
                            const SizedBox(width: 32),
                            _modeTab('Video', _CameraMode.video),
                          ],
                        ),
                      ),
                    Center(
                      child: GestureDetector(
                        onTap: _mode == _CameraMode.photo ? _takePhoto : null,
                        onLongPressStart: _mode == _CameraMode.video
                            ? (_) => _startVideoRecording()
                            : null,
                        onLongPressEnd: _mode == _CameraMode.video
                            ? (_) => _stopVideoRecording()
                            : null,
                        child: _shutterButton(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _modeTab(String label, _CameraMode mode) {
    final isActive = _mode == mode;
    return GestureDetector(
      onTap: () => _switchMode(mode),
      child: Text(
        label,
        style: TextStyle(
          color: isActive
              ? KoraColors.purple
              : Colors.white.withValues(alpha: 0.5),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _shutterButton() {
    if (_mode == _CameraMode.video && _isRecording) {
      return SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                value: _recordProgress,
                strokeWidth: 4,
                color: KoraColors.red,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: KoraColors.red,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _mode == _CameraMode.video ? KoraColors.red : Colors.white,
        ),
      ),
    );
  }
}
