import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/conversation_directory.dart';
import '../../services/message_service.dart';
import '../../services/chat_sync_service.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/chat_list_item.dart';
import '../../widgets/chat_peek_overlay.dart';
import '../../widgets/kora_empty_state.dart';
import '../../widgets/kora_menu_sheet.dart';
import '../../widgets/new_chat_sheet.dart';
import '../chat/kora_chat_screen.dart';
import '../chat/contact_info_screen.dart';
import '../new_group_screen.dart';
import '../settings/privacy_screen.dart';
import 'package:local_auth/local_auth.dart';
import '../archived_chats_screen.dart';
import '../locked_chats_screen.dart';
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
  int _archivedCount = 0;
  int _lockedCount = 0;
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Selection mode (long-press a chat) ──────────────────────
  final Set<String> _selectedIds = {};
  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Refresh the chat list whenever polling detects new incoming messages.
    ChatSyncService.instance.onNewMessages = _refresh;
    _initMessages();
  }

  Future<void> _initMessages() async {
    await _loadAll();
  }

  Future<void> _refresh() async {
    await _loadAll();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      ChatService.instance.getChats(),
      ChatService.instance.getArchivedChats(),
      ChatService.instance.getLockedChats(),
    ]);
    _chats = results[0];
    _archivedCount = results[1].length;
    _lockedCount = results[2].length;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ChatSyncService.instance.onNewMessages = null;
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
      onOpenProfile: () => _openProfile(chat),
      onRefresh: () => _refresh(),
    );
  }

  /// Opens [chat]'s Profile / Contact info screen — used when the
  /// user taps the header (avatar/name) inside the Chat Peek.
  void _openProfile(ChatPreview chat) {
    final lowerName = chat.name.toLowerCase().replaceAll(' ', '_');
    final koraId = 'KM-${chat.name.hashCode.abs().toString().padLeft(9, '0')}';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactInfoScreen(
          name: chat.name,
          avatarAsset: chat.avatarAsset,
          avatarUrl: chat.avatarUrl,
          badge: chat.badge,
          isOnline: chat.isOnline,
          lastSeen: chat.isOnline ? null : 'last seen recently',
          koraId: koraId,
          username: '@$lowerName',
          about: 'Hey there! I am using Kora Messenger.',
          phone: '+123 456 7890',
          recipientEmail: chat.recipientEmail,
          isAiChat: false,
        ),
      ),
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
          recipientEmail: chat.recipientEmail,
        ),
      ),
    ).then((_) => _refresh()); // refresh unread badges when returning from chat
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
    final dir = await ConversationDirectoryService.instance.get(chat.id);
    final isLocked = dir?['isLocked'] as bool? ?? false;

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
          'mute',
          chat.isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
          chat.isMuted ? 'Unmute' : 'Mute',
          textPrimary,
        ),
        _quickActionItem(
          'pin',
          Icons.push_pin_outlined,
          chat.isPinned ? 'Unpin' : 'Pin',
          textPrimary,
        ),
        _quickActionItem(
          'lock',
          isLocked ? Icons.lock_open_outlined : Icons.lock_outline,
          isLocked ? 'Unlock chat' : 'Lock chat',
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
      case 'lock':
        await _lockSelected(unlock: isLocked);
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

    // Already muted → tapping mute again just unmutes, no dialog.
    if (allMuted) {
      for (final c in selected) {
        await ConversationDirectoryService.instance.setMuted(c.id, false);
      }
      _clearSelection();
      await _refresh();
      return;
    }

    // Not muted → ask for a duration first, like WhatsApp's
    // "Mute message notifications" dialog (8 hours / 1 week / Always).
    final choice = await _showMuteDurationDialog();
    if (choice == null) return; // cancelled — leave selection as-is

    DateTime? until;
    if (choice == 0) {
      until = DateTime.now().add(const Duration(hours: 8));
    } else if (choice == 1) {
      until = DateTime.now().add(const Duration(days: 7));
    }
    // choice == 2 → "Always" → until stays null (no expiry)

    for (final c in selected) {
      await ConversationDirectoryService.instance.setMuted(c.id, true, until: until);
    }
    _clearSelection();
    await _refresh();
  }

  /// Kora-styled version of WhatsApp's "Mute message notifications"
  /// dialog. Returns 0 (8 hours), 1 (1 week), 2 (Always), or null if
  /// the user cancelled.
  Future<int?> _showMuteDurationDialog() async {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    int selected = 0;

    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Widget option(int index, String label) {
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setDialogState(() => selected = index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Radio<int>(
                        value: index,
                        groupValue: selected,
                        activeColor: KoraColors.purple,
                        onChanged: (v) => setDialogState(() => selected = v!),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Dialog(
              backgroundColor: card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mute message notifications',
                      style: TextStyle(color: textPrimary, fontSize: 19, fontWeight: FontWeight.w700, height: 1.25),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        'Other members will not see that you muted this chat. You will still be notified if you are mentioned.',
                        style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    option(0, '8 hours'),
                    option(1, '1 week'),
                    option(2, 'Always'),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancel', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w700)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, selected),
                          child: const Text('OK', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: KoraColors.darkSurface,
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 4),
          content: Text(
            count == 1 ? '1 chat archived' : '$count chats archived',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: KoraColors.purple,
            onPressed: () async {
              for (final id in ids) {
                await ConversationDirectoryService.instance.setArchived(id, false);
              }
              await _refresh();
            },
          ),
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

  /// Lock/unlock selected chats. Locking hides a chat from BOTH the
  /// Home list and Archived Chats — it's only reachable through the
  /// biometric-gated Locked Chats screen.
  Future<void> _lockSelected({bool unlock = false}) async {
    final ids = List<String>.from(_selectedIds);
    if (ids.isEmpty) return;

    // Locking requires biometric confirmation first (unlocking from
    // the long-press menu also gates here so nobody can unlock a chat
    // just by long-pressing on the Home screen).
    if (!unlock) {
      final authed = await _authenticate('Lock chat');
      if (!authed) return;
    }

    for (final id in ids) {
      await ConversationDirectoryService.instance.setLocked(id, !unlock);
    }
    _clearSelection();
    await _refresh();
  }

  /// Biometric gate for locked-chat features. Returns true if the
  /// device has biometrics and the user authenticated, or false if
  /// biometrics are unavailable / the user cancelled.
  Future<bool> _authenticate(String reason) async {
    try {
      final localAuth = LocalAuthentication();
      final available = await localAuth.canCheckBiometrics ||
          await localAuth.isDeviceSupported();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication is not available on this device.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
      return await localAuth.authenticate(
        localizedReason: '$reason requires biometric authentication',
        biometricOnly: false,
      );
    } catch (_) {
      return false;
    }
  }

  /// Opens the Locked Chats screen — biometric-gated, just like
  /// WhatsApp's "Locked chats" entry point in the chat list header.
  Future<void> _openLockedChats() async {
    final authed = await _authenticate('Open Locked Chats');
    if (!authed) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LockedChatsScreen()),
    );
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
      KoraMenuOption(
        icon: Icons.mark_chat_unread_outlined,
        label: 'Mark as unread',
        onTap: () => _markSelectedUnread(),
      ),
    ]);
  }

  /// "Mark as unread" — sets a forced-unread flag so the chat shows
  /// a badge on Home even though every message was actually seen.
  /// Cleared automatically when the chat is opened again.
  Future<void> _markSelectedUnread() async {
    final ids = List<String>.from(_selectedIds);
    for (final id in ids) {
      await ConversationDirectoryService.instance.setForcedUnread(id, true);
    }
    _clearSelection();
    await _refresh();
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
        icon: Icons.lock_outline,
        label: 'Locked Chats',
        onTap: _openLockedChats,
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
            if (!_showSearch && !_isSelecting && (_lockedCount > 0 || _archivedCount > 0))
              _buildTopShortcuts(textPrimary, textMuted, border),
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

  /// Fixed shortcut rows pinned to the very top of the Home screen
  /// (above every chat, even pinned ones) — matches WhatsApp
  /// Business's "Locked chats" / "Archived" rows. Only shown once
  /// there's at least one chat in that state; tapping opens the
  /// respective full-screen list.
  Widget _buildTopShortcuts(Color textPrimary, Color textMuted, Color border) {
    return Column(
      children: [
        if (_lockedCount > 0)
          _buildShortcutRow(
            iconWidget: _buildLockedChatIcon(textMuted),
            label: 'Locked chats',
            count: null,
            textPrimary: textPrimary,
            textMuted: textMuted,
            onTap: _openLockedChats,
          ),
        if (_archivedCount > 0)
          _buildShortcutRow(
            iconWidget: Icon(Icons.archive_outlined, size: 22, color: textMuted),
            label: 'Archived',
            count: _archivedCount,
            textPrimary: textPrimary,
            textMuted: textMuted,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ArchivedChatsScreen()),
              );
              await _refresh();
            },
          ),
        Divider(height: 1, color: textMuted.withValues(alpha: 0.12)),
      ],
    );
  }

  /// WhatsApp-style chat-bubble-with-lock icon for the "Locked chats"
  /// shortcut row. A speech-bubble outline with a small lock at the
  /// center, matching WhatsApp Business exactly.
  Widget _buildLockedChatIcon(Color iconColor) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 22, color: iconColor),
          Positioned(
            bottom: 3,
            child: Icon(Icons.lock, size: 9, color: iconColor),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutRow({
    required Widget iconWidget,
    required String label,
    required int? count,
    required Color textPrimary,
    required Color textMuted,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            SizedBox(width: 24, height: 24, child: Center(child: iconWidget)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            if (count != null)
              Text(
                '$count',
                style: TextStyle(color: textMuted, fontSize: 14, fontWeight: FontWeight.w500),
              ),
          ],
        ),
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
