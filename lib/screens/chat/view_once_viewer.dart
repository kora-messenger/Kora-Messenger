import 'dart:io';
import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Full-screen viewer for view-once media.
/// Shows photo or video on a black background.
/// Tap anywhere to close. On close, signals that the media was viewed.
class ViewOnceViewer extends StatefulWidget {
  final String? mediaPath;
  final String? mediaUrl;
  final bool isVideo;
  final String? thumbnailPath;

  const ViewOnceViewer({
    super.key,
    this.mediaPath,
    this.mediaUrl,
    this.isVideo = false,
    this.thumbnailPath,
  });

  @override
  State<ViewOnceViewer> createState() => _ViewOnceViewerState();
}

class _ViewOnceViewerState extends State<ViewOnceViewer> {
  bool _isVideoPlaying = false;

  void _close() {
    Navigator.pop(context, true); // true = was viewed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _close,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media content
            Center(
              child: widget.isVideo ? _buildVideo() : _buildImage(),
            ),
            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_outlined, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('View once',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _close,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
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
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Center(
                    child: Text(
                      'Tap to close - This media will disappear',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
    // Show thumbnail with play button; video plays via system player
    // (video_player package not yet added to avoid pubspec changes)
    final thumb = widget.thumbnailPath != null && File(widget.thumbnailPath!).existsSync()
        ? Image.file(File(widget.thumbnailPath!), fit: BoxFit.contain)
        : widget.mediaUrl != null
            ? Image.network(widget.mediaUrl!, fit: BoxFit.contain)
            : const Icon(Icons.videocam, color: Colors.white54, size: 64);

    return Stack(
      alignment: Alignment.center,
      children: [
        thumb,
        if (!_isVideoPlaying)
          GestureDetector(
            onTap: () => setState(() => _isVideoPlaying = true),
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
            ),
          ),
        if (_isVideoPlaying)
          const CircularProgressIndicator(color: Colors.white),
      ],
    );
  }
}
