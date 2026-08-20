import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chat_models.dart';
import '../../models/message_model.dart';
import '../../services/message_service.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import '../../widgets/kora_menu_sheet.dart';
import 'chat_header.dart';
import 'message_bubble.dart';
import 'message_composer.dart';
import 'message_action_menu.dart';
import 'reply_preview.dart';
import 'chat_empty_state.dart';
import 'translate_sheet.dart';
import '../settings/default_chat_theme_screen.dart';
import '../settings/wallpaper_screen.dart';

/// Kora's main conversation screen.
/// Opens when a user taps any conversation from the Home/Chats list.
/// Supports: text messages, voice messages, replies, reactions,
/// translation, attachments (UI), message actions, chat menu, and
/// both light/dark themes.
class KoraChatScreen extends StatefulWidget {
  final String chatId;
  final String name;
  final String? avatarAsset;
  final String? avatarUrl;
  final KoraBadgeType badge;
  final bool isOnline;
  final String? lastSeen;

  const KoraChatScreen({
    super.key,
    required this.chatId,
    required this.name,
    this.avatarAsset,
    this.avatarUrl,
    this.badge = KoraBadgeType.none,
    this.isOnline = false,
    this.lastSeen,
  });

  @override
  State<KoraChatScreen> createState() => _KoraChatScreenState();
}

class _KoraChatScreenState extends State<KoraChatScreen> {
  final _scrollController = ScrollController();
  final _messageService = MessageService.instance;
  final _themeProvider = ChatThemeProvider.instance;

  List<KoraMessage> _messages = [];
  final Map<String, GlobalKey> _rowKeys = {};
  KoraMessage? _replyTarget;

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChanged);
    _loadMessages();
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _loadMessages() {
    _messages = List.from(_messageService.getMessages(widget.chatId));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage(String text) {
    _messageService.sendMessage(
      widget.chatId,
      text,
      replyToId: _replyTarget?.id,
      replyToText: _replyTarget?.text,
      replyToName: _replyTarget != null ? (_replyTarget!.isMe ? 'You' : widget.name) : null,
    );
    setState(() {
      _messages = List.from(_messageService.getMessages(widget.chatId));
      _replyTarget = null;
    });
    _scrollToBottom();
  }

  void _sendVoice(String duration) {
    _messageService.sendVoiceMessage(widget.chatId, duration);
    setState(() {
      _messages = List.from(_messageService.getMessages(widget.chatId));
    });
    _scrollToBottom();
  }

  void _onReact(String messageId, String emoji) {
    _messageService.toggleReaction(widget.chatId, messageId, emoji);
    setState(() {
      _messages = List.from(_messageService.getMessages(widget.chatId));
    });
  }

  void _onDelete(String messageId) {
    _messageService.deleteMessage(widget.chatId, messageId);
    setState(() {
      _messages = List.from(_messageService.getMessages(widget.chatId));
    });
  }

  void _onCopy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(seconds: 1),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onTranslate(String text) {
    TranslateSheet.show(context, text);
  }

  void _showMessageActions(GlobalKey key, KoraMessage message) {
    showKoraMessageActionMenu(
      context,
      messageKey: key,
      isMe: message.isMe,
      onReact: (emoji) => _onReact(message.id, emoji),
      onReply: () => setState(() => _replyTarget = message),
      onCopy: () => _onCopy(message.text),
      onForward: () {},
      onTranslate: () => _onTranslate(message.text),
      onDelete: () => _onDelete(message.id),
    );
  }

  bool get _isEmpty => _messages.isEmpty;

  bool get _isOfficial =>
      widget.badge == KoraBadgeType.officialPurple;

  @override
  Widget build(BuildContext context) {
    final theme = _themeProvider.activeTheme;
    final hasWallpaperImage = _themeProvider.wallpaperImagePath != null;
    final hasWallpaperAsset = _themeProvider.wallpaperAssetPath != null;

    return Scaffold(
      backgroundColor: theme.wallpaper,
      body: SafeArea(
        child: Column(
          children: [
            ChatHeader(
              name: widget.name,
              avatarAsset: widget.avatarAsset,
              avatarUrl: widget.avatarUrl,
              badge: widget.badge,
              isOnline: widget.isOnline,
              lastSeen: widget.lastSeen,
              onBack: () => Navigator.pop(context),
              onAvatarTap: () {},
              onVoiceCall: () {},
              onVideoCall: () {},
              menuOptions: [
                KoraMenuOption(icon: Icons.person_outline, label: 'Contact info', onTap: () {}),
                KoraMenuOption(icon: Icons.search, label: 'Search', onTap: () {}),
                KoraMenuOption(icon: Icons.photo_library_outlined, label: 'Media & files', onTap: () {}),
                KoraMenuOption(icon: Icons.notifications_outlined, label: 'Mute notifications', onTap: () {}),
                KoraMenuOption(icon: Icons.palette_outlined, label: 'Chat theme', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DefaultChatThemeScreen()));
                }),
                KoraMenuOption(icon: Icons.image_outlined, label: 'Wallpaper', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WallpaperScreen()));
                }),
                KoraMenuOption(icon: Icons.cleaning_services_outlined, label: 'Clear chat', onTap: () {}),
                KoraMenuOption(icon: Icons.block, label: 'Block', onTap: () {}, color: Colors.red),
                KoraMenuOption(icon: Icons.report_outlined, label: 'Report', onTap: () {}, color: Colors.red),
              ],
            ),
            // Message area
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: hasWallpaperAsset
                          ? BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage(_themeProvider.wallpaperAssetPath!),
                                fit: BoxFit.cover,
                                onError: (_, __) {},
                              ),
                            )
                          : hasWallpaperImage
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
                  if ((hasWallpaperAsset || hasWallpaperImage) && _themeProvider.wallpaperDimLevel > 0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: Colors.black.withValues(alpha: _themeProvider.wallpaperDimLevel * 0.75),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: _isEmpty
                        ? ChatEmptyState(
                            name: widget.name,
                            isOfficial: _isOfficial,
                          )
                        : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final rk = _rowKeys.putIfAbsent(message.id, () => GlobalKey());

                            final showDate = index == 0 ||
                                !_isSameDay(_messages[index - 1].timestamp, message.timestamp);

                            return Column(
                              children: [
                                if (showDate) _buildDateSeparator(context, message.timestamp),
                                Container(
                                  key: rk,
                                  child: MessageBubble(
                                    key: ValueKey(message.id),
                                    message: message,
                                    onLongPress: () => _showMessageActions(rk, message),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
            // Reply preview
            if (_replyTarget != null)
              ReplyPreview(
                name: _replyTarget!.isMe ? 'You' : widget.name,
                text: _replyTarget!.text,
                onCancel: () => setState(() => _replyTarget = null),
              ),
            // Composer
            MessageComposer(
              onSend: _sendMessage,
              onSendVoice: _sendVoice,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(BuildContext context, DateTime time) {
    final brightness = Theme.of(context).brightness;
    final textMuted = KoraColors.textMutedFor(brightness);
    final card = KoraColors.cardFor(brightness);

    String label;
    final now = DateTime.now();
    if (_isSameDay(now, time)) {
      label = 'Today';
    } else if (_isSameDay(now.subtract(const Duration(days: 1)), time)) {
      label = 'Yesterday';
    } else {
      label = '${time.day}/${time.month}/${time.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: card.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
