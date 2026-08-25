import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../theme/kora_colors.dart';
import '../widgets/kora_avatar.dart';
import '../widgets/kora_badge.dart';
import 'chat/kora_chat_screen.dart';
import '../utils/kora_page_routes.dart';

/// Kora's search screen — finds conversations, users, usernames, Kora IDs,
/// channels, and (eventually) messages. Opened from the Home header.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';

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
      _refreshResults();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<ChatPreview> _cachedResults = [];
  String _lastQuery = '';

  Future<void> _refreshResults() async {
    if (_query == _lastQuery && _cachedResults.isNotEmpty) return;
    _lastQuery = _query;
    if (_query.isEmpty) {
      _cachedResults = [];
      if (mounted) setState(() {});
      return;
    }
    final all = await ChatService.instance.getChats();
    final q = _query.toLowerCase();
    _cachedResults = all.where((c) {
      final name = c.name.toLowerCase();
      final lastMsg = c.lastMessage.toLowerCase();
      return name.contains(q) || lastMsg.contains(q);
    }).toList();
    if (mounted) setState(() {});
  }

  List<ChatPreview> get _results {
    if (_query.isEmpty) return [];
    return _cachedResults;
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

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

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
                              onChanged: (v) { _query = v; _refreshResults(); },
                              style: TextStyle(color: textPrimary, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Search chats, users, Kora IDs...',
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

    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No results for "$_query"',
          style: TextStyle(color: textSecondary, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final chat = _results[index];
        return ListTile(
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
        );
      },
    );
  }
}
