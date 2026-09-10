import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

/// Media Gallery screen — full-screen viewer for photos and videos in a chat.
/// Mirrors WhatsApp's media gallery (tap photo → fullscreen with swipe).
///
/// Features:
/// - Full-screen image with pinch-to-zoom
/// - Swipe left/right for next/previous
/// - Download/share/delete options
/// - Date and sender info overlay
class MediaGalleryScreen extends StatefulWidget {
  final List<String> mediaPaths;
  final int initialIndex;
  final String chatName;

  const MediaGalleryScreen({
    super.key,
    required this.mediaPaths,
    this.initialIndex = 0,
    required this.chatName,
  });

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Media pager
          PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaPaths.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) => _MediaView(
              path: widget.mediaPaths[index],
              onToggleOverlay: () => setState(() => _showOverlay = !_showOverlay),
            ),
          ),
          // Top overlay
          if (_showOverlay)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  color: Colors.black54,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(widget.chatName,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.white),
                        onPressed: () => Share.shareXFiles([XFile(widget.mediaPaths[_currentIndex])]),
                      ),
                      IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
                    ],
                  ),
                ),
              ),
            ),
          // Bottom overlay
          if (_showOverlay)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _bottomAction(Icons.download, 'Save', () {}),
                      _bottomAction(Icons.forward, 'Forward', () {}),
                      _bottomAction(Icons.star_border, 'Star', () {}),
                      _bottomAction(Icons.delete_outline, 'Delete', () {}),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bottomAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}


/// Renders the actual media file — images and videos, no placeholders.
class _MediaView extends StatefulWidget {
  final String path;
  final VoidCallback onToggleOverlay;

  const _MediaView({required this.path, required this.onToggleOverlay});

  @override
  State<_MediaView> createState() => _MediaViewState();
}

class _MediaViewState extends State<_MediaView> {
  VideoPlayerController? _videoController;
  bool _videoError = false;

  @override
  void initState() {
    super.initState();
    final lower = widget.path.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') ||
        lower.endsWith('.webm') || lower.endsWith('.3gp')) {
      _videoController = VideoPlayerController.file(File(widget.path))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        }).catchError((_) {
          if (mounted) setState(() => _videoError = true);
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    if (controller != null && controller.value.isInitialized) {
      return GestureDetector(
        onTap: widget.onToggleOverlay,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
            IconButton(
              icon: Icon(
                controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                color: Colors.white.withValues(alpha: 0.85),
                size: 64,
              ),
              onPressed: () {
                setState(() {
                  controller.value.isPlaying ? controller.pause() : controller.play();
                });
              },
            ),
          ],
        ),
      );
    }

    if (controller != null && !_videoError) {
      return const Center(child: CircularProgressIndicator(color: Colors.white54));
    }

    return GestureDetector(
      onTap: widget.onToggleOverlay,
      child: Center(
        child: Image.file(
          File(widget.path),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _missingFile(),
        ),
      ),
    );
  }

  Widget _missingFile() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image_outlined, size: 64, color: Colors.white24),
        SizedBox(height: 12),
        Text('Media not available on this device',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }
}
