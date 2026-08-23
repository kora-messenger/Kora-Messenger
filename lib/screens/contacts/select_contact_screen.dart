import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/kora_api.dart';
import '../../models/chat_models.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_avatar.dart';
import '../chat/call_screen.dart';
import '../chat/contact_info_screen.dart';
import '../new_community_screen.dart';
import '../new_group_screen.dart';
import 'new_contact_screen.dart';
import 'qr_code_screen.dart';

/// A Kora contact the user has explicitly added (via "New contact"),
/// loaded straight from local storage — never a device/phone contact.
class _RecentContact {
  final String name;
  final String koraId;
  final String username;
  final String phoneNumber;

  _RecentContact({
    required this.name,
    required this.koraId,
    required this.username,
    required this.phoneNumber,
  });

  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    if (username.isNotEmpty) return '@$username';
    return phoneNumber;
  }

  String get subtitle {
    if (username.isNotEmpty) return '@$username';
    if (phoneNumber.isNotEmpty) return phoneNumber;
    return koraId;
  }

  /// Unique-ish key used to de-duplicate the list (most recent wins).
  String get dedupeKey {
    if (koraId.isNotEmpty) return 'k:$koraId';
    if (username.isNotEmpty) return 'u:${username.toLowerCase()}';
    return 'p:$phoneNumber';
  }
}

/// Kora's "Select contact" screen — the entry point for starting a new
/// call. Opens straight into search (keyboard up, ready to type) just
/// like the reference flow; a back arrow closes the search and reveals
/// the user's own "Recently added" Kora contacts — never the device's
/// phone contact list.
class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key});

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  static const _kContactsKey = 'kora_contacts';

  bool _isLoading = true;
  bool _isSearching = true; // Opens straight into search, keyboard up.

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _query = '';

  List<_RecentContact> _recentContacts = [];

  @override
  void initState() {
    super.initState();
    _loadRecentContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentContacts() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kContactsKey) ?? [];

    final parsed = <_RecentContact>[];
    for (final json in raw) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        parsed.add(_RecentContact(
          name: (map['name'] as String? ?? '').trim(),
          koraId: (map['koraId'] as String? ?? '').trim(),
          username: (map['username'] as String? ?? '').trim(),
          phoneNumber: (map['phoneNumber'] as String? ?? '').trim(),
        ));
      } catch (_) {
        // Skip malformed entries.
      }
    }

    // Most recently added first (entries are appended on save).
    final reversed = parsed.reversed.toList();

    // De-duplicate, keeping the most recent occurrence of each contact.
    final seen = <String>{};
    final deduped = <_RecentContact>[];
    for (final c in reversed) {
      if (seen.add(c.dedupeKey)) deduped.add(c);
    }

    if (!mounted) return;
    setState(() {
      _recentContacts = deduped;
      _isLoading = false;
    });
  }

  List<_RecentContact> get _filteredRecent {
    if (_query.isEmpty) return _recentContacts;
    final q = _query.toLowerCase();
    return _recentContacts.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.username.toLowerCase().contains(q) ||
          c.koraId.toLowerCase().contains(q) ||
          c.phoneNumber.toLowerCase().contains(q);
    }).toList();
  }

  // ── Actions ──────────────────────────────────────────────────

  void _openContact(_RecentContact contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactInfoScreen(
          name: contact.displayName,
          koraId: contact.koraId.isNotEmpty ? contact.koraId : null,
          username: contact.username.isNotEmpty ? contact.username : null,
          about: 'Hey there! I\'m on Kora.',
          badge: KoraBadgeType.none,
          isOnline: true,
          phone: contact.phoneNumber.isNotEmpty ? contact.phoneNumber : null,
        ),
      ),
    );
  }

  void _callContact(_RecentContact contact, {bool isVideo = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          contactName: contact.displayName,
          isVideoCall: isVideo,
          isOutgoing: true,
          badge: KoraBadgeType.none,
        ),
      ),
    );
  }

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
    // Re-focus so the keyboard reliably pops back up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
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

    final filteredRecent = _filteredRecent;

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
                  hintText: 'Search name or number',
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
                      '${_recentContacts.length} recently added',
                      style: TextStyle(color: KoraColors.purple, fontSize: 12.5, fontWeight: FontWeight.w600),
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
                  _loadRecentContacts();
                } else if (value == 'invite') {
                  Share.share(
                    'Join me on Kora Messenger: ${KoraApi.inviteDownloadUrl}',
                    subject: 'Join me on Kora Messenger',
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'refresh',
                  child: Text('Refresh', style: TextStyle(color: textPrimary)),
                ),
                PopupMenuItem(
                  value: 'invite',
                  child: Text('Invite a friend', style: TextStyle(color: textPrimary)),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoading(textSecondary)
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (!_isSearching) ...[
                    _actionRow(
                      icon: Icons.person_add_rounded,
                      label: 'New contact',
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
                        _loadRecentContacts();
                      },
                    ),
                    _actionRow(
                      icon: Icons.group_add_rounded,
                      label: 'New group',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NewGroupScreen()),
                      ),
                    ),
                    _actionRow(
                      icon: Icons.groups_rounded,
                      label: 'New community',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NewCommunityScreen()),
                      ),
                    ),
                    Divider(height: 1, color: border, indent: 20, endIndent: 20),
                    const SizedBox(height: 4),
                  ],
                  if (filteredRecent.isNotEmpty) ...[
                    _sectionHeader('Recently added', textMuted),
                    ...filteredRecent.map((c) => _recentContactTile(c, textPrimary, textSecondary)),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search_outlined, size: 40, color: textMuted),
                            const SizedBox(height: 12),
                            Text(
                              _isSearching || _query.isNotEmpty
                                  ? 'No contacts found'
                                  : 'No recently added Kora contacts yet',
                              style: TextStyle(color: textSecondary, fontSize: 14),
                            ),
                            if (!_isSearching && _query.isEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Tap "New contact" to add someone',
                                style: TextStyle(color: textMuted, fontSize: 12.5),
                              ),
                            ],
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

  Widget _buildLoading(Color textSecondary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6, color: KoraColors.purple),
          ),
          const SizedBox(height: 16),
          Text('Loading contacts…', style: TextStyle(color: textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label,
        style: TextStyle(color: textMuted, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    );
  }

  /// A quick-action row (New contact / New group / New community) with
  /// a Kora-branded gradient circle icon.
  Widget _actionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: KoraColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _recentContactTile(_RecentContact contact, Color textPrimary, Color textSecondary) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: KoraAvatar(name: contact.displayName, size: 46),
      title: Text(
        contact.displayName,
        style: TextStyle(color: textPrimary, fontSize: 15.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        contact.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: textSecondary, fontSize: 13),
      ),
      trailing: GestureDetector(
        onTap: () => _callContact(contact),
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            gradient: KoraColors.brandGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.call_rounded, color: Colors.white, size: 18),
        ),
      ),
      onTap: () => _openContact(contact),
    );
  }
}
