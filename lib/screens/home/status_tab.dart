import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/kora_colors.dart';
import '../../services/session_manager.dart';
import '../../services/status_service.dart';
import '../../services/status_trigger_service.dart';
import '../status/status_triggers_screen.dart';

import '../../models/status_model.dart';
import '../../widgets/kora_avatar.dart';
import '../chat/kora_camera_screen.dart';
import '../status/status_audience_selector.dart';
import '../chat/kora_media_editor_screen.dart';
import '../status/text_status_screen.dart';
import '../status/status_viewer_screen.dart';
import '../status/status_layout_screen.dart';
import '../status/status_privacy_screen.dart';
import '../channel_landing_screen.dart';

/// "Updates" screen — Kora's Updates tab, rebuilt to match WhatsApp's
/// actual Updates screen structure:
///
/// - Header: "Updates" title + camera icon (jumps straight into the
///   status camera) + 3-dot menu (Kora extras: status privacy, status
///   triggers, muted updates, music settings, cross-posting).
/// - Status area (no section label — straight to My status):
///   My status row → Recent updates (gradient ring) → Viewed updates
///   (gray ring) → Muted updates (label + inline row of small avatars).
///   Status rows show name + relative time right-aligned, no subtitle.
/// - Channels: "Channels" label with a "+" (find channels), followed
///   channels with last-update preview + time + unread pill, a
///   "Find channels" row, and follow suggestions when none are followed.
/// - FAB: a single pencil — opens the text status editor directly.
///   Long-press the pencil for the full creation sheet (Camera, Gallery,
///   Layout) so Kora's collage feature stays reachable.
class StatusTab extends StatefulWidget {
  const StatusTab({super.key});

  @override
  State<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<StatusTab> {
  Map<String, dynamic>? _session;
  bool _isLoaded = false;

  final List<_ChannelSuggestion> _suggestions = [
    _ChannelSuggestion(name: 'Kora Tech News', followers: '842K followers', color: KoraColors.purple, icon: Icons.bolt, lastUpdate: 'Kora 4.0 rolls out HD video calls for everyone', time: '10:42', unread: 3),
    _ChannelSuggestion(name: 'Naija Football Daily', followers: '611K followers', color: KoraColors.blue, icon: Icons.sports_soccer, lastUpdate: 'FULL-TIME: Super Eagles secure the win ⚽', time: '09:15', unread: 0),
    _ChannelSuggestion(name: 'Afrobeats Central', followers: '398K followers', color: const Color(0xFFEC4899), icon: Icons.music_note, lastUpdate: 'New drop: this week\'s top 10 tracks 🎧', time: 'Yesterday', unread: 1),
    _ChannelSuggestion(name: 'Kora Community Updates', followers: '215K followers', color: const Color(0xFF22C55E), icon: Icons.campaign, lastUpdate: 'Community polls are live — try them in your group', time: 'Yesterday', unread: 0),
    _ChannelSuggestion(name: 'Tech Africa Weekly', followers: '1.2M followers', color: const Color(0xFFF59E0B), icon: Icons.trending_up, lastUpdate: 'The state of African fintech in 2026', time: 'Tuesday', unread: 2),
    _ChannelSuggestion(name: 'Design Daily', followers: '534K followers', color: const Color(0xFF14B8A6), icon: Icons.brush, lastUpdate: 'Glassmorphism, but make it accessible', time: 'Monday', unread: 0),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    StatusTriggerService.instance.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _loadData() async {
    await StatusService.instance.init();
    await StatusTriggerService.instance.init();
    StatusTriggerService.instance.addListener(_refresh);
    final session = await SessionManager.instance.loadSession();
    if (mounted) {
      setState(() {
        _session = session;
        _isLoaded = true;
      });
    }
  }

  /// Live profile from the shared notifier — same source the bottom nav
  /// Profile icon and Profile tab read from, so "My Status" can never
  /// show a different name/photo than the rest of the app.
  Map<String, dynamic>? get _liveSession =>
      SessionManager.instance.profileNotifier.value ?? _session;

  void _refresh() {
    setState(() {});
  }

  // ── Status creation ───────────────────────────────────────────

  void _openTextStatus() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TextStatusScreen()),
    ).then((_) => _refresh());
  }

  void _captureFromCamera() async {
    // Show audience selector first
    final audience = await showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.backgroundFor(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatusAudienceSelector(
        onSelected: (audience) => Navigator.of(ctx).pop(audience),
      ),
    );
    if (audience == null || !mounted) return;
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const KoraCameraScreen()),
    );
    if (result == null || !mounted) return;
    final path = result['path'] as String;
    final isVideo = result['isVideo'] as bool;

    // Open editor before posting (WhatsApp-style)
    final edited = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KoraMediaEditorScreen(mediaPath: path, isVideo: isVideo),
      ),
    );
    if (edited == null || !mounted) return;

    final caption = edited['caption'] as String?;
    final item = StatusItem(
      id: 'status_${DateTime.now().millisecondsSinceEpoch}',
      type: isVideo ? StatusType.video : StatusType.photo,
      mediaPath: edited['path'] as String,
      caption: caption,
      createdAt: DateTime.now(),
    );
    await StatusService.instance.addStatusItem(item);
    _refresh();
  }

  void _pickFromGallery() async {
    final picker = ImagePicker();
    // WhatsApp-style: pick multiple photos at once (up to 30)
    final photos = await picker.pickMultiImage(imageQuality: 100, limit: 30);
    if (photos.isNotEmpty && mounted) {
      for (final photo in photos) {
        final item = StatusItem(
          id: 'status_${DateTime.now().millisecondsSinceEpoch}_${photos.indexOf(photo)}',
          type: StatusType.photo,
          mediaPath: photo.path,
          createdAt: DateTime.now(),
        );
        await StatusService.instance.addStatusItem(item);
      }
      _refresh();
      return;
    }
    if (!mounted) return;
    // If no multi-photo, try single video
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

  /// Long-press the FAB for the full creation sheet — keeps Kora's
  /// Layout/collage and bulk-gallery flows reachable. The primary
  /// paths match WhatsApp: camera icon → camera, pencil FAB → text.
  void _openCreationSheet() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Text status
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(color: KoraColors.purple, shape: BoxShape.circle),
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
              title: Text('Text status', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text('Share a text update', style: TextStyle(color: textSecondary, fontSize: 13)),
              onTap: () { Navigator.pop(context); _openTextStatus(); },
            ),
            // Camera
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(color: KoraColors.blue, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
              title: Text('Camera', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text('Capture photo or video', style: TextStyle(color: textSecondary, fontSize: 13)),
              onTap: () { Navigator.pop(context); _captureFromCamera(); },
            ),
            // Gallery
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: KoraColors.purple.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.photo_library, color: KoraColors.purple, size: 20),
              ),
              title: Text('Gallery', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text('Upload from gallery', style: TextStyle(color: textSecondary, fontSize: 13)),
              onTap: () { Navigator.pop(context); _pickFromGallery(); },
            ),
            // Layout/Collage (WhatsApp 2026 Layout feature)
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: KoraColors.blue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.grid_view_rounded, color: KoraColors.blue, size: 20),
              ),
              title: Text('Layout', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text('Combine 2-6 photos into a collage', style: TextStyle(color: textSecondary, fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StatusLayoutScreen()),
                ).then((_) => _refresh());
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  // ── Status viewing ─────────────────────────────────────────────

  void _openMyStatus() {
    final items = StatusService.instance.myStatusItems;
    if (items.isEmpty) {
      // WhatsApp: tapping an empty My status jumps straight to the camera.
      _captureFromCamera();
      return;
    }
    final status = KoraStatus(
      id: 'my_status',
      userEmail: _liveSession?['email'] ?? '',
      username: _liveSession?['username'] ?? '',
      fullName: _liveSession?['fullName'] ?? 'You',
      avatarUrl: _liveSession?['avatarUrl'],
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
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              leading: const Icon(Icons.bolt, color: KoraColors.purple),
              title: Text('Status triggers', style: TextStyle(color: textPrimary)),
              subtitle: Text('Automated status updates', style: TextStyle(color: textSecondary, fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StatusTriggersScreen()),
                ).then((_) => _refresh());
              },
            ),
            ListTile(
              leading: Icon(Icons.lock_outline, color: textPrimary),
              title: Text('Status privacy', style: TextStyle(color: textPrimary)),
              onTap: () { Navigator.pop(context); _openPrivacy(); },
            ),
            ListTile(
              leading: Icon(Icons.volume_off, color: textPrimary),
              title: Text('Muted updates', style: TextStyle(color: textPrimary)),
              onTap: () { Navigator.pop(context); _showMutedUpdates(); },
            ),
            ListTile(
              leading: Icon(Icons.music_note, color: textPrimary),
              title: Text('Music settings', style: TextStyle(color: textPrimary)),
              onTap: () { Navigator.pop(context); _showMusicSettings(); },
            ),
            ListTile(
              leading: Icon(Icons.share_outlined, color: textPrimary),
              title: Text('Cross-posting', style: TextStyle(color: textPrimary)),
              onTap: () { Navigator.pop(context); _showCrossPostingSettings(); },
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: textPrimary),
              title: Text('Status settings', style: TextStyle(color: textPrimary)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void _showMutedUpdates() {
    final muted = StatusService.instance.contactStatuses.where((s) => s.isMuted).toList();
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.surfaceFor(brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text('Muted updates', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close, color: textSecondary, size: 22),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: muted.length,
                  itemBuilder: (context, i) {
                    final s = muted[i];
                    return ListTile(
                      leading: KoraAvatar(name: s.fullName, imageUrl: s.avatarUrl, size: 44),
                      title: Text(s.fullName, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                      subtitle: Text(_timeAgo(s.lastUpdatedAt), style: TextStyle(color: textSecondary, fontSize: 13)),
                      onTap: () { Navigator.pop(context); _openContactStatus(s); },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMusicSettings() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.music_note, color: textPrimary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Add music to your status',
                      style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: KoraColors.purple.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(Icons.search, color: KoraColors.purple, size: 20),
              ),
              title: Text('Search for music', style: TextStyle(color: textPrimary)),
              subtitle: Text('Find songs to add to your status', style: TextStyle(color: textSecondary, fontSize: 13)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: KoraColors.blue.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(Icons.trending_up, color: KoraColors.blue, size: 20),
              ),
              title: Text('Trending now', style: TextStyle(color: textPrimary)),
              subtitle: Text('Popular songs in your region', style: TextStyle(color: textSecondary, fontSize: 13)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(Icons.favorite, color: Colors.green, size: 20),
              ),
              title: Text('Your favorites', style: TextStyle(color: textPrimary)),
              subtitle: Text("Songs you've saved", style: TextStyle(color: textSecondary, fontSize: 13)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _showCrossPostingSettings() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, color: textPrimary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Cross-posting',
                          style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _crossPostingToggle('Instagram', Icons.camera_alt_outlined, Colors.pink, false, (v) {}, setSheetState),
                _crossPostingToggle('Facebook', Icons.facebook, Colors.blue, false, (v) {}, setSheetState),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'When enabled, your Kora status will also be shared to the selected platforms.',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _crossPostingToggle(String label, IconData icon, Color color, bool value, Function(bool) onChanged, StateSetter setSheetState) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    return SwitchListTile(
      secondary: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: TextStyle(color: textPrimary)),
      value: value,
      onChanged: (v) {
        onChanged(v);
        setSheetState(() {});
      },
      activeColor: KoraColors.purple,
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return Scaffold(
        backgroundColor: KoraColors.backgroundFor(Theme.of(context).brightness),
        body: Center(child: CircularProgressIndicator(color: KoraColors.purple)),
      );
    }

    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    final fullName = _liveSession?['fullName'] ?? 'You';
    final avatarUrl = _liveSession?['avatarUrl'] as String? ?? '';
    final myItems = StatusService.instance.myStatusItems;
    final hasStatus = myItems.isNotEmpty;
    final allStatuses = StatusService.instance.contactStatuses;
    final recentStatuses = allStatuses.where((s) => !s.isViewed && !s.isMuted).toList();
    final viewedStatuses = allStatuses.where((s) => s.isViewed && !s.isMuted).toList();
    final mutedUpdates = allStatuses.where((s) => s.isMuted).toList();
    final followed = _suggestions.where((s) => s.following).toList();
    final notFollowing = _suggestions.where((s) => !s.following).toList();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header — WhatsApp Updates tab: title + camera icon.
            // The 3-dot keeps Kora's extras (triggers, privacy, music,
            // cross-posting) reachable.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
              child: Row(
                children: [
                  Text('Updates',
                    style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.photo_camera_outlined, color: textPrimary, size: 24),
                    tooltip: 'Camera',
                    onPressed: _captureFromCamera,
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: textPrimary, size: 22),
                    onPressed: _showMoreOptions),
                ],
              ),
            ),
            // Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 110),
                children: [
                  // Status area — no section label, straight to My status
                  _buildMyStatusRow(fullName, avatarUrl, hasStatus, myItems, bg, textPrimary, textSecondary),
                  if (recentStatuses.isNotEmpty) ...[
                    _sectionLabel('Recent updates', textMuted),
                    ...recentStatuses.map((s) =>
                        _buildContactStatusTile(s, bg, textPrimary, textSecondary, isUnviewed: true)),
                  ],
                  if (viewedStatuses.isNotEmpty) ...[
                    _sectionLabel('Viewed updates', textMuted),
                    ...viewedStatuses.map((s) =>
                        _buildContactStatusTile(s, bg, textPrimary, textSecondary, isUnviewed: false)),
                  ],
                  if (mutedUpdates.isNotEmpty) ...[
                    _sectionLabel('Muted updates', textMuted),
                    _buildMutedRow(mutedUpdates, textSecondary),
                  ],
                  // Channels — WhatsApp: "Channels" label with a "+"
                  // to find channels, followed channels with preview +
                  // time + unread pill, then the Find channels row.
                  _channelsHeader(textPrimary, textSecondary),
                  ...followed.map((s) => _followedChannelTile(s, textPrimary, textSecondary)),
                  _findChannelsRow(surface, textSecondary),
                  if (notFollowing.isNotEmpty) ...[
                    ...notFollowing.map((s) => _channelTile(s, textPrimary, textSecondary)),
                    _pillButton(
                      icon: Icons.grid_view_rounded,
                      label: 'Explore more',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChannelLandingScreen()),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      // FAB — WhatsApp: a single pencil that opens the text editor.
      floatingActionButton: GestureDetector(
        onLongPress: _openCreationSheet,
        child: FloatingActionButton(
          onPressed: _openTextStatus,
          backgroundColor: KoraColors.purple,
          elevation: 4,
          child: const Icon(Icons.edit, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  // ── Section helpers ───────────────────────────────────────────

  /// WhatsApp-style small gray section label.
  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  /// "Channels" header with the "+" that opens channel discovery —
  /// WhatsApp's exact pattern.
  Widget _channelsHeader(Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 8, 4),
      child: Row(
        children: [
          Text('Channels',
            style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.add, color: textSecondary, size: 24),
            tooltip: 'Find channels',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChannelLandingScreen()),
            ),
          ),
        ],
      ),
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
  ) {
    final totalViews = myItems.fold(0, (sum, item) => sum + item.viewedBy.length);
    final trigger = StatusTriggerService.instance.getActiveTrigger();

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
      title: Row(
        children: [
          Text(
            'My status',
            style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (trigger != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: KoraColors.brandGradient,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'auto',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        trigger != null
            ? '${trigger.emoji} ${trigger.statusText}'
            : (hasStatus
                ? (totalViews > 0 ? '$totalViews ${totalViews == 1 ? 'view' : 'views'}' : 'Tap to view')
                : 'Tap to add status update'),
        style: TextStyle(
          color: trigger != null ? KoraColors.purple : textSecondary,
          fontSize: 13,
          fontWeight: trigger != null ? FontWeight.w500 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Contact status row — WhatsApp style: ringed avatar, name, and the
  /// relative time right-aligned. No subtitle.
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
          gradient: isUnviewed ? KoraColors.brandGradient : null,
          color: isUnviewed ? null : textSecondary.withValues(alpha: 0.3),
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: KoraAvatar(name: status.fullName, imageUrl: status.avatarUrl, size: 48),
        ),
      ),
      title: Text(
        status.fullName,
        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: Text(
        _timeAgo(status.lastUpdatedAt),
        style: TextStyle(color: textSecondary, fontSize: 12.5),
      ),
    );
  }

  /// Muted updates — WhatsApp shows the label with the muted avatars
  /// laid out in a small horizontal row beneath it. Tapping an avatar
  /// opens that viewer directly.
  Widget _buildMutedRow(List<KoraStatus> muted, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: muted.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, i) {
            final s = muted[i];
            return GestureDetector(
              onTap: () => _openContactStatus(s),
              child: KoraAvatar(name: s.fullName, imageUrl: s.avatarUrl, size: 52),
            );
          },
        ),
      ),
    );
  }

  Widget _findChannelsRow(Color surface, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ChannelLandingScreen()),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: textSecondary.withValues(alpha: 0.2), width: 0.5),
              ),
              child: Icon(Icons.search, color: textSecondary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text('Find channels to follow',
                  style: TextStyle(color: textSecondary, fontSize: 15)),
            ),
            Icon(Icons.chevron_right, color: textSecondary, size: 22),
          ],
        ),
      ),
    );
  }

  /// Followed channel row — WhatsApp style: avatar, bold name, last
  /// update preview, timestamp, and an unread-count pill on the right.
  Widget _followedChannelTile(_ChannelSuggestion s, Color textPrimary, Color textSecondary) {
    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChannelLandingScreen()),
      ),
      leading: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: s.color,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(s.icon, color: Colors.white, size: 24),
      ),
      title: Text(s.name, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(
        s.lastUpdate,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: textSecondary, fontSize: 13),
      ),
      trailing: s.unread > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${s.unread}',
                style: const TextStyle(
                  color: KoraColors.purple,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Text(s.time, style: TextStyle(color: textSecondary, fontSize: 12.5)),
    );
  }

  Widget _channelTile(_ChannelSuggestion s, Color textPrimary, Color textSecondary) {
    return ListTile(
      leading: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: s.color,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(s.icon, color: Colors.white, size: 24),
      ),
      title: Text(s.name, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(s.followers, style: TextStyle(color: textSecondary, fontSize: 13)),
      trailing: TextButton(
        onPressed: () => setState(() => s.following = true),
        style: TextButton.styleFrom(
          backgroundColor: KoraColors.purple.withValues(alpha: 0.1),
        ),
        child: Text('Follow', style: TextStyle(color: KoraColors.purple, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: KoraColors.purple, size: 22),
            ),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _ChannelSuggestion {
  final String name;
  final String followers;
  final Color color;
  final IconData icon;
  final String lastUpdate;
  final String time;
  final int unread;
  bool following;

  _ChannelSuggestion({
    required this.name,
    required this.followers,
    required this.color,
    required this.icon,
    this.lastUpdate = '',
    this.time = '',
    this.unread = 0,
    this.following = false,
  });
}
