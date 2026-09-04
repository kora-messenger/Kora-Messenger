import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';
import '../../services/kora_ai_service.dart';

/// Kora AI Support — official product support assistant.
///
/// Different from Kora AI: this is specifically for troubleshooting
/// Kora Messenger and understanding Kora features.
class KoraSupportScreen extends StatefulWidget {
  const KoraSupportScreen({super.key});

  @override
  State<KoraSupportScreen> createState() => _KoraSupportScreenState();
}

class _KoraSupportScreenState extends State<KoraSupportScreen>
    with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late String _conversationId;
  List<KoraAiMessage> _messages = [];
  bool _isSending = false;
  bool _initialized = false;

  static const List<String> _suggestions = [
    "I can't receive my OTP",
    'How do I enable App Lock?',
    "My messages aren't sending",
    'How does translation work?',
  ];

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  Future<void> _initConversation() async {
    final prefs = await SharedPreferences.getInstance();
    final existingId = prefs.getString('kora_support_active_conversation');

    if (existingId != null) {
      _conversationId = existingId;
    } else {
      _conversationId =
          KoraAiService.instance.generateConversationId(isSupport: true);
      await prefs.setString('kora_support_active_conversation', _conversationId);
    }

    final history = await KoraAiService.instance.getHistory(
      conversationId: _conversationId,
      isSupport: true,
    );

    setState(() {
      _messages = history;
      _initialized = true;
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _inputController.text).trim();
    if (text.isEmpty || _isSending) return;

    _inputController.clear();

    setState(() {
      _messages.add(KoraAiMessage(role: 'user', content: text));
      _isSending = true;
    });
    _scrollToBottom();

    final result = await KoraAiService.instance.sendSupportMessage(
      message: text,
      conversationId: _conversationId,
    );

    setState(() {
      _isSending = false;
      if (result.success) {
        _messages.add(KoraAiMessage(role: 'assistant', content: result.response));
      } else {
        _messages.add(KoraAiMessage(
          role: 'assistant',
          content: 'Sorry, I couldn\'t connect to the support service. ${result.error ?? ''}',
        ));
      }
    });
    _scrollToBottom();
  }

  Future<void> _clearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.darkCard,
        title: Text(
          'Clear chat?',
          style: TextStyle(color: KoraColors.textPrimaryFor(Brightness.dark)),
        ),
        content: Text(
          "All messages in this chat will be deleted. This can't be undone.",
          style: TextStyle(color: KoraColors.textSecondaryFor(Brightness.dark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: KoraColors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await KoraAiService.instance.clearConversation(
      conversationId: _conversationId,
      isSupport: true,
    );
    setState(() => _messages.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.trueBlack,
      appBar: _buildAppBar(),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : Column(
              children: [
                Expanded(child: _buildChatArea()),
                _buildInputBar(),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [KoraColors.purple, KoraColors.blue],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.support_agent, color: Colors.white, size: 20),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Kora AI Support',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.greenAccent,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Official Support',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _clearChat,
                tooltip: 'Clear chat',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    if (_messages.isEmpty) {
      return _buildWelcome();
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _messages.length + (_isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isSending) {
          return _buildTypingIndicator();
        }
        final msg = _messages[index];
        return _buildMessage(msg);
      },
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [KoraColors.purple, KoraColors.blue],
                ),
                boxShadow: [
                  BoxShadow(
                    color: KoraColors.purple.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.support_agent, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Kora AI Support',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Official support for Kora Messenger. Ask about account issues, messaging, calls, security, and more.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KoraColors.textSecondaryFor(Brightness.dark),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _suggestions.map((s) => _buildSuggestionChip(s)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: KoraColors.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KoraColors.borderFor(Brightness.dark)),
        ),
        child: Text(
          text,
          style: const TextStyle(color: KoraColors.purple, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildMessage(KoraAiMessage msg) {
    final isUser = msg.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAiAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [KoraColors.purple, KoraColors.blue],
                      )
                    : null,
                color: isUser ? null : KoraColors.darkCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isUser ? const Radius.circular(18) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : KoraColors.textPrimaryFor(Brightness.dark),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(msg.timestamp),
                    style: TextStyle(
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.6)
                          : KoraColors.textMutedFor(Brightness.dark),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildUserAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildAiAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KoraColors.purple, KoraColors.blue],
        ),
      ),
      child: const Icon(Icons.support_agent, color: Colors.white, size: 18),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: KoraColors.darkCard,
      ),
      child: const Icon(Icons.person, color: KoraColors.purple, size: 18),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _buildAiAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: KoraColors.darkCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: KoraColors.darkSurface,
          border: Border(
            top: BorderSide(color: KoraColors.borderFor(Brightness.dark), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: KoraColors.darkCard,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _inputController,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Describe your issue...',
                    hintStyle: TextStyle(color: KoraColors.hintFor(Brightness.dark)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isSending ? null : () => _sendMessage(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [KoraColors.purple, KoraColors.blue],
                  ),
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

/// Animated typing indicator — three bouncing dots.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = (i * 0.2);
            final t = (_controller.value + offset) % 1.0;
            final scale = 0.5 + 0.5 * (1 - (2 * t - 1).abs());
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: KoraColors.purple,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
