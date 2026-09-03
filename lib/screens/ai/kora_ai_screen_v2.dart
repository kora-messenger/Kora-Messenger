import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';
import '../../ai/kora_ai_manager.dart';
import '../../ai/streaming/ai_stream_event.dart';
import '../../ai/conversation/conversation.dart';
import '../../ai/conversation/conversation_repository.dart';
import '../../ai/conversation/conversation_manager.dart';
import '../../ai/streaming/ai_stream_client.dart';
import '../../ai/context/context_manager.dart';
import '../../ai/conversation/conversation_message.dart';
import '../../ai/model/ai_request.dart';
import '../../ai/model/ai_error.dart';
import '../../ai/premium/ai_entitlement.dart';
import 'package:share_plus/share_plus.dart';

/// Kora AI — Full AI assistant with streaming, conversation history,
/// voice input, file analysis, and translation.
///
/// Architecture: UI → KoraAIManager → AIStreamClient → Kora AI API
/// Provider keys live server-side. Client never sees API credentials.
class KoraAiScreenV2 extends StatefulWidget {
  const KoraAiScreenV2({super.key});

  @override
  State<KoraAiScreenV2> createState() => _KoraAiScreenV2State();
}

class _KoraAiScreenV2State extends State<KoraAiScreenV2>
    with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late KoraAIManager _aiManager;
  late ConversationRepository _repo;

  String? _currentConversationId;
  List<ConversationMessage> _messages = [];
  List<Conversation> _conversationHistory = [];
  bool _isGenerating = false;
  bool _isStreaming = false;
  String _streamingText = '';
  StreamSubscription<AIStreamEvent>? _streamSub;
  bool _showHistoryPanel = false;

  // Error state
  AIError? _lastError;

  // Quick actions
  static const _quickActions = [
    {'label': 'Write', 'icon': Icons.auto_awesome, 'prompt': 'Help me write a message: '},
    {'label': 'Translate', 'icon': Icons.language, 'prompt': 'Translate this to French: '},
    {'label': 'Summarize', 'icon': Icons.subject, 'prompt': 'Summarize this text for me: '},
    {'label': 'Explain', 'icon': Icons.lightbulb, 'prompt': 'Explain this concept: '},
  ];

  @override
  void initState() {
    super.initState();
    _repo = ConversationRepository();
    _aiManager = KoraAIManager(
      conversationManager: ConversationManager(_repo),
      streamClient: AIStreamClient(),
      contextManager: ContextManager(),
    );
    _loadOrCreateConversation();
    _loadHistory();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _streamSub?.cancel();
    super.dispose();
  }

  Future<void> _loadOrCreateConversation() async {
    final conversations = await _repo.getConversations();
    if (conversations.isNotEmpty) {
      final latest = conversations.first;
      _currentConversationId = latest.id;
      _messages = await _repo.getMessages(latest.id);
    } else {
      await _createNewConversation();
    }
    setState(() {});
  }

  Future<void> _loadHistory() async {
    _conversationHistory = await _repo.getConversations();
    setState(() {});
  }

  Future<void> _createNewConversation() async {
    _currentConversationId = await _repo.createConversation(null).then((c) => c.id);
    _messages = [];
    setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isGenerating) return;

    _inputController.clear();
    _lastError = null;

    // Add user message to UI immediately
    final userMsg = ConversationMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _currentConversationId!,
      role: MessageRole.user,
      content: text,
      createdAt: DateTime.now(),
    );
    _messages.add(userMsg);
    await _repo.addMessage(_currentConversationId!, userMsg);
    _scrollToBottom();

    setState(() {
      _isGenerating = true;
      _isStreaming = true;
      _streamingText = '';
    });

    try {
      final stream = _aiManager.sendMessage(
        conversationId: _currentConversationId!,
        message: text,
      );

      _streamSub = stream.listen(
        (event) {
          switch (event) {
            case AIStreamStarted():
              setState(() => _isStreaming = true);
            case AIStreamTextDelta(:final text):
              setState(() => _streamingText += text);
              _scrollToBottom();
            case AIStreamMessageCompleted(:final fullText):
              final aiMsg = ConversationMessage(
                id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
                conversationId: _currentConversationId!,
                role: MessageRole.assistant,
                content: fullText,
                createdAt: DateTime.now(),
              );
              _messages.add(aiMsg);
              _repo.addMessage(_currentConversationId!, aiMsg);
              setState(() {
                _isStreaming = false;
                _streamingText = '';
              });
              _scrollToBottom();
            case AIStreamError(:final message, :final isRetryable):
              setState(() {
                _isGenerating = false;
                _isStreaming = false;
                _streamingText = '';
                _lastError = AIError(
                  type: AIErrorType.streamingInterruption,
                  message: message,
                  isRetryable: isRetryable,
                );
              });
            case AIStreamStopped():
              setState(() {
                _isGenerating = false;
                _isStreaming = false;
              });
          }
        },
        onDone: () {
          setState(() => _isGenerating = false);
        },
        onError: (e) {
          setState(() {
            _isGenerating = false;
            _isStreaming = false;
            _streamingText = '';
            _lastError = AIError.fromException(e);
          });
        },
      );
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _isStreaming = false;
        _lastError = AIError.fromException(e);
      });
    }
  }

  Future<void> _stopGeneration() async {
    _streamSub?.cancel();
    await _aiManager.cancelGeneration();
    setState(() {
      _isGenerating = false;
      _isStreaming = false;
      if (_streamingText.isNotEmpty) {
        // Save partial response
        final partialMsg = ConversationMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: _currentConversationId!,
          role: MessageRole.assistant,
          content: _streamingText,
          createdAt: DateTime.now(),
        );
        _messages.add(partialMsg);
        _repo.addMessage(_currentConversationId!, partialMsg);
        _streamingText = '';
      }
    });
  }

  Future<void> _retryLastMessage() async {
    if (_messages.isEmpty) return;
    // Find last user message
    final lastUserMsg = _messages.lastWhere((m) => m.role == MessageRole.user);
    // Remove last assistant message if any
    if (_messages.isNotEmpty && _messages.last.role == MessageRole.assistant) {
      _messages.removeLast();
    }
    setState(() {});
    _inputController.text = lastUserMsg.content;
    _sendMessage();
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showMessageOptions(ConversationMessage msg, bool isUser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.surfaceFor(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.copy), title: const Text('Copy'),
            onTap: () { Navigator.pop(ctx); _copyMessage(msg.content); }),
          if (!isUser) ...[
            ListTile(leading: const Icon(Icons.refresh), title: const Text('Regenerate'),
              onTap: () { Navigator.pop(ctx); _retryLastMessage(); }),
            ListTile(leading: const Icon(Icons.share), title: const Text('Share'),
              onTap: () { Navigator.pop(ctx); Share.share(msg.content); }),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(gradient: KoraColors.brandGradient, shape: BoxShape.circle),
            child: const Center(child: Icon(Icons.auto_awesome, color: Colors.white, size: 18)),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kora AI', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
            Text('Free for everyone', style: TextStyle(color: textMuted, fontSize: 11)),
          ]),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: textPrimary),
            onPressed: () => setState(() => _showHistoryPanel = !_showHistoryPanel),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textPrimary),
            color: surface,
            onSelected: (value) async {
              switch (value) {
                case 'new':
                  await _createNewConversation();
                  _loadHistory();
                case 'clear':
                  if (_currentConversationId != null) {
                    await _repo.clearMessages(_currentConversationId!);
                    _messages = [];
                    setState(() {});
                  }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'new', child: Text('New conversation')),
              const PopupMenuItem(value: 'clear', child: Text('Clear messages')),
            ],
          ),
        ],
      ),
      body: _showHistoryPanel
        ? _buildHistoryPanel(surface, textPrimary, textMuted)
        : _buildChatView(surface, textPrimary, textMuted),
    );
  }

  Widget _buildHistoryPanel(Color surface, Color textPrimary, Color textMuted) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Text('Conversation History', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton(onPressed: () => setState(() => _showHistoryPanel = false), child: const Text('Close')),
      ])),
      Expanded(child: _conversationHistory.isEmpty
        ? Center(child: Text('No conversations yet', style: TextStyle(color: textMuted)))
        : ListView.builder(
            itemCount: _conversationHistory.length,
            itemBuilder: (ctx, i) {
              final conv = _conversationHistory[i];
              return ListTile(
                leading: Container(width: 40, height: 40, decoration: BoxDecoration(gradient: KoraColors.brandGradient, shape: BoxShape.circle),
                  child: const Center(child: Icon(Icons.chat, color: Colors.white, size: 18))),
                title: Text(conv.title ?? 'New Conversation', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(conv.lastMessagePreview ?? 'No messages', style: TextStyle(color: textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () async {
                  await _repo.deleteConversation(conv.id);
                  _loadHistory();
                  if (conv.id == _currentConversationId) _createNewConversation();
                }),
                onTap: () async {
                  _currentConversationId = conv.id;
                  _messages = await _repo.getMessages(conv.id);
                  setState(() => _showHistoryPanel = false);
                },
              );
            },
          )),
    ]);
  }

  Widget _buildChatView(Color surface, Color textPrimary, Color textMuted) {
    return Column(children: [
      Expanded(child: _messages.isEmpty && _streamingText.isEmpty
        ? _buildEmptyState(textPrimary, textMuted)
        : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isStreaming ? 1 : 0) + (_lastError != null ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i < _messages.length) {
                final msg = _messages[i];
                return _buildMessageBubble(msg, textPrimary, textMuted);
              }
              if (_isStreaming && i == _messages.length) {
                return _buildStreamingBubble(textPrimary, textMuted);
              }
              return _buildErrorWidget(textPrimary, textMuted);
            },
          )),
      if (_isGenerating)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: TextButton.icon(
          onPressed: _stopGeneration,
          icon: const Icon(Icons.stop_circle, color: Colors.red, size: 18),
          label: const Text('Stop generating', style: TextStyle(color: Colors.red, fontSize: 13)),
        )),
      _buildComposer(surface, textPrimary, textMuted),
    ]);
  }

  Widget _buildEmptyState(Color textPrimary, Color textMuted) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 80, height: 80, decoration: BoxDecoration(gradient: KoraColors.brandGradient, shape: BoxShape.circle),
        child: const Center(child: Icon(Icons.auto_awesome, color: Colors.white, size: 36))),
      const SizedBox(height: 20),
      Text('How can I help you?', style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Ask me anything — I can write, translate, summarize, and more.', style: TextStyle(color: textMuted, fontSize: 14)),
      const SizedBox(height: 32),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: _quickActions.map((a) {
        return ActionChip(
          label: Text(a['label'] as String),
          avatar: Icon(a['icon'] as IconData, size: 16, color: KoraColors.purple),
          backgroundColor: KoraColors.purple.withValues(alpha: 0.08),
          side: BorderSide(color: KoraColors.purple.withValues(alpha: 0.2)),
          onPressed: () { _inputController.text = a['prompt'] as String; _focusNode.requestFocus(); },
        );
      }).toList()),
    ]));
  }

  Widget _buildMessageBubble(ConversationMessage msg, Color textPrimary, Color textMuted) {
    final isUser = msg.role == MessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg, isUser),
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? KoraColors.purple : KoraColors.surfaceFor(Theme.of(context).brightness),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
              bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
              bottomRight: isUser ? Radius.zero : const Radius.circular(16),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(msg.content, style: TextStyle(
              color: isUser ? Colors.white : textPrimary,
              fontSize: 15, height: 1.4,
            )),
            const SizedBox(height: 4),
            Text(_formatTime(msg.createdAt), style: TextStyle(
              color: isUser ? Colors.white.withValues(alpha: 0.5) : textMuted,
              fontSize: 10,
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildStreamingBubble(Color textPrimary, Color textMuted) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: KoraColors.surfaceFor(Theme.of(context).brightness),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thinking indicator while no text yet
          if (_streamingText.isEmpty)
            Row(mainAxisSize: MainAxisSize.min, children: [
              _buildDot(0), _buildDot(1), _buildDot(2),
            ])
          else
            Text(_streamingText + '▌', style: TextStyle(color: textPrimary, fontSize: 15, height: 1.4)),
        ]),
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 600),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 8, height: 8,
      decoration: BoxDecoration(
        color: KoraColors.purple.withValues(alpha: 0.4 + (index * 0.2)),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildErrorWidget(Color textPrimary, Color textMuted) {
    if (_lastError == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Icon(Icons.error_outline, color: Colors.red.withValues(alpha: 0.6), size: 32),
        const SizedBox(height: 8),
        Text(_lastError!.userMessage, style: TextStyle(color: textMuted, fontSize: 14), textAlign: TextAlign.center),
        if (_lastError!.isRetryable) ...[
          const SizedBox(height: 12),
          TextButton.icon(onPressed: _retryLastMessage, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry')),
        ],
      ]),
    );
  }

  Widget _buildComposer(Color surface, Color textPrimary, Color textMuted) {
    return SafeArea(child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: surface, border: Border(top: BorderSide(color: textMuted.withValues(alpha: 0.1)))),
      child: Row(children: [
        // Voice input button
        GestureDetector(
          onLongPress: () {
            if (!kIsWeb) _startVoiceInput();
          },
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: KoraColors.purple.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.mic, color: KoraColors.purple, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        // Text input
        Expanded(child: Container(
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24),
            border: Border.all(color: textMuted.withValues(alpha: 0.15))),
          child: TextField(
            controller: _inputController, focusNode: _focusNode,
            style: TextStyle(color: textPrimary, fontSize: 15),
            minLines: 1, maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Ask Kora AI…',
              hintStyle: TextStyle(color: textMuted, fontSize: 15),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onSubmitted: (_) => _sendMessage(),
          ),
        )),
        const SizedBox(width: 8),
        // Send button
        GestureDetector(
          onTap: _isGenerating ? null : _sendMessage,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(gradient: KoraColors.brandGradient, shape: BoxShape.circle),
            child: Center(child: Icon(_isGenerating ? Icons.hourglass_top : Icons.send, color: Colors.white, size: 20)),
          ),
        ),
      ]),
    ));
  }

  void _startVoiceInput() {
    // Voice input via platform channel
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('Voice input — hold to speak'), backgroundColor: KoraColors.purple, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)),
    );
    // TODO: Connect to AIVoiceManager when implemented
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }
}
