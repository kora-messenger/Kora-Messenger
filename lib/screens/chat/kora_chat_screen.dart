import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../models/chat_models.dart';
import '../../models/message_model.dart';
import '../../services/message_service.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import '../../config/kora_api.dart';
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
import '../settings/premium_subscribe_sheet.dart';

/// Kora's main conversation screen.
/// Opens when a user taps any conversation from the Home/Chats list.
/// Supports: text messages, voice messages, replies, reactions,
/// translation, attachments (UI), message actions, chat menu, and
/// both light/dark themes.
///
/// Kora Support and Kora AI chats have AI-powered responses.
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
  bool _isLoading = true;
  bool _isAiTyping = false;
  Timer? _statusTimer;

  bool get _isAiChat =>
      widget.chatId == 'kora_support' || widget.chatId == 'kora_ai';

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChanged);
    _loadMessages();
    // Refresh every 500ms to pick up status changes (sent → delivered → read)
    _statusTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) _refreshMessages();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _themeProvider.removeListener(_onThemeChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMessages() async {
    _messages = await _messageService.loadMessages(widget.chatId);
    if (mounted) {
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
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

  void _refreshMessages() {
    _messages = List.from(_messageService.getMessages(widget.chatId));
    setState(() {});
    _scrollToBottom();
  }

  Future<void> _sendMessage(String text) async {
    await _messageService.sendMessage(
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

    // If this is an AI chat, get an AI response
    if (_isAiChat) {
      await _getAiResponse(text);
    }
  }

  Future<void> _getAiResponse(String userMessage) async {
    setState(() => _isAiTyping = true);

    try {
      final chatType = widget.chatId == 'kora_support' ? 'support' : 'ai';
      final history = _messages
          .where((m) => m.type != KoraMessageType.action)
          .map((m) => {'text': m.text, 'isMe': m.isMe})
          .toList();

      final response = await http.post(
        Uri.parse('${KoraApi.baseUrl}/koraAiChat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chatType': chatType,
          'message': userMessage,
          'history': history,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final reply = data['reply'] as String? ??
          "I'm here to help! Could you tell me more?";

      await _messageService.addIncomingMessage(
        widget.chatId,
        reply,
        isAi: true,
      );
    } catch (e) {
      // Fallback response if the backend is unreachable
      await _messageService.addIncomingMessage(
        widget.chatId,
        widget.chatId == 'kora_support'
            ? "I'm here to help with any Kora-related questions! Could you tell me more about what you need?"
            : "I'd be happy to help with that! Let me know a bit more about what you're looking for.",
        isAi: true,
      );
    }

    if (mounted) {
      setState(() => _isAiTyping = false);
      _refreshMessages();
    }
  }

  void _sendVoice(String duration) async {
    await _messageService.sendVoiceMessage(widget.chatId, duration);
    _refreshMessages();
  }

  void _onReact(String messageId, String emoji) async {
    await _messageService.toggleReaction(widget.chatId, messageId, emoji);
    _refreshMessages();
  }

  void _onDelete(String messageId) async {
    await _messageService.deleteMessage(widget.chatId, messageId);
    _refreshMessages();
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

  void _onActionTap(KoraMessage message) {
    if (message.actionType == 'subscribe_premium') {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const PremiumSubscribeSheet(),
      );
    }
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
              isOnline: _isAiChat ? true : widget.isOnline,
              lastSeen: _isAiChat ? 'AI Assistant' : widget.lastSeen,
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
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
                        : _isEmpty
                            ? ChatEmptyState(
                                name: widget.name,
                                isOfficial: _isOfficial,
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: _messages.length + (_isAiTyping ? 1 : 0),
                                itemBuilder: (context, index) {
                                  // Typing indicator at the end
                                  if (_isAiTyping && index == _messages.length) {
                                    return _buildTypingIndicator(context);
                                  }

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
                                          onActionTap: () => _onActionTap(message),
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

  Widget _buildTypingIndicator(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: KoraColors.cardFor(brightness),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.2 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.name} is typing',
              style: TextStyle(color: textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: KoraColors.purple.withValues(alpha: 0.6),
              ),
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
