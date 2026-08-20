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
    // and mark any newly-arrived incoming messages as viewed while open.
    _statusTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      _messageService.markChatViewed(widget.chatId);
      _refreshMessages();
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
    // Mark all incoming messages as viewed — clears the Home unread badge.
    await _messageService.markChatViewed(widget.chatId);
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
          .where((m) => m.type != KoraMessageType.action && m.type != KoraMessageType.issueList)
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
      ).timeout(const Duration(seconds: 45));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final reply = data['reply'] as String? ??
          "I'm here to help! Could you tell me more?";
      final isWebSearch = data['isWebSearch'] as bool? ?? false;
      final issueList = data['issueList'] as List?;
      final actionLabel = data['actionLabel'] as String?;
      final actionType = data['actionType'] as String?;

      // If the AI returned an issue list, show it as an issueList message
      if (issueList != null && issueList.isNotEmpty) {
        final issues = issueList
            .map((e) => IssueOption(
              id: e['id'] as String,
              label: e['label'] as String,
            ))
            .toList();
        await _messageService.addIncomingMessage(
          widget.chatId,
          reply,
          isAi: true,
          type: KoraMessageType.issueList,
          issueOptions: issues,
        );
      } else if (actionLabel != null && actionType != null) {
        // Guided response with an action button (e.g. "Contact Live Support")
        await _messageService.addIncomingMessage(
          widget.chatId,
          reply,
          isAi: true,
          actionLabel: actionLabel,
          actionType: actionType,
        );
      } else {
        await _messageService.addIncomingMessage(
          widget.chatId,
          reply,
          isAi: true,
          isWebSearch: isWebSearch,
        );
      }
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

  /// Called when the user taps an issue from the support issue list.
  /// Sends the issue as a user message, then gets AI-guided troubleshooting.
  Future<void> _onIssueSelected(IssueOption issue) async {
    // Send the issue label as a user message
    await _messageService.sendUserMessage(widget.chatId, issue.label);
    setState(() {
      _messages = List.from(_messageService.getMessages(widget.chatId));
    });
    _scrollToBottom();

    // Get AI guidance using the [ISSUE] prefix so the backend knows to
    // return pre-written step-by-step troubleshooting instructions.
    await _getAiResponse('[ISSUE]${issue.id}');
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

  void _openCallScreen({required bool isVideo}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CallScreen(
          name: widget.name,
          isVideo: isVideo,
          avatarAsset: widget.avatarAsset,
          avatarUrl: widget.avatarUrl,
        ),
      ),
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
    } else if (message.actionType == 'contact_support') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Live Support will be available soon. For now, email support@koramessenger.com'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showContactInfo() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final surface = KoraColors.cardFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: KoraColors.borderFor(brightness),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Avatar
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: KoraColors.brandGradient,
                ),
                child: Center(
                  child: Text(
                    widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            // Name
            Text(
              widget.name,
              style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isOnline ? 'online' : (widget.lastSeen ?? 'last seen recently'),
              style: TextStyle(color: KoraColors.purple, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Divider(color: KoraColors.borderFor(brightness), height: 1),
            // Info tiles
            _contactInfoTile(Icons.info_outline, 'About', 'Hey there! I am using Kora Messenger.', surface, textPrimary, textSecondary),
            _contactInfoTile(Icons.phone_outlined, 'Phone', '+123 456 7890', surface, textPrimary, textSecondary),
            _contactInfoTile(Icons.alternate_email, 'Kora ID', '@${widget.name.toLowerCase().replaceAll(' ', '_')}', surface, textPrimary, textSecondary),
            const Spacer(),
            // Action buttons
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.block, color: Colors.red, size: 18),
                        label: const Text('Block', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.report_outlined, color: Colors.red, size: 18),
                        label: const Text('Report', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactInfoTile(IconData icon, String label, String value, Color surface, Color textPrimary, Color textSecondary) {
    return ListTile(
      leading: Icon(icon, color: KoraColors.purple, size: 22),
      title: Text(label, style: TextStyle(color: textSecondary, fontSize: 13)),
      subtitle: Text(value, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }

  void _showChatSearch() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final surface = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    final searchController = TextEditingController();
    List<KoraMessage> searchResults = [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          void doSearch(String query) {
            if (query.isEmpty) {
              searchResults = [];
            } else {
              searchResults = _messages.where((m) {
                final lower = query.toLowerCase();
                return m.text.toLowerCase().contains(lower);
              }).toList();
            }
            setSheetState(() {});
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          autofocus: true,
                          onChanged: doSearch,
                          decoration: InputDecoration(
                            hintText: 'Search messages by date or text...',
                            hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                            prefixIcon: Icon(Icons.search, color: textSecondary, size: 20),
                            filled: true,
                            fillColor: KoraColors.surfaceFor(brightness),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          style: TextStyle(color: textPrimary, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text('Cancel', style: TextStyle(color: KoraColors.purple, fontSize: 14, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Date hint
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tip: Try searching a date like "20/8" or a keyword',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Search results
                Expanded(
                  child: searchResults.isEmpty
                      ? Center(
                          child: Text(
                            searchController.text.isEmpty ? 'Start typing to search' : 'No messages found',
                            style: TextStyle(color: textSecondary, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final msg = searchResults[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: msg.isMe ? KoraColors.purple : surface,
                                child: Icon(
                                  msg.isMe ? Icons.arrow_upward : Icons.arrow_downward,
                                  color: msg.isMe ? Colors.white : textPrimary,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                msg.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: textPrimary, fontSize: 14),
                              ),
                              subtitle: Text(
                                '${msg.isMe ? 'You' : widget.name} • ${msg.timestamp.day}/${msg.timestamp.month}/${msg.timestamp.year}',
                                style: TextStyle(color: textSecondary, fontSize: 12),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showMuteDialog() {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: KoraColors.borderFor(brightness),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.notifications_off, color: KoraColors.purple, size: 22),
                    const SizedBox(width: 8),
                    Text('Mute notifications', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _muteOption('8 hours', surface, textPrimary, textSecondary),
              _muteOption('1 week', surface, textPrimary, textSecondary),
              _muteOption('Always', surface, textPrimary, textSecondary),
              ListTile(
                leading: Icon(Icons.notifications, color: KoraColors.purple, size: 22),
                title: Text('Unmute', style: TextStyle(color: textPrimary, fontSize: 15)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Notifications unmuted for ${widget.name}'),
                      backgroundColor: KoraColors.purple,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _muteOption(String duration, Color surface, Color textPrimary, Color textSecondary) {
    return ListTile(
      leading: Icon(Icons.notifications_off_outlined, color: KoraColors.purple, size: 22),
      title: Text(duration, style: TextStyle(color: textPrimary, fontSize: 15)),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Muted ${widget.name} for $duration'),
            backgroundColor: KoraColors.purple,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
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
    // When the default theme has no custom wallpaper override, use
    // Kora's signature milk doodle wallpaper.
    final usesDefaultDoodle = _themeProvider.usesDefaultWallpaperAsset;
    final wallpaperAssetPath = hasWallpaperAsset
        ? _themeProvider.wallpaperAssetPath!
        : (usesDefaultDoodle ? _themeProvider.defaultWallpaperAsset : null);
    final hasWallpaper = wallpaperAssetPath != null;

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
              onVoiceCall: () => _openCallScreen(isVideo: false),
              onVideoCall: () => _openCallScreen(isVideo: true),
              menuOptions: [
                KoraMenuOption(icon: Icons.person_outline, label: 'Contact info', onTap: () => _showContactInfo()),
                KoraMenuOption(icon: Icons.search, label: 'Search', onTap: () => _showChatSearch()),
                KoraMenuOption(icon: Icons.photo_library_outlined, label: 'Media & files', onTap: () {}),
                KoraMenuOption(icon: Icons.notifications_outlined, label: 'Mute notifications', onTap: () => _showMuteDialog()),
                KoraMenuOption(icon: Icons.palette_outlined, label: 'Chat theme', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DefaultChatThemeScreen()));
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
                      decoration: hasWallpaper
                          ? BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage(wallpaperAssetPath),
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
                  if ((hasWallpaper || hasWallpaperImage) && _themeProvider.wallpaperDimLevel > 0)
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
                                          onIssueTap: (issue) => _onIssueSelected(issue),
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

/// Kora's call screen — opened when user taps voice/video call.
/// Shows a full-screen gradient with the contact's info, call timer,
/// and mute/speaker/end buttons. This is a UI placeholder — actual
/// VoIP functionality will require a signaling backend.
class _CallScreen extends StatefulWidget {
  final String name;
  final bool isVideo;
  final String? avatarAsset;
  final String? avatarUrl;

  const _CallScreen({
    required this.name,
    required this.isVideo,
    this.avatarAsset,
    this.avatarUrl,
  });

  @override
  State<_CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<_CallScreen> {
  int _seconds = 0;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _duration {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A0D2E),
              Color(0xFF0D1B2A),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Call type icon
              Icon(
                widget.isVideo ? Icons.videocam : Icons.call,
                color: KoraColors.purple.withValues(alpha: 0.6),
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                widget.isVideo ? 'Video call' : 'Voice call',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              // Avatar
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: KoraColors.brandGradient,
                  boxShadow: [
                    BoxShadow(
                      color: KoraColors.purple.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Name
              Text(
                widget.name,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              // Duration
              Text(
                _seconds < 3 ? 'Calling…' : _duration,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(flex: 3),
              // Control buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute
                    GestureDetector(
                      onTap: () => setState(() => _isMuted = !_isMuted),
                      child: Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: _isMuted ? Colors.white : Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isMuted ? Icons.mic_off : Icons.mic,
                          color: _isMuted ? Colors.black : Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    // End call
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 64, height: 64,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                      ),
                    ),
                    // Speaker
                    GestureDetector(
                      onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                      child: Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: _isSpeakerOn ? Colors.white : Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.volume_up,
                          color: _isSpeakerOn ? Colors.black : Colors.white,
                          size: 24,
                        ),
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
