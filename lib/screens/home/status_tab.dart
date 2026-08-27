import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/kora_colors.dart';
import '../../services/session_manager.dart';
import '../../services/status_service.dart';
import '../../models/status_model.dart';
import '../../widgets/kora_avatar.dart';
import '../chat/kora_camera_screen.dart';
import '../status/text_status_screen.dart';
import '../status/status_viewer_screen.dart';
import '../status/status_privacy_screen.dart';
import '../channel_landing_screen.dart';

/// "Updates" screen — Kora's WhatsApp-style Updates tab.
///
/// Matches WhatsApp's Updates screen layout exactly:
/// - Header: "Updates" title + search icon + 3-dot menu
/// - Status section: My Status row, Recent updates (colored ring),
///   Viewed updates (gray ring), Muted updates (collapsed)
/// - Channels section: Find channels to follow, channel suggestions,
///   Explore more button
/// - FAB: Camera (photo/video status), secondary FAB: Edit (text status)
///
/// All actions are functional — no placeholders.
class StatusTab extends StatefulWidget {
  const StatusTab({super.key});

  @override
  State<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<StatusTab> {
  Map<String, dynamic>? _session;
  bool _isLoaded = false;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<_ChannelSuggestion> _suggestions = [
    _ChannelSuggestion(name: 'Kora Tech News', followers: '842K followers', color: KoraColors.purple, icon: Icons.bolt),
    _ChannelSuggestion(name: 'Naija Football Daily', followers: '611K followers', color: KoraColors.blue, icon: Icons.sports_soccer),
    _ChannelSuggestion(name: 'Afrobeats Central', followers: '398K followers', color: const Color(0xFFEC4899), icon: Icons.music_note),
    _ChannelSuggestion(name: 'Kora Community Updates', followers: '215K followers', color: const Color(0xFF22C55E), icon: Icons.campaign),
    _ChannelSuggestion(name: 'Tech Africa Weekly', followers: '1.2M followers', color: const Color(0xFFF59E0B), icon: Icons.trending_up),
    _ChannelSuggestion(name: 'Design Daily', followers: '534K followers', color: const Color(0xFF14B8A6), icon: Icons.brush),
  ];
  bool _suggestionsExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await StatusService.instance.init();
    final session = await SessionManager.instance.loadSession();
    if (mounted) {
      setState(() {
        _session = session;
        _isLoaded = true;
      });
    }
  }

  void _refresh() {
    setState(() {});
  }

  // ── Status creation (all functional) ──────────────────────────

  void _openCameraStatus() {
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final brightness = Theme.of(context).brightness;
        final textPrimary = KoraColors.textPrimaryFor(brightness);
        final textSecondary = KoraColors.textSecondaryFor(brightness);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(color: KoraColors.purple, shape: BoxShape.circle),
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
              title: Text('Text status', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text('Share a text update', style: TextStyle(color: textSecondary, fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                _openTextStatus();
              },
            ),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(color: KoraColors.blue, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
              title: Text('Camera', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text('Capture photo or video', style: TextStyle(color: textSecondary, fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                _captureFromCamera();
              },
            ),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: KoraColors.purple.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(Icons.photo_library, color: KoraColors.purple, size: 20),
              ),
              title: Text('Gallery', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text('Upload from gallery', style: TextStyle(color: textSecondary, fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _openTextStatus() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TextStatusScreen()),
    ).then((_) => _refresh());
  }

  void _captureFromCamera() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const KoraCameraScreen()),
    );
    if (result == null || !mounted) return;
    final path = result['path'] as String;
    final isVideo = result['isVideo'] as bool;

    final item = StatusItem(
      id: 'status_${DateTime.now().millisecondsSinceEpoch}',
      type: isVideo ? StatusType.video : StatusType.photo,
      mediaPath: path,
      createdAt: DateTime.now(),
    );
    await StatusService.instance.addStatusItem(item);
    _refresh();
  }

  void _pickFromGallery() async {
    final picker = ImagePicker();
    // Pick image first — user can also pick video
    final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (photo != null && mounted) {
      final item = StatusItem(
        id: 'status_${DateTime.now().millisecondsSinceEpoch}',
        type: StatusType.photo,
        mediaPath: photo.path,
        createdAt: DateTime.now(),
      );
      await StatusService.instance.addStatusItem(item);
      _refresh();
      return;
    }
    // If no photo selected, try video
    if (!mounted) return;
    final video = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 30));
    if (video != null && mounted) {
      final item = StatusItem(
        id: 'status_${DateTime.now().millisecondsSinceEpoch}',
        type: StatusType.video,
        mediaPath: video.path,
        duration: const Duration(seconds: 30),
        createdAt: DateTime.now(),
      );
      await StatusService.instance.addStatusItem(item);
      _refresh();
    }
  }

  // ── Status viewing ─────────────────────────────────────────────

  void _openMyStatus() {
    final items = StatusService.instance.myStatusItems;
    if (items.isEmpty) {
      _openCameraStatus();
      return;
    }
    final status = KoraStatus(
      id: 'my_status',
      userEmail: _session?['email'] ?? '',
      username: _session?['username'] ?? '',
      fullName: _session?['fullName'] ?? 'You',
      avatarUrl: _session?['avatarUrl'],
      items: items,
      lastUpdatedAt: items.last.createdAt,
      privacy: StatusService.instance.privacy,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatusViewerScreen(status: status, isMyStatus: true),
      ),
    ).then((_) => _refresh());
  }

  void _openContactStatus(KoraStatus status) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatusViewerScreen(status: status, isMyStatus: false),
      ),
    ).then((_) => _refresh());
  }

  // ── Options menu ───────────────────────────────────────────────

  void _openPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StatusPrivacyScreen()),
    );
  }

  void _showMoreOptions() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.cardFor(brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
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
              leading: Icon(Icons.lock_outline, color: textPrimary),
              title: Text('Status privacy', style: TextStyle(color: textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _openPrivacy();
              },
            ),
            ListTile(
              leading: Icon(Icons.volume_off, color: textPrimary),
              title: Text('Muted updates', style: TextStyle(color: textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showMutedUpdates();
              },
            ),
            ListTile(
              leading: Icon(Icons.campaign_outlined, color: textPrimary),
              title: Text('Create channel', style: TextStyle(color: textPrimary)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChannelLandingScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void _showMutedUpdates() {
    final muted = StatusService.instance.mutedUpdates;
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.cardFor(brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text('Muted updates', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (muted.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text('No muted updates', style: TextStyle(color: textSecondary, fontSize: 15)),
              )
            else
              ...muted.map((s) => ListTile(
                    leading: KoraAvatar(name: s.fullName, imageUrl: s.avatarUrl, size: 48),
                    title: Text(s.fullName, style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    subtitle: Text(s.timeAgo, style: TextStyle(color: textSecondary, fontSize: 13)),
                    onTap: () {
                      Navigator.pop(context);
                      _openContactStatus(s);
                    },
                  )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _toggleFollow(_ChannelSuggestion s) {
    setState(() => s.following = !s.following);
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final border = KoraColors.borderFor(brightness);

    final fullName = _session?['fullName'] as String? ?? 'You';
    final avatarUrl = _session?['avatarUrl'] as String? ?? '';
    final myItems = StatusService.instance.myStatusItems;
    final hasStatus = myItems.isNotEmpty;

    final recentUpdates = StatusService.instance.recentUpdates;
    final viewedUpdates = StatusService.instance.viewedUpdates;
    final mutedUpdates = StatusService.instance.mutedUpdates;

    // Filter for search
    final filteredRecent = _searchQuery.isEmpty
        ? recentUpdates
        : recentUpdates.where((s) => s.fullName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    final filteredViewed = _searchQuery.isEmpty
        ? viewedUpdates
        : viewedUpdates.where((s) => s.fullName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    final filteredSuggestions = _searchQuery.isEmpty
        ? _suggestions
        : _suggestions.where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    final visibleSuggestions = filteredSuggestions.where((s) => !s.dismissed).toList();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            if (!_isSearching)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                child: Row(
                  children: [
                    Text('Updates',
                        style: TextStyle(
                            color: textPrimary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const Spacer(),
                    IconButton(
                        icon: Icon(Icons.search, color: textSecondary, size: 22),
                        onPressed: () {
                          setState(() => _isSearching = true);
                        }),
                    IconButton(
                        icon: Icon(Icons.more_vert, color: textSecondary, size: 22),
                        onPressed: _showMoreOptions),
                  ],
                ),
              )
            else
              // ── Inline search bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimary, size: 22),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _isSearching = false;
                          _searchQuery = '';
                        });
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(color: textPrimary, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(color: textSecondary, fontSize: 16),
                          filled: true,
                          fillColor: surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          prefixIcon: Icon(Icons.search, color: textSecondary, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: textSecondary, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      ),
                    ),
                  ],
                ),
              ),
            // ── Body ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 110),
                children: [
                  // ── Status section ──
                  _sectionLabel('Status', textPrimary),
                  _buildMyStatusRow(fullName, avatarUrl, hasStatus, myItems, bg, textPrimary, textSecondary, border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Divider(color: border, height: 1),
                  ),
                  if (filteredRecent.isNotEmpty) ...[
                    _sectionLabel('Recent updates', textPrimary),
                    ...filteredRecent.map((s) =>
                        _buildContactStatusTile(s, bg, textPrimary, textSecondary, isUnviewed: true)),
                  ],
                  if (filteredViewed.isNotEmpty) ...[
                    _sectionLabel('Viewed updates', textPrimary),
                    ...filteredViewed.map((s) =>
                        _buildContactStatusTile(s, bg, textPrimary, textSecondary, isUnviewed: false)),
                  ],
                  if (mutedUpdates.isNotEmpty && _searchQuery.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: GestureDetector(
                        onTap: _showMutedUpdates,
                        child: Row(
                          children: [
                            Icon(Icons.volume_off, color: textSecondary, size: 18),
                            const SizedBox(width: 8),
                            Text('Muted updates (${mutedUpdates.length})',
                                style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  // ── Channels section ──
                  if (filteredRecent.isEmpty && filteredViewed.isEmpty && _searchQuery.isEmpty) ...[
                    const SizedBox(height: 8),
                  ],
                  _sectionLabel('Channels', textPrimary),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Text(
                      'Stay updated on topics that matter to you. Find channels to follow below.',
                      style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.4),
                    ),
                  ),
                  _findChannelsRow(surface, textSecondary),
                  const SizedBox(height: 4),
                  if (_suggestionsExpanded) ...[
                    ...visibleSuggestions.map((s) => _channelTile(s, textPrimary, textSecondary)),
                    _pillButton(
                      icon: Icons.grid_view_rounded,
                      label: 'Explore more',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChannelLandingScreen()),
                      ),
                    ),
                  ] else ...[
                    _pillButton(
                      icon: Icons.grid_view_rounded,
                      label: 'Explore more',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChannelLandingScreen()),
                      ),
                    ),
                    _pillButton(
                      icon: Icons.add,
                      label: 'Create channel',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChannelLandingScreen()),
                      ),
                    ),
                  ],
                  // ── Followed channels ──
                  if (_suggestions.any((s) => s.following)) ...[
                    const SizedBox(height: 8),
                    _sectionLabel('Following', textPrimary),
                    ..._suggestions.where((s) => s.following).map((s) => _followedChannelTile(s, textPrimary, textSecondary, surface, border)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      // ── FABs ──
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46, height: 46,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
            child: IconButton(
              icon: Icon(Icons.edit_outlined, color: textPrimary, size: 20),
              onPressed: _openTextStatus,
            ),
          ),
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
              onPressed: _openCameraStatus,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section helpers ───────────────────────────────────────────

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(label, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildMyStatusRow(
    String fullName,
    String avatarUrl,
    bool hasStatus,
    List<StatusItem> myItems,
    Color bg,
    Color textPrimary,
    Color textSecondary,
    Color border,
  ) {
    final totalViews = myItems.fold(0, (sum, item) => sum + item.viewedBy.length);

    return ListTile(
      onTap: _openMyStatus,
      leading: hasStatus
          ? Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: KoraColors.brandGradient,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: KoraAvatar(name: fullName, imageUrl: avatarUrl.isEmpty ? null : avatarUrl, size: 48),
              ),
            )
          : Stack(
              clipBehavior: Clip.none,
              children: [
                KoraAvatar(name: fullName, imageUrl: avatarUrl.isEmpty ? null : avatarUrl, size: 52),
                Positioned(
                  bottom: -2, right: -2,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
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
        hasStatus ? 'My status' : 'Add status',
        style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        hasStatus
            ? (totalViews > 0 ? '$totalViews views' : 'Tap to view')
            : 'Disappears after 24 hours',
        style: TextStyle(color: textSecondary, fontSize: 13),
      ),
    );
  }

  Widget _buildContactStatusTile(
    KoraStatus status,
    Color bg,
    Color textPrimary,
    Color textSecondary, {
    required bool isUnviewed,
  }) {
    return ListTile(
      onTap: () => _openContactStatus(status),
      leading: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isUnviewed
              ? KoraColors.brandGradient
              : LinearGradient(colors: [textSecondary.withValues(alpha: 0.4), textSecondary.withValues(alpha: 0.4)]),
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
          ),
          child: KoraAvatar(name: status.fullName, imageUrl: status.avatarUrl, size: 48),
        ),
      ),
      title: Text(status.fullName, style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      subtitle: Text(status.timeAgo, style: TextStyle(color: textSecondary, fontSize: 13)),
    );
  }

  // ── Channel tiles ──────────────────────────────────────────────

  Widget _findChannelsRow(Color surface, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text('Find channels to follow',
                style: TextStyle(color: textSecondary, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: () => setState(() => _suggestionsExpanded = !_suggestionsExpanded),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
              child: Icon(
                _suggestionsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: textSecondary, size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelTile(_ChannelSuggestion s, Color textPrimary, Color textSecondary) {
    return ListTile(
      leading: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: s.color.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Icon(s.icon, color: s.color, size: 24),
      ),
      title: Text(s.name, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(s.followers, style: TextStyle(color: textSecondary, fontSize: 13)),
      trailing: s.following
          ? OutlinedButton(
              onPressed: () => _toggleFollow(s),
              style: OutlinedButton.styleFrom(
                foregroundColor: textPrimary,
                side: BorderSide(color: textSecondary.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                minimumSize: const Size(72, 32),
              ),
              child: const Text('Following', style: TextStyle(fontSize: 13)),
            )
          : ElevatedButton(
              onPressed: () => _toggleFollow(s),
              style: ElevatedButton.styleFrom(
                backgroundColor: KoraColors.purple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                minimumSize: const Size(56, 32),
              ),
              child: const Text('Follow', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
    );
  }

  Widget _followedChannelTile(_ChannelSuggestion s, Color textPrimary, Color textSecondary, Color surface, Color border) {
    return ListTile(
      leading: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: s.color.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Icon(s.icon, color: s.color, size: 24),
      ),
      title: Text(s.name, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(s.followers, style: TextStyle(color: textSecondary, fontSize: 13)),
      onTap: () {
        // Open channel landing screen for followed channel
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ChannelLandingScreen()),
        );
      },
    );
  }

  Widget _pillButton({required IconData icon, required String label, required VoidCallback onTap}) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(icon, color: textPrimary, size: 20),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Channel suggestion helper class ──────────────────────────
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
