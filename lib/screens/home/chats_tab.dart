import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/subscription_pricing.dart';
import '../../models/chat_models.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import '../../services/chat_vault_service.dart';
import '../../services/home_search_service.dart';
import '../../services/conversation_directory.dart';
import '../../services/session_manager.dart';
import '../../services/message_service.dart';
import '../../services/chat_sync_service.dart';
import '../../theme/kora_colors.dart';
import '../../utils/kora_page_routes.dart';
import '../../widgets/chat_list_item.dart';
import '../../widgets/chat_peek_overlay.dart';
import '../../widgets/kora_avatar.dart';
import '../../widgets/kora_empty_state.dart';
import '../../widgets/kora_menu_sheet.dart';
import '../../widgets/new_chat_sheet.dart';
import '../chat/contact_info_screen.dart';
import '../chat/group_chat_info_screen.dart';
import '../chat/kora_chat_screen.dart';
import '../../config/kora_api.dart';
import '../new_group_screen.dart';
import '../kora_notifications_screen.dart';
import '../settings/privacy_screen.dart';
import 'package:local_auth/local_auth.dart';
import '../archived_chats_screen.dart';
import '../locked_chats_screen.dart';
import '../starred_messages_screen.dart';
import 'profile_tab.dart';
import '../settings/link_device_screen.dart';
import '../settings/billing_screen.dart';
import '../chat/broadcast_list_screen.dart';

/// The "Chats" tab — Kora's central conversation list.
/// Owns the Home header (branding, avatar, search, three-dot menu) and,
/// when the user long-presses a chat, a WhatsApp-style selection action
/// bar (pin, delete, mute, archive, more).
class ChatsTab extends StatefulWidget {
  final VoidCallback? onSettingsTap;
  final VoidCallback? onGoToUpdates;

  const ChatsTab({
    super.key,
    this.onSettingsTap,
    this.onGoToUpdates,
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

  // ── Inline search state (WhatsApp-style) ──────────────────────
  Timer? _searchDebounce;
  List<HomeMessageHit> _messageHits = [];
  bool _searchingMessages = false;
  HomeSearchFilter _searchFilter = HomeSearchFilter.all;
  List<String> _recentSearches = [];
  bool _lockedRevealed = false;
  List<ChatPreview> _revealedLockedChats = [];

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
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── Chat Peek (Telegram-style avatar long-press) ────────────
  // Long-press a chat's avatar → peek panel slides in showing recent
  // messages. The peek stays open after the finger lifts. Scrolling
  // to the last message marks it as read. Tapping anywhere opens the
  // full chat where both users can continue chatting.


  /// Opens [chat]'s Profile / Contact info screen — used when the
  /// user taps the header (avatar/name) inside the Chat Peek.

  void _openChat(ChatPreview chat) {
    if (chat.id == 'kora_notifications') {
      // Refresh on return — the service chat marks itself read on
      // open, so Home must rebuild the moment the user comes back.
      pushSlideUp(
        context,
        const KoraNotificationsScreen(),
      ).then((_) => _refresh());
      return;
    }
    // Refresh on return — opening the chat marks it viewed, and the
    // stale unread badge would otherwise linger until a manual pull.
    pushSlideUp(
      context,
      KoraChatScreen(
        chatId: chat.id,
        name: chat.name,
        avatarAsset: chat.avatarAsset,
        avatarUrl: chat.avatarUrl,
        badge: chat.badge,
        isOnline: chat.isOnline,
        isGroupChat: chat.isGroupChat,
        lastSeen: chat.isOnline ? null : 'last seen recently',
      ),
    );
  }

  /// WhatsApp-style Chat Peek — long-press the profile picture to
  /// preview recent messages in a floating card. The peek is SILENT:
  /// no read receipts are sent, so the other user doesn't know you
  /// looked. Tapping the message area opens the full chat; tapping
  /// outside closes the peek.
  void _showChatPeek(ChatPreview chat) {
    ChatPeekOverlay.show(
      context,
      chat,
      onOpenChat: () => _openChat(chat),
      onOpenProfile: () => _openProfile(chat),
      onRefresh: _refresh,
    );
  }

  /// WhatsApp home-screen behavior: tapping a contact's circle profile
  /// photo on the chat list opens their PROFILE — the same Contact
  /// Info screen you reach by tapping their name inside a chat.
  /// Long-press still shows the silent chat peek.
  Future<void> _openProfile(ChatPreview chat) async {
    // Builtin system chats don't have a contact profile.
    if (chat.id == 'kora_ai' ||
        chat.id == 'kora_support' ||
        chat.id == 'kora_notifications') {
      return;
    }

    // Group chats open the group info screen, same as inside the chat.
    if (chat.isGroupChat) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatInfoScreen(
            groupName: chat.name,
            groupDescription: 'Group description',
            avatarUrl: chat.avatarUrl,
            avatarAsset: chat.avatarAsset,
            participants: [
              GroupParticipant(name: chat.name, koraId: 'me', isAdmin: true),
              GroupParticipant(name: 'Member', koraId: 'member1', isAdmin: false),
            ],
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            chatId: chat.id,
          ),
        ),
      );
      return;
    }

    // 1:1 chats — fetch the real profile from the backend using the
    // same lookup the chat screen's "Contact info" flow uses.
    String koraId = '';
    String username = '';
    String about = 'Hey there! I am using Kora Messenger.';
    String? phone;
    String fullName = chat.name;
    String? avatarUrl = chat.avatarUrl;

    if (chat.recipientEmail != null && chat.recipientEmail!.isNotEmpty) {
      try {
        final resp = await http.post(
          Uri.parse(KoraApi.lookupByEmailEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': chat.recipientEmail}),
        );
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          if (data['success'] == true &&
              data['found'] == true &&
              data['user'] != null) {
            final user = data['user'] as Map<String, dynamic>;
            koraId = user['koraId']?.toString() ?? '';
            username = user['username']?.toString() ?? '';
            fullName = user['fullName']?.toString() ?? chat.name;
            about = user['bio']?.toString() ?? about;
            phone = (user['phoneNumber'] != null &&
                    user['phoneNumber'].toString().isNotEmpty)
                ? user['phoneNumber'].toString()
                : null;
            if (user['avatarUrl'] != null &&
                user['avatarUrl'].toString().isNotEmpty) {
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
          chatId: chat.id,
          avatarAsset: chat.avatarAsset,
          avatarUrl: avatarUrl,
          badge: chat.badge,
          isOnline: chat.isOnline,
          koraId: koraId.isNotEmpty ? koraId : null,
          username: username.isNotEmpty ? username : null,
          about: about,
          phone: phone,
          recipientEmail: chat.recipientEmail,
          isAiChat: false,
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
  /// WhatsApp-style long-press — directly enters selection mode with
  /// the chat pre-selected. No floating popup; the selection toolbar
  /// appears at the top with pin, delete, mute, archive, and overflow.
  void _onChatLongPress(ChatPreview chat) {
    setState(() {
      _selectedIds.clear();
      _selectedIds.add(chat.id);
    });
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
    // Telegram's service chat can't be archived.
    ids.remove('kora_notifications');
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
    // Telegram's service chat can't be deleted.
    ids.remove('kora_notifications');
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

    // Telegram's service chat can't be locked away.
    ids.remove('kora_notifications');
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
      KoraMenuOption(
        icon: Icons.lock_outline,
        label: 'Lock chat',
        onTap: () => _lockSelected(unlock: false),
      ),
      KoraMenuOption(
        icon: Icons.lock_open_outlined,
        label: 'Unlock chat',
        onTap: () => _lockSelected(unlock: true),
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
        _messageHits = [];
        _lockedRevealed = false;
        _searchFilter = HomeSearchFilter.all;
      } else {
        _loadRecentSearches();
      }
    });
  }

  // ── Inline search (WhatsApp behavior) ─────────────────────────
  // Debounced: waits 250ms after the last keystroke before scanning
  // message contents across all chats.
  void _onSearchChanged(String v) {
    setState(() => _searchQuery = v);
    _searchDebounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() {
        _messageHits = [];
        _searchingMessages = false;
        _lockedRevealed = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 250), _runMessageSearch);
  }

  Future<void> _runMessageSearch() async {
    final q = _searchQuery.trim();
    if (q.isEmpty || !mounted) return;
    setState(() => _searchingMessages = true);

    // WhatsApp-style secret code: typing the locked-chats code in the
    // search bar reveals the locked chats right in the results.
    bool revealed = false;
    List<ChatPreview> locked = [];
    try {
      if (await ChatVaultService.instance.hasSecretCode() &&
          await ChatVaultService.instance.verifySecretCode(q)) {
        revealed = true;
        locked = await ChatService.instance.getLockedChats();
      }
    } catch (_) {}

    final hits = await HomeSearchService.instance.searchMessages(
      q,
      filter: _searchFilter,
    );
    if (!mounted) return;
    setState(() {
      _searchingMessages = false;
      _messageHits = hits;
      _lockedRevealed = revealed;
      _revealedLockedChats = locked;
    });
  }

  Future<void> _loadRecentSearches() async {
    final recents = await HomeSearchService.instance.getRecentSearches();
    if (mounted) setState(() => _recentSearches = recents);
  }

  void _clearSearchInput() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _messageHits = [];
      _lockedRevealed = false;
      _searchingMessages = false;
    });
  }

  /// Opens a chat from a search hit, scrolls to the exact message and
  /// highlights it. Records the query in Recent searches.
  void _openMessageHit(HomeMessageHit hit) {
    HomeSearchService.instance.addRecentSearch(_searchQuery.trim());
    pushSlideUp(
      context,
      KoraChatScreen(
        chatId: hit.chatId,
        name: hit.chatName,
        avatarAsset: hit.avatarAsset,
        avatarUrl: hit.avatarUrl,
        badge: hit.badge,
        isGroupChat: hit.isGroupChat,
        initialJumpMessageId: hit.message.id,
      ),
    ).then((_) => _refresh());
  }

  /// Opens a chat row from search results and records the query.
  void _openChatFromSearch(ChatPreview chat) {
    HomeSearchService.instance.addRecentSearch(_searchQuery.trim());
    _openChat(chat);
  }

  Future<void> _readAll() async {
    for (final c in _chats) {
      if (c.unreadCount > 0) {
        await MessageService.instance.markChatViewed(c.id);
        // "Read all" also clears the Mark-as-unread flag.
        await ConversationDirectoryService.instance.setForcedUnread(c.id, false);
      }
    }
    _chats = await ChatService.instance.getChats();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All messages marked as read'),
        duration: const Duration(seconds: 1),
        backgroundColor: KoraColors.purple,
      ),
    );
  }

  // ── Selection mode handlers ──


  void _toggleSelected(String chatId) {
    setState(() {
      if (_selectedIds.contains(chatId)) {
        _selectedIds.remove(chatId);
      } else {
        _selectedIds.add(chatId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds.addAll(_filteredChats.map((c) => c.id));
    });
    for (final c in _chats) {
      MessageService.instance.markChatViewed(c.id);
      ConversationDirectoryService.instance.setForcedUnread(c.id, false);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Marked all as read"),
        duration: const Duration(seconds: 1),
        backgroundColor: KoraColors.purple,
      ),
    );
  }

  void _openMenu() {
    KoraMenuSheet.show(context, [
      KoraMenuOption(
        icon: Icons.group_add_outlined,
        label: 'New group',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NewGroupScreen()),
          );
        },
      ),
      KoraMenuOption(
        icon: Icons.campaign_outlined,
        label: 'New channel',
        onTap: () {
          widget.onGoToUpdates?.call();
        },
      ),
      KoraMenuOption(
        icon: Icons.broadcast_on_personal_outlined,
        label: 'New broadcast',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BroadcastListScreen()),
          );
        },
      ),
      KoraMenuOption(
        icon: Icons.phonelink_setup_outlined,
        label: 'Linked devices',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LinkDeviceScreen()),
          );
        },
      ),
      KoraMenuOption(
        icon: Icons.star_outline,
        label: 'Starred messages',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StarredMessagesScreen()),
          );
        },
      ),
      KoraMenuOption(
        icon: Icons.payments_outlined,
        label: 'Payments',
        onTap: () async {
          final session = await SessionManager.instance.loadSession();
          final email = session?['email']?.toString() ?? '';
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BillingScreen(selectedPlan: SubscriptionPlan.monthly, userEmail: email)),
          );
        },
      ),
      KoraMenuOption(
        icon: Icons.done_all,
        label: 'Read all',
        onTap: _readAll,
      ),
      KoraMenuOption(
        icon: Icons.settings_outlined,
        label: 'Settings',
        onTap: () {
          widget.onSettingsTap?.call();
        },
      ),
    ]);
  }

  List<ChatPreview> get _filteredChats {
    if (_searchQuery.isEmpty) return _chats;
    final q = _searchQuery.toLowerCase();
    return _chats.where((c) {
      final name = c.name.toLowerCase();
      final lastMsg = c.lastMessage.toLowerCase();
      final chatId = c.id.toLowerCase();
      final email = (c.recipientEmail ?? '').toLowerCase();
      // Search by name, last message, Kora ID (chat ID), and email
      return name.contains(q) || lastMsg.contains(q) || chatId.contains(q) || email.contains(q);
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
                      child: _showSearch && _searchQuery.trim().isNotEmpty
                          ? _buildSearchResults(textPrimary, textSecondary, textMuted, border)
                          : _showSearch && _recentSearches.isNotEmpty
                          ? _buildRecentSearches(textPrimary, textSecondary, textMuted, border)
                          : _filteredChats.isEmpty
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
                                if (_isSelecting) {
                                  return ChatListItem(
                                    chat: chat,
                                    isSelected: _selectedIds.contains(chat.id),
                                    onTap: () => _onChatTap(chat),
                                    onLongPress: (_) => _onChatLongPress(chat),
                                    onAvatarLongPress: () => _showChatPeek(chat),
                                  );
                                }
                                return Dismissible(
                                  key: ValueKey(chat.id),
                                  direction: DismissDirection.horizontal,
                                  background: Container(
                                    color: KoraColors.purple.withValues(alpha: 0.85),
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 24),
                                    child: const Icon(Icons.archive, color: Colors.white, size: 26),
                                  ),
                                  secondaryBackground: Container(
                                    color: KoraColors.purple.withValues(alpha: 0.85),
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 24),
                                    child: const Icon(Icons.push_pin, color: Colors.white, size: 26),
                                  ),
                                  confirmDismiss: (direction) async {
                                    // Telegram's service chat is a permanent
                                    // system chat — it can't be archived.
                                    if (chat.id == 'kora_notifications') {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .clearSnackBars();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            backgroundColor:
                                                KoraColors.darkSurface,
                                            duration:
                                                Duration(seconds: 2),
                                            content: Text(
                                              'Kora Notifications can\u2019t be archived',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13.5),
                                            ),
                                          ),
                                        );
                                      }
                                      return false;
                                    }
                                    if (direction == DismissDirection.startToEnd) {
                                      // Swipe right → archive
                                      await ConversationDirectoryService.instance.setArchived(chat.id, true);
                                      await _refresh();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).clearSnackBars();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: KoraColors.darkSurface,
                                            duration: const Duration(seconds: 4),
                                            content: const Text('Chat archived', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                                            action: SnackBarAction(
                                              label: 'UNDO',
                                              textColor: KoraColors.purple,
                                              onPressed: () async {
                                                await ConversationDirectoryService.instance.setArchived(chat.id, false);
                                                await _refresh();
                                              },
                                            ),
                                          ),
                                        );
                                      }
                                      return false; // don't remove from list — _refresh handles it
                                    } else {
                                      // Swipe left → toggle pin
                                      await ConversationDirectoryService.instance.setPinned(chat.id, !chat.isPinned);
                                      await _refresh();
                                      return false;
                                    }
                                  },
                                  child: ChatListItem(
                                    chat: chat,
                                    isSelected: _selectedIds.contains(chat.id),
                                    onTap: () => _onChatTap(chat),
                                    onLongPress: (_) => _onChatLongPress(chat),
                                    onAvatarLongPress: () => _showChatPeek(chat),
                                    onAvatarTap: () => _openProfile(chat),
                                  ),
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
      key: const ValueKey('normal'),
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
            'Kora Messenger',
            style: TextStyle(
              color: textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
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
                onChanged: _onSearchChanged,
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
                onTap: _clearSearchInput,
                child: Icon(Icons.close, color: textMuted, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  // ── WhatsApp-style sectioned search results ───────────────────────
  Widget _buildSearchResults(Color textPrimary, Color textSecondary,
      Color textMuted, Color border) {
    final chatHits = _searchFilter == HomeSearchFilter.all
        ? _filteredChats
        : const <ChatPreview>[];

    final children = <Widget>[
      // Media filter chips (WhatsApp: Photos, Videos, Links, GIFs...)
      _buildFilterChips(textPrimary, textMuted, border),
    ];

    // Chats section
    if (chatHits.isNotEmpty) {
      children.add(_sectionHeader('Chats', textMuted));
      for (final c in chatHits.take(5)) {
        children.add(ChatListItem(
          chat: c,
          onTap: () => _openChatFromSearch(c),
          onLongPress: (_) => _onChatLongPress(c),
          onAvatarLongPress: () => _showChatPeek(c),
        ));
      }
    }

    // Locked chats revealed by the secret code (WhatsApp behavior)
    if (_lockedRevealed && _revealedLockedChats.isNotEmpty && _searchFilter == HomeSearchFilter.all) {
      children.add(_sectionHeader('Locked chats', textMuted));
      for (final c in _revealedLockedChats) {
        children.add(ChatListItem(
          chat: c,
          onTap: () => _openChatFromSearch(c),
          onAvatarLongPress: () => _showChatPeek(c),
        ));
      }
    }

    // Messages section
    if (_searchFilter != HomeSearchFilter.all) {
      children
          .add(_sectionHeader(kHomeSearchFilterLabels[_searchFilter] ?? 'Media', textMuted));
    } else if (_messageHits.isNotEmpty || _searchingMessages) {
      children.add(_sectionHeader('Messages', textMuted));
    }
    for (final hit in _messageHits) {
      children.add(_buildMessageHitRow(hit, textPrimary, textSecondary, textMuted));
    }

    // Searching… / No results states
    if (_searchingMessages && _messageHits.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Center(
          child: SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: KoraColors.purple),
          ),
        ),
      ));
    } else if (chatHits.isEmpty && _messageHits.isEmpty && !_lockedRevealed) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 120),
        child: Center(
          child: Text(
            'No results for "$_searchQuery"',
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
        ),
      ));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: children,
    );
  }

  Widget _sectionHeader(String label, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Text(
        label,
        style: TextStyle(color: textMuted, fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildFilterChips(Color textPrimary, Color textMuted, Color border) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final f in HomeSearchFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _searchFilter = f);
                  _runMessageSearch();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _searchFilter == f
                        ? KoraColors.purple
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _searchFilter == f ? KoraColors.purple : border,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    kHomeSearchFilterLabels[f]!,
                    style: TextStyle(
                      color: _searchFilter == f ? Colors.white : textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageHitRow(HomeMessageHit hit, Color textPrimary,
      Color textSecondary, Color textMuted) {
    final m = hit.message;
    final snippet = _snippetFor(m);
    return InkWell(
      onTap: () => _openMessageHit(hit),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            KoraAvatar(
              name: hit.chatName,
              assetPath: hit.avatarAsset,
              imageUrl: hit.avatarUrl,
              size: 44,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hit.chatName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _hitTimestamp(m.timestamp),
                        style: TextStyle(color: textMuted, fontSize: 11.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  _highlighted(
                    snippet,
                    _searchQuery.trim(),
                    TextStyle(color: textSecondary, fontSize: 13.5),
                    TextStyle(
                      color: KoraColors.purple,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// WhatsApp-style snippet with the matched text highlighted in Kora
  /// purple. First occurrence is highlighted.
  Widget _highlighted(String text, String q, TextStyle base, TextStyle hl) {
    final lower = text.toLowerCase();
    final ql = q.toLowerCase();
    final idx = ql.isEmpty ? -1 : lower.indexOf(ql);
    if (idx < 0) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
    }
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: text.substring(0, idx), style: base),
        TextSpan(text: text.substring(idx, idx + ql.length), style: hl),
        TextSpan(text: text.substring(idx + ql.length), style: base),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _snippetFor(KoraMessage m) {
    switch (m.type) {
      case KoraMessageType.image:
        return '[Photo] ${m.text}';
      case KoraMessageType.video:
        return '[Video] ${m.text}';
      case KoraMessageType.videoNote:
        return '[Video message]';
      case KoraMessageType.voice:
        return '[Voice message] ${m.voiceTranscript ?? ''}';
      case KoraMessageType.document:
      case KoraMessageType.file:
        return '[Document] ${m.attachmentName ?? m.text}';
      case KoraMessageType.sticker:
        return '[Sticker]';
      case KoraMessageType.contact:
        return '[Contact] ${m.text}';
      case KoraMessageType.location:
        return '[Location] ${m.text}';
      default:
        return m.text;
    }
  }

  String _hitTimestamp(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(t.year, t.month, t.day);
    if (d == today) {
      final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
      final ampm = t.hour >= 12 ? 'PM' : 'AM';
      return '$h:' + t.minute.toString().padLeft(2, '0') + ' $ampm';
    }
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
  }

  // ── Recent searches (shown when the search bar is empty) ──────────
  Widget _buildRecentSearches(Color textPrimary, Color textSecondary,
      Color textMuted, Color border) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent searches',
                  style: TextStyle(color: textMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: () async {
                  await HomeSearchService.instance.clearSearchHistory();
                  _loadRecentSearches();
                },
                child: Text('Clear all',
                    style: TextStyle(color: KoraColors.purple, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        for (final q in _recentSearches)
          InkWell(
            onTap: () {
              _searchController.text = q;
              _onSearchChanged(q);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              child: Row(
                children: [
                  Icon(Icons.history, color: textMuted, size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      q,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textPrimary, fontSize: 14.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      await HomeSearchService.instance.removeRecentSearch(q);
                      _loadRecentSearches();
                    },
                    child: Icon(Icons.close, color: textMuted, size: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
