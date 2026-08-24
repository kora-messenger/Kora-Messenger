import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../theme/kora_colors.dart';
import '../screens/chat/message_bubble.dart';
import 'kora_avatar.dart';

/// Telegram-style "Chat Peek" — long-press a chat's avatar on the Home
/// screen to preview its recent messages in a near-full-screen zoom-in
/// panel (not a side panel).
///
/// Visual behavior matches Telegram:
/// - The panel appears centered, covering most of the screen.
/// - The chat's recent messages are shown (last 25).
/// - Scrolling to the bottom (the newest message) marks the chat as read.
/// - Tapping outside the panel dismisses it (returns to Home).
/// - Tapping inside the panel opens the full chat screen.
class ChatPeekOverlay {
  static OverlayEntry? _entry;

  static bool get isShowing => _entry != null;

  static void show(
    BuildContext context,
    ChatPreview chat, {
    required VoidCallback onOpenChat,
    required VoidCallback onMarkedRead,
  }) {
    _entry?.remove();
    _entry = null;

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
  }
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

class _ChatPeekViewState extends State<_ChatPeekView>
    with SingleTickerProviderStateMixin {
  List<KoraMessage> _messages = [];
  bool _markedRead = false;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _opacityAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    MessageService.instance.loadMessages(widget.chat.id).then((msgs) {
      if (!mounted) return;
      setState(() => _messages = msgs);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        if (_scrollController.position.maxScrollExtent <= 0) {
          _markAsRead();
        }
      });
    });

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animController.forward();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_markedRead || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
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

  void _handleOpenChat() {
    _animController.reverse().then((_) {
      ChatPeekOverlay.hide();
      widget.onOpenChat();
    });
  }

  void _handleDismiss() {
    _animController.reverse().then((_) {
      ChatPeekOverlay.hide();
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final screenSize = MediaQuery.of(context).size;
    final topInset = MediaQuery.of(context).padding.top;

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Stack(
            children: [
              // Dimmed background — tap outside dismisses.
              Positioned.fill(
                child: GestureDetector(
                  onTap: _handleDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: Opacity(
                    opacity: _opacityAnim.value * 0.6,
                    child: Container(color: Colors.black),
                  ),
                ),
              ),
              // Near-full-screen zoom-in panel.
              Positioned.fill(
                child: Center(
                  child: Transform.scale(
                    scale: 0.92 + 0.08 * _scaleAnim.value,
                    child: Opacity(
                      opacity: _opacityAnim.value,
                      child: Material(
                        color: card,
                        elevation: 0,
                        borderRadius: BorderRadius.zero,
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(
                        width: screenSize.width,
                        height: screenSize.height,
                        child: Column(
                          children: [
                            SizedBox(height: topInset),
                            GestureDetector(
                              onTap: _handleOpenChat,
                              behavior: HitTestBehavior.opaque,
                              child: _buildHeader(
                                textPrimary,
                                textSecondary,
                                border,
                                brightness,
                              ),
                            ),
                            Divider(height: 1, color: border),
                            Expanded(
                              child: GestureDetector(
                                onTap: _handleOpenChat,
                                behavior: HitTestBehavior.translucent,
                                child: _buildMessages(textSecondary),
                              ),
                            ),
                            SizedBox(
                              height: MediaQuery.of(context).padding.bottom,
                            ),
                          ],
                        ),
                      ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    Color textPrimary,
    Color textSecondary,
    Color border,
    Brightness brightness,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      color: KoraColors.surfaceFor(brightness),
      child: Row(
        children: [
          GestureDetector(
            onTap: _handleDismiss,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.arrow_back, color: textPrimary, size: 24),
            ),
          ),
          const SizedBox(width: 4),
          KoraAvatar(
            name: widget.chat.name,
            assetPath: widget.chat.avatarAsset,
            imageUrl: widget.chat.avatarUrl,
            size: 42,
            showOnlineDot: widget.chat.isOnline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.chat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (widget.chat.isMuted) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.notifications_off,
                        size: 14,
                        color: textSecondary,
                      ),
                    ],
                  ],
                ),
                Text(
                  widget.chat.isOnline
                      ? 'online'
                      : 'last seen recently',
                  style: TextStyle(color: textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: textSecondary, size: 22),
            onPressed: _handleOpenChat,
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(Color textSecondary) {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet',
          style: TextStyle(color: textSecondary, fontSize: 13),
        ),
      );
    }

    final preview = _messages.length > 25
        ? _messages.sublist(_messages.length - 25)
        : _messages;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      physics: const ClampingScrollPhysics(),
      itemCount: preview.length,
      itemBuilder: (context, index) {
        final msg = preview[index];
        return MessageBubble(message: msg);
      },
    );
  }
}
