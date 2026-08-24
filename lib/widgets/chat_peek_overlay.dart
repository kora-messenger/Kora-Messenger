import 'package:flutter/material.dart';
import 'dart:io';
import '../models/chat_models.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../services/conversation_directory.dart';
import '../theme/kora_colors.dart';
import '../theme/chat_theme_provider.dart';
import '../screens/chat/message_bubble.dart';
import 'kora_avatar.dart';

/// Telegram-style "Chat Peek" — long-press a chat's avatar on the Home
/// screen to preview its recent messages in a compact card that floats
/// over a dimmed Home screen (does NOT cover the full screen).
///
/// Pushed as a real (non-opaque) route, so:
/// - The Android back button / iOS swipe-back gesture closes ONLY the
///   peek (pops this route) — it never closes the app.
/// - Tapping the header (avatar/name) opens that contact's Profile.
/// - Tapping the message area opens the full chat.
/// - Tapping outside the card, or an action in the menu below it,
///   closes the peek.
///
/// Below the peek card, a separate floating action menu offers quick
/// actions — Mark as unread, Pin, Mute, Delete — exactly like Telegram.
class ChatPeekOverlay {
  static bool _showing = false;
  static bool get isShowing => _showing;

  static Future<void> show(
    BuildContext context,
    ChatPreview chat, {
    required VoidCallback onOpenChat,
    required VoidCallback onOpenProfile,
    required VoidCallback onRefresh,
  }) async {
    if (_showing) return;
    _showing = true;
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (ctx, animation, secondaryAnimation) => _ChatPeekView(
          chat: chat,
          animation: animation,
          onOpenChat: onOpenChat,
          onOpenProfile: onOpenProfile,
          onRefresh: onRefresh,
        ),
      ),
    );
    _showing = false;
  }
}

class _ChatPeekView extends StatefulWidget {
  final ChatPreview chat;
  final Animation<double> animation;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenProfile;
  final VoidCallback onRefresh;

  const _ChatPeekView({
    required this.chat,
    required this.animation,
    required this.onOpenChat,
    required this.onOpenProfile,
    required this.onRefresh,
  });

  @override
  State<_ChatPeekView> createState() => _ChatPeekViewState();
}

class _ChatPeekViewState extends State<_ChatPeekView> {
  List<KoraMessage> _messages = [];
  bool _markedRead = false;
  bool _isPinned = false;
  bool _isMuted = false;
  final ScrollController _scrollController = ScrollController();
  final _themeProvider = ChatThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _isPinned = widget.chat.isPinned;
    _isMuted = widget.chat.isMuted;

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
    if (pos.pixels >= pos.maxScrollExtent - 60) {
      _markAsRead();
    }
  }

  void _markAsRead() {
    if (_markedRead) return;
    _markedRead = true;
    MessageService.instance.markChatViewed(widget.chat.id);
    widget.onRefresh();
  }

  void _close() => Navigator.of(context).pop();

  void _handleOpenProfile() {
    _close();
    widget.onOpenProfile();
  }

  void _handleOpenChat() {
    _close();
    widget.onOpenChat();
  }

  Future<void> _markUnread() async {
    await ConversationDirectoryService.instance.setForcedUnread(widget.chat.id, true);
    widget.onRefresh();
    _close();
  }

  Future<void> _togglePin() async {
    await ConversationDirectoryService.instance.setPinned(widget.chat.id, !_isPinned);
    widget.onRefresh();
    _close();
  }

  Future<void> _toggleMute() async {
    await ConversationDirectoryService.instance.setMuted(widget.chat.id, !_isMuted);
    widget.onRefresh();
    _close();
  }

  Future<void> _delete() async {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Delete this chat?',
                style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'This will permanently delete all messages in this chat. This cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    await MessageService.instance.deleteChat(widget.chat.id);
    await ConversationDirectoryService.instance.remove(widget.chat.id);
    widget.onRefresh();
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final screenSize = MediaQuery.of(context).size;
    final topInset = MediaQuery.of(context).padding.top;

    final fade = CurvedAnimation(parent: widget.animation, curve: Curves.easeOut);
    final scale = CurvedAnimation(parent: widget.animation, curve: Curves.easeOutCubic);

    // Compact card — NOT full screen. Leaves the Home screen visible
    // (dimmed) around and below it, matching Telegram/WhatsApp peeks.
    final cardHeight = screenSize.height * 0.58;

    return WillPopScope(
      // Hardware back / gesture just pops THIS route — it closes the
      // peek, never the app, since we pushed it as a normal route.
      onWillPop: () async => true,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Dimmed backdrop — tap outside the card closes the peek.
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                behavior: HitTestBehavior.opaque,
                child: FadeTransition(
                  opacity: fade,
                  child: Container(color: Colors.black.withValues(alpha: 0.6)),
                ),
              ),
            ),
            Positioned(
              top: topInset + 10,
              left: 10,
              right: 10,
              child: FadeTransition(
                opacity: fade,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.85, end: 1.0).animate(scale),
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    // Absorb taps inside so they don't fall through to
                    // the dimmed backdrop's dismiss handler.
                    onTap: () {},
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── The peek card itself ──
                        Material(
                          color: card,
                          elevation: 12,
                          borderRadius: BorderRadius.circular(18),
                          clipBehavior: Clip.antiAlias,
                          child: SizedBox(
                            height: cardHeight,
                            child: Column(
                              children: [
                                // Header — tap opens the contact's Profile.
                                GestureDetector(
                                  onTap: _handleOpenProfile,
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    color: surface,
                                    child: _buildHeader(textPrimary, textSecondary),
                                  ),
                                ),
                                Divider(height: 1, color: border),
                                // Messages — uses the SAME chat wallpaper
                                // theme as the real chat screen. Tap
                                // opens the full chat.
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _handleOpenChat,
                                    behavior: HitTestBehavior.translucent,
                                    child: _buildWallpaperedMessages(textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // ── Floating quick-action menu ──
                        Material(
                          color: card,
                          elevation: 12,
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: SizedBox(
                            width: screenSize.width * 0.62,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildMenuItem(
                                  icon: Icons.mark_chat_unread_outlined,
                                  label: 'Mark as unread',
                                  textPrimary: textPrimary,
                                  onTap: _markUnread,
                                ),
                                _buildMenuItem(
                                  icon: _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                  label: _isPinned ? 'Unpin' : 'Pin',
                                  textPrimary: textPrimary,
                                  onTap: _togglePin,
                                ),
                                _buildMenuItem(
                                  icon: _isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                                  label: _isMuted ? 'Unmute' : 'Mute',
                                  textPrimary: textPrimary,
                                  onTap: _toggleMute,
                                ),
                                _buildMenuItem(
                                  icon: Icons.delete_outline,
                                  label: 'Delete',
                                  textPrimary: Colors.red,
                                  onTap: _delete,
                                  isLast: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color textPrimary,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: textPrimary),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          KoraAvatar(
            name: widget.chat.name,
            assetPath: widget.chat.avatarAsset,
            imageUrl: widget.chat.avatarUrl,
            size: 38,
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
          Icon(Icons.more_vert, color: textSecondary, size: 20),
        ],
      ),
    );
  }

  /// Renders the message preview using the SAME wallpaper as the real
  /// chat screen ([KoraChatScreen]) — so the peek feels like a genuine
  /// window into that chat, not a generic list.
  Widget _buildWallpaperedMessages(Color textSecondary) {
    final theme = _themeProvider.activeTheme;
    final hasWallpaperImage = _themeProvider.wallpaperImagePath != null;
    final hasWallpaperAsset = _themeProvider.wallpaperAssetPath != null;
    final usesDefaultDoodle = _themeProvider.usesDefaultWallpaperAsset;
    final wallpaperAssetPath = hasWallpaperAsset
        ? _themeProvider.wallpaperAssetPath!
        : (usesDefaultDoodle ? _themeProvider.defaultWallpaperAsset : null);
    final hasWallpaper = wallpaperAssetPath != null;

    return Container(
      color: theme.wallpaper,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: hasWallpaper
                  ? BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(wallpaperAssetPath),
                        fit: BoxFit.cover,
                        onError: (_, __) {},
                      ),
                    )
                  : hasWallpaperImage && File(_themeProvider.wallpaperImagePath!).existsSync()
                      ? BoxDecoration(
                          image: DecorationImage(
                            image: FileImage(File(_themeProvider.wallpaperImagePath!)),
                            fit: BoxFit.cover,
                            onError: (_, __) {},
                          ),
                        )
                      : null,
            ),
          ),
          if ((hasWallpaper || hasWallpaperImage) && _themeProvider.wallpaperDimLevel > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: _themeProvider.wallpaperDimLevel * 0.75),
                ),
              ),
            ),
          _buildMessages(textSecondary),
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
