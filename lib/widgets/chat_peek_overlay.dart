import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../theme/kora_colors.dart';
import '../screens/chat/message_bubble.dart';
import 'kora_avatar.dart';

/// A single quick action shown in the peek's bottom action bar.
class PeekAction {
  final IconData icon;
  final IconData? activeIcon; // shown instead of [icon] when [isActive] is true
  final String label;
  final String? activeLabel;
  final bool isActive;
  final bool isDestructive;
  final VoidCallback onTrigger;

  const PeekAction({
    required this.icon,
    required this.label,
    required this.onTrigger,
    this.activeIcon,
    this.activeLabel,
    this.isActive = false,
    this.isDestructive = false,
  });
}

/// Telegram-style "Chat Peek" — press-and-hold a chat's avatar on the
/// Home screen to preview its recent messages without opening the full
/// chat screen, and crucially, without marking anything as read.
///
/// While the finger stays down, dragging over one of the bottom action
/// icons highlights it; lifting the finger there triggers that action.
/// Lifting anywhere else just dismisses the peek — the chat's unread
/// state is completely untouched by peeking.
class ChatPeekOverlay {
  static OverlayEntry? _entry;
  static _ChatPeekViewState? _state;

  static bool get isShowing => _entry != null;

  static void show(
    BuildContext context,
    ChatPreview chat, {
    required List<PeekAction> actions,
    required VoidCallback onOpenChat,
  }) {
    if (_entry != null) return;
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (_) => _ChatPeekView(
        chat: chat,
        actions: actions,
        onOpenChat: onOpenChat,
      ),
    );
    overlay.insert(_entry!);
  }

  /// Forward the held finger's current global position so the peek can
  /// highlight whichever bottom action icon it's hovering over.
  static void updatePointer(Offset globalPosition) {
    _state?.updateHover(globalPosition);
  }

  /// Finger lifted — trigger the hovered action (if any) then dismiss.
  static void commitAndHide() {
    _state?.commitHoveredAction();
    hide();
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
  final List<PeekAction> actions;
  final VoidCallback onOpenChat;

  const _ChatPeekView({
    required this.chat,
    required this.actions,
    required this.onOpenChat,
  });

  @override
  State<_ChatPeekView> createState() => _ChatPeekViewState();
}

class _ChatPeekViewState extends State<_ChatPeekView> {
  List<KoraMessage> _messages = [];
  bool _visible = false;
  int? _hoveredIndex;
  final GlobalKey _barKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    ChatPeekOverlay._registerState(this);
    // Deliberately just [loadMessages] — never markChatViewed here.
    // Peeking must never affect the chat's unread state.
    MessageService.instance.loadMessages(widget.chat.id).then((msgs) {
      if (mounted) setState(() => _messages = msgs);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  void updateHover(Offset globalPosition) {
    final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final local = box.globalToLocal(globalPosition);
    final size = box.size;
    int? newHover;
    if (local.dy >= -16 && local.dy <= size.height + 16 && local.dx >= 0 && local.dx <= size.width) {
      final iconWidth = size.width / widget.actions.length;
      final idx = (local.dx / iconWidth).floor();
      if (idx >= 0 && idx < widget.actions.length) newHover = idx;
    }
    if (newHover != _hoveredIndex && mounted) {
      setState(() => _hoveredIndex = newHover);
    }
  }

  void commitHoveredAction() {
    if (_hoveredIndex != null) {
      widget.actions[_hoveredIndex!].onTrigger();
    }
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
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: Container(color: const Color(0xB3000000)),
            ),
          ),
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
                  GestureDetector(
                    onTap: widget.onOpenChat,
                    child: _buildHeader(textPrimary, textSecondary, border),
                  ),
                  Divider(height: 1, color: border),
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onOpenChat,
                      child: _buildMessages(textSecondary),
                    ),
                  ),
                  Divider(height: 1, color: border),
                  _buildActionBar(textPrimary, textSecondary),
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
    final preview = _messages.length > 25
        ? _messages.sublist(_messages.length - 25)
        : _messages;
    return IgnorePointer(
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: 10),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: preview.length,
        itemBuilder: (context, index) {
          final msg = preview[preview.length - 1 - index];
          return MessageBubble(message: msg);
        },
      ),
    );
  }

  Widget _buildActionBar(Color textPrimary, Color textSecondary) {
    return Container(
      key: _barKey,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: List.generate(widget.actions.length, (i) {
          final action = widget.actions[i];
          final hovered = _hoveredIndex == i;
          final color = action.isDestructive
              ? KoraColors.red
              : (hovered ? KoraColors.purple : textPrimary);
          return Expanded(
            child: AnimatedScale(
              scale: hovered ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hovered ? KoraColors.purple.withValues(alpha: 0.15) : Colors.transparent,
                    ),
                    child: Icon(
                      action.isActive ? (action.activeIcon ?? action.icon) : action.icon,
                      color: color,
                      size: 21,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    action.isActive ? (action.activeLabel ?? action.label) : action.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 10.5,
                      fontWeight: hovered ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
