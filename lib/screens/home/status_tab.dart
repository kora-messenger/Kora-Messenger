import 'dart:io';

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
import '../status/my_status_list_screen.dart';
import '../status/status_layout_screen.dart';
import '../status/status_privacy_screen.dart';
import '../channel_landing_screen.dart';

/// "Updates" screen — Kora's Updates tab, rebuilt to match WhatsApp's
/// actual Updates screen structure:
///
/// - Header: "Updates" title + search (inline) + 3-dot menu (Kora
///   extras: status privacy, status triggers, muted updates, music
///   settings, cross-posting).
/// - Status section (WhatsApp's current design, confirmed from the
///   reference recordings): a "Status" label above a horizontal
///   carousel of portrait preview cards. Each card shows the latest
///   status media as its background, a small ringed avatar at the
///   top-center (brand gradient ring = unviewed, gray = viewed), and
///   the name in white at the bottom-left. The My status card carries
///   a green "+" badge on its avatar and opens the status camera
///   directly when empty.
/// - Muted updates: label + inline row of small avatars below the
///   carousel.
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
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

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
    _searchController.dispose();
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

  void _openMyStatus() async {
    final items = StatusService.instance.myStatusItems;
    if (items.isEmpty) {
      // WhatsApp: tapping an empty My status jumps straight to the camera.
      _captureFromCamera();
      return;
    }
    // WhatsApp: "My status" opens an intermediate list of your posted
    // items (each with its own view count) before the full viewer.
    final action = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyStatusListScreen(
          fullName: _liveSession?['fullName'] ?? 'You',
          avatarUrl: _liveSession?['avatarUrl'],
          userEmail: _liveSession?['email'],
          username: _liveSession?['username'],
        ),
      ),
    );
    if (action == 'text') {
      _openTextStatus();
    } else if (action == 'camera') {
      _captureFromCamera();
    }
    _refresh();
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
    final mutedUpdates = allStatuses.where((s) => s.isMuted).toList();
    final followed = _suggestions
        .where((s) => s.following && (_searchQuery.isEmpty || s.name.toLowerCase().contains(_searchQuery.toLowerCase())))
        .toList();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header — WhatsApp Updates tab: title + search + 3-dot.
            // Search toggles an inline search bar (statuses/channels);
            // the 3-dot keeps Kora's extras reachable.
            if (!_isSearching)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                child: Row(
                  children: [
                    Text('Updates',
                      style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.search, color: textPrimary, size: 24),
                      tooltip: 'Search',
                      onPressed: () => setState(() => _isSearching = true),
                    ),
                    IconButton(
                      icon: Icon(Icons.more_vert, color: textPrimary, size: 22),
                      onPressed: _showMoreOptions),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 12, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimary, size: 22),
                      onPressed: () {
                        _searchController.clear();
                        setState(() { _isSearching = false; _searchQuery = ''; });
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(color: textPrimary, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Search status and channels',
                          hintStyle: TextStyle(color: textSecondary, fontSize: 15),
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
                                  onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                                )
                              : null,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            // Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 110),
                children: [
                  // Status — WhatsApp's current design: "Status" label
                  // above a horizontal carousel of portrait preview
                  // cards. My status first, then unviewed (gradient
                  // ring), then viewed (gray ring).
                  _sectionLabel('Status', textPrimary),
                  _buildStatusCarousel(
                    fullName, avatarUrl, hasStatus, myItems, allStatuses,
                    surface, textPrimary, textSecondary),
                  // Empty state — the reference app's treatment: with no
                  // contact statuses, a muted gray explainer sits under
                  // My status. Never demo/simulated contact statuses.
                  if (allStatuses.isEmpty && _searchQuery.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        'No status updates yet. Contacts\' status updates will appear here.',
                        style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.4),
                      ),
                    ),
                  if (mutedUpdates.isNotEmpty && _searchQuery.isEmpty) ...[
                    _sectionLabel('Muted updates', textMuted),
                    _buildMutedRow(mutedUpdates, textSecondary),
                  ],
                  // Channels — WhatsApp's real pattern: "Channels" header
                  // with an "Explore" pill. Followed channels show with a
                  // last-update preview, time, and unread pill. With
                  // nothing followed, just the short explainer text —
                  // no suggestion tiles or search row on the main tab.
                  _channelsHeader(textPrimary, textSecondary),
                  if (followed.isNotEmpty)
                    ...followed.map((s) => _followedChannelTile(s, textPrimary, textSecondary))
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        'Stay updated on topics that matter to you. The channels you follow will appear here.',
                        style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.4),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      // FAB — WhatsApp's real double FAB: pencil (text status) above
      // camera (with a small "+" badge, opens the status camera directly).
      // Long-press the camera FAB for Kora's full creation sheet
      // (Camera / Gallery / Layout).
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
          GestureDetector(
            onLongPress: _openCreationSheet,
            child: Container(
              decoration: BoxDecoration(
                gradient: KoraColors.brandGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: KoraColors.purple.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: FloatingActionButton(
                onPressed: _captureFromCamera,
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.photo_camera, color: Colors.white, size: 24),
                    Positioned(
                      bottom: -2, right: -4,
                      child: Container(
                        width: 15, height: 15,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: KoraColors.purple, width: 1.5),
                        ),
                        child: const Icon(Icons.add, color: KoraColors.purple, size: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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

  /// "Channels" header with the "Explore" pill on the right — the
  /// reference app's current design (grey pill: grid icon + "Explore").
  Widget _channelsHeader(Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
      child: Row(
        children: [
          Text('Channels',
            style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChannelLandingScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.grid_view_rounded, color: textSecondary, size: 15),
                  const SizedBox(width: 6),
                  Text('Explore',
                    style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status carousel (current WhatsApp design) ────────────────
  //
  // A horizontal strip of portrait preview cards. Confirmed details
  // from the reference recordings (native resolution):
  //   • card ≈ 104×184, corner radius 14, ~10px gap, ~16px side padding
  //   • card background = the contact's latest status media
  //   • small circular avatar at the top-center with a white gap
  //     ring (brand gradient = unviewed, gray = viewed)
  //   • name in white, bottom-left, bold, with a soft shadow
  //   • My status card: same layout + a "+" badge on the avatar;
  //     when there is no status yet the card shows the avatar centered
  //     on a plain card and opens the camera directly.

  Widget _buildStatusCarousel(
    String fullName,
    String avatarUrl,
    bool hasStatus,
    List<StatusItem> myItems,
    List<KoraStatus> allStatuses,
    Color surface,
    Color textPrimary,
    Color textSecondary,
  ) {
    final q = _searchQuery.toLowerCase();
    final recent = allStatuses
        .where((s) => !s.isViewed && !s.isMuted)
        .where((s) => q.isEmpty || s.fullName.toLowerCase().contains(q))
        .toList();
    final viewed = allStatuses
        .where((s) => s.isViewed && !s.isMuted)
        .where((s) => q.isEmpty || s.fullName.toLowerCase().contains(q))
        .toList();

    final cards = <Widget>[
      _myStatusCard(fullName, avatarUrl, hasStatus, myItems, surface, textPrimary),
      ...recent.map((s) => _contactStatusCard(s, surface, unviewed: true)),
      ...viewed.map((s) => _contactStatusCard(s, surface, unviewed: false)),
    ];

    return SizedBox(
      height: 186,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => cards[i],
      ),
    );
  }

  /// My status card — always the first card in the carousel.
  Widget _myStatusCard(
    String fullName,
    String avatarUrl,
    bool hasStatus,
    List<StatusItem> myItems,
    Color surface,
    Color textPrimary,
  ) {
    final latest = hasStatus
        ? myItems.lastWhere((i) => !i.isDeleted, orElse: () => myItems.last)
        : null;
    return _statusCard(
      background: latest != null ? _statusPreview(latest, surface) : null,
      fallbackColor: surface,
      avatar: _cardAvatar(
        name: fullName,
        imageUrl: avatarUrl,
        ring: hasStatus,
        ringColor: Colors.grey,
        plusBadge: true,
        avatarSize: hasStatus ? 30 : 54,
      ),
      avatarCentered: !hasStatus,
      label: 'My status',
      labelColor: hasStatus ? Colors.white : textPrimary,
      onTap: _openMyStatus,
    );
  }

  /// Contact status card — media preview background, ringed avatar at
  /// the top-center, white name at the bottom-left.
  Widget _contactStatusCard(KoraStatus status, Color surface, {required bool unviewed}) {
    final latest = status.items.isNotEmpty ? status.items.last : null;
    return _statusCard(
      background: latest != null ? _statusPreview(latest, surface) : null,
      fallbackColor: surface,
      avatar: _cardAvatar(
        name: status.fullName,
        imageUrl: status.avatarUrl,
        ring: unviewed,
        ringColor: Colors.grey,
      ),
      avatarCentered: false,
      label: status.fullName,
      labelColor: Colors.white,
      onTap: () => _openContactStatus(status),
    );
  }

  /// The shared portrait card: 104×184, radius 14, avatar at the
  /// top-center, name at the bottom-left.
  Widget _statusCard({
    Widget? background,
    required Color fallbackColor,
    required Widget avatar,
    required bool avatarCentered,
    required String label,
    required Color labelColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 104,
        height: 184,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: fallbackColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (background != null) Positioned.fill(child: background),
            // Soft scrim behind the avatar so it reads on any media.
            Positioned(
              top: 0, left: 0, right: 0, height: 60,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: background != null ? 0.25 : 0.0),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            if (avatarCentered)
              Center(child: avatar)
            else
              Positioned(
                top: 8, left: 0, right: 0,
                child: Center(child: avatar),
              ),
            Positioned(
              left: 8, right: 8, bottom: 8,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Small ringed avatar used on the status cards: white gap between
  /// the ring and the avatar, with an optional "+" badge (My status).
  Widget _cardAvatar({
    required String name,
    String? imageUrl,
    required bool ring,
    required Color ringColor,
    bool plusBadge = false,
    double avatarSize = 30,
  }) {
    final avatar = Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ring ? KoraColors.brandGradient : null,
        color: ring ? null : ringColor,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: KoraAvatar(
          name: name,
          imageUrl: (imageUrl ?? '').isEmpty ? null : imageUrl,
          size: avatarSize,
        ),
      ),
    );
    if (!plusBadge) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          bottom: -3, right: -3,
          child: Container(
            width: 17, height: 17,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Container(
              decoration: const BoxDecoration(
                gradient: KoraColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 10),
            ),
          ),
        ),
      ],
    );
  }

  /// Card background from a status item: the media preview for
  /// photo/video, the colored text canvas for text statuses. All file
  /// loads are guarded — a missing file falls back to a soft brand
  /// gradient instead of crashing (see the earlier avatar-path crash).
  Widget _statusPreview(StatusItem item, Color surface) {
    if (item.type == StatusType.text) {
      return Container(
        color: item.backgroundColor ?? KoraColors.purple,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(10),
        child: Text(
          item.text ?? '',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: item.textColor ?? Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final path = item.mediaThumbnailPath ?? item.mediaPath;
    if (path != null && File(path).existsSync()) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _previewFallback(surface),
      );
    }
    return _previewFallback(surface);
  }

  Widget _previewFallback(Color surface) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            KoraColors.purple.withValues(alpha: 0.35),
            KoraColors.blue.withValues(alpha: 0.25),
            surface,
          ],
        ),
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
