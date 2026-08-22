import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/kora_api.dart';
import '../../models/chat_models.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_avatar.dart';
import '../chat/contact_info_screen.dart';
import '../new_community_screen.dart';
import '../new_group_screen.dart';
import 'new_contact_screen.dart';
import 'qr_code_screen.dart';

/// A merged entry combining a device contact with its Kora registration
/// status (if any).
class _MergedContact {
  final Contact contact;
  final bool onKora;
  final Map<String, dynamic>? koraUser;
  final String matchedPhone;

  _MergedContact({
    required this.contact,
    required this.onKora,
    this.koraUser,
    required this.matchedPhone,
  });

  String get displayName {
    final name = contact.displayName ?? '';
    return name.trim().isEmpty ? matchedPhone : name.trim();
  }
}

/// Kora's "Select contact" screen — the entry point for starting a new
/// chat, group, or community. Mirrors the familiar contact-picker layout
/// (quick actions up top, then a synced contacts list) but built in
/// Kora's own visual identity: purple-to-blue gradient action icons
/// instead of flat green ones, and real backend-verified "on Kora"
/// status per contact instead of a static placeholder.
class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key});

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  bool _isLoading = true;
  bool _permissionDenied = false;
  bool _isSearching = false;

  final _searchController = TextEditingController();
  String _query = '';

  List<_MergedContact> _koraContacts = [];
  List<_MergedContact> _inviteContacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
    });

    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _permissionDenied = true;
      });
      return;
    }

    List<Contact> deviceContacts = [];
    try {
      deviceContacts = await FlutterContacts.getAll(properties: ContactProperties.all);
    } catch (_) {
      deviceContacts = [];
    }

    // Only keep contacts that have at least one phone number.
    final withPhones = deviceContacts.where((c) => c.phones.isNotEmpty).toList();
    withPhones.sort((a, b) =>
        (a.displayName ?? '').toLowerCase().compareTo((b.displayName ?? '').toLowerCase()));

    final koraMatches = <_MergedContact>[];
    final inviteMatches = <_MergedContact>[];

    // Check each contact's primary phone number against the Kora backend,
    // a handful at a time so we don't fire hundreds of requests at once.
    const batchSize = 8;
    for (var i = 0; i < withPhones.length; i += batchSize) {
      final batch = withPhones.skip(i).take(batchSize).toList();
      final results = await Future.wait(batch.map((c) => _checkContact(c)));
      for (final merged in results) {
        if (merged.onKora) {
          koraMatches.add(merged);
        } else {
          inviteMatches.add(merged);
        }
      }
      if (mounted) {
        // Progressive reveal so the list doesn't feel frozen on big
        // contact books.
        setState(() {
          _koraContacts = List.of(koraMatches);
          _inviteContacts = List.of(inviteMatches);
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _koraContacts = koraMatches;
      _inviteContacts = inviteMatches;
    });
  }

  Future<_MergedContact> _checkContact(Contact contact) async {
    final phone = contact.phones.first.number;
    try {
      final res = await http.post(
        Uri.parse(KoraApi.authEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'checkPhoneNumber', 'phoneNumber': phone}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(res.body);
      if (data['success'] == true && data['registered'] == true) {
        return _MergedContact(
          contact: contact,
          onKora: true,
          koraUser: data['user'] as Map<String, dynamic>?,
          matchedPhone: phone,
        );
      }
    } catch (_) {
      // Network hiccup — treat as not-on-Kora for this pass, non-fatal.
    }
    return _MergedContact(contact: contact, onKora: false, matchedPhone: phone);
  }

  List<_MergedContact> _filtered(List<_MergedContact> source) {
    if (_query.isEmpty) return source;
    final q = _query.toLowerCase();
    return source.where((m) {
      final name = m.displayName.toLowerCase();
      final phone = m.matchedPhone.toLowerCase();
      final username = (m.koraUser?['username'] as String? ?? '').toLowerCase();
      final koraId = (m.koraUser?['koraId'] as String? ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q) || username.contains(q) || koraId.contains(q);
    }).toList();
  }

  void _openContact(_MergedContact merged) {
    final user = merged.koraUser;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactInfoScreen(
          name: (user?['fullName'] as String?)?.isNotEmpty == true
              ? user!['fullName'] as String
              : merged.displayName,
          koraId: user?['koraId'] as String?,
          username: user?['username'] as String?,
          about: (user?['bio'] as String?)?.isNotEmpty == true
              ? user!['bio'] as String
              : 'Hey there! I\'m on Kora.',
          avatarUrl: (user?['avatarUrl'] as String?)?.isNotEmpty == true
              ? user!['avatarUrl'] as String
              : null,
          badge: KoraBadgeType.none,
          isOnline: true,
          phone: merged.matchedPhone,
        ),
      ),
    );
  }

  void _inviteContact(_MergedContact merged) {
    Share.share(
      'Hey ${merged.displayName.split(' ').first}! I\'m on Kora Messenger — join me here: ${KoraApi.inviteDownloadUrl}',
      subject: 'Join me on Kora Messenger',
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    final totalContacts = _koraContacts.length + _inviteContacts.length;
    final filteredKora = _filtered(_koraContacts);
    final filteredInvite = _filtered(_inviteContacts);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () {
            if (_isSearching) {
              setState(() {
                _isSearching = false;
                _query = '';
                _searchController.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        titleSpacing: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: textPrimary, fontSize: 17),
                cursorColor: KoraColors.purple,
                decoration: InputDecoration(
                  hintText: 'Search contacts',
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
                      '$totalContacts contacts',
                      style: TextStyle(color: KoraColors.purple, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: Icon(Icons.search, color: textPrimary),
              onPressed: () => setState(() => _isSearching = true),
            ),
          if (!_isSearching)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: textPrimary),
              color: KoraColors.cardFor(brightness),
              onSelected: (value) {
                if (value == 'refresh') {
                  _loadContacts();
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
                  child: Text('Refresh contacts', style: TextStyle(color: textPrimary)),
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
            : _permissionDenied
                ? _buildPermissionDenied(textPrimary, textSecondary)
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (!_isSearching) ...[
                        _actionRow(
                          gradient: true,
                          icon: Icons.group_add_rounded,
                          label: 'New group',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NewGroupScreen()),
                          ),
                        ),
                        _actionRow(
                          gradient: true,
                          icon: Icons.person_add_rounded,
                          label: 'New contact',
                          trailing: IconButton(
                            icon: Icon(Icons.qr_code_2_rounded, color: textSecondary, size: 24),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const QrCodeScreen()),
                            ),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NewContactScreen()),
                          ),
                        ),
                        _actionRow(
                          gradient: true,
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
                      if (filteredKora.isNotEmpty) ...[
                        _sectionHeader('Contacts on Kora', textMuted),
                        ...filteredKora.map((m) => _contactTile(m, textPrimary, textSecondary)),
                      ],
                      if (filteredInvite.isNotEmpty) ...[
                        _sectionHeader('Invite to Kora', textMuted),
                        ...filteredInvite.map((m) => _inviteTile(m, textPrimary, textSecondary)),
                      ],
                      if (!_isLoading && filteredKora.isEmpty && filteredInvite.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Center(
                            child: Text(
                              _isSearching ? 'No contacts found' : 'No contacts with phone numbers found',
                              style: TextStyle(color: textSecondary, fontSize: 14),
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
          Text('Syncing contacts…', style: TextStyle(color: textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPermissionDenied(Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contacts_outlined, color: textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(
              'Kora needs access to your contacts to show who\'s already on Kora.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textPrimary, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: KoraColors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () async {
                final result = await Permission.contacts.request();
                if (result.isGranted) {
                  _loadContacts();
                } else {
                  openAppSettings();
                }
              },
              child: const Text('Grant access'),
            ),
          ],
        ),
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

  /// A quick-action row (New group / New contact / New community) with
  /// a Kora-branded gradient circle icon — replaces WhatsApp's flat
  /// green circles with Kora's purple-to-blue identity.
  Widget _actionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool gradient = true,
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

  Widget _contactTile(_MergedContact merged, Color textPrimary, Color textSecondary) {
    final user = merged.koraUser;
    final bio = (user?['bio'] as String?)?.trim();
    final subtitle = (bio != null && bio.isNotEmpty) ? bio : 'Hey there! I\'m on Kora.';
    final avatarUrl = user?['avatarUrl'] as String?;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: KoraAvatar(
        name: merged.displayName,
        imageUrl: (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : null,
        size: 46,
      ),
      title: Text(
        merged.displayName,
        style: TextStyle(color: textPrimary, fontSize: 15.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: textSecondary, fontSize: 13),
      ),
      onTap: () => _openContact(merged),
    );
  }

  Widget _inviteTile(_MergedContact merged, Color textPrimary, Color textSecondary) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: KoraAvatar(name: merged.displayName, size: 46),
      title: Text(
        merged.displayName,
        style: TextStyle(color: textPrimary, fontSize: 15.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        merged.matchedPhone,
        style: TextStyle(color: textSecondary, fontSize: 13),
      ),
      trailing: TextButton(
        onPressed: () => _inviteContact(merged),
        style: TextButton.styleFrom(foregroundColor: KoraColors.purple),
        child: const Text('Invite', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
