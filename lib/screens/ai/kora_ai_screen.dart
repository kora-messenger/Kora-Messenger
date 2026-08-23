import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ai_features_service.dart';
import '../../services/kora_ai_service.dart';
import '../../theme/kora_colors.dart';

/// Kora AI — general-purpose intelligent assistant.
///
/// Supports text, image understanding, file analysis, web research, and conversation memory.
/// Free for all Kora Messenger users.
class KoraAiScreen extends StatefulWidget {
  const KoraAiScreen({super.key});

  @override
  State<KoraAiScreen> createState() => _KoraAiScreenState();
}

class _QuickActionItem {
  final String label;
  final IconData icon;
  final String templatePrompt;

  const _QuickActionItem({
    required this.label,
    required this.icon,
    required this.templatePrompt,
  });
}

class _KoraAiScreenState extends State<KoraAiScreen>
    with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  late String _conversationId;
  List<KoraAiMessage> _messages = [];
  bool _isSending = false;
  bool _initialized = false;

  // Pending image attachment (base64)
  String? _pendingImageBase64;
  File? _pendingImageFile;

  // Pending file attachment
  String? _pendingFileName;
  String? _pendingFileContent;

  static const List<String> _suggestions = [
    'What can you do?',
    'Help me write a message',
    'Translate a sentence',
    'Summarize this text for me',
    'Fix my grammar',
    'Explain a concept',
  ];

  static const List<_QuickActionItem> _quickActions = [
    _QuickActionItem(
      label: 'Write',
      icon: Icons.auto_awesome,
      templatePrompt: 'Help me write a message: ',
    ),
    _QuickActionItem(
      label: 'Translate',
      icon: Icons.language,
      templatePrompt: 'Translate this to French: ',
    ),
    _QuickActionItem(
      label: 'Summarize',
      icon: Icons.subject,
      templatePrompt: 'Summarize this text for me: ',
    ),
    _QuickActionItem(
      label: 'Grammar',
      icon: Icons.edit,
      templatePrompt: 'Fix my grammar in this text: ',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  Future<void> _initConversation() async {
    final prefs = await SharedPreferences.getInstance();
    final existingId = prefs.getString('kora_ai_active_conversation');

    if (existingId != null) {
      _conversationId = existingId;
    } else {
      _conversationId = KoraAiService.instance.generateConversationId();
      await prefs.setString('kora_ai_active_conversation', _conversationId);
    }

    final history = await KoraAiService.instance.getHistory(
      conversationId: _conversationId,
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

  Future<void> _pickImage() async {
    try {
      final xfile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 80,
      );
      if (xfile == null) return;

      final file = File(xfile.path);
      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);

      setState(() {
        _pendingImageFile = file;
        _pendingImageBase64 = base64Str;
        _pendingFileName = null;
        _pendingFileContent = null;
      });
    } catch (_) {
      // Silently ignore — user may have cancelled
    }
  }

  void _removePendingImage() {
    setState(() {
      _pendingImageFile = null;
      _pendingImageBase64 = null;
    });
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'json', 'csv'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      final ioFile = File(file.path!);
      final sizeInBytes = await ioFile.length();
      if (sizeInBytes > 100 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File is too large (>100KB). Please select a smaller file.'),
              backgroundColor: KoraColors.red,
            ),
          );
        }
        return;
      }

      final content = await ioFile.readAsString();
      setState(() {
        _pendingFileName = file.name;
        _pendingFileContent = content;
        _pendingImageFile = null;
        _pendingImageBase64 = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: KoraColors.red,
          ),
        );
      }
    }
  }

  void _removePendingFile() {
    setState(() {
      _pendingFileName = null;
      _pendingFileContent = null;
    });
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _inputController.text).trim();
    if (text.isEmpty && _pendingImageBase64 == null && _pendingFileContent == null) return;
    if (_isSending) return;

    _inputController.clear();
    final hasImage = _pendingImageBase64 != null;
    final hasFile = _pendingFileContent != null;

    String displayText = text;
    if (displayText.isEmpty) {
      if (hasImage) displayText = '[Image]';
      if (hasFile) displayText = '[File: $_pendingFileName]';
    } else if (hasFile) {
      displayText = '[File: $_pendingFileName] $text';
    }

    final fileContent = _pendingFileContent;
    final fileName = _pendingFileName;
    final imageBase64 = _pendingImageBase64;

    setState(() {
      _messages.add(KoraAiMessage(role: 'user', content: displayText));
      _isSending = true;
      _pendingImageFile = null;
      _pendingImageBase64 = null;
      _pendingFileName = null;
      _pendingFileContent = null;
    });
    _scrollToBottom();

    KoraAiResult result;
    if (hasFile && fileContent != null && fileName != null) {
      result = await AiFeaturesService.instance.analyzeFile(
        fileContent,
        fileName,
        text,
        conversationId: _conversationId,
      );
    } else if (hasImage && imageBase64 != null) {
      result = await AiFeaturesService.instance.analyzeImage(
        imageBase64,
        text,
        conversationId: _conversationId,
      );
    } else {
      result = await KoraAiService.instance.sendAiMessage(
        message: text,
        conversationId: _conversationId,
      );
    }

    setState(() {
      _isSending = false;
      if (result.success) {
        _messages.add(KoraAiMessage(role: 'assistant', content: result.response));
      } else {
        _messages.add(KoraAiMessage(
          role: 'assistant',
          content: 'Sorry, I couldn\'t connect. ${result.error ?? ''}',
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
          'Clear AI chat?',
          style: TextStyle(color: KoraColors.textPrimaryFor(Brightness.dark)),
        ),
        content: Text(
          'This will remove all messages from this conversation.',
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
    );
    setState(() => _messages.clear());
  }

  void _showContextMenu(BuildContext context, String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: KoraColors.borderFor(Brightness.dark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: KoraColors.purple),
              title: const Text(
                'Copy',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
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
                if (_pendingImageFile != null) _buildImagePreview(),
                if (_pendingFileName != null) _buildFilePreview(),
                _buildQuickActionsRow(),
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
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
              const Expanded(
                child: Text(
                  'Kora AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
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
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
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
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Kora AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your intelligent assistant. Ask me anything — questions, writing, translation, coding, analysis, and more.',
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
      child: GestureDetector(
        onLongPress: !isUser ? () => _showContextMenu(context, msg.content) : null,
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
      ),
    );
  }

  Widget _buildAiAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KoraColors.purple, KoraColors.blue],
        ),
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
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
            decoration: const BoxDecoration(
              color: KoraColors.darkCard,
              borderRadius: BorderRadius.only(
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

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _pendingImageFile!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Image ready to send',
            style: TextStyle(
              color: KoraColors.textSecondaryFor(Brightness.dark),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _removePendingImage,
            child: Icon(
              Icons.close,
              color: KoraColors.textSecondaryFor(Brightness.dark),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePreview() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: KoraColors.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KoraColors.purple.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file, color: KoraColors.purple, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _pendingFileName ?? 'Attached File',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _removePendingFile,
              child: Icon(
                Icons.close,
                color: KoraColors.textSecondaryFor(Brightness.dark),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    return Container(
      height: 36,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _quickActions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final action = _quickActions[index];
          return ActionChip(
            avatar: Icon(action.icon, size: 15, color: KoraColors.purple),
            label: Text(
              action.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: KoraColors.darkCard,
            side: BorderSide(color: KoraColors.borderFor(Brightness.dark)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: () {
              _inputController.text = action.templatePrompt;
              _inputController.selection = TextSelection.fromPosition(
                TextPosition(offset: _inputController.text.length),
              );
              _focusNode.requestFocus();
            },
          );
        },
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
            // Image picker button
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: KoraColors.darkCard,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.image_outlined,
                  color: KoraColors.textSecondaryFor(Brightness.dark),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Paperclip/attach file button
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: KoraColors.darkCard,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.attach_file,
                  color: KoraColors.textSecondaryFor(Brightness.dark),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
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
                    hintText: 'Ask Kora AI anything...',
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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
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
