import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/message_service.dart';
import '../theme/kora_colors.dart';
import '../widgets/kora_avatar.dart';
import '../widgets/kora_badge.dart';
import 'chat/kora_chat_screen.dart';
import '../utils/kora_page_routes.dart';

/// Kora's global search — finds conversations, users, usernames, Kora IDs,
/// channels, and messages across ALL chats.
///
/// This replaces the old chat-only search. Results are grouped by:
/// 1. Chats (matched by name, last message)
/// 2. Messages (matched by text content across all conversations)
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';

  List<ChatPreview> _chatResults = [];
  Map<String, List<KoraMessage>> _messageResults = {};
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _onQueryChanged() {
    final q = _controller.text;
    if (q != _query) {
      _query = q;
      _performSearch();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    if (_query.trim().isEmpty) {
      setState(() {
        _chatResults = [];
        _messageResults = {};
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);

    // Search chats by name/last message
    final allChats = await ChatService.instance.getChats();
    final q = _query.toLowerCase();
    _chatResults = allChats.where((c) {
      final name = c.name.toLowerCase();
      final lastMsg = c.lastMessage.toLowerCase();
      final email = (c.recipientEmail ?? '').toLowerCase();
      return name.contains(q) || lastMsg.contains(q) || email.contains(q);
    }).toList();

    // Search across all messages
    _messageResults = await MessageService.instance.searchAllMessages(_query);

    if (mounted) setState(() => _searching = false);
  }

  void _openChat(ChatPreview chat) {
    pushSlideUp(
      context,
      KoraChatScreen(
        chatId: chat.id,
        name: chat.name,
        avatarAsset: chat.avatarAsset,
        avatarUrl: chat.avatarUrl,
        badge: chat.badge,
        isOnline: chat.isOnline,
        lastSeen: chat.isOnline ? null : 'last seen recently',
        recipientEmail: chat.recipientEmail,
      ),
    );
  }

  void _openChatWithMessage(ChatPreview chat) {
    _openChat(chat);
  }

  ChatPreview? _getChatForId(String chatId) {
    try {
      final chats = ChatService.instance.getCachedChats();
      return chats.firstWhere((c) => c.id == chatId);
    } catch (_) {
      // Not found in cache — create a minimal preview
      return ChatPreview(
        id: chatId,
        name: chatId.replaceAll('kora_support', 'Kora Support').replaceAll('kora_ai', 'Kora AI'),
        lastMessage: '',
        lastMessageTime: '',
        avatarAsset: null,
        avatarUrl: null,
        badge: null,
        isOnline: false,
        unreadCount: 0,
        recipientEmail: null,
      );
    }
  }

  int get _totalMessageHits =>
      _messageResults.values.fold(0, (sum, list) => sum + list.length);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: textMuted, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              onChanged: (v) { _query = v; _performSearch(); },
                              style: TextStyle(color: textPrimary, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Search chats, users, messages...',
                                hintStyle: TextStyle(color: textMuted, fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                              child: Icon(Icons.close, color: textMuted, size: 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    if (_query.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.travel_explore, size: 48, color: textMuted),
            const SizedBox(height: 16),
            Text(
              'Search Kora',
              style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Find conversations, users, usernames, Kora IDs, channels, and messages.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      );
    }

    if (_searching) {
      return Center(
        child: CircularProgressIndicator(color: KoraColors.purple),
      );
    }

    final hasResults = _chatResults.isNotEmpty || _messageResults.isNotEmpty;

    if (!hasResults) {
      return Center(
        child: Text(
          'No results for "$_query"',
          style: TextStyle(color: textSecondary, fontSize: 14),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // ── Chats section ──
        if (_chatResults.isNotEmpty) ...[
          _sectionHeader(context, 'CHATS (${_chatResults.length})'),
          ..._chatResults.map((chat) => ListTile(
            leading: KoraAvatar(
              name: chat.name,
              assetPath: chat.avatarAsset,
              imageUrl: chat.avatarUrl,
              size: 46,
            ),
            title: KoraNameWithBadge(
              name: chat.name,
              badge: chat.badge,
              style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              chat.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
            onTap: () => _openChat(chat),
          )),
        ],

        // ── Messages section ──
        if (_messageResults.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionHeader(context, 'MESSESSAGES ($_totalMessageHits)'),
          ..._messageResults.entries.expand((entry) {
            final chatId = entry.key;
            final messages = entry.value;
            final chat = _getChatForId(chatId);

            return messages.map((msg) {
              final snippet = msg.text.isNotEmpty
                  ? msg.text
                  : (msg.mediaCaption ?? '[${msg.type.name}]');
              return ListTile(
                leading: KoraAvatar(
                  name: chat?.name ?? chatId,
                  assetPath: chat?.avatarAsset,
                  imageUrl: chat?.avatarUrl,
                  size: 42,
                ),
                title: Text(
                  msg.isMe ? 'You' : (chat?.name ?? chatId),
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textSecondary, fontSize: 13, height: 1.3),
                ),
                onTap: () {
                  if (chat != null) _openChatWithMessage(chat);
                },
              );
            });
          }).toList(),
        ],
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String label) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          color: KoraColors.textMutedFor(brightness),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
