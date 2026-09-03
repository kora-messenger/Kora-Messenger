import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/conversation_directory.dart';
import '../theme/kora_colors.dart';
import '../utils/kora_page_routes.dart';
import '../widgets/chat_list_item.dart';
import '../widgets/kora_empty_state.dart';
import 'chat/kora_chat_screen.dart';

/// Archived chats screen — shows chats the user has archived.
/// Long-press a chat to select it, then use the "Unarchive" action to
/// bring it back to the main Home list.
class ArchivedChatsScreen extends StatefulWidget {
  const ArchivedChatsScreen({super.key});

  @override
  State<ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<ArchivedChatsScreen> {
  List<ChatPreview> _chats = [];
  bool _loading = true;
  final Set<String> _selectedIds = {};
  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final chats = await ChatService.instance.getArchivedChats();
    if (!mounted) return;
    setState(() {
      _chats = chats;
      _loading = false;
    });
  }

  void _openChat(ChatPreview chat) {
    pushSlideUp(
      context,
      KoraChatScreen(
        isGroupChat: false,
        chatId: chat.id,
        name: chat.name,
        avatarAsset: chat.avatarAsset,
        avatarUrl: chat.avatarUrl,
        badge: chat.badge,
        isOnline: chat.isOnline,
        lastSeen: chat.isOnline ? null : 'last seen recently',
      ),
    );
  }

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

  void _onChatLongPress(ChatPreview chat) {
    setState(() {
      if (_selectedIds.contains(chat.id)) {
        _selectedIds.remove(chat.id);
      } else {
        _selectedIds.add(chat.id);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  Future<void> _unarchiveSelected() async {
    final ids = List<String>.from(_selectedIds);
    if (ids.isEmpty) return;
    for (final id in ids) {
      await ConversationDirectoryService.instance.setArchived(id, false);
    }
    final count = ids.length;
    _clearSelection();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count == 1 ? 'Chat unarchived' : '$count chats unarchived'),
          backgroundColor: KoraColors.purple,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    // WhatsApp behavior: back while chats are selected cancels the
    // selection instead of leaving the screen.
    return PopScope(
      canPop: !_isSelecting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isSelecting) {
          setState(() => _selectedIds.clear());
        }
      },
      child: Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        title: _isSelecting
            ? Text(
                '${_selectedIds.length}',
                style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
              )
            : Text(
                'Archived Chats',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: _isSelecting ? _clearSelection : () => Navigator.pop(context),
        ),
        actions: _isSelecting
            ? [
                IconButton(
                  tooltip: 'Unarchive',
                  icon: Icon(Icons.unarchive_outlined, color: textPrimary),
                  onPressed: _unarchiveSelected,
                ),
              ]
            : null,
      ),
      body: _loading
          ? const SizedBox.shrink()
          : _chats.isEmpty
              ? const KoraEmptyState(
                  icon: Icons.archive_outlined,
                  title: 'No archived chats',
                  message: 'Long-press a chat and select "Archive" to move it here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: _chats.length,
                  separatorBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(left: 84),
                    child: Divider(
                      height: 1,
                      color: textSecondary.withValues(alpha: 0.08),
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    return ChatListItem(
                      chat: chat,
                      isSelected: _selectedIds.contains(chat.id),
                      onTap: () => _onChatTap(chat),
                      onLongPress: (_) => _onChatLongPress(chat),
                    );
                  },
                ),
    ),
    );
  }
}
