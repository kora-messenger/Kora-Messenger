import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../models/chat_models.dart';
import '../../models/message_model.dart';
import '../../services/message_service.dart';
import '../../services/offline_voice_sync.dart';
import '../../services/audio_playback_service.dart';
import 'voice_translation_sheet.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import '../../config/kora_api.dart';
import '../../widgets/kora_menu_sheet.dart';
import 'chat_header.dart';
import 'message_bubble.dart';
import 'message_composer.dart';
import 'call_screen.dart';
import 'message_action_menu.dart';
import 'contact_info_screen.dart';
import 'reply_preview.dart';
import 'chat_empty_state.dart';
import 'translate_sheet.dart';
import '../settings/default_chat_theme_screen.dart';
import '../settings/premium_subscribe_sheet.dart';
import '../settings/billing_screen.dart';
import '../../config/subscription_pricing.dart';
import '../../services/session_manager.dart';
import '../../services/conversation_directory.dart';
import '../suspension_screen.dart';
import '../settings/chat_backup_screen.dart';
import 'ai_chat_summary_sheet.dart';

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
  final String? recipientEmail;

  const KoraChatScreen({
    super.key,
    required this.chatId,
    required this.name,
    this.avatarAsset,
    this.avatarUrl,
    this.badge = KoraBadgeType.none,
    this.isOnline = false,
    this.lastSeen,
    this.recipientEmail,
  });

  @override
  State<KoraChatScreen> createState() => _KoraChatScreenState();
}

class _KoraChatScreenState extends State<KoraChatScreen> {
  String? _userEmail;

  final _scrollController = ScrollController();
  final _messageService = MessageService.instance;
  final _themeProvider = ChatThemeProvider.instance;

  List<KoraMessage> _messages = [];
  final Map<String, GlobalKey> _rowKeys = {};
  KoraMessage? _replyTarget;
  bool _isLoading = true;
  bool _isAiTyping = false;
  bool _isBlocked = false;
  Timer? _statusTimer;
  StreamSubscription<String>? _syncSub;

  // New-messages indicator (down arrow with count)
  bool _isAtBottom = true;
  int _newMessagesCount = 0;

  // Inline chat search
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<KoraMessage> _searchResults = [];

  bool get _isAiChat =>
      widget.chatId == 'kora_support' || widget.chatId == 'kora_ai';

  @override
  void initState() {
    super.initState();
    _loadEmail();
    _themeProvider.addListener(_onThemeChanged);
    // Register this conversation in the directory so it appears
    // on the Home screen with correct name/avatar/badge/online state.
    ConversationDirectoryService.instance.upsert(
      chatId: widget.chatId,
      name: widget.name,
      avatarAsset: widget.avatarAsset,
      avatarUrl: widget.avatarUrl,
      badge: widget.badge,
      isOnline: widget.isOnline,
      recipientEmail: widget.recipientEmail,
    );
    _loadMessages();
    _scrollController.addListener(_onScrollChanged);
    // Listen for offline voice sync events — when a pending note
    // transitions to sent, refresh the message list.
    _syncSub = OfflineVoiceSyncService.instance.syncStream.listen((chatId) {
      if (chatId == widget.chatId && mounted) {
        _refreshMessages();
      }
    });
    // Poll for status changes (sent → delivered → read) and mark
    // newly-arrived incoming messages as viewed while the chat is open.
    // 300ms keeps the ticks feeling instant without burning CPU.
    _statusTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) return;
      _messageService.markChatViewed(widget.chatId);
      _refreshMessages();
    });
  }

  
  Future<void> _loadEmail() async {
    final session = await SessionManager.instance.loadSession();
    if (session != null && mounted) {
      setState(() {
        _userEmail = session['email']?.toString() ?? '';
      });
    }
  }

@override
  void dispose() {
    _searchController.dispose();
    _statusTimer?.cancel();
    _syncSub?.cancel();
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
    // Auto-translate new messages if enabled (WhatsApp auto_translation)
    await _messageService.autoTranslateChat(widget.chatId);
    _messages = List.from(_messageService.getMessages(widget.chatId));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isBlocked = _messageService.isBlocked(widget.chatId);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  String _formatChatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} kB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openBlockingInfo() async {
    final uri = Uri.parse(KoraApi.blockingInfoUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    // Consider "at bottom" if within 80px of the end
    final atBottom = (maxScroll - currentScroll) < 80;
    if (atBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = atBottom;
        if (atBottom) _newMessagesCount = 0;
      });
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
    setState(() {
      _isAtBottom = true;
      _newMessagesCount = 0;
    });
  }

  void _refreshMessages() {
    final newMsgs = _messageService.getMessages(widget.chatId);
    // Count new messages that arrived while the user is scrolled up
    if (!_isAtBottom && newMsgs.length > _messages.length) {
      _newMessagesCount += newMsgs.length - _messages.length;
    }
    _messages = List.from(newMsgs);
    setState(() {});
    // Do NOT scroll here — this is called by the periodic timer every 500ms.
    // Scrolling here prevents the user from scrolling up to read older messages.
  }

  Future<void> _sendMessage(String text) async {
    _runDetection(text);
    await _messageService.sendMessage(
      widget.chatId,
      text,
      replyToId: _replyTarget?.id,
      replyToText: _replyTarget?.text,
      replyToName: _replyTarget != null ? (_replyTarget!.isMe ? 'You' : widget.name) : null,
      recipientEmail: widget.recipientEmail,
      recipientName: widget.name,
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

  void _sendMedia(
    String path, bool isVideo, String? caption, bool isViewOnce, bool isHD, double? width, double? height,
  ) async {
    await _messageService.sendMediaMessage(
      widget.chatId,
      mediaPath: path,
      isVideo: isVideo,
      caption: caption,
      isViewOnce: isViewOnce,
      isHD: isHD,
      width: width,
      height: height,
      replyToId: _replyTarget?.id,
      replyToText: _replyTarget?.text,
      replyToName: _replyTarget != null ? (_replyTarget!.isMe ? 'You' : widget.name) : null,
      recipientEmail: widget.recipientEmail,
      recipientName: widget.name,
    );
    setState(() {
      _messages = List.from(_messageService.getMessages(widget.chatId));
      _replyTarget = null;
    });
    _scrollToBottom();
  }

  void _runDetection(String messageContent) async {
    try {
      final sessionEmail = SessionManager.instance.currentEmail;
      final sessionUser = SessionManager.instance.currentUser;
      final userKoraId = sessionUser?.koraId ?? '';
      final username = sessionUser?.username ?? '';

      final resp = await http.post(
        Uri.parse(KoraApi.autoDetectEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'analyzeMessage',
          'userEmail': sessionEmail,
          'userKoraId': userKoraId,
          'username': username,
          'messageContent': messageContent,
        }),
      );

      final data = jsonDecode(resp.body);
      if (data['suspended'] == true && mounted) {
        await SessionManager.instance.clearSession();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => SuspensionScreen(
              email: sessionEmail,
              suspensionReason: data['message'] ?? 'Your account has been suspended for violating Kora Messenger Community Guidelines.',
              isPermanent: data['isPermanent'] ?? false,
            ),
          ),
          (route) => false,
        );
      }
    } catch (_) {}
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
      ).timeout(const Duration(seconds: 120));

      // Log HTTP status if not 200
      if (response.statusCode != 200) {
        debugPrint('[Kora AI] HTTP ${response.statusCode} — ${response.body.substring(0, (response.body.length > 300 ? 300 : response.body.length))}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final success = data['success'] as bool? ?? true;
      final reply = data['reply'] as String? ??
          "I'm here to help! Could you tell me more?";

      // Log the actual error for developers when the AI request fails
      if (!success) {
        final errorDetail = data['error'] as String? ?? 'Unknown error';
        debugPrint('[Kora AI] Request failed — chatType=$chatType, error=$errorDetail');
      }
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

  void _sendVoice(
    String duration, {
    String? filePath,
    String? transcript,
    String? translatedLanguageCode,
    String? translatedLanguageName,
    bool isPlayOnce = false,
  }) async {
    await _messageService.sendVoiceMessage(
      widget.chatId,
      duration,
      filePath: filePath,
      transcript: transcript,
      translatedLanguageCode: translatedLanguageCode,
      translatedLanguageName: translatedLanguageName,
      isPlayOnce: isPlayOnce,
      recipientEmail: widget.recipientEmail,
      recipientName: widget.name,
    );
    setState(() {
      _messages = List.from(_messageService.getMessages(widget.chatId));
    });
    _scrollToBottom();
  }

  /// Auto-deletes a play-once voice note after the recipient plays it.
  void _onSelfDestructVoice(String messageId) async {
    await _messageService.deleteMessage(widget.chatId, messageId);
    setState(() {
      _messages = List.from(_messageService.getMessages(widget.chatId));
    });
  }

  /// Tap the "X" on an in-flight voice upload — cancels the attempt
  /// without deleting the note; it switches to the tap-to-retry look
  /// but stays in the background sync queue for auto-upload later.
  void _onCancelVoiceUpload(String messageId) async {
    await _messageService.cancelVoiceUpload(widget.chatId, messageId);
    _refreshMessages();
  }

  /// Tap the retry arrow on a not-sent voice note. Returns whether the
  /// device is online so [VoiceMessageBubble] can show its own error.
  Future<bool> _onRetryVoiceUpload(String messageId) async {
    final online = await _messageService.retryVoiceUpload(widget.chatId, messageId);
    _refreshMessages();
    return online;
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

  /// Translate a message — WhatsApp-style persistent translation.
  /// Persists the translated text on the message record so it doesn't
  /// need to be re-translated every time the chat is opened.
  void _onTranslate(KoraMessage message) {
    if (!ChatThemeProvider.instance.isPremium) {
      _showPremiumSheetForTranslation();
      return;
    }

    // If already translated, show the translate sheet with the existing translation
    if (message.translatedText != null) {
      TranslateSheet.show(context, message.text);
      return;
    }

    // Translate and persist on the message
    MessageService.instance.translateMessage(
      widget.chatId,
      message.id,
    ).then((translated) {
      if (translated != null && mounted) {
        setState(() {}); // refresh bubbles to show translated text
      } else if (mounted) {
        // Fallback to the translate sheet if API fails
        TranslateSheet.show(context, message.text);
      }
    });
  }

  void _showPremiumSheetForTranslation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PremiumSubscribeSheet(),
    );
  }

  /// Retry sending a message that failed (status = unsent).
  /// Mirrors WhatsApp's RetrySend mechanism.
  void _onRetrySend(String messageId) async {
    await _messageService.retrySingleMessage(widget.chatId, messageId);
    if (mounted) {
      _messages = List.from(_messageService.getMessages(widget.chatId));
      setState(() {});
    }
  }

  void _showMessageActions(GlobalKey key, KoraMessage message) {
    showKoraMessageActionMenu(
      context,
      messageKey: key,
      isMe: message.isMe,
      messageType: message.type,
      onReact: (emoji) => _onReact(message.id, emoji),
      onReply: () => setState(() => _replyTarget = message),
      onCopy: () => _onCopy(message.text),
      onForward: () {},
      onTranslate: () => _onTranslate(message),
      onTranscribeVoice: message.type == KoraMessageType.voice && ChatThemeProvider.instance.isPremium
          ? () => VoiceTranslationSheet.show(
              context,
              voiceDuration: message.voiceDuration ?? '0:05',
              autoTranslate: false,
            )
          : null,
      onTranslateVoice: message.type == KoraMessageType.voice && ChatThemeProvider.instance.isPremium
          ? () => VoiceTranslationSheet.show(
              context,
              voiceDuration: message.voiceDuration ?? '0:05',
              autoTranslate: true,
            )
          : null,
      onDelete: () => _onDelete(message.id),
    );
  }

  void _openCallScreen({required bool isVideo}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          contactName: widget.name,
          isVideoCall: isVideo,
          isOutgoing: true,
          avatarUrl: widget.avatarUrl,
          badge: widget.badge,
        ),
      ),
    ).then((result) {
      // Call logging is handled by CallScreen itself via CallService.
    });
  }

  Future<void> _onActionTap(KoraMessage message) async {
    if (message.actionType == 'subscribe_premium') {
      final plan = await showModalBottomSheet<SubscriptionPlan>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const PremiumSubscribeSheet(),
      );
      if (plan != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BillingScreen(selectedPlan: plan, userEmail: _userEmail ?? '')),
        );
      }
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

  Future<void> _showContactInfo() async {
    // Default values from chat data
    String koraId = '';
    String username = '';
    String about = 'Hey there! I am using Kora Messenger.';
    String? phone;
    String fullName = widget.name;
    String? avatarUrl = widget.avatarUrl;

    // Fetch real profile from backend using recipient email
    if (widget.recipientEmail != null && widget.recipientEmail!.isNotEmpty && !_isAiChat) {
      try {
        final resp = await http.post(
          Uri.parse(KoraApi.lookupByEmailEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': widget.recipientEmail,
          }),
        );
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          if (data['success'] == true && data['found'] == true && data['user'] != null) {
            final user = data['user'] as Map<String, dynamic>;
            koraId = user['koraId']?.toString() ?? '';
            username = user['username']?.toString() ?? '';
            fullName = user['fullName']?.toString() ?? widget.name;
            about = user['bio']?.toString() ?? about;
            phone = (user['phoneNumber'] != null && user['phoneNumber'].toString().isNotEmpty)
                ? user['phoneNumber'].toString()
                : null;
            if (user['avatarUrl'] != null && user['avatarUrl'].toString().isNotEmpty) {
              avatarUrl = user['avatarUrl'].toString();
            }
          }
        }
      } catch (_) {
        // Fall back to chat data if lookup fails
      }
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactInfoScreen(
          name: fullName,
          avatarAsset: widget.avatarAsset,
          avatarUrl: avatarUrl,
          badge: widget.badge,
          isOnline: _isAiChat ? true : widget.isOnline,
          lastSeen: _isAiChat ? 'AI Assistant' : widget.lastSeen,
          koraId: koraId.isNotEmpty ? koraId : null,
          username: username.isNotEmpty ? username : null,
          about: about,
          phone: phone,
          recipientEmail: widget.recipientEmail,
          isAiChat: _isAiChat,
        ),
      ),
    );
  }

  void _showChatSearch() {
    setState(() {
      _showSearch = true;
      _searchQuery = '';
      _searchResults = [];
    });
  }

  void _hideSearch() {
    setState(() {
      _showSearch = false;
      _searchController.clear();
      _searchQuery = '';
      _searchResults = [];
    });
  }

  void _doSearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _searchResults = [];
      } else {
        final lower = query.toLowerCase();
        _searchResults = _messages.where((m) => m.text.toLowerCase().contains(lower)).toList();
      }
    });
  }

  Widget _buildSearchBar() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: KoraColors.cardFor(brightness),
        border: Border(
          bottom: BorderSide(color: KoraColors.borderFor(brightness), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: textPrimary, size: 22),
              onPressed: _hideSearch,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _doSearch,
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: textSecondary, size: 20),
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                ),
                style: TextStyle(color: textPrimary, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    if (_searchQuery.isEmpty) {
      return Center(
        child: Text('Start typing to search', style: TextStyle(color: textSecondary, fontSize: 14)),
      );
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Text('No messages found', style: TextStyle(color: textSecondary, fontSize: 14)),
      );
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final msg = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: msg.isMe ? KoraColors.purple : KoraColors.cardFor(brightness),
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
    );
  }

  // ── Clear chat ──────────────────────────────────────────────

  void _showClearChatDialog() {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final sizeLabel = _formatChatSize(_messageService.chatSizeBytes(widget.chatId));
    bool alsoClearStarred = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.close, color: textPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'Clear chat',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'All messages in this chat will be deleted. This cannot be undone.',
                      style: TextStyle(color: textSecondary, fontSize: 15, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: border, height: 1),
                  CheckboxListTile(
                    value: alsoClearStarred,
                    onChanged: (v) => setDialogState(() => alsoClearStarred = v ?? false),
                    title: Text('Clear starred messages', style: TextStyle(color: textPrimary, fontSize: 15)),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: KoraColors.purple,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _messageService.clearChat(
                            widget.chatId,
                            keepStarred: !alsoClearStarred,
                          );
                          _refreshMessages();
                          if (mounted) {
                            SchedulerBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Chat cleared'),
                                    backgroundColor: KoraColors.purple,
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            });
                          }
                        },
                        child: Text(
                          'Clear chat ($sizeLabel)',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Block ────────────────────────────────────────────────────

  void _showBlockDialog() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final surface = KoraColors.cardFor(brightness);
    bool reportToKora = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: const Icon(Icons.block, color: Colors.red, size: 26),
                ),
                const SizedBox(height: 18),
                Text(
                  'Block ${widget.name}?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  "This person won't be able to message or call you. They won't know you blocked or reported them.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => setDialogState(() => reportToKora = !reportToKora),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: reportToKora,
                          onChanged: (v) => setDialogState(() => reportToKora = v ?? false),
                          activeColor: KoraColors.purple,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Report to Kora',
                                  style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'The last 5 messages in this chat will be sent to Kora.',
                                  style: TextStyle(color: textSecondary, fontSize: 12, height: 1.3),
                                ),
                                GestureDetector(
                                  onTap: _openBlockingInfo,
                                  child: const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Learn more',
                                      style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _performBlock(reportToKora);
                      },
                      child: const Text('Block', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _performBlock(bool reportToKora) async {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);

    // Loading dialog — "Please wait a moment" while we process the block
    // (and, if selected, send the report to Kora).
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(color: KoraColors.purple, strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Text('Please wait a moment...', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 5));
    await _messageService.setBlocked(widget.chatId, true);

    if (mounted) {
      Navigator.pop(context); // dismiss loading dialog
      setState(() => _isBlocked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reportToKora
              ? '${widget.name} has been blocked and reported.'
              : '${widget.name} has been blocked.'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _unblock() async {
    await _messageService.setBlocked(widget.chatId, false);
    if (mounted) {
      setState(() => _isBlocked = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.name} has been unblocked.'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteChat() async {
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
              Text('Delete this chat?', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
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

    if (confirmed == true) {
      await _messageService.deleteChat(widget.chatId);
      if (mounted) Navigator.pop(context); // leave the chat screen
    }
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

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.wallpaper,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Fixed full-screen wallpaper layer ──
            // Sits behind everything at a constant size so it never
            // rescales/shifts when the keyboard opens or closes —
            // only the AnimatedPadding around the composer should move.
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
            // ── Foreground content ──
            Column(
          children: [
            // When searching, show the inline search bar instead of the chat header.
            if (_showSearch)
              _buildSearchBar()
            else
            ChatHeader(
              name: widget.name,
              avatarAsset: widget.avatarAsset,
              avatarUrl: widget.avatarUrl,
              badge: widget.badge,
              isOnline: _isAiChat ? true : widget.isOnline,
              lastSeen: _isAiChat ? 'AI Assistant' : widget.lastSeen,
              onBack: () => Navigator.pop(context),
              onAvatarTap: _showContactInfo,
              onVoiceCall: _isAiChat ? null : () => _openCallScreen(isVideo: false),
              onVideoCall: _isAiChat ? null : () => _openCallScreen(isVideo: true),
              menuOptions: [
                KoraMenuOption(icon: Icons.person_outline, label: 'Contact info', onTap: () => _showContactInfo()),
                KoraMenuOption(icon: Icons.search, label: 'Search', onTap: () => _showChatSearch()),
                KoraMenuOption(icon: Icons.photo_library_outlined, label: 'Media & files', onTap: () {}),
                KoraMenuOption(icon: Icons.notifications_outlined, label: 'Mute notifications', onTap: () => _showMuteDialog()),
                KoraMenuOption(icon: Icons.palette_outlined, label: 'Chat theme', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DefaultChatThemeScreen()));
                }),
                KoraMenuOption(icon: Icons.cloud_outlined, label: 'Chat backup', onTap: () {
  Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatBackupScreen()));
}),
                KoraMenuOption(icon: Icons.auto_awesome, label: 'Summarize chat', onTap: () => _showChatSummary()),
                KoraMenuOption(icon: Icons.access_time, label: 'Catch me up', onTap: () => _showCatchMeUp()),
                KoraMenuOption(icon: Icons.cleaning_services_outlined, label: 'Clear chat', onTap: () => _showClearChatDialog()),
                if (!_isAiChat) ...[
                  KoraMenuOption(icon: Icons.block, label: 'Block', onTap: () => _showBlockDialog(), color: Colors.red),
                  KoraMenuOption(icon: Icons.report_outlined, label: 'Report', onTap: () => _showBlockDialog(), color: Colors.red),
                ],
              ],
            ),
            // Message area (or search results when searching).
            // Wallpaper now lives in the fixed background layer above,
            // so this area stays transparent and never rescales it.
            Expanded(
              child: _showSearch
                ? _buildSearchResults()
                : Stack(
                children: [
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
                                          onCancelVoiceUpload: () => _onCancelVoiceUpload(message.id),
                                          onRetryVoiceUpload: () => _onRetryVoiceUpload(message.id),
                                          onSelfDestruct: () => _onSelfDestructVoice(message.id),
                                          onRetrySend: () => _onRetrySend(message.id),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                  ),
                  // ── New-messages indicator ──
                  // Shows a down-arrow with count when new messages arrive
                  // while the user has scrolled up to read older messages.
                  if (!_showSearch && !_isAtBottom && _newMessagesCount > 0)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _scrollToBottom,
                          child: AnimatedScale(
                            scale: 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: KoraColors.cardFor(Theme.of(context).brightness),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: KoraColors.borderFor(Theme.of(context).brightness),
                                  width: 0.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      gradient: KoraColors.brandGradient,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$_newMessagesCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: KoraColors.textSecondaryFor(Theme.of(context).brightness),
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Reply preview
            if (_replyTarget != null && !_showSearch)
              ReplyPreview(
                name: _replyTarget!.isMe ? 'You' : widget.name,
                text: _replyTarget!.text,
                onCancel: () => setState(() => _replyTarget = null),
              ),
            // Composer or blocked-state bar — hidden during search
            if (!_showSearch)
              // Plain Padding (no extra animation layer) — the OS reports
              // viewInsets.bottom frame-by-frame as the keyboard animates,
              // so tracking it directly here keeps the composer perfectly
              // glued to the keyboard on both open AND close, with zero
              // lag. A separate AnimatedPadding/AnimatedContainer here
              // would re-animate on its own timer/curve, fighting the
              // system keyboard animation and causing a visible delay
              // (most noticeable when the keyboard closes).
              Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: _isBlocked && !_isAiChat
                    ? _buildBlockedBar()
                    : MessageComposer(
                        onSend: _sendMessage,
                        onSendVoice: _sendVoice,
                        onMicTap: () => AudioPlaybackService.instance.stop(),
                        onSendMedia: _sendMedia,
                      ),
              ),
          ],
        ),
          ],
        ),
      ),
    );
  }

  /// Show AI chat summary sheet.
  void _showChatSummary() {
    final messages = _messages
        .where((m) => m.type != KoraMessageType.action && m.type != KoraMessageType.issueList)
        .map((m) => {
              'sender': m.isMe ? 'Me' : widget.name,
              'text': m.text,
              'timestamp': m.timestamp.toIso8601String(),
            })
        .toList();

    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No messages to summarize.'),
          backgroundColor: KoraColors.purple,
        ),
      );
      return;
    }

    AiChatSummarySheet.show(context, messages, isCatchMeUp: false);
  }

  /// Show AI Catch Me Up sheet.
  void _showCatchMeUp() {
    final messages = _messages
        .where((m) => m.type != KoraMessageType.action && m.type != KoraMessageType.issueList)
        .map((m) => {
              'sender': m.isMe ? 'Me' : widget.name,
              'text': m.text,
              'timestamp': m.timestamp.toIso8601String(),
            })
        .toList();

    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No messages to catch up on.'),
          backgroundColor: KoraColors.purple,
        ),
      );
      return;
    }

    // Count messages that aren't from the user (missed messages)
    final missedCount = _messages.where((m) => !m.isMe && m.type != KoraMessageType.action).length;

    AiChatSummarySheet.show(context, messages, isCatchMeUp: true, missedCount: missedCount);
  }

  /// The blocked-state bar shown at the bottom of a chat when the
  /// user has blocked the person they're talking to. Mirrors WhatsApp's
  /// pattern: a notice + "Unblock" and "Delete chat" buttons.
  Widget _buildBlockedBar() {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You blocked this person. Tap to unblock.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: KoraColors.purple.withValues(alpha: 0.5), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: _unblock,
                    child: const Text('Unblock', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: _deleteChat,
                    child: const Text('Delete chat', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
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
