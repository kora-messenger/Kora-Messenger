import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/message_model.dart';
import '../../models/chat_models.dart';

/// Kora's video note bubble — matches WhatsApp's real Video Notes
/// behavior exactly (verified against WhatsApp's own FAQ + docs):
///
/// - **In the chat feed**: autoplays MUTED, looping 3 times, the moment
///   it appears — no tap needed. After the 3rd loop it freezes on the
///   first frame as a static circular thumbnail with a play icon.
/// - **Tap**: opens a larger circular view in a dimmed lightbox overlay
///   and plays WITH SOUND once. Shows a small ✕ to close (tap ✕ or tap
///   the dimmed backdrop) and a live elapsed-time counter at the bottom
///   that counts UP while playing.
/// - Timestamp + read receipts sit tucked at the bottom-right EDGE of
///   the circle (overlapping it), not a separate row underneath.
/// - No download/forward affordance is built into this widget — video
///   notes are deliberately ephemeral, same restriction WhatsApp
///   applies (Forward is already hidden for this type in the message
///   action menu).
class VideoNoteBubble extends StatefulWidget {
  final KoraMessage message;

  const VideoNoteBubble({super.key, required this.message});

  @override
  State<VideoNoteBubble> createState() => _VideoNoteBubbleState();
}

class _VideoNoteBubbleState extends State<VideoNoteBubble> {
  VideoPlayerController? _previewController;
  int _loopCount = 0;
  bool _previewDone = false;
  bool _previewFailed = false;

  @override
  void initState() {
    super.initState();
    _startMutedPreview();
  }

  Future<void> _startMutedPreview() async {
    final path = widget.message.mediaPath;
    if (path == null || !File(path).existsSync()) {
      if (mounted) setState(() => _previewFailed = true);
      return;
    }
    try {
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(false);
      controller.addListener(_onPreviewTick);
      await controller.play();
      if (mounted) {
        setState(() => _previewController = controller);
      } else {
        controller.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => _previewFailed = true);
    }
  }

  void _onPreviewTick() {
    final c = _previewController;
    if (c == null || _previewDone) return;
    final v = c.value;
    if (v.duration > Duration.zero && v.position >= v.duration) {
      _loopCount++;
      if (_loopCount >= 3) {
        _previewDone = true;
        c.pause();
        c.seekTo(Duration.zero);
        if (mounted) setState(() {});
      } else {
        c.seekTo(Duration.zero);
        c.play();
      }
    }
  }

  void _openLightbox() {
    final path = widget.message.mediaPath;
    if (path == null || !File(path).existsSync()) return;
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      barrierLabel: 'Close video note',
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => _VideoNoteLightbox(
        path: path,
        message: widget.message,
      ),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _previewController?.removeListener(_onPreviewTick);
    _previewController?.dispose();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  Widget _statusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded, color: Color(0xFF53BDEB), size: 14);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded, color: Colors.white70, size: 14);
      case MessageStatus.sent:
        return const Icon(Icons.done_rounded, color: Colors.white70, size: 14);
      case MessageStatus.pendingOffline:
        return const Icon(Icons.access_time_rounded, color: Colors.white54, size: 12);
      case MessageStatus.unsent:
        return const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14);
      case MessageStatus.none:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    const size = 190.0;
    final message = widget.message;
    final totalSecs = message.mediaDuration ?? 0;
    final mins = (totalSecs ~/ 60).toString();
    final secs = (totalSecs % 60).toString().padLeft(2, '0');
    final showingPreview = _previewController != null &&
        _previewController!.value.isInitialized &&
        !_previewDone;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: _openLightbox,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipOval(
                  child: Container(
                    width: size,
                    height: size,
                    color: Colors.black,
                    child: showingPreview
                        ? FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _previewController!.value.size.width,
                              height: _previewController!.value.size.height,
                              child: VideoPlayer(_previewController!),
                            ),
                          )
                        : (message.mediaThumbnailPath != null
                            ? Image.file(File(message.mediaThumbnailPath!), fit: BoxFit.cover)
                            : Container(color: const Color(0xFF1A1A24))),
                  ),
                ),
                Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                        BorderSide(color: Colors.white24, width: 1.5)),
                  ),
                ),
                // Play icon shows once the muted preview has finished
                // its 3 loops and frozen — matches WhatsApp's static
                // thumbnail-with-play-icon state after the auto-preview.
                if (_previewDone || _previewFailed)
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                  ),
                // Small muted icon while the auto-preview is looping —
                // WhatsApp's preview is always silent.
                if (showingPreview)
                  const Positioned(
                    top: 12,
                    right: 12,
                    child: Icon(Icons.volume_off_rounded, color: Colors.white70, size: 16),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$mins:$secs',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        Positioned(
          bottom: -4,
          right: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
                if (message.isMe) ...[
                  const SizedBox(width: 4),
                  _statusIcon(message.status),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The "larger view" WhatsApp opens on tap — plays the video note WITH
/// SOUND over a dimmed backdrop, with a ✕ to close and a live elapsed
/// counter. Matches the exact frames observed in WhatsApp Business.
class _VideoNoteLightbox extends StatefulWidget {
  final String path;
  final KoraMessage message;
  const _VideoNoteLightbox({required this.path, required this.message});

  @override
  State<_VideoNoteLightbox> createState() => _VideoNoteLightboxState();
}

class _VideoNoteLightboxState extends State<_VideoNoteLightbox> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.file(File(widget.path));
    await c.initialize();
    await c.setVolume(1.0);
    c.addListener(_onTick);
    await c.play();
    if (mounted) setState(() => _controller = c);
  }

  void _onTick() {
    final c = _controller;
    if (c == null) return;
    final v = c.value;
    if (v.duration > Duration.zero && v.position >= v.duration) {
      Navigator.of(context).maybePop();
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 280.0;
    final c = _controller;
    final elapsed = c != null && c.value.isInitialized ? c.value.position.inSeconds : 0;
    final mins = (elapsed ~/ 60).toString();
    final secs = (elapsed % 60).toString().padLeft(2, '0');

    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              ClipOval(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: c != null && c.value.isInitialized
                      ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: c.value.size.width,
                            height: c.value.size.height,
                            child: VideoPlayer(c),
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 30, height: 30,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black87,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$mins:$secs',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
