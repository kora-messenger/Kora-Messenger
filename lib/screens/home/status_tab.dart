import 'package:flutter/material.dart';

import '../../theme/kora_colors.dart';
import '../../services/session_manager.dart';
import '../../widgets/kora_avatar.dart';

/// A single "Find channels to follow" suggestion row.
class _ChannelSuggestion {
  final String name;
  final String followers;
  final Color color;
  final IconData icon;
  bool following = false;
  bool dismissed = false;

  _ChannelSuggestion({
    required this.name,
    required this.followers,
    required this.color,
    required this.icon,
  });
}

/// "Updates" screen — Kora's own take on the merged Status + Community
/// page: "Add status" up top (disappears after 24h, like the reference),
/// then a "Community" section with a dismissible "Find channels to
/// follow" suggestion list.
///
/// Tapping the short chevron collapses/restores the suggested channels:
/// ▲ hides the list (replaced by "Explore more" + "Create channel"),
/// ▼ brings it back.
class StatusTab extends StatefulWidget {
  const StatusTab({super.key});

  @override
  State<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<StatusTab> {
  bool _suggestionsExpanded = true;
  Map<String, dynamic>? _session;

  final List<_ChannelSuggestion> _suggestions = [
    _ChannelSuggestion(
      name: 'Kora Tech News',
      followers: '842K followers',
      color: KoraColors.purple,
      icon: Icons.bolt,
    ),
    _ChannelSuggestion(
      name: 'Naija Football Daily',
      followers: '611K followers',
      color: KoraColors.blue,
      icon: Icons.sports_soccer,
    ),
    _ChannelSuggestion(
      name: 'Afrobeats Central',
      followers: '398K followers',
      color: const Color(0xFFEC4899),
      icon: Icons.music_note,
    ),
    _ChannelSuggestion(
      name: 'Kora Community Updates',
      followers: '215K followers',
      color: const Color(0xFF22C55E),
      icon: Icons.campaign,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await SessionManager.instance.loadSession();
    if (mounted) setState(() => _session = session);
  }

  void _dismissSuggestion(_ChannelSuggestion s) {
    setState(() => s.dismissed = true);
  }

  void _toggleFollow(_ChannelSuggestion s) {
    setState(() => s.following = !s.following);
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — coming soon'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final border = KoraColors.borderFor(brightness);

    final visibleSuggestions = _suggestions.where((s) => !s.dismissed).toList();
    final fullName = _session?['fullName'] as String? ?? 'You';
    final avatarUrl = _session?['avatarUrl'] as String? ?? '';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  Text(
                    'Updates',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.search, color: textSecondary, size: 22),
                    onPressed: () => _comingSoon('Search updates'),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: textSecondary, size: 22),
                    onPressed: () => _comingSoon('More options'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 110),
                children: [
                  _sectionLabel('Status', textPrimary),
                  _addStatusTile(fullName, avatarUrl, bg, textPrimary, textSecondary),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Divider(color: border, height: 1),
                  ),
                  _sectionLabel('Community', textPrimary),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Text(
                      'Stay updated on topics that matter to you. Find communities to follow below.',
                      style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.4),
                    ),
                  ),
                  _findChannelsRow(surface, textSecondary),
                  const SizedBox(height: 4),
                  if (_suggestionsExpanded) ...[
                    ...visibleSuggestions.map(
                      (s) => _channelTile(s, textPrimary, textSecondary),
                    ),
                    _pillButton(
                      icon: Icons.grid_view_rounded,
                      label: 'Explore more',
                      onTap: () => _comingSoon('Explore channels'),
                    ),
                  ] else ...[
                    _pillButton(
                      icon: Icons.grid_view_rounded,
                      label: 'Explore more',
                      onTap: () => _comingSoon('Explore channels'),
                    ),
                    _pillButton(
                      icon: Icons.add,
                      label: 'Create channel',
                      onTap: () => _comingSoon('Create channel'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_suggestionsExpanded) ...[
            Container(
              width: 46,
              height: 46,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
              child: IconButton(
                icon: Icon(Icons.edit_outlined, color: textPrimary, size: 20),
                onPressed: () => _comingSoon('Text status'),
              ),
            ),
          ],
          Container(
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
            child: FloatingActionButton(
              onPressed: () => _comingSoon('Camera status'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sections ─────────────────────────────────────────────────

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _addStatusTile(
    String fullName,
    String avatarUrl,
    Color bg,
    Color textPrimary,
    Color textSecondary,
  ) {
    return ListTile(
      onTap: () => _comingSoon('Add status'),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          KoraAvatar(name: fullName, imageUrl: avatarUrl.isEmpty ? null : avatarUrl, size: 52),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: KoraColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 13),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        'Add status',
        style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Disappears after 24 hours',
        style: TextStyle(color: textSecondary, fontSize: 13),
      ),
    );
  }

  Widget _findChannelsRow(Color surface, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Find channels to follow',
              style: TextStyle(color: textSecondary, fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _suggestionsExpanded = !_suggestionsExpanded),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
              child: Icon(
                _suggestionsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelTile(_ChannelSuggestion s, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
          child: Icon(s.icon, color: Colors.white, size: 22),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                s.name,
                style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.verified, size: 15, color: KoraColors.blue),
          ],
        ),
        subtitle: Text(
          s.followers,
          style: TextStyle(color: textSecondary, fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _toggleFollow(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: s.following
                      ? null
                      : KoraColors.purple.withValues(alpha: 0.14),
                  gradient: s.following ? KoraColors.brandGradient : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s.following ? 'Following' : 'Follow',
                  style: TextStyle(
                    color: s.following ? Colors.white : KoraColors.purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _dismissSuggestion(s),
              child: Icon(Icons.close, size: 18, color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return Builder(
      builder: (context) {
        final brightness = Theme.of(context).brightness;
        final border = KoraColors.borderFor(brightness);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, color: KoraColors.purple, size: 18),
              label: Text(
                label,
                style: const TextStyle(color: KoraColors.purple, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
        );
      },
    );
  }
}
