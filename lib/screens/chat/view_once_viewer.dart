import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/secure_screen.dart';

/// Full-screen viewer for View Once media.
///
/// WhatsApp parity:
/// - Screenshot blocking (FLAG_SECURE via SecureScreen)
/// - Photo: tap to close, auto-marks as viewed
/// - Video: plays once with 60s countdown, auto-closes when done
/// - No save, no forward, no share
/// - Long-press for info dialog
class ViewOnceViewer extends StatefulWidget {
  final String? mediaPath;
  final String? mediaUrl;
  final bool isVideo;
  final String? thumbnailPath;
  final VoidCallback? onViewed;

  const ViewOnceViewer({
    super.key,
    this.mediaPath,
    this.mediaUrl,
    this.isVideo = false,
    this.thumbnailPath,
    this.onViewed,
  });

  @override
  State<ViewOnceViewer> createState() => _ViewOnceViewerState();
}

class _ViewOnceViewerState extends State<ViewOnceViewer> {
  VideoPlayerController? _videoController;
  bool _isVideoPlaying = false;
  bool _hasViewed = false;
  int _videoCountdown = 60;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initVideoPlayer();
    }
  }

  void _initVideoPlayer() {
    if (widget.mediaPath != null && File(widget.mediaPath!).existsSync()) {
      _videoController = VideoPlayerController.file(File(widget.mediaPath!));
    } else if (widget.mediaUrl != null) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl!));
    }

    _videoController?.initialize().then((_) {
      if (mounted) {
        setState(() {});
        _videoController!.play();
        setState(() => _isVideoPlaying = true);
        _videoController!.setLooping(false);
        _videoController!.seekTo(const Duration(seconds: 0));

        // Start countdown
        _startCountdown();

        _videoController!.addListener(() {
          if (_videoController!.value.position >= _videoController!.value.duration) {
            _markViewedAndClose();
          }
        });
      }
    });
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _isVideoPlaying && !_hasViewed) {
        setState(() => _videoCountdown--);
        if (_videoCountdown <= 0) {
          _markViewedAndClose();
        } else {
          _startCountdown();
        }
      }
    });
  }

  void _markViewedAndClose() {
    if (_hasViewed) return;
    setState(() => _hasViewed = true);
    widget.onViewed?.call();

    // Delete local cached file
    if (widget.mediaPath != null && File(widget.mediaPath!).existsSync()) {
      try {
        File(widget.mediaPath!).deleteSync();
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context, true);
  }

  void _close() {
    if (!_hasViewed) {
      widget.onViewed?.call();
      if (widget.mediaPath != null && File(widget.mediaPath!).existsSync()) {
        try {
          File(widget.mediaPath!).deleteSync();
        } catch (_) {}
      }
    }
    if (mounted) Navigator.pop(context, true);
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.visibility_outlined, color: KoraColors.purple, size: 24),
            const SizedBox(width: 10),
            const Text('View Once', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: const Text(
          'This photo or video will disappear from the chat after you open it.\n\n'
          '• You can\'t forward, save, star, or share it.\n'
          '• Screenshots are blocked for your privacy.\n'
          '• Once viewed, it can\'t be opened again.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Got it', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrap with SecureScreen to block screenshots
    return SecureScreen(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _close,
          onLongPress: _showInfoDialog,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media
              Center(
                child: widget.isVideo ? _buildVideo() : _buildImage(),
              ),
              // Top bar
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.visibility_outlined, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              if (widget.isVideo && _isVideoPlaying)
                                Text('$_videoCountdown',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))
                              else
                                const Text('View once',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _close,
                          child: Container(
                            width: 36, height: 36,
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom hint
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Center(
                      child: Text(
                        'Tap to close \u2022 Screenshots blocked \u2022 Not savable',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (widget.mediaPath != null && File(widget.mediaPath!).existsSync()) {
      return Image.file(File(widget.mediaPath!), fit: BoxFit.contain);
    } else if (widget.mediaUrl != null) {
      return Image.network(widget.mediaUrl!, fit: BoxFit.contain);
    }
    return const Icon(Icons.broken_image, color: Colors.white54, size: 64);
  }

  Widget _buildVideo() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      return Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
          // Progress bar
          Positioned(
            bottom: 80, left: 30, right: 30,
            child: VideoProgressIndicator(
              _videoController!,
              allowScrubbing: false,
              colors: const VideoProgressColors(
                playedColor: KoraColors.purple,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      );
    }

    // Fallback to thumbnail while initializing
    final thumb = widget.thumbnailPath != null && File(widget.thumbnailPath!).existsSync()
        ? Image.file(File(widget.thumbnailPath!), fit: BoxFit.contain)
        : widget.mediaUrl != null
            ? Image.network(widget.mediaUrl!, fit: BoxFit.contain)
            : const Icon(Icons.videocam, color: Colors.white54, size: 64);

    return Stack(
      alignment: Alignment.center,
      children: [
        thumb,
        const CircularProgressIndicator(color: Colors.white),
      ],
    );
  }
}
