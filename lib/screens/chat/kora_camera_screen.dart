import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/kora_api.dart';
import '../../theme/kora_colors.dart';

/// WhatsApp 2026-style in-app camera for Kora Messenger.
///
/// Full-screen viewfinder with:
/// - Shutter button: tap for photo, hold to record video (progress ring)
/// - Flash toggle (auto / on / off / torch)
/// - Front/back camera switch
/// - Photo/Video mode tabs (swipe or tap)
/// - Pinch-to-zoom and 0.5x / 1x / 2x quick zoom buttons
/// - Gallery thumbnail (bottom-left) to pick from gallery
/// - Recording timer with red dot
/// - Max video duration: 3 minutes
/// - Captured media goes to MediaEditorScreen for editing before sending
class KoraCameraScreen extends StatefulWidget {
  const KoraCameraScreen({super.key});

  @override
  State<KoraCameraScreen> createState() => _KoraCameraScreenState();
}

enum _CameraMode { photo, video }

enum _FlashMode { off, auto, on, torch }

class _KoraCameraScreenState extends State<KoraCameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCamera = 0;
  _CameraMode _mode = _CameraMode.photo;
  _FlashMode _flashMode = _FlashMode.off;
  bool _isRecording = false;
  bool _isInitializing = true;
  double _recordProgress = 0.0;
  DateTime? _recordStart;
  double _currentZoom = 1.0;
  double _maxZoom = 1.0;
  double _minZoom = 1.0;
  String? _galleryThumbnail;

  static const _maxVideoDuration = Duration(seconds: 180);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
    _loadGalleryThumbnail();
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

  void _loadGalleryThumbnail() async {
    try {
      final picker = ImagePicker();
      final media = await picker.pickImage(source: ImageSource.gallery, imageQuality: 30);
      if (mounted && media != null) {
        setState(() => _galleryThumbnail = media.path);
      }
    } catch (_) {}
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

    try {
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
    } catch (_) {
      _minZoom = 1.0;
      _maxZoom = 1.0;
    }

    await _applyFlashMode();
    if (mounted) setState(() {});
  }

  Future<void> _applyFlashMode() async {
    if (_controller == null) return;
    switch (_flashMode) {
      case _FlashMode.off:
        await _controller!.setFlashMode(FlashMode.off);
        break;
      case _FlashMode.auto:
        await _controller!.setFlashMode(FlashMode.auto);
        break;
      case _FlashMode.on:
        await _controller!.setFlashMode(FlashMode.always);
        break;
      case _FlashMode.torch:
        await _controller!.setFlashMode(FlashMode.torch);
        break;
    }
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCamera = (_selectedCamera + 1) % _cameras.length;
    await _controller?.dispose();
    await _setupController(_selectedCamera);
  }

  void _cycleFlashMode() async {
    _flashMode = _flashMode == _FlashMode.off
        ? _FlashMode.auto
        : _flashMode == _FlashMode.auto
            ? _FlashMode.on
            : _flashMode == _FlashMode.on
                ? _FlashMode.torch
                : _FlashMode.off;
    await _applyFlashMode();
    setState(() {});
  }

  void _switchMode(_CameraMode newMode) {
    if (_isRecording) return;
    setState(() => _mode = newMode);
  }

  void _setZoom(double zoom) async {
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    _currentZoom = clamped;
    try {
      await _controller!.setZoomLevel(clamped);
    } catch (_) {}
    if (mounted) setState(() {});
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

  void _pickFromGallery() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (photo != null && mounted) {
      _finishCapture(photo.path, false);
      return;
    }
    if (!mounted) return;
    final video = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 180));
    if (video != null && mounted) {
      _finishCapture(video.path, true);
    }
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

  IconData _flashIcon() {
    switch (_flashMode) {
      case _FlashMode.off:
        return Icons.flash_off;
      case _FlashMode.auto:
        return Icons.flash_auto;
      case _FlashMode.on:
        return Icons.flash_on;
      case _FlashMode.torch:
        return Icons.flashlight_on;
    }
  }

  String _recordTimeString() {
    final seconds = (_recordProgress * 180).toInt();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
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
          // Camera preview with pinch-to-zoom
          GestureDetector(
            onScaleStart: (_) {},
            onScaleUpdate: (details) {
              final newZoom = _currentZoom * details.scale;
              _setZoom(newZoom);
            },
            child: Center(
              child: AspectRatio(
                aspectRatio: aspect,
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // Top gradient overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _topButton(Icons.close, () => Navigator.pop(context)),
                    if (_isRecording)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _recordTimeString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        if (!_isRecording) ...[
                          _topButton(_flashIcon(), _cycleFlashMode),
                          const SizedBox(width: 8),
                        ],
                        if (!_isRecording) _topButton(Icons.cameraswitch_outlined, _switchCamera),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Zoom quick buttons (right side)
          if (!_isRecording)
            Positioned(
              bottom: 140,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _zoomButton('0.5x', 0.5, _currentZoom == 0.5),
                  const SizedBox(height: 8),
                  _zoomButton('1x', 1.0, _currentZoom == 1.0 && _currentZoom != 0.5),
                  if (_maxZoom >= 2.0) ...[
                    const SizedBox(height: 8),
                    _zoomButton('2x', 2.0, _currentZoom == 2.0),
                  ],
                ],
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
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isRecording)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _modeTab('Photo', _CameraMode.photo),
                            const SizedBox(width: 32),
                            _modeTab('Video', _CameraMode.video),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          // Gallery thumbnail (bottom-left)
                          GestureDetector(
                            onTap: _pickFromGallery,
                            child: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white38, width: 2),
                                image: _galleryThumbnail != null
                                    ? DecorationImage(
                                        image: FileImage(File(_galleryThumbnail!)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: Colors.white12,
                              ),
                              child: _galleryThumbnail == null
                                  ? const Icon(Icons.photo_outlined, color: Colors.white54, size: 22)
                                  : null,
                            ),
                          ),
                          const Spacer(),
                          // Shutter button
                          GestureDetector(
                            onTap: _mode == _CameraMode.photo ? _takePhoto : null,
                            onLongPressStart: _mode == _CameraMode.video
                                ? (_) => _startVideoRecording()
                                : null,
                            onLongPressEnd: _mode == _CameraMode.video
                                ? (_) => _stopVideoRecording()
                                : null,
                            child: _shutterButton(),
                          ),
                          const Spacer(),
                          // Right placeholder for symmetry
                          const SizedBox(width: 48, height: 48),
                        ],
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
        width: 40, height: 40,
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _zoomButton(String label, double zoom, bool isActive) {
    return GestureDetector(
      onTap: () => _setZoom(zoom),
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: isActive ? KoraColors.purple : Colors.black38,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
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
          color: isActive ? Colors.white : Colors.white54,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _shutterButton() {
    if (_isRecording) {
      return SizedBox(
        width: 72, height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 72, height: 72,
              child: CircularProgressIndicator(
                value: _recordProgress,
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(KoraColors.purple),
                backgroundColor: Colors.white24,
              ),
            ),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _mode == _CameraMode.video ? Colors.red : Colors.white,
          width: 4,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _mode == _CameraMode.video ? Colors.red : Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// Face & Hands Effects privacy notice — shown briefly on first camera open.
  Widget _buildEffectsPrivacyBadge(BuildContext context) {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () async {
            final uri = Uri.parse(KoraApi.faceHandsEffectsUrl);
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Face & hand effects are processed on-device only. Learn more →',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }
}
