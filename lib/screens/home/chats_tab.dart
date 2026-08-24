import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/conversation_directory.dart';
import '../../services/message_service.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/chat_list_item.dart';
import '../../widgets/chat_peek_overlay.dart';
import '../../widgets/kora_empty_state.dart';
import '../../widgets/kora_menu_sheet.dart';
import '../../widgets/new_chat_sheet.dart';
import '../chat/kora_chat_screen.dart';
import '../new_group_screen.dart';
import '../settings/privacy_screen.dart';
import '../archived_chats_screen.dart';
import '../starred_messages_screen.dart';
import 'profile_tab.dart';

/// The "Chats" tab — Kora's central conversation list.
/// Owns the Home header (branding, avatar, search, three-dot menu) and,
/// when the user long-presses a chat, a WhatsApp-style selection action
/// bar (pin, delete, mute, archive, more).
class ChatsTab extends StatefulWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onGoToChannels;

  const ChatsTab({
    super.key,
    this.onProfileTap,
    this.onGoToChannels,
  });

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  List<ChatPreview> _chats = [];
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Selection mode (long-press a chat) ──────────────────────
  final Set<String> _selectedIds = {};
  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initMessages();
  }

  Future<void> _initMessages() async {
    _chats = await ChatService.instance.getChats();
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    _chats = await ChatService.instance.getChats();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Chat Peek (Telegram-style avatar long-press) ────────────
  // Long-press a chat's avatar → peek panel slides in showing recent
  // messages. The peek stays open after the finger lifts. Scrolling
  // to the last message marks it as read. Tapping anywhere opens the
  // full chat where both users can continue chatting.

  void _onAvatarPeekStart(ChatPreview chat, Offset globalPosition) {
    ChatPeekOverlay.show(
      context,
      chat,
      onOpenChat: () => _openChat(chat),
      onMarkedRead: () => _refresh(),
    );
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
    );
  }

  // ── Selection mode handlers ──────────────────────────────────

  void _onChatTap(ChatPreview chat) {
    if (_isSelecting) {
      setState(() {
        if (_selectedIds.contains(chat.id)) {
          _selectedIds.remove(chat.id);
        } else {
          _selectedIds.add(chat.id);
        }
      });
    } else {
      _openChat(chat);
    }
  }

  /// Telegram-style floating quick-action menu — long-pressing a chat
  /// opens a small rounded popup anchored right at the touch point
  /// (not a full-screen multi-select mode). Tapping outside dismisses
  /// it; tapping an action runs it on just this one chat. "Select"
  /// is the escape hatch into the existing bulk-selection toolbar for
  /// when the user wants to act on several chats at once.
  Future<void> _onChatLongPress(ChatPreview chat, Offset globalPosition) async {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);

    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(globalPosition, globalPosition),
      Offset.zero & overlayBox.size,
    );

    final hasUnread = chat.unreadCount > 0;

    final action = await showMenu<String>(
      context: context,
      position: position,
      color: card,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [
        _quickActionItem(
          'mark',
          hasUnread ? Icons.mark_chat_read_outlined : Icons.mark_chat_unread_outlined,
          hasUnread ? 'Mark as read' : 'Mark as unread',
          textPrimary,
        ),
        _quickActionItem(
          'pin',
          Icons.push_pin_outlined,
          chat.isPinned ? 'Unpin' : 'Pin',
          textPrimary,
        ),
        _quickActionItem(
          'mute',
          chat.isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
          chat.isMuted ? 'Unmute' : 'Mute',
          textPrimary,
        ),
        _quickActionItem('archive', Icons.archive_outlined, 'Archive', textPrimary),
        _quickActionItem('select', Icons.check_circle_outline, 'Select', textPrimary),
        _quickActionItem('delete', Icons.delete_outline, 'Delete', Colors.red),
      ],
    );

    if (action == null || !mounted) return;

    // Run each action on just this one chat, via the existing bulk
    // handlers — set the selection to only this chat, run, and (for
    // everything except "select") clear the selection right after.
    setState(() => _selectedIds
      ..clear()
      ..add(chat.id));

    switch (action) {
      case 'mark':
        await _markSelectedRead(hasUnread);
        break;
      case 'pin':
        await _togglePinSelected();
        break;
      case 'mute':
        await _toggleMuteSelected();
        break;
      case 'archive':
        await _archiveSelected();
        break;
      case 'select':
        // Leave _selectedIds as-is — this hands off to the bulk
        // selection toolbar with this chat pre-selected.
        break;
      case 'delete':
        await _deleteSelected();
        break;
    }
  }

  PopupMenuItem<String> _quickActionItem(
    String value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 46,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  List<ChatPreview> get _selectedChats =>
      _chats.where((c) => _selectedIds.contains(c.id)).toList();

  Future<void> _togglePinSelected() async {
    final selected = _selectedChats;
    if (selected.isEmpty) return;
    final allPinned = selected.every((c) => c.isPinned);
    for (final c in selected) {
      await ConversationDirectoryService.instance.setPinned(c.id, !allPinned);
    }
    _clearSelection();
    await _refresh();
  }

  Future<void> _toggleMuteSelected() async {
    final selected = _selectedChats;
    if (selected.isEmpty) return;
    final allMuted = selected.every((c) => c.isMuted);
    for (final c in selected) {
      await ConversationDirectoryService.instance.setMuted(c.id, !allMuted);
    }
    _clearSelection();
    await _refresh();
  }

  Future<void> _archiveSelected() async {
    final ids = List<String>.from(_selectedIds);
    if (ids.isEmpty) return;
    for (final id in ids) {
      await ConversationDirectoryService.instance.setArchived(id, true);
    }
    final count = ids.length;
    _clearSelection();
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count == 1 ? 'Chat archived' : '$count chats archived'),
          backgroundColor: KoraColors.purple,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _markSelectedRead(bool read) async {
    final selected = _selectedChats;
    if (selected.isEmpty) return;
    for (final c in selected) {
      if (read) {
        await MessageService.instance.markChatViewed(c.id);
      }
      // "Mark as unread" has no true backend flag today — Kora treats
      // read state as derived from message.isSeen — so we only support
      // marking read from here, matching what's actually persistable.
    }
    _clearSelection();
    await _refresh();
  }

  Future<void> _deleteSelected() async {
    final ids = List<String>.from(_selectedIds);
    if (ids.isEmpty) return;
    final count = ids.length;

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
              Text(
                count == 1 ? 'Delete this chat?' : 'Delete $count chats?',
                style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'This will permanently delete all messages in ${count == 1 ? 'this chat' : 'these chats'}. This cannot be undone.',
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

    if (confirmed != true) return;

    for (final id in ids) {
      await MessageService.instance.deleteChat(id);
      await ConversationDirectoryService.instance.remove(id);
    }
    _clearSelection();
    await _refresh();
  }

  void _openSelectionOverflowMenu() {
    KoraMenuSheet.show(context, [
      KoraMenuOption(
        icon: Icons.select_all,
        label: 'Select all',
        onTap: () {
          setState(() {
            _selectedIds.addAll(_filteredChats.map((c) => c.id));
          });
        },
      ),
      KoraMenuOption(
        icon: Icons.mark_chat_read_outlined,
        label: 'Mark as read',
        onTap: () => _markSelectedRead(true),
      ),
    ]);
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

  void _readAll() {
    setState(() {
      _chats = _chats.map((c) {
        // Can't mutate ChatPreview directly since it's immutable,
        // but we mark unread as 0 visually — when we wire real data
        // this will call the backend
        return ChatPreview(
          id: c.id,
          name: c.name,
          avatarAsset: c.avatarAsset,
          avatarUrl: c.avatarUrl,
          lastMessage: c.lastMessage,
          timestamp: c.timestamp,
          unreadCount: 0,
          status: c.status,
          badge: c.badge,
          isMuted: c.isMuted,
          isPinned: c.isPinned,
          isOnline: c.isOnline,
          isTyping: c.isTyping,
        );
      }).toList();
    });
    for (final c in _chats) {
      MessageService.instance.markChatViewed(c.id);
    }
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
          widget.onGoToChannels?.call();
        },
      ),
      KoraMenuOption(
        icon: Icons.archive_outlined,
        label: 'Archived Chats',
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ArchivedChatsScreen()),
          );
          await _refresh();
        },
      ),
      KoraMenuOption(
        icon: Icons.star_outline,
        label: 'Starred Messages',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StarredMessagesScreen()),
          );
        },
      ),
      KoraMenuOption(
        icon: Icons.done_all,
        label: 'Read All',
        onTap: _readAll,
      ),
      KoraMenuOption(
        icon: Icons.privacy_tip_outlined,
        label: 'Privacy',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PrivacyScreen()),
          );
        },
      ),
      KoraMenuOption(
        icon: Icons.settings_outlined,
        label: 'Settings',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileTab()),
          );
        },
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
            _isSelecting
                ? _buildSelectionHeader(context, textPrimary, surface)
                : _buildHeader(context, textPrimary, surface, textMuted, border),
            if (_showSearch && !_isSelecting)
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
                      onRefresh: _refresh,
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
                                  isSelected: _selectedIds.contains(chat.id),
                                  onTap: () => _onChatTap(chat),
                                  onLongPress: (pos) => _onChatLongPress(chat, pos),
                                  onAvatarPeekStart: (pos) => _onAvatarPeekStart(chat, pos),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: (_chats.isEmpty || _isSelecting)
          ? null
          : FloatingActionButton(
              onPressed: () => NewChatSheet.show(context),
              backgroundColor: KoraColors.purple,
              elevation: 4,
              child: const Icon(Icons.chat_bubble, color: Colors.white, size: 24),
            ),
    );
  }

  /// WhatsApp-style selection action bar shown when one or more chats
  /// are long-pressed/selected on the Home screen: back arrow + count,
  /// pin, delete, mute, archive, and an overflow menu.
  Widget _buildSelectionHeader(BuildContext context, Color textPrimary, Color surface) {
    final selected = _selectedChats;
    final allPinned = selected.isNotEmpty && selected.every((c) => c.isPinned);
    final allMuted = selected.isNotEmpty && selected.every((c) => c.isMuted);

    return Container(
      color: surface,
      padding: const EdgeInsets.fromLTRB(4, 10, 8, 10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: textPrimary),
            onPressed: _clearSelection,
          ),
          Text(
            '${_selectedIds.length}',
            style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          IconButton(
            tooltip: allPinned ? 'Unpin' : 'Pin',
            icon: Icon(
              allPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: textPrimary,
            ),
            onPressed: _togglePinSelected,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(Icons.delete_outline, color: textPrimary),
            onPressed: _deleteSelected,
          ),
          IconButton(
            tooltip: allMuted ? 'Unmute' : 'Mute',
            icon: Icon(
              allMuted ? Icons.notifications_outlined : Icons.notifications_off_outlined,
              color: textPrimary,
            ),
            onPressed: _toggleMuteSelected,
          ),
          IconButton(
            tooltip: 'Archive',
            icon: Icon(Icons.archive_outlined, color: textPrimary),
            onPressed: _archiveSelected,
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: textPrimary),
            onPressed: _openSelectionOverflowMenu,
          ),
        ],
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
              gradient: KoraColors.brandGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'K',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
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
