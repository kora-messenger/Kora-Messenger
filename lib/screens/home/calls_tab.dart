import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/kora_colors.dart';
import '../../models/call_log.dart';
import '../../models/chat_models.dart';
import '../../services/call_service.dart';
import '../../services/contacts_service.dart';
import '../../widgets/kora_avatar.dart';
import '../../widgets/kora_badge.dart';
import '../../widgets/kora_empty_state.dart';
import '../../widgets/kora_menu_sheet.dart';
import '../chat/call_screen.dart';
import "../../services/session_manager.dart";
import '../contacts/select_contact_screen.dart';
import 'scheduled_calls_screen.dart';
import 'keypad_screen.dart';
import 'favorites_screen.dart';

/// "Calls" tab — call history plus a "Start a call" quick-dial section,
/// styled in Kora's own identity (purple-to-blue gradient action
/// circles, gradient FAB) on top of the familiar WhatsApp-style layout:
/// quick actions row, Recent call log, then a dismissible "Start a
/// call" contact list.
///
/// Tapping "Hide" on "Start a call" persists the choice and swaps the
/// section for a quiet "end-to-end encrypted" note, just like the
/// reference screen — restorable later from the ⋮ menu.
class CallsTab extends StatefulWidget {
  const CallsTab({super.key});

  @override
  State<CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends State<CallsTab> {
  static const _kHiddenKey = 'kora_start_call_hidden';

  List<CallLog> _logs = [];
  bool _loading = true;

  bool _startCallHidden = false;
  bool _showAllStartCall = false;

  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadCalls();
    _loadHiddenPref();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCalls() async {
    await CallService.instance.init();
    if (mounted) {
      setState(() {
        _logs = CallService.instance.getLogs();
        _loading = false;
      });
    }
  }

  Future<void> _loadHiddenPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _startCallHidden = prefs.getBool(_kHiddenKey) ?? false);
    }
  }

  Future<void> _setStartCallHidden(bool hidden) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHiddenKey, hidden);
    if (mounted) setState(() => _startCallHidden = hidden);
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ── Data (filtered by inline search) ────────────────────────

  List<CallLog> get _filteredLogs {
    if (_query.isEmpty) return _logs;
    final q = _query.toLowerCase();
    return _logs.where((l) => l.contactName.toLowerCase().contains(q)).toList();
  }

  List<Map<String, Object?>> _startCallContacts = [];
  bool _contactsLoaded = false;

  Future<void> _loadContacts() async {
    final contacts = await ContactsService.instance.getContacts();
    if (mounted) {
      setState(() {
        _startCallContacts = contacts;
        _contactsLoaded = true;
      });
    }
  }

  List<Map<String, Object?>> get _filteredStartCallContacts {
    if (_query.isEmpty) return _startCallContacts;
    final q = _query.toLowerCase();
    return _startCallContacts.where((c) {
      final name = (c['name'] as String).toLowerCase();
      final username = (c['username'] as String).toLowerCase();
      final koraId = (c['koraId'] as String).toLowerCase();
      return name.contains(q) || username.contains(q) || koraId.contains(q);
    }).toList();
  }

  // ── Actions ──────────────────────────────────────────────────

  void _openCallWithContact(Map<String, Object?> contact, {required bool isVideo}) async {
    final session = await SessionManager.instance.loadSession();
    final myEmail = session?['email'] as String? ?? '';
    if (!mounted) return;
    final contactEmail = contact['email'] as String?;
    if (contactEmail == null || contactEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Can\'t call this contact — no Kora email on file'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          contactName: contact['name'] as String,
          isVideoCall: isVideo,
          isOutgoing: true,
          badge: contact['premium'] == true ? KoraBadgeType.premiumBlue : KoraBadgeType.none,
        ),
      ),
    );
  }

  void _openNewCallPicker() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectContactScreen()));
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _query = '';
      }
    });
  }

  void _openMenu() {
    final options = [
      if (_startCallHidden)
        KoraMenuOption(
          icon: Icons.visibility_outlined,
          label: 'Show suggested contacts',
          onTap: () => _setStartCallHidden(false),
        ),
      if (_logs.isNotEmpty)
        KoraMenuOption(
          icon: Icons.clear_all,
          label: 'Clear call log',
          onTap: () async {
            await CallService.instance.clearAll();
            if (mounted) setState(() => _logs = []);
          },
        ),
    ];

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing to manage here yet'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    KoraMenuSheet.show(context, options);
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final border = KoraColors.borderFor(brightness);

    final filteredLogs = _filteredLogs;
    final startCallContacts = _filteredStartCallContacts;
    final visibleStartCallContacts =
        _showAllStartCall ? startCallContacts : startCallContacts.take(4).toList();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(textPrimary, textSecondary, surface, border),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
                  : (filteredLogs.isEmpty && startCallContacts.isEmpty && _query.isNotEmpty)
                      ? KoraEmptyState(
                          icon: Icons.search_off,
                          title: 'No matches',
                          message: 'Nothing found for "$_query".',
                        )
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 100),
                          children: [
                            if (!_isSearching) _buildQuickActions(textPrimary, textSecondary, surface),
                            if (filteredLogs.isNotEmpty) ...[
                              _sectionLabel('Recent', textPrimary),
                              ...List.generate(filteredLogs.length, (i) {
                                final log = filteredLogs[i];
                                final isLast = i == filteredLogs.length - 1;
                                return Column(
                                  children: [
                                    _callTile(context, log, textPrimary, textSecondary),
                                    if (!isLast)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 76),
                                        child: Divider(height: 1, color: border),
                                      ),
                                  ],
                                );
                              }),
                            ] else if (!_loading && _query.isEmpty)
                              // No empty-state text here — the current
                              // reference build shows no "No calls yet"
                              // text; the Start a call contact section
                              // below fills the empty history.
                              const SizedBox.shrink(),
                            const SizedBox(height: 8),
                            if (_startCallHidden)
                              _buildEncryptedNote(textSecondary)
                            else if (startCallContacts.isNotEmpty) ...[
                              _buildStartCallHeader(textPrimary, surface, textSecondary),
                              ...visibleStartCallContacts.map(
                                (c) => _startCallTile(c, textPrimary, textSecondary, border),
                              ),
                              if (!_showAllStartCall && startCallContacts.length > 4)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: () => setState(() => _showAllStartCall = true),
                                      style: TextButton.styleFrom(
                                        backgroundColor: surface,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      ),
                                      child: Text(
                                        'More',
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
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
          onPressed: _openNewCallPicker,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_call, color: Colors.white),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────

  Widget _buildHeader(Color textPrimary, Color textSecondary, Color surface, Color border) {
    if (_isSearching) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: border, width: 0.5),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _toggleSearch,
                child: Icon(Icons.arrow_back, color: textSecondary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(color: textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search calls',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_query.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  child: Icon(Icons.close, color: textSecondary, size: 18),
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Text(
            'Calls',
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
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: textSecondary, size: 22),
            onPressed: _openMenu,
          ),
        ],
      ),
    );
  }

  // ── Quick actions row ────────────────────────────────────────

  Widget _buildQuickActions(Color textPrimary, Color textSecondary, Color surface) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _quickAction(Icons.call_outlined, 'Call', surface, textPrimary, textSecondary, _openNewCallPicker),
          _quickAction(Icons.calendar_month_outlined, 'Schedule', surface, textPrimary, textSecondary,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduledCallsScreen()))),
          _quickAction(Icons.dialpad, 'Keypad', surface, textPrimary, textSecondary,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KeypadScreen()))),
          _quickAction(Icons.favorite_border, 'Favorites', surface, textPrimary, textSecondary,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()))),
        ],
      ),
    );
  }

  Widget _quickAction(
    IconData icon,
    String label,
    Color surface,
    Color textPrimary,
    Color textSecondary,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
            child: Icon(icon, color: KoraColors.purple, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Section headers ──────────────────────────────────────────

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildStartCallHeader(Color textPrimary, Color surface, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Start a call',
              style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => _setStartCallHidden(true),
            style: TextButton.styleFrom(
              backgroundColor: surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
            child: Text(
              'Hide',
              style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncryptedNote(Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 14, color: textSecondary),
            const SizedBox(width: 6),
            Text(
              'Your personal calls are ',
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
            ShaderMask(
              shaderCallback: (bounds) => KoraColors.brandGradient.createShader(bounds),
              child: const Text(
                'end-to-end encrypted',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent call tile ─────────────────────────────────────────

  Widget _callTile(BuildContext context, CallLog log, Color textPrimary, Color textSecondary) {
    final isMissed = log.isMissed;

    final arrowIcon = log.isOutgoing ? Icons.arrow_outward : Icons.arrow_downward;
    final arrowColor = isMissed ? KoraColors.red : const Color(0xFF22C55E);
    final nameColor = isMissed ? KoraColors.red : textPrimary;

    return ListTile(
      leading: KoraAvatar(
        name: log.contactName,
        assetPath: log.avatarAsset,
        imageUrl: log.avatarUrl,
        size: 50,
      ),
      title: Row(
        children: [
          Flexible(
            child: KoraNameWithBadge(
              name: log.contactName,
              badge: log.badge,
              badgeSize: 13,
              style: TextStyle(
                color: nameColor,
                fontSize: 16,
                fontWeight: isMissed ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Icon(
            log.type == CallType.video ? Icons.videocam_outlined : Icons.call_outlined,
            color: textSecondary,
            size: 14,
          ),
          const SizedBox(width: 4),
          Icon(arrowIcon, color: arrowColor, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              isMissed
                  ? 'Missed'
                  : log.durationSeconds != null
                      ? '${(log.durationSeconds! ~/ 60)}m ${log.durationSeconds! % 60}s'
                      : _formatTime(log.timestamp),
              style: TextStyle(
                color: isMissed ? KoraColors.red : textSecondary,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isMissed) ...[
            const SizedBox(width: 6),
            Text(
              '• ${_formatTime(log.timestamp)}',
              style: TextStyle(color: textSecondary, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      trailing: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              contactName: log.contactName,
              avatarUrl: log.avatarUrl,
              badge: log.badge,
              isVideoCall: log.type == CallType.video,
              isOutgoing: true,
            ),
          ),
        ),
        child: Icon(
          log.type == CallType.video ? Icons.videocam_outlined : Icons.call_outlined,
          color: KoraColors.purple,
          size: 24,
        ),
      ),
    );
  }

  // ── Start-a-call contact tile ────────────────────────────────

  Widget _startCallTile(Map<String, Object?> contact, Color textPrimary, Color textSecondary, Color border) {
    final name = contact['name'] as String;
    final isPremium = contact['premium'] == true;
    final avatarUrl = contact['avatarUrl'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: KoraAvatar(name: name, size: 46, isPremium: isPremium, imageUrl: avatarUrl),
        title: Text(
          name,
          style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _openCallWithContact(contact, isVideo: false),
              child: Icon(Icons.call_outlined, color: KoraColors.purple, size: 22),
            ),
            const SizedBox(width: 18),
            GestureDetector(
              onTap: () => _openCallWithContact(contact, isVideo: true),
              child: Icon(Icons.videocam_outlined, color: KoraColors.purple, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
