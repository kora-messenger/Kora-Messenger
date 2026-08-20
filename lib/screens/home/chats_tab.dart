import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/message_service.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/chat_list_item.dart';
import '../../widgets/kora_empty_state.dart';
import '../../widgets/kora_menu_sheet.dart';
import '../../widgets/new_chat_sheet.dart';
import '../chat/kora_chat_screen.dart';
import '../new_group_screen.dart';
import '../channel_landing_screen.dart';

/// The "Chats" tab — Kora's central conversation list.
/// Owns the Home header (branding, avatar, search, three-dot menu).
/// Features inline search bar, Read all, New Group, New Channel.
class ChatsTab extends StatefulWidget {
  final VoidCallback? onProfileTap;

  const ChatsTab({super.key, this.onProfileTap});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  List<ChatPreview> _chats = [];
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initMessages();
  }

  Future<void> _initMessages() async {
    await MessageService.instance.init();
    // Load messages for all known chats so ChatService can build previews
    await MessageService.instance.loadMessages('kora_support');
    await MessageService.instance.loadMessages('kora_ai');
    if (mounted) {
      setState(() => _chats = ChatService.instance.getChats());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openChat(ChatPreview chat) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KoraChatScreen(
          chatId: chat.id,
          name: chat.name,
          avatarAsset: chat.avatarAsset,
          avatarUrl: chat.avatarUrl,
          badge: chat.badge,
          isOnline: chat.isOnline,
          lastSeen: chat.isOnline ? null : 'last seen recently',
        ),
      ),
    ).then((_) {
      // Refresh unread badges/bold state after returning — the chat
      // screen marks incoming messages as viewed while it's open.
      if (mounted) setState(() => _chats = ChatService.instance.getChats());
    });
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  Future<void> _readAll() async {
    // Persist: mark every incoming message in every chat as viewed,
    // so the badges stay cleared after the next refresh too.
    for (final c in _chats) {
      await MessageService.instance.markChatViewed(c.id);
    }
    if (mounted) {
      setState(() => _chats = ChatService.instance.getChats());
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All messages marked as read'),
        duration: const Duration(seconds: 1),
        backgroundColor: KoraColors.purple,
      ),
    );
  }

  void _openMenu() {
    KoraMenuSheet.show(context, [
      KoraMenuOption(
        icon: Icons.group_add_outlined,
        label: 'New Group',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NewGroupScreen()),
          );
        },
      ),
      KoraMenuOption(
        icon: Icons.campaign_outlined,
        label: 'New Channel',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ChannelLandingScreen()),
          );
        },
      ),
      KoraMenuOption(
        icon: Icons.archive_outlined,
        label: 'Archived Chats',
        onTap: () {},
      ),
      KoraMenuOption(
        icon: Icons.star_outline,
        label: 'Starred Messages',
        onTap: () {},
      ),
      KoraMenuOption(
        icon: Icons.done_all,
        label: 'Read All',
        onTap: _readAll,
      ),
      KoraMenuOption(
        icon: Icons.privacy_tip_outlined,
        label: 'Privacy',
        onTap: () {},
      ),
      KoraMenuOption(
        icon: Icons.settings_outlined,
        label: 'Settings',
        onTap: () {},
      ),
    ]);
  }

  List<ChatPreview> get _filteredChats {
    if (_searchQuery.isEmpty) return _chats;
    final q = _searchQuery.toLowerCase();
    return _chats.where((c) {
      final name = c.name.toLowerCase();
      // Also search by Kora ID and last message content
      final lastMsg = c.lastMessage.toLowerCase();
      return name.contains(q) || lastMsg.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context, textPrimary, surface, textMuted, border),
            if (_showSearch)
              _buildInlineSearch(surface, textPrimary, textMuted, border),
            Expanded(
              child: _chats.isEmpty
                  ? KoraEmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'No conversations yet',
                      message: 'Start a chat with friends, family, or Kora Support to see it here.',
                      actionLabel: 'Start a Chat',
                      onAction: () => NewChatSheet.show(context),
                    )
                  : RefreshIndicator(
                      color: KoraColors.purple,
                      onRefresh: () async {
                        setState(() => _chats = ChatService.instance.getChats());
                      },
                      child: _filteredChats.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 120),
                                Center(
                                  child: Text(
                                    'No results for "$_searchQuery"',
                                    style: TextStyle(color: textSecondary, fontSize: 14),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(top: 4, bottom: 90),
                              itemCount: _filteredChats.length,
                              separatorBuilder: (_, __) => Padding(
                                padding: const EdgeInsets.only(left: 84),
                                child: Divider(
                                  height: 1,
                                  color: textSecondary.withValues(alpha: 0.08),
                                ),
                              ),
                              itemBuilder: (context, index) {
                                final chat = _filteredChats[index];
                                return ChatListItem(
                                  chat: chat,
                                  onTap: () => _openChat(chat),
                                  onLongPress: () {},
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _chats.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => NewChatSheet.show(context),
              backgroundColor: KoraColors.purple,
              elevation: 4,
              child: const Icon(Icons.chat_bubble, color: Colors.white, size: 24),
            ),
    );
  }

  Widget _buildHeader(BuildContext context, Color textPrimary, Color surface, Color textMuted, Color border) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/kora_logo_lockup.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Kora',
            style: TextStyle(
              color: textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onProfileTap,
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                gradient: KoraColors.brandGradient,
                shape: BoxShape.circle,
                border: Border.all(color: textPrimary.withValues(alpha: 0.08), width: 1),
              ),
              child: const Center(
                child: Text(
                  'IJ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.search, color: textPrimary, size: 24),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: textPrimary, size: 24),
            onPressed: _openMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildInlineSearch(Color surface, Color textPrimary, Color textMuted, Color border) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(color: textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search messages, names, Kora IDs...',
                  hintStyle: TextStyle(color: textMuted, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: Icon(Icons.close, color: textMuted, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
