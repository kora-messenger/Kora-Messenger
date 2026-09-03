import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/kora_api.dart';
import '../../models/chat_models.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_avatar.dart';
import '../../utils/kora_page_routes.dart';
import '../../services/accounts_manager.dart';
import '../../services/contacts_service.dart';
import '../../services/conversation_directory.dart';
import '../chat/kora_chat_screen.dart';
import '../new_community_screen.dart';
import '../new_group_screen.dart';
import 'new_contact_screen.dart';
import 'qr_code_screen.dart';

/// Kora's "Select contact" screen — the entry point for starting a new
/// chat (the compose/pencil action on Home). Deep-matched against the
/// reference recording:
///
/// - Back arrow + "Select contact" title with a live contact-count
///   subtitle, search icon, 3-dot menu (Refresh / Invite a friend).
/// - Three action rows in this exact order: New group, New contact
///   (with a small QR-code icon on the row itself), New community.
/// - "Contacts on Kora" section listing every contact — starting with
///   the user's own account as "<Name> (You)" / "Message yourself",
///   exactly like the reference's "Wisdom MTN (You)" top entry.
/// - Tapping any contact opens the chat directly (not a contact-info
///   page) — this screen's whole purpose is starting a conversation.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  bool _isLoading = true;
  bool _isSearching = false;
  String _query = '';

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  List<Map<String, Object?>> _contacts = [];

  // The active account's own profile, shown as the "Message yourself"
  // row at the top of the contact list.
  String _myName = '';
  String _myAvatarUrl = '';
  String _myEmail = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final email = await AccountsManager.instance.getActiveEmail() ?? '';
    final accounts = await AccountsManager.instance.getAccounts();
    final me = accounts.firstWhere(
      (a) => (a['email'] as String?)?.toLowerCase().trim() == email.toLowerCase().trim(),
      orElse: () => const {},
    );
    final contacts = await ContactsService.instance.getContacts();

    if (!mounted) return;
    setState(() {
      _myEmail = email;
      _myName = (me['fullName'] as String?)?.trim() ?? '';
      _myAvatarUrl = (me['avatarUrl'] as String?) ?? '';
      _contacts = contacts;
      _isLoading = false;
    });
  }

  List<Map<String, Object?>> get _filteredContacts {
    if (_query.isEmpty) return _contacts;
    final q = _query.toLowerCase();
    return _contacts.where((c) {
      final name = (c['name'] as String? ?? '').toLowerCase();
      final koraId = (c['koraId'] as String? ?? '').toLowerCase();
      final username = (c['username'] as String? ?? '').toLowerCase();
      final phone = (c['phoneNumber'] as String? ?? '').toLowerCase();
      return name.contains(q) || koraId.contains(q) || username.contains(q) || phone.contains(q);
    }).toList();
  }

  bool get _myNameMatchesQuery {
    if (_query.isEmpty) return true;
    return _myName.toLowerCase().contains(_query.toLowerCase());
  }

  // ── Actions ──────────────────────────────────────────────────

  void _closeSearchOrPop() {
    if (_isSearching) {
      setState(() {
        _isSearching = false;
        _query = '';
        _searchController.clear();
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _openSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _openSelfChat() async {
    Navigator.push(
      context,
      SlideUpPageRoute(
        builder: (_) => KoraChatScreen(
          chatId: 'self_${_myEmail.toLowerCase()}',
          name: _myName.isNotEmpty ? _myName : 'You',
          avatarUrl: _myAvatarUrl.isNotEmpty ? _myAvatarUrl : null,
          badge: KoraBadgeType.none,
          isOnline: true,
          recipientEmail: _myEmail,
        ),
      ),
    );
  }

  Future<void> _openContactChat(Map<String, Object?> contact) async {
    final name = contact['name'] as String? ?? '';
    final koraId = contact['koraId'] as String? ?? '';
    final username = contact['username'] as String? ?? '';
    final email = contact['email'] as String? ?? '';
    final phone = contact['phoneNumber'] as String? ?? '';
    final avatarUrl = contact['avatarUrl'] as String? ?? '';
    final isPremium = contact['premium'] == true;

    final fallbackId = koraId.isNotEmpty
        ? koraId
        : (username.isNotEmpty ? username : (phone.isNotEmpty ? phone : name));

    // Kora users get a deterministic shared thread (same chatId on both
    // sides). Phone-only contacts who aren't on Kora yet fall back to a
    // locally-keyed chat, same convention as New Contact's non-matched path.
    final chatId = email.isNotEmpty
        ? await ConversationDirectoryService.resolveDmChatId(
            recipientEmail: email,
            myEmail: _myEmail,
            fallback: fallbackId,
          )
        : fallbackId;

    if (!mounted) return;
    Navigator.push(
      context,
      SlideUpPageRoute(
        builder: (_) => KoraChatScreen(
          chatId: chatId,
          name: name.isNotEmpty ? name : fallbackId,
          avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
          badge: isPremium ? KoraBadgeType.premiumBlue : KoraBadgeType.none,
          isOnline: false,
          recipientEmail: email.isNotEmpty ? email : null,
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    final filtered = _filteredContacts;
    final showSelf = _myNameMatchesQuery;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: _closeSearchOrPop,
        ),
        titleSpacing: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: TextStyle(color: textPrimary, fontSize: 17),
                cursorColor: KoraColors.purple,
                decoration: InputDecoration(
                  hintText: 'Name, number, @username',
                  hintStyle: TextStyle(color: textMuted, fontSize: 17),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select contact',
                    style: TextStyle(color: textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  if (!_isLoading)
                    Text(
                      '${_contacts.length} contacts',
                      style: TextStyle(color: textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                ],
              ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: Icon(Icons.search, color: textPrimary),
              onPressed: _openSearch,
            ),
          if (!_isSearching)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: textPrimary),
              color: KoraColors.cardFor(brightness),
              onSelected: (value) {
                if (value == 'refresh') {
                  _load();
                } else if (value == 'invite') {
                  Share.share(
                    'Join me on Kora Messenger: ${KoraApi.inviteDownloadUrl}',
                    subject: 'Join me on Kora Messenger',
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'refresh', child: Text('Refresh', style: TextStyle(color: textPrimary))),
                PopupMenuItem(value: 'invite', child: Text('Invite a friend', style: TextStyle(color: textPrimary))),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: KoraColors.purple))
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (!_isSearching) ...[
                    _actionRow(
                      icon: Icons.group_add_rounded,
                      label: 'New group',
                      textPrimary: textPrimary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NewGroupScreen()),
                      ),
                    ),
                    _actionRow(
                      icon: Icons.person_add_rounded,
                      label: 'New contact',
                      textPrimary: textPrimary,
                      trailing: IconButton(
                        icon: Icon(Icons.qr_code_2_rounded, color: textSecondary, size: 24),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const QrCodeScreen()),
                        ),
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NewContactScreen()),
                        );
                        _load();
                      },
                    ),
                    _actionRow(
                      icon: Icons.groups_rounded,
                      label: 'New community',
                      textPrimary: textPrimary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NewCommunityScreen()),
                      ),
                    ),
                    Divider(height: 1, color: border, indent: 20, endIndent: 20),
                    const SizedBox(height: 4),
                  ],
                  if (showSelf || filtered.isNotEmpty) ...[
                    _sectionHeader('Contacts on Kora', textMuted),
                    if (showSelf) _selfTile(textPrimary, textSecondary),
                    ...filtered.map((c) => _contactTile(c, textPrimary, textSecondary)),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search_outlined, size: 40, color: textMuted),
                            const SizedBox(height: 12),
                            Text('No contacts found', style: TextStyle(color: textSecondary, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    required Color textPrimary,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(gradient: KoraColors.brandGradient, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
      title: Text(label, style: TextStyle(color: textPrimary, fontSize: 15.5, fontWeight: FontWeight.w600)),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _sectionHeader(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _selfTile(Color textPrimary, Color textSecondary) {
    final name = _myName.isNotEmpty ? _myName : 'You';
    return ListTile(
      leading: KoraAvatar(name: name, imageUrl: _myAvatarUrl.isNotEmpty ? _myAvatarUrl : null, size: 48),
      title: Text('$name (You)', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text('Message yourself', style: TextStyle(color: textSecondary, fontSize: 13)),
      onTap: _openSelfChat,
    );
  }

  Widget _contactTile(Map<String, Object?> contact, Color textPrimary, Color textSecondary) {
    final name = contact['name'] as String? ?? '';
    final koraId = contact['koraId'] as String? ?? '';
    final username = contact['username'] as String? ?? '';
    final phone = contact['phoneNumber'] as String? ?? '';
    final avatarUrl = contact['avatarUrl'] as String? ?? '';
    final isPremium = contact['premium'] == true;

    final displayName = name.isNotEmpty ? name : (username.isNotEmpty ? '@$username' : phone);
    final subtitle = username.isNotEmpty
        ? '@$username'
        : (koraId.isNotEmpty ? koraId : (phone.isNotEmpty ? phone : 'Not on Kora yet'));

    return ListTile(
      leading: KoraAvatar(name: displayName, imageUrl: avatarUrl.isNotEmpty ? avatarUrl : null, size: 48, isPremium: isPremium),
      title: Text(displayName, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 13)),
      onTap: () => _openContactChat(contact),
    );
  }
}
