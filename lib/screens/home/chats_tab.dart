import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/chat_list_item.dart';
import '../../widgets/kora_empty_state.dart';
import '../../widgets/kora_menu_sheet.dart';
import '../../widgets/new_chat_sheet.dart';
import '../search_screen.dart';

/// The "Chats" tab — Kora's central conversation list.
/// Owns the Home header (branding, avatar, search, three-dot menu) since
/// the header's actions are specific to this tab.
class ChatsTab extends StatefulWidget {
  final VoidCallback? onProfileTap;

  const ChatsTab({super.key, this.onProfileTap});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  List<ChatPreview> _chats = [];

  @override
  void initState() {
    super.initState();
    _chats = ChatService.instance.getChats();
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  void _openMenu() {
    KoraMenuSheet.show(context, [
      KoraMenuOption(
        icon: Icons.group_add_outlined,
        label: 'New Group',
        onTap: () {},
      ),
      KoraMenuOption(
        icon: Icons.campaign_outlined,
        label: 'New Channel',
        onTap: () {},
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

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context, textPrimary),
            Expanded(
              child: _chats.isEmpty
                  ? KoraEmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'No conversations yet',
                      message:
                          'Start a chat with friends, family, or Kora Support to see it here.',
                      actionLabel: 'Start a Chat',
                      onAction: () => NewChatSheet.show(context),
                    )
                  : RefreshIndicator(
                      color: KoraColors.purple,
                      onRefresh: () async {
                        setState(() => _chats = ChatService.instance.getChats());
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.only(top: 4, bottom: 90),
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
                            onTap: () {},
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

  Widget _buildHeader(BuildContext context, Color textPrimary) {
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
            onPressed: _openSearch,
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: textPrimary, size: 24),
            onPressed: _openMenu,
          ),
        ],
      ),
    );
  }
}
