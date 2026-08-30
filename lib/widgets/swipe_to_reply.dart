import 'package:flutter/material.dart';

/// SwipeToReply — a gesture detector wrapper that enables swipe-to-reply
/// on any chat message bubble, exactly like WhatsApp.
///
/// Usage: wrap a message bubble in SwipeToReply, provide onReply callback.
/// When the user swipes right (incoming) or left (outgoing) past the threshold,
/// the onReply callback fires and the reply preview bar slides in.
///
/// The widget manages its own animation controller and snap-back.
class SwipeToReply extends StatefulWidget {
  final Widget child;
  final bool isMe;
  final VoidCallback onReply;
  final double threshold;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.isMe,
    required this.onReply,
    this.threshold = 60.0,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  double _dragExtent = 0;
  bool _snapping = false;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    // For incoming messages: swipe right (positive)
    // For outgoing (isMe) messages: swipe left (negative)
    final delta = widget.isMe ? -details.delta.dx : details.delta.dx;
    if (delta > 0 && _dragExtent < 80) {
      setState(() {
        _dragExtent += details.delta.dx.abs() * 0.5;
        _snapping = false;
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragExtent >= widget.threshold) {
      widget.onReply();
    }
    // Snap back with animation
    setState(() {
      _snapping = true;
      _dragExtent = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final replyIconOpacity = (_dragExtent / widget.threshold).clamp(0.0, 1.0);
    final offset = widget.isMe ? -_dragExtent : _dragExtent;

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Reply icon that appears behind the bubble during swipe
          if (_dragExtent > 0)
            Positioned(
              left: widget.isMe ? null : 4,
              right: widget.isMe ? 4 : null,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: replyIconOpacity,
                child: const Icon(
                  Icons.reply,
                  size: 24,
                  color: Color(0xFF6C63FF),
                ),
              ),
            ),
          // The message bubble, translated by drag extent
          AnimatedContainer(
            duration: _snapping ? const Duration(milliseconds: 200) : Duration.zero,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(offset, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
