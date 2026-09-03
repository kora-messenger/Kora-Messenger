import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../widgets/secure_screen.dart';
import '../../services/anti_screenshot_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../models/chat_models.dart';
import '../../models/message_model.dart';
import '../../services/message_service.dart';
import '../../services/offline_voice_sync.dart';
import '../../services/audio_playback_service.dart';
import '../../services/chat_sound_service.dart';
import 'voice_translation_sheet.dart';
import 'forward_message_screen.dart';
import 'view_once_viewer.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import '../../config/kora_api.dart';
import '../../widgets/kora_menu_sheet.dart';
import 'chat_header.dart';
import 'message_bubble.dart';
import 'message_composer.dart';
import 'package:file_picker/file_picker.dart';
import 'call_screen.dart';
import 'message_action_menu.dart';
import 'message_info_screen.dart';
import '../../widgets/ai_chat_tools.dart';
import '../../ai/streaming/ai_stream_client.dart';
import '../../ai/streaming/ai_stream_event.dart';
import '../../ai/model/ai_request.dart';
import '../../widgets/ai_catch_me_up.dart';
import 'media_gallery_screen.dart';
import 'e2ee_verification_screen.dart';
import 'disappearing_messages_screen.dart';
import 'contact_info_screen.dart';
import 'group_chat_info_screen.dart';
import 'reply_preview.dart';
import 'chat_empty_state.dart';
import 'translate_sheet.dart';
import '../settings/default_chat_theme_screen.dart';
import '../settings/premium_subscribe_sheet.dart';
import '../settings/billing_screen.dart';
import '../../config/subscription_pricing.dart';
import '../../services/session_manager.dart';
import '../../services/spam_protection_service.dart';
import '../../services/conversation_directory.dart';
import '../suspension_screen.dart';
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
  final bool isGroupChat;
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
    this.isGroupChat = false,
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
  String? _highlightedMessageId;
  bool _isLoading = true;
  bool _screenshotBlocked = false;
  bool _isAiTyping = false;
  String? _aiStreamingText;
  bool _isBlocked = false;
  bool _isSpammer = false;
  int _spamScore = 0;
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

  void _checkScreenshotBlock() async {
    final chatId = widget.chatId;
    if (chatId == null) return;
    final enabled = await AntiScreenshotService.instance.isEnabled(chatId);
    if (mounted) setState(() => _screenshotBlocked = enabled);
  }

  @override
  void initState() {
    super.initState();
    _checkScreenshotBlock();
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
      // Check if the other user is flagged as a spammer (async, non-blocking)
      if (!_isAiChat && (widget.recipientEmail?.isNotEmpty ?? false)) {
        _checkSpamStatus();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }


  Future<void> _checkSpamStatus() async {
    if (widget.recipientEmail == null || widget.recipientEmail!.isEmpty) return;
    final spamStatus = await SpamProtectionService.instance.checkSpamStatus(widget.recipientEmail!);
    if (mounted) {
      setState(() {
        _isSpammer = spamStatus['isSpammer'] ?? false;
        _spamScore = spamStatus['spamScore'] ?? 0;
      });
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
    // Detect incoming messages (not from me) and play sound
    if (newMsgs.length > _messages.length) {
      final newOnes = newMsgs.sublist(_messages.length);
      for (final m in newOnes) {
        if (!m.isMe && !m.isAi) {
          ChatSoundService.instance.playIncoming();
          break; // one sound per refresh cycle
        }
      }
    }
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
    // Anti-spam: local rate limit check
    if (!SpamProtectionService.instance.canSendLocally(widget.chatId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You\'re sending messages too fast. Please slow down.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _runDetection(text);
    await _messageService.sendMessage(
      widget.chatId,
      text,
      replyToId: _replyTarget?.id,
      replyToText: _replyTarget?.text,
      replyToName: _replyTarget != null ? (_replyTarget!.isMe ? 'You' : widget.name) : null,
      replyToType: _replyTarget?.type,
      recipientEmail: widget.recipientEmail,
      recipientName: widget.name,
    );
    ChatSoundService.instance.playOutgoing();
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

  Future<void> _sendSticker(String sticker) async {
    _runDetection(sticker);
    await _messageService.sendMessage(
      widget.chatId,
      sticker,
      type: KoraMessageType.sticker,
      replyToId: _replyTarget?.id,
      replyToText: _replyTarget?.text,
      replyToName: _replyTarget != null ? (_replyTarget!.isMe ? 'You' : widget.name) : null,
      replyToType: _replyTarget?.type,
      recipientEmail: widget.recipientEmail,
      recipientName: widget.name,
    );
    ChatSoundService.instance.playOutgoing();
    setState(() {
      _messages = List.from(_messageService.getMessages(widget.chatId));
      _replyTarget = null;
    });
    _scrollToBottom();

    if (_isAiChat) {
      await _getAiResponse(sticker);
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
      replyToType: _replyTarget?.type,
      recipientEmail: widget.recipientEmail,
      recipientName: widget.name,
    );
    ChatSoundService.instance.playOutgoing();
    setState(() {
      _messages = List.from(_messageService.getMessages(widget.chatId));
      _replyTarget = null;
    });
    _scrollToBottom();
  }

  // ── Send video note (WhatsApp-style circular video message) ──
  void _sendVideoNote(String path, int durationSeconds) async {
    await _messageService.sendMediaMessage(
      widget.chatId,
      mediaPath: path,
      isVideo: true,
      isVideoNote: true,
      duration: durationSeconds,
      replyToId: _replyTarget?.id,
      replyToText: _replyTarget?.text,
      replyToName: _replyTarget != null ? (_replyTarget!.isMe ? 'You' : widget.name) : null,
      replyToType: _replyTarget?.type,
      recipientEmail: widget.recipientEmail,
      recipientName: widget.name,
    );
    ChatSoundService.instance.playOutgoing();
    setState(() {
      _messages = List.from(_messageService.getMessages(widget.chatId));
      _replyTarget = null;
    });
    _scrollToBottom();
  }

  // ── Send document ────────────────────────────────────
  void _sendDocument(String path, String fileName, int fileSize) async {
    final sizeStr = fileSize > 1024 * 1024
        ? '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(fileSize / 1024).toStringAsFixed(0)} KB';

    await _messageService.sendMessage(
      widget.chatId,
      '📎 $fileName ($sizeStr)',
      type: KoraMessageType.document,
      replyToId: _replyTarget?.id,
      replyToText: _replyTarget?.text,
      replyToName: _replyTarget != null ? (_replyTarget!.isMe ? 'You' : widget.name) : null,
      recipientEmail: widget.recipientEmail,
      recipientName: widget.name,
    );
    ChatSoundService.instance.playOutgoing();
    setState(() {
      _messages = List.from(_messageService.getMessages(widget.chatId));
      _replyTarget = null;
    });
    _scrollToBottom();
  }

  // ── Send contact (vCard) ─────────────────────────────
  void _sendContact(String name, String phone) async {
    await _messageService.sendMessage(
      widget.chatId,
      '👤 $name\n$phone',
      type: KoraMessageType.contact,
      replyToId: _replyTarget?.id,
      replyToText: _replyTarget?.text,
      replyToName: _replyTarget != null ? (_replyTarget!.isMe ? 'You' : widget.name) : null,
      recipientEmail: widget.recipientEmail,
      recipientName: widget.name,
    );
    ChatSoundService.instance.playOutgoing();
    setState(() {
      _messages = List.from(_messageService.getMessages(widget.chatId));
      _replyTarget = null;
    });
    _scrollToBottom();
  }

  // ── Send location ────────────────────────────────────
  void _sendLocation(double lat, double lng, String address) async {
    await _messageService.sendMessage(
      widget.chatId,
      '📍 $address',
      type: KoraMessageType.location,
      replyToId: _replyTarget?.id,
      replyToText: _replyTarget?.text,
      replyToName: _replyTarget != null ? (_replyTarget!.isMe ? 'You' : widget.name) : null,
      recipientEmail: widget.recipientEmail,
      recipientName: widget.name,
    );
    ChatSoundService.instance.playOutgoing();
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

    // Try streaming via the new orchestrator first; fall back to the old endpoint.
    try {
      final chatType = widget.chatId == 'kora_support' ? 'support' : 'ai';
      final history = _messages
          .where((m) => m.type != KoraMessageType.action && m.type != KoraMessageType.issueList)
          .map((m) => {'text': m.text, 'isMe': m.isMe})
          .toList();

      final request = AIRequest(
        conversationId: widget.chatId ?? 'kora_ai',
        message: userMessage,
        feature: chatType,
        history: history,
      );

      final streamClient = AIStreamClient();
      final stream = streamClient.streamMessage(request);
      final fullResponse = StringBuffer();
      bool streamed = false;

      await for (final event in stream) {
        if (!mounted) return;
        if (event is AIStreamTextDelta) {
          streamed = true;
          fullResponse.write(event.text);
          // Update the typing indicator with partial text
          setState(() => _aiStreamingText = fullResponse.toString());
        } else if (event is AIStreamMessageCompleted) {
          streamed = true;
          fullResponse.clear();
          fullResponse.write(event.fullText);
          break;
        } else if (event is AIStreamError) {
          // Fall through to legacy fallback
          streamed = false;
          break;
        }
      }

      if (streamed && fullResponse.isNotEmpty) {
        await _messageService.addIncomingMessage(
          widget.chatId,
          fullResponse.toString(),
          isAi: true,
        );
        if (mounted) {
          setState(() {
            _isAiTyping = false;
            _aiStreamingText = null;
          });
          _refreshMessages();
        }
        return;
      }

      // Legacy fallback — use the old non-streaming endpoint
      await _getAiResponseLegacy(userMessage);
    } catch (e) {
      // Fall back to legacy on any error
      await _getAiResponseLegacy(userMessage);
    }

    if (mounted) {
      setState(() {
        _isAiTyping = false;
        _aiStreamingText = null;
      });
      _refreshMessages();
    }
  }

  /// Legacy non-streaming AI response (fallback).
  Future<void> _getAiResponseLegacy(String userMessage) async {
    try {
      final chatType = widget.chatId == 'kora_support' ? 'support' : 'ai';
      final history = _messages
          .where((m) => m.type != KoraMessageType.action && m.type != KoraMessageType.issueList)
          .map((m) => {'text': m.text, 'isMe': m.isMe})
          .toList();

      final response = await http.post(
        Uri.parse(KoraApi.aiChatSupportEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chatType': chatType,
          'message': userMessage,
          'history': history,
        }),
      ).timeout(const Duration(seconds: 120));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final reply = data['reply'] as String? ??
          "I'm here to help! Could you tell me more?";
      final isWebSearch = data['isWebSearch'] as bool? ?? false;
      final issueList = data['issueList'] as List?;
      final actionLabel = data['actionLabel'] as String?;
      final actionType = data['actionType'] as String?;

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
      await _messageService.addIncomingMessage(
        widget.chatId,
        widget.chatId == 'kora_support'
            ? "I'm here to help with any Kora-related questions! Could you tell me more about what you need?"
            : "I'd be happy to help with that! Let me know a bit more about what you're looking for.",
        isAi: true,
      );
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
    final isPremium = ChatThemeProvider.instance.isPremium;

    // Check if the user is trying to add a 2nd/3rd reaction as a free user
    if (!isPremium) {
      final messages = _messageService.getMessages(widget.chatId);
      final msg = messages.where((m) => m.id == messageId).firstOrNull;
      if (msg != null && msg.reactions.isNotEmpty && !msg.reactions.contains(emoji)) {
        // Free user already has 1 reaction and is trying to add a different one → premium upsell
        if (mounted) {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => const PremiumSubscribeSheet(),
          );
        }
        return;
      }
    }

    await _messageService.toggleReaction(widget.chatId, messageId, emoji, isPremium: isPremium);
    _refreshMessages();
  }


  void _onDelete(String messageId) async {
    await _messageService.deleteMessage(widget.chatId, messageId);
    _refreshMessages();
  }

  void _onStar(String messageId) async {
    await _messageService.toggleStar(widget.chatId, messageId);
    _refreshMessages();
  }

  void _showMessageInfo(KoraMessage message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageInfoScreen(
          message: message,
          chatName: widget.name,
          isGroup: widget.isGroupChat,
        ),
      ),
    );
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

  /// Scroll to a specific message by ID and highlight it briefly.
  /// Used when the user taps a quoted reply to jump to the original.
  void _scrollToMessage(String messageId) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    
    final rk = _rowKeys.putIfAbsent(messageId, () => GlobalKey());
    
    // Use the row key to get the actual rendered position
    final ctx = rk.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5, // center the message in the viewport
      );
      
      // Brief highlight effect
      _highlightedMessageId = messageId;
      setState(() {});
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _highlightedMessageId = null;
          setState(() {});
        }
      });
    }
  }
  
  /// Reply to a message — sets the reply target and scrolls to compose.
  void _replyToMessage(KoraMessage message) {
    setState(() {
      _replyTarget = message;
    });
  }

  void _showMessageActions(GlobalKey key, KoraMessage message) {
    showKoraMessageActionMenu(
      context,
      messageKey: key,
      isMe: message.isMe,
      messageType: message.type,
      isPremium: ChatThemeProvider.instance.isPremium,
      currentReactionCount: message.reactions.length,
      isStarred: message.isStarred,
      onPremiumUpsell: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => const PremiumSubscribeSheet(),
        );
      },
      onReact: (emoji) => _onReact(message.id, emoji),
      onReply: () => setState(() => _replyTarget = message),
      onCopy: () => _onCopy(message.text),
      onForward: () => _onForward(message),
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
      onStar: () => _onStar(message.id),
      onMessageInfo: message.isMe ? () => _showMessageInfo(message) : null,
      onDelete: () => _onDelete(message.id),
      onReportSpam: !message.isMe ? () => _showReportSpamDialog(message) : null,
      onAskAI: _isAiChat ? null : () => AiChatTools.show(context, message.text),
    );
  }

  void _onForward(KoraMessage message) async {
    final count = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => ForwardMessageScreen(message: message),
      ),
    );
    if (count != null && count > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Forwarded to $count chat${count > 1 ? "s" : ""}'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onViewOnceMedia(KoraMessage message) async {
    final viewed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ViewOnceViewer(
          mediaPath: message.mediaPath,
          mediaUrl: message.mediaUrl,
          isVideo: message.type == KoraMessageType.video,
          thumbnailPath: message.mediaThumbnailPath,
        ),
      ),
    );
    if (viewed == true) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == message.id);
        if (idx >= 0) {
          _messages[idx] = _messages[idx].copyWith(isMediaPlayed: true);
        }
      });
    }
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
    // Show Group Chat Info if this is a group chat
    if (widget.isGroupChat) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatInfoScreen(
            groupName: widget.name,
            groupDescription: 'Group description',
            avatarUrl: widget.avatarUrl,
            avatarAsset: widget.avatarAsset,
            participants: [
              GroupParticipant(name: widget.name, koraId: 'me', isAdmin: true),
              GroupParticipant(name: 'Member', koraId: 'member1', isAdmin: false),
            ],
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            chatId: widget.chatId,
          ),
        ),
      );
      return;
    }

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
          chatId: widget.chatId,
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

  void _showMediaGallery() {
    final mediaMessages = _messages.where((m) =>
        m.type == KoraMessageType.image ||
        m.type == KoraMessageType.video ||
        m.type == KoraMessageType.document).toList();

    if (mediaMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No media in this chat yet.'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final mediaPaths = mediaMessages
        .where((m) => m.mediaPath != null)
        .map((m) => m.mediaPath!)
        .toList();

    if (mediaPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Media files are not cached locally.'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaGalleryScreen(
          mediaPaths: mediaPaths,
          chatName: widget.name,
        ),
      ),
    );
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


  // ── Report Spam ─────────────────────────────────────────────

  void _showReportSpamFromMenu() {
    _showReportSpamDialog(null);
  }

  void _showReportSpamDialog(KoraMessage? message) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final surface = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    String selectedReason = 'Spam';
    final reasons = ['Spam', 'Scam or fraud', 'Harassment', 'Inappropriate content', 'Other'];

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
                  child: const Icon(Icons.report_outlined, color: Colors.red, size: 26),
                ),
                const SizedBox(height: 18),
                Text(
                  'Report ${widget.name}?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  'Report this user for spam or abuse. Kora will review the report and take action if needed. They won\'t know you reported them.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 16),
                // Reason selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<String>(
                    value: selectedReason,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: TextStyle(color: textPrimary, fontSize: 14)))).toList(),
                    onChanged: (v) => setDialogState(() => selectedReason = v ?? 'Spam'),
                  ),
                ),
                const SizedBox(height: 12),
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
                        _performReportSpam(selectedReason, message);
                      },
                      child: const Text('Report', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 15)),
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

  Future<void> _performReportSpam(String reason, KoraMessage? message) async {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);

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
              Text('Submitting report...', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );

    final result = await SpamProtectionService.instance.reportSpam(
      reportedEmail: widget.recipientEmail ?? '',
      chatId: widget.chatId,
      messageId: message?.id,
      messageText: message?.text,
      reason: reason,
    );

    if (mounted) {
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['success'] == true
              ? result['autoFlagged'] == true
                  ? 'Reported. User has been flagged for review.'
                  : 'Report submitted. Thank you for keeping Kora safe.'
              : 'Failed to submit report. Please try again.'),
          backgroundColor: result['success'] == true ? KoraColors.purple : Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
    // Kora's signature professional wallpaper.
    final usesDefaultDoodle = _themeProvider.usesDefaultWallpaperAsset;
    final wallpaperAssetPath = hasWallpaperAsset
        ? _themeProvider.wallpaperAssetPath!
        : (usesDefaultDoodle ? _themeProvider.defaultWallpaperAsset : null);
    final hasWallpaper = wallpaperAssetPath != null;

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final scaffold = Scaffold(
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
                KoraMenuOption(icon: Icons.photo_library_outlined, label: 'Media & files', onTap: () => _showMediaGallery()),
                KoraMenuOption(icon: Icons.notifications_outlined, label: 'Mute notifications', onTap: () => _showMuteDialog()),
                KoraMenuOption(icon: Icons.timer_outlined, label: 'Disappearing messages', onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => DisappearingMessagesScreen(chatId: widget.chatId),
                  ));
                }),
                KoraMenuOption(icon: Icons.palette_outlined, label: 'Chat theme', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DefaultChatThemeScreen()));
                }),
                KoraMenuOption(icon: Icons.auto_awesome, label: 'Summarize chat', onTap: () => _showChatSummary()),
                KoraMenuOption(icon: Icons.access_time, label: 'Catch me up', onTap: () => _showCatchMeUp()),
                if (!_isAiChat) ...[
                  KoraMenuOption(icon: Icons.cleaning_services_outlined, label: 'Clear chat', onTap: () => _showClearChatDialog()),
                  KoraMenuOption(icon: Icons.block, label: 'Block', onTap: () => _showBlockDialog(), color: Colors.red),
                  KoraMenuOption(icon: Icons.report_outlined, label: 'Report', onTap: () => _showReportSpamFromMenu(), color: Colors.red),
                ],
              ],
            ),
            if (_isSpammer && !_showSearch) _buildSpamWarningBanner(),
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
                                          isHighlighted: _highlightedMessageId == message.id,
                                          onLongPress: () => _showMessageActions(rk, message),
                                          onReplyTap: message.replyToId != null ? () => _scrollToMessage(message.replyToId!) : null,
                                          onSwipeReply: () => _replyToMessage(message),
                                          onActionTap: () => _onActionTap(message),
                                          onIssueTap: (issue) => _onIssueSelected(issue),
                                          onCancelVoiceUpload: () => _onCancelVoiceUpload(message.id),
                                          onRetryVoiceUpload: () => _onRetryVoiceUpload(message.id),
                                          onSelfDestruct: () => _onSelfDestructVoice(message.id),
                                          onRetrySend: () => _onRetrySend(message.id),
                                          onViewOnceMedia: () => _onViewOnceMedia(message),
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
                        onSendSticker: _sendSticker,
                        onSendVoice: _sendVoice,
                        onMicTap: () => AudioPlaybackService.instance.stop(),
                        onSendMedia: _sendMedia,
                        onSendVideoNote: _sendVideoNote,
                        onSendDocument: _sendDocument,
                        onSendContact: _sendContact,
                        onSendLocation: _sendLocation,
                      ),
              ),
          ],
        ),
          ],
        ),
      ),
    );
      if (_screenshotBlocked) {
      return SecureScreen(child: scaffold);
    }
    return scaffold;
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


  /// Spam warning banner shown when the other user is flagged.
  Widget _buildSpamWarningBanner() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(color: Colors.orange.withValues(alpha: 0.2), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This user has been reported for spam. Be cautious.',
              style: TextStyle(
                color: textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() => _isSpammer = false); // dismiss
            },
            child: Icon(Icons.close, color: Colors.orange.shade700, size: 18),
          ),
        ],
      ),
    );
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
    final textPrimary = KoraColors.textPrimaryFor(brightness);

    // When streaming, show the partial response instead of just dots
    final hasStreamText = _aiStreamingText != null && _aiStreamingText!.isNotEmpty;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        child: hasStreamText
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _aiStreamingText!,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TypingDots(color: KoraColors.purple.withValues(alpha: 0.4)),
                        const SizedBox(width: 6),
                        Text('streaming', style: TextStyle(
                          fontSize: 10,
                          color: KoraColors.purple.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        )),
                      ],
                    ),
                  ],
                ),
              )
            : _TypingDots(color: KoraColors.purple.withValues(alpha: 0.6)),
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

class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = (_controller.value + i * 0.2) % 1.0;
            final scale = 0.5 + 0.5 * (0.5 - (progress - 0.5).abs() * 2);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Kora's call screen — opened when user taps voice/video call.
