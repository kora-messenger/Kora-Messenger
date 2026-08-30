import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';

import '../../theme/kora_colors.dart';
import '../../widgets/kora_avatar.dart';
import '../../widgets/channel_reactions_bar.dart';
import '../new_community_screen.dart';
import '../community_info_screen.dart';
import '../community_directory_screen.dart';
import '../channel_creation_screen.dart';
import '../channel_invite_screen.dart';

/// "Communities" tab — Kora's WhatsApp-style Communities hub.
///
/// Layout:
/// - Header: "Communities" title + 3-dot menu
/// - List of communities the user belongs to
/// - Each community shows: avatar, name, groups count, last activity
/// - Tapping a community opens CommunityInfoScreen
/// - "New community" button at the bottom
class ChannelsTab extends StatefulWidget {
  const ChannelsTab({super.key});

  @override
  State<ChannelsTab> createState() => _ChannelsTabState();
}

class _ChannelsTabState extends State<ChannelsTab> {
  static const _prefsKey = 'kora_communities';
  final List<_Community> _communities = [];

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  Future<void> _loadCommunities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        if (mounted) {
          setState(() {
            _communities.clear();
            for (final item in list) {
              final m = item as Map<String, dynamic>;
              _communities.add(_Community(
                name: m['name'] ?? '',
                description: m['description'] ?? '',
                iconPath: m['iconPath'],
                createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
                groups: (m['groups'] as List<dynamic>?)?.map((g) => _Group(
                  name: g['name'] ?? '',
                  isAnnouncement: g['isAnnouncement'] ?? false,
                  lastMessage: g['lastMessage'],
                  lastTime: g['lastTime'],
                )).toList() ?? [],
              ));
            }
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _saveCommunities() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _communities.map((c) => {
      'name': c.name,
      'description': c.description,
      'iconPath': c.iconPath,
      'createdAt': c.createdAt.toIso8601String(),
      'groups': c.groups.map((g) => {
        'name': g.name,
        'isAnnouncement': g.isAnnouncement,
        'lastMessage': g.lastMessage,
        'lastTime': g.lastTime,
      }).toList(),
    }).toList();
    await prefs.setString(_prefsKey, jsonEncode(list));
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final card = KoraColors.cardFor(brightness);
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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  Text('Communities',
                      style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: textPrimary, size: 22),
                    onPressed: _showMoreOptions,
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: _communities.isEmpty
                  ? _buildEmptyState(textPrimary, textSecondary, textMuted, surface, border)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: _communities.length,
                      itemBuilder: (context, index) {
                        final community = _communities[index];
                        return _buildCommunityTile(community, card, textPrimary, textSecondary, textMuted, border, surface);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createCommunity,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            gradient: KoraColors.brandGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: KoraColors.purple.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary, Color textMuted, Color surface, Color border) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                gradient: KoraColors.brandGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: KoraColors.purple.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.groups_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 24),
            Text('Stay connected with a community',
                style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text('Communities bring members together in topic-based groups. Create a community to get started.',
                style: TextStyle(color: textSecondary, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            // New community button
            GestureDetector(
              onTap: _createCommunity,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: KoraColors.brandGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: KoraColors.purple.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text('New community',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityTile(
    _Community community,
    Color card,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color border,
    Color surface,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Column(
        children: [
          // Community header row
          ListTile(
            onTap: () => _openCommunity(community),
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            leading: _buildCommunityAvatar(community),
            title: Text(community.name,
                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            subtitle: Text(
              '${community.groups.length} ${community.groups.length == 1 ? "group" : "groups"}',
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
            trailing: Icon(Icons.chevron_right, color: textMuted, size: 24),
          ),
          // Groups under community (show first 3)
          ...community.groups.take(3).map((group) => _buildGroupRow(
              group, surface, textPrimary, textSecondary, textMuted, border, community)),
          if (community.groups.length > 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: GestureDetector(
                onTap: () => _openCommunity(community),
                child: Text('View all ${community.groups.length} groups',
                    style: TextStyle(color: KoraColors.purple, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommunityAvatar(_Community community) {
    if (community.iconPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(File(community.iconPath!), width: 48, height: 48, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        gradient: KoraColors.brandGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          community.name.isNotEmpty ? community.name[0].toUpperCase() : 'K',
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildGroupRow(
    _Group group,
    Color surface,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color border,
    _Community community,
  ) {
    return ListTile(
      onTap: () => _openCommunity(community),
      contentPadding: const EdgeInsets.fromLTRB(56, 0, 16, 4),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: surface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          group.isAnnouncement ? Icons.campaign_outlined : Icons.group_outlined,
          color: group.isAnnouncement ? KoraColors.purple : textMuted,
          size: 18,
        ),
      ),
      title: Row(
        children: [
          if (group.isAnnouncement)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Announcement',
                  style: TextStyle(color: KoraColors.purple, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          Expanded(
            child: Text(group.name,
                style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      subtitle: group.lastMessage != null
          ? Text(group.lastMessage!, style: TextStyle(color: textMuted, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis)
          : Text('Tap to start chatting', style: TextStyle(color: textMuted, fontSize: 12)),
      trailing: group.lastTime != null
          ? Text(group.lastTime!, style: TextStyle(color: textMuted, fontSize: 11))
          : null,
    );
  }

  void _createCommunity() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewCommunityScreen()),
    );
    if (result != null && result is _Community && mounted) {
      setState(() => _communities.add(result));
      await _saveCommunities();
    }
  }

  void _openCommunity(_Community community) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityInfoScreen(community: community),
      ),
    ).then((updated) {
      if (updated != null && updated is _Community && mounted) {
        setState(() {
          final idx = _communities.indexWhere((c) => c.name == updated.name);
          if (idx >= 0) _communities[idx] = updated;
        });
        _saveCommunities();
      }
    });
  }

  void _showMoreOptions() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: KoraColors.textSecondaryFor(brightness).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: Icon(Icons.add, color: textPrimary),
            title: Text('New community', style: TextStyle(color: textPrimary)),
            onTap: () { Navigator.pop(context); _createCommunity(); },
          ),
          ListTile(
            leading: Icon(Icons.travel_explore_outlined, color: textPrimary),
            title: Text('Discover communities', style: TextStyle(color: textPrimary)),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CommunityDirectoryScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.campaign_outlined, color: textPrimary),
            title: Text('Create channel', style: TextStyle(color: textPrimary)),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChannelCreationScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.settings_outlined, color: textPrimary),
            title: Text('Community settings', style: TextStyle(color: textPrimary)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Community {
  final String name;
  final String description;
  final String? iconPath;
  final DateTime createdAt;
  final List<_Group> groups;

  _Community({
    required this.name,
    this.description = '',
    this.iconPath,
    required this.createdAt,
    List<_Group>? groups,
  }) : groups = groups ?? [];
}

class _Group {
  final String name;
  final bool isAnnouncement;
  final String? lastMessage;
  final String? lastTime;

  _Group({
    required this.name,
    this.isAnnouncement = false,
    this.lastMessage,
    this.lastTime,
  });
}
