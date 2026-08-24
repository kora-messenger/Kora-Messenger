import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../theme/kora_colors.dart';
import '../screens/chat/message_bubble.dart';
import 'kora_avatar.dart';

/// Telegram-style "Chat Peek" — press-and-hold a chat's avatar on the
/// Home screen to preview its recent messages without opening the full
/// chat screen.
///
/// The peek stays open after the finger lifts. While open:
/// - **Scroll** through the last 25 messages. Scrolling to the bottom
///   (the last/newest message) marks the chat's unread messages as read
///   on the peeking user's side — without ever opening the full chat.
/// - **Tap anywhere** on the screen opens the full chat screen, where
///   both users can continue chatting. Closing the full chat returns
///   to the Home screen naturally (standard Navigator.pop).
class ChatPeekOverlay {
  static OverlayEntry? _entry;
  static _ChatPeekViewState? _state;

  static bool get isShowing => _entry != null;

  static void show(
    BuildContext context,
    ChatPreview chat, {
    required VoidCallback onOpenChat,
    required VoidCallback onMarkedRead,
  }) {
    // If a peek is already open, dismiss it first.
    _entry?.remove();
    _entry = null;
    _state = null;

    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (_) => _ChatPeekView(
        chat: chat,
        onOpenChat: onOpenChat,
        onMarkedRead: onMarkedRead,
      ),
    );
    overlay.insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
    _state = null;
  }

  static void _registerState(_ChatPeekViewState state) => _state = state;
}

class _ChatPeekView extends StatefulWidget {
  final ChatPreview chat;
  final VoidCallback onOpenChat;
  final VoidCallback onMarkedRead;

  const _ChatPeekView({
    required this.chat,
    required this.onOpenChat,
    required this.onMarkedRead,
  });

  @override
  State<_ChatPeekView> createState() => _ChatPeekViewState();
}

class _ChatPeekViewState extends State<_ChatPeekView> {
  List<KoraMessage> _messages = [];
  bool _visible = false;
  bool _markedRead = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    ChatPeekOverlay._registerState(this);

    // Deliberately just [loadMessages] — never markChatViewed here.
    // Read state is only changed when the user scrolls to the bottom.
    MessageService.instance.loadMessages(widget.chat.id).then((msgs) {
      if (!mounted) return;
      setState(() => _messages = msgs);

      // If all messages fit on screen (no scrolling needed), the user
      // can already see the last message — mark as read after a brief
      // moment so it doesn't feel instant/jarring.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        if (_scrollController.position.maxScrollExtent <= 0) {
          _markAsRead();
        }
      });
    });

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_markedRead || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // User has scrolled to (or very near) the bottom — the last/newest
    // message is visible. Mark the chat's unread messages as read.
    if (pos.pixels >= pos.maxScrollExtent - 60) {
      _markAsRead();
    }
  }

  void _markAsRead() {
    if (_markedRead) return;
    _markedRead = true;
    MessageService.instance.markChatViewed(widget.chat.id);
    widget.onMarkedRead();
  }

  void _handleTap() {
    ChatPeekOverlay.hide();
    widget.onOpenChat();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final screenSize = MediaQuery.of(context).size;
    final panelWidth = screenSize.width * 0.86;
    final topInset = MediaQuery.of(context).padding.top;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dimmed background — tapping outside the peek panel dismisses
          // it and returns to the normal Home screen (does NOT open chat).
          Positioned.fill(
            child: GestureDetector(
              onTap: ChatPeekOverlay.hide,
              behavior: HitTestBehavior.opaque,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: Container(color: const Color(0xB3000000)),
              ),
            ),
          ),
          // Peek panel — slides in from the left edge.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            top: topInset + 24,
            bottom: 24,
            left: _visible ? 0 : -panelWidth,
            width: panelWidth,
            child: Material(
              color: card,
              elevation: 16,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Header — tap opens full chat.
                  GestureDetector(
                    onTap: _handleTap,
                    behavior: HitTestBehavior.opaque,
                    child: _buildHeader(textPrimary, textSecondary, border),
                  ),
                  Divider(height: 1, color: border),
                  // Messages — scrollable. Scroll to bottom → mark as read.
                  // Tap (without scrolling) → open full chat.
                  Expanded(
                    child: GestureDetector(
                      onTap: _handleTap,
                      behavior: HitTestBehavior.translucent,
                      child: _buildMessages(textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color textPrimary, Color textSecondary, Color border) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          KoraAvatar(
            name: widget.chat.name,
            assetPath: widget.chat.avatarAsset,
            imageUrl: widget.chat.avatarUrl,
            size: 40,
            showOnlineDot: widget.chat.isOnline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.chat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  widget.chat.isOnline ? 'online' : 'last seen recently',
                  style: TextStyle(color: textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: textSecondary, size: 22),
        ],
      ),
    );
  }

  Widget _buildMessages(Color textSecondary) {
    if (_messages.isEmpty) {
      return Center(
        child: Text('No messages yet', style: TextStyle(color: textSecondary, fontSize: 13)),
      );
    }
    // Show the last 25 messages in chronological order (oldest at top,
    // newest at bottom). The user scrolls DOWN to reach the last
    // message — reaching it marks the chat as read.
    final preview = _messages.length > 25
        ? _messages.sublist(_messages.length - 25)
        : _messages;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 10),
      physics: const ClampingScrollPhysics(),
      itemCount: preview.length,
      itemBuilder: (context, index) {
        final msg = preview[index];
        return MessageBubble(message: msg);
      },
    );
  }
}
