import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/kora_colors.dart';
import '../../models/status_model.dart';
import '../../services/status_service.dart';
import '../../widgets/kora_avatar.dart';

/// Full-screen status viewer — WhatsApp-style story playback.
///
/// Features:
/// - Segmented progress bars at top (one per status item)
/// - Auto-advance with configurable duration per item
/// - Tap left/right to navigate between items
/// - Hold to pause
/// - Swipe up or tap Reply to reply
/// - Emoji reaction bar (8 emojis)
/// - View-once indicator
class StatusViewerScreen extends StatefulWidget {
  final KoraStatus status;
  final bool isMyStatus;
  final int initialIndex;

  const StatusViewerScreen({
    super.key,
    required this.status,
    this.isMyStatus = false,
    this.initialIndex = 0,
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isPaused = false;
  Timer? _timer;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();

  // Animation for progress bars
  late AnimationController _animController;

  // Default duration per status item
  static const _textDuration = Duration(seconds: 6);
  static const _mediaDuration = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.status.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _animController = AnimationController(
      vsync: this,
      duration: _textDuration,
    );
    _startPlayback();
    _replyFocusNode.addListener(() {
      if (_replyFocusNode.hasFocus) {
        _pausePlayback();
      } else if (_replyController.text.isEmpty) {
        _resumePlayback();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    _pageController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  void _startPlayback() {
    final items = widget.status.items;
    if (items.isEmpty) return;

    final item = items[_currentIndex];
    final duration = item.type == StatusType.text ? _textDuration : _mediaDuration;

    _animController.duration = duration;
    _animController.forward(from: 0).then((_) {
      _nextItem();
    });

    // Mark as viewed
    if (!widget.isMyStatus) {
      StatusService.instance
          .markStatusViewed(widget.status.id, item.id);
    }
  }

  void _pausePlayback() {
    if (!_isPaused) {
      setState(() => _isPaused = true);
      _animController.stop();
    }
  }

  void _resumePlayback() {
    if (_isPaused) {
      setState(() => _isPaused = false);
      _animController.forward();
    }
  }

  void _nextItem() {
    if (_currentIndex < widget.status.items.length - 1) {
      _replyController.clear();
      setState(() => _currentIndex++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      _startPlayback();
    } else {
      // End of status — pop
      Navigator.of(context).pop();
    }
  }

  void _previousItem() {
    if (_currentIndex > 0) {
      _replyController.clear();
      setState(() => _currentIndex--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      _startPlayback();
    }
  }

  void _onTapLeft() {
    _animController.stop();
    _previousItem();
  }

  void _onTapRight() {
    _animController.stop();
    _nextItem();
  }

  void _react(int emojiCodePoint) {
    // Send emoji reaction
    if (!widget.isMyStatus) {
      StatusService.instance.replyToStatus(
        widget.status.id,
        widget.status.items[_currentIndex].id,
        String.fromCharCode(emojiCodePoint),
      );
    }
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reacted to ${widget.status.fullName}\'s status'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _sendReply(String reply) {
    if (reply.trim().isEmpty) return;
    if (!widget.isMyStatus) {
      StatusService.instance.replyToStatus(
        widget.status.id,
        widget.status.items[_currentIndex].id,
        reply.trim(),
      );
    }
    _replyController.clear();
    _replyFocusNode.unfocus();
    _resumePlayback();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Reply sent'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.status.items;
    if (items.isEmpty) {
      return const Scaffold(body: Center(child: Text('No status available')));
    }

    final item = items[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onLongPressStart: (_) => _pausePlayback(),
          onLongPressEnd: (_) => _resumePlayback(),
          onTapUp: (details) {
            final width = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < width / 3) {
              _onTapLeft();
            } else {
              _onTapRight();
            }
          },
          child: Column(
            children: [
              // Progress bars + header
              _buildProgressHeader(item),
              // Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return _buildStatusContent(items[index]);
                  },
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                ),
              ),
              // Bottom bar: reply / reactions
              if (widget.isMyStatus)
                _buildMyStatusFooter(item)
              else
                _buildContactFooter(item),
            ],
          ),
        ),
      ),
    );
  }

  // ── Progress bars + header ───────────────────────────────────

  Widget _buildProgressHeader(StatusItem item) {
    final items = widget.status.items;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          // Progress bars
          Row(
            children: List.generate(items.length, (i) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: i < _currentIndex
                        ? 1.0
                        : i == _currentIndex
                            ? _animController.value
                            : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // User info row — back arrow, avatar, name + time (+ reshared tag), 3-dot
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 6),
              KoraAvatar(
                name: widget.status.fullName,
                imageUrl: widget.status.avatarUrl,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.status.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          _formatTime(item.createdAt),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        if (item.isReshared) ...[
                          Text(' • ', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                          Icon(Icons.repeat, color: Colors.white.withValues(alpha: 0.6), size: 13),
                          const SizedBox(width: 3),
                          Text(
                            'Reshared',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // View count (my status only)
              if (widget.isMyStatus) ...[
                Icon(Icons.visibility, color: Colors.white.withValues(alpha: 0.6), size: 16),
                const SizedBox(width: 4),
                Text(
                  '${item.viewedBy.length}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                ),
                const SizedBox(width: 12),
              ],
              // 3-dot menu
              IconButton(
                icon: Icon(Icons.more_vert, color: Colors.white.withValues(alpha: 0.7), size: 20),
                onPressed: () => _showOptionsSheet(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Status content ───────────────────────────────────────────

  Widget _buildStatusContent(StatusItem item) {
    switch (item.type) {
      case StatusType.text:
        return _buildTextStatus(item);
      case StatusType.photo:
        return _buildPhotoStatus(item);
      case StatusType.video:
        return _buildVideoStatus(item);
      case StatusType.voice:
        return _buildVoiceStatus(item);
    }
  }

  Widget _buildTextStatus(StatusItem item) {
    return Container(
      color: item.backgroundColor ?? KoraColors.purple,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              item.text ?? '',
              style: TextStyle(
                color: item.textColor ?? Colors.white,
                fontSize: 28,
                height: 1.4,
                fontFamily: item.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (item.musicTitle != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.music_note, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      item.musicTitle!,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoStatus(StatusItem item) {
    if (item.mediaPath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(item.mediaPath!), fit: BoxFit.contain),
          if (item.caption != null && item.caption!.isNotEmpty)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.caption!,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    }
    return Container(
      color: Colors.black12,
      child: const Center(child: Icon(Icons.image, color: Colors.white24, size: 64)),
    );
  }

  Widget _buildVideoStatus(StatusItem item) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.mediaThumbnailPath != null)
            Image.file(File(item.mediaThumbnailPath!), fit: BoxFit.contain)
          else
            const Center(child: Icon(Icons.videocam, color: Colors.white24, size: 64)),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceStatus(StatusItem item) {
    return Container(
      color: KoraColors.purple,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            item.duration != null
                ? '${item.duration!.inSeconds}s'
                : 'Voice status',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ── Footer ──────────────────────────────────────────────────

  Widget _buildMyStatusFooter(StatusItem item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Row(
        children: [
          Icon(Icons.visibility, color: Colors.white.withValues(alpha: 0.6), size: 18),
          const SizedBox(width: 6),
          Text(
            '${item.viewedBy.length} views',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
          ),
          const Spacer(),
          Text(
            '${item.replyCount} replies',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// Persistent bottom bar — WhatsApp's exact Updates viewer pattern:
  /// a single always-visible reply field with two quick-emoji reactions,
  /// a reshare icon, and a heart (like) icon in one row. No toggle
  /// between a reaction grid and a reply field.
  Widget _buildContactFooter(StatusItem item) {
    final hasText = _replyController.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      focusNode: _replyFocusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Reply',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _sendReply,
                    ),
                  ),
                  if (hasText)
                    GestureDetector(
                      onTap: () => _sendReply(_replyController.text),
                      child: Container(
                        width: 32, height: 32,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: const BoxDecoration(
                          gradient: KoraColors.brandGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send, color: Colors.white, size: 15),
                      ),
                    )
                  else ...[
                    _quickEmojiButton(0x1F60D), // 😍
                    _quickEmojiButton(0x1F602), // 😂
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _footerIconButton(Icons.repeat, onTap: () => _forwardToChat(item)),
          const SizedBox(width: 6),
          _footerIconButton(Icons.favorite_border, onTap: () => _react(0x2764)),
        ],
      ),
    );
  }

  Widget _quickEmojiButton(int codePoint) {
    return GestureDetector(
      onTap: () => _react(codePoint),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Text(String.fromCharCode(codePoint), style: const TextStyle(fontSize: 20)),
      ),
    );
  }

  Widget _footerIconButton(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ── Options sheet ─────────────────────────────────────────────

  void _showOptionsSheet(StatusItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final textPrimary = KoraColors.textPrimaryFor(Theme.of(context).brightness);
        final textSecondary = KoraColors.textSecondaryFor(Theme.of(context).brightness);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            if (widget.isMyStatus) ...[
              ListTile(
                leading: Icon(Icons.visibility, color: textPrimary),
                title: Text('View info', style: TextStyle(color: textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _showViewsScreen(item);
                },
              ),
              ListTile(
                leading: Icon(Icons.share_outlined, color: textPrimary),
                title: Text('Share', style: TextStyle(color: textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _shareStatus(item);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteStatus(item);
                },
              ),
            ] else ...[
              ListTile(
                leading: Icon(widget.status.isMuted ? Icons.volume_up : Icons.volume_off, color: textPrimary),
                title: Text(
                  widget.status.isMuted ? 'Unmute updates' : 'Mute updates',
                  style: TextStyle(color: textPrimary),
                ),
                onTap: () {
                  StatusService.instance.toggleMute(widget.status.id);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.forward_outlined, color: textPrimary),
                title: Text('Forward to chat', style: TextStyle(color: textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _forwardToChat(item);
                },
              ),
              ListTile(
                leading: Icon(Icons.share_outlined, color: textPrimary),
                title: Text('Share', style: TextStyle(color: textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _shareStatus(item);
                },
              ),
              ListTile(
                leading: Icon(Icons.report_outlined, color: textPrimary),
                title: Text('Report', style: TextStyle(color: textPrimary)),
                onTap: () => Navigator.pop(context),
              ),
            ],
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void _showViewsScreen(StatusItem item) {
    // Show who viewed this status
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final textPrimary = KoraColors.textPrimaryFor(Theme.of(context).brightness);
        final textSecondary = KoraColors.textSecondaryFor(Theme.of(context).brightness);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text('Status info', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (item.viewedBy.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text('No views yet', style: TextStyle(color: textSecondary, fontSize: 15)),
              )
            else
              ...item.viewedBy.map((email) => ListTile(
                    leading: KoraAvatar(name: email, size: 40),
                    title: Text(email, style: TextStyle(color: textPrimary)),
                    subtitle: Text('Viewed', style: TextStyle(color: textSecondary, fontSize: 12)),
                  )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _deleteStatus(StatusItem item) {
    StatusService.instance.deleteStatusItem(item.id);
    if (widget.status.items.length <= 1) {
      Navigator.of(context).pop();
    }
  }

  void _shareStatus(StatusItem item) {
    if (item.mediaPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sharing status...'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      // For text status, share the text
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sharing: ${item.text ?? ''}'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _forwardToChat(StatusItem item) {
    // WhatsApp-style: forward status content to a chat
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Select a chat to forward to'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Select',
          textColor: Colors.white,
          onPressed: () {
            // In production, this opens chat picker and forwards the status item
          },
        ),
      ),
    );
  }

  // (old share stub removed)

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
