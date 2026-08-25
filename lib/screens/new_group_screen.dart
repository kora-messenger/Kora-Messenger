import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import '../widgets/kora_avatar.dart';
import '../services/contacts_service.dart';
import 'new_group_details_screen.dart';

/// New Group screen — pick the people to add to a new group.
///
/// Recently-contacted Kora users show at the top under "RECENT",
/// everyone else shows below under "ALL CONTACTS". Tapping a contact
/// toggles a selection circle at the corner of their avatar. The
/// forward arrow at the bottom-right continues to the group-details
/// screen with the selected contacts.
class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  /// Kora IDs of the contacts the user has selected for the new group.
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, Object>> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await ContactsService.instance.getContacts();
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    }
  }

  List<Map<String, Object>> get _recentContacts =>
      _contacts.where((c) => c['recent'] == true).toList();

  List<Map<String, Object>> get _allContacts =>
      _contacts.where((c) => c['recent'] != true).toList();

  List<Map<String, Object>> _filter(List<Map<String, Object>> source) {
    if (_query.isEmpty) return source;
    final q = _query.toLowerCase();
    return source.where((c) {
      final name = (c['name'] as String).toLowerCase();
      final koraId = (c['koraId'] as String).toLowerCase();
      final username = (c['username'] as String).toLowerCase();
      return name.contains(q) || koraId.contains(q) || username.contains(q);
    }).toList();
  }

  void _toggleSelection(String koraId) {
    setState(() {
      if (_selectedIds.contains(koraId)) {
        _selectedIds.remove(koraId);
      } else {
        _selectedIds.add(koraId);
      }
    });
  }

  void _continue() {
    // No minimum selection required — the user can create a group
    // solo and add members later from the group's own screen.
    final selectedContacts =
        _contacts.where((c) => _selectedIds.contains(c['koraId'])).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewGroupDetailsScreen(members: selectedContacts),
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: textPrimary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _selectedIds.isEmpty
                          ? 'New Group'
                          : '${_selectedIds.length} selected',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
                    Icon(Icons.search, color: textMuted, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                        style: TextStyle(color: textPrimary, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Search by name, Kora ID, or @username',
                          hintStyle: TextStyle(color: textMuted, fontSize: 14),
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
                        child: Icon(Icons.close, color: textMuted, size: 18),
                      ),
                  ],
                ),
              ),
            ),
            // Contact list
            Expanded(child: _buildList(context, textPrimary, textSecondary, textMuted)),
            // Forward arrow — continues to group details
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 20, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _continue,
                    child: Container(
                      width: 56,
                      height: 56,
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
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, Color textPrimary, Color textSecondary, Color textMuted) {
    final recent = _filter(_recentContacts);
    final all = _filter(_allContacts);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: KoraColors.purple));
    }

    if (recent.isEmpty && all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_outlined, size: 48, color: textMuted),
            const SizedBox(height: 12),
            Text('No contacts yet', style: TextStyle(color: textSecondary, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Add contacts or start chatting to see them here.',
                style: TextStyle(color: textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (recent.isNotEmpty) ...[
          _sectionLabel('RECENT', textMuted),
          ..._buildContactTiles(recent, textPrimary, textSecondary, textMuted),
          const SizedBox(height: 8),
        ],
        if (all.isNotEmpty) ...[
          _sectionLabel('ALL CONTACTS', textMuted),
          ..._buildContactTiles(all, textPrimary, textSecondary, textMuted),
        ],
      ],
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  List<Widget> _buildContactTiles(
    List<Map<String, Object>> contacts,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    return List.generate(contacts.length, (index) {
      final contact = contacts[index];
      final koraId = contact['koraId'] as String;
      final isSelected = _selectedIds.contains(koraId);
      final isLast = index == contacts.length - 1;

      final isPremium = contact['premium'] == true;

      return Column(
        children: [
          ListTile(
            leading: _buildSelectableAvatar(contact['name'] as String, isSelected, isPremium),
            title: Text(
              contact['name'] as String,
              style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              contact['username'] != null && (contact['username'] as String).isNotEmpty
                  ? '$koraId · ${contact['username']}'
                  : koraId,
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
            onTap: () => _toggleSelection(koraId),
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(left: 76),
              child: Divider(height: 1, color: textMuted.withValues(alpha: 0.08)),
            ),
        ],
      );
    });
  }

  Widget _buildSelectableAvatar(String name, bool isSelected, bool isPremium) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          KoraAvatar(name: name, size: 48, isPremium: isPremium),
          Positioned(
            right: -2,
            bottom: -2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? KoraColors.purple : Colors.transparent,
                border: Border.all(
                  color: isSelected ? KoraColors.purple : Colors.white,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 13)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
