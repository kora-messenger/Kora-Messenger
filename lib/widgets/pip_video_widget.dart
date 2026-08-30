import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// PiP Video widget — floating picture-in-picture video player.
/// Mirrors WhatsApp's PiP video playback when navigating away from a video.
///
/// Shows a small floating video player in the bottom corner that stays
/// on top of other screens. Can be dragged, expanded, or dismissed.
class PipVideoWidget extends StatefulWidget {
  final String videoPath;

  const PipVideoWidget({super.key, required this.videoPath});

  @override
  State<PipVideoWidget> createState() => _PipVideoWidgetState();
}

class _PipVideoWidgetState extends State<PipVideoWidget> {
  Offset _position = const Offset(0, 0);
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final size = _isExpanded ? const Size(200, 360) : const Size(120, 200);
    final screenSize = MediaQuery.of(context).size;

    // Default position: bottom-right corner
    final defaultPos = Offset(screenSize.width - size.width - 16, screenSize.height - size.height - 80);
    final pos = _position == Offset.zero ? defaultPos : _position;

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _position += d.delta),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Stack(
            children: [
              // Video placeholder
              const Center(child: Icon(Icons.play_circle_fill, size: 32, color: Colors.white54)),
              // Controls overlay
              Positioned(
                top: 4, right: 4,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                        child: Icon(_isExpanded ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
