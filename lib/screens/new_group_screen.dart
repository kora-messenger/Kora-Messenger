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

  List<Map<String, Object?>> _contacts = [];
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

  List<Map<String, Object?>> get _recentContacts =>
      _contacts.where((c) => c['recent'] == true).toList();

  List<Map<String, Object?>> get _allContacts =>
      _contacts.where((c) => c['recent'] != true).toList();

  List<Map<String, Object?>> _filter(List<Map<String, Object?>> source) {
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
            // Header row — back arrow directly attached to the search
            // field, plus a dial-pad icon on the right. There is no
            // separate title text; the search bar itself is the header,
            // exactly matching the reference recording.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: textPrimary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: border, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) => setState(() => _query = v),
                              style: TextStyle(color: textPrimary, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Name, number, @username',
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
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _openDialPadEntry,
                    child: Icon(Icons.dialpad, color: textPrimary, size: 24),
                  ),
                ],
              ),
            ),
            // Selected-members chip strip — appears once at least one
            // contact is picked, each with an X to remove. Matches the
            // reference: selection feedback lives here, not in a title.
            if (_selectedIds.isNotEmpty) _buildSelectedChipStrip(textPrimary),
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

  /// Horizontal strip of the currently selected contacts, shown right
  /// below the search bar — each avatar has a small X badge to remove
  /// that person from the selection. Matches the reference recording.
  Widget _buildSelectedChipStrip(Color textPrimary) {
    final selected = _contacts.where((c) => _selectedIds.contains(c['koraId'])).toList();
    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        itemCount: selected.length,
        itemBuilder: (context, index) {
          final c = selected[index];
          final name = c['name'] as String;
          final koraId = c['koraId'] as String;
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () => _toggleSelection(koraId),
              child: SizedBox(
                width: 52,
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        KoraAvatar(name: name, size: 48, isPremium: c['premium'] == true),
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Color(0xFF8E8E93),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name.split(' ').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Dial-pad entry — lets the user type a phone number directly to
  /// find and select someone, instead of scrolling the contact list.
  /// Matches the dial-pad icon in the reference recording's search bar.
  void _openDialPadEntry() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final brightness = Theme.of(sheetContext).brightness;
        final card = KoraColors.cardFor(brightness);
        final textPrimary = KoraColors.textPrimaryFor(brightness);
        final textMuted = KoraColors.textMutedFor(brightness);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add by phone number',
                    style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: textPrimary, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '+234...',
                    hintStyle: TextStyle(color: textMuted, fontSize: 15),
                    filled: true,
                    fillColor: KoraColors.surfaceFor(brightness),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      final query = controller.text.trim();
                      Navigator.pop(sheetContext);
                      if (query.isEmpty) return;
                      final match = _contacts.where((c) {
                        final phone = (c['phoneNumber'] as String?) ?? (c['koraId'] as String);
                        return phone.contains(query);
                      }).toList();
                      if (match.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('No Kora user found with that number'),
                            backgroundColor: KoraColors.purple,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        setState(() => _selectedIds.add(match.first['koraId'] as String));
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: KoraColors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Next', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        // Create from existing group (WhatsApp 2026 feature)
        if (recent.isNotEmpty) ...[
          _sectionLabel('Frequently contacted', textMuted),
          ..._buildContactTiles(recent, textPrimary, textSecondary, textMuted),
          const SizedBox(height: 8),
        ],
        if (all.isNotEmpty) ...[
          _sectionLabel('Contacts on Kora', textMuted),
          ..._buildContactTiles(all, textPrimary, textSecondary, textMuted),
        ],
      ],
    );
  }



  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  List<Widget> _buildContactTiles(
    List<Map<String, Object?>> contacts,
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
            leading: KoraAvatar(name: contact['name'] as String, size: 48, isPremium: isPremium),
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
            trailing: _buildSelectionCircle(isSelected, textMuted),
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

  /// Trailing radio-style selection circle — outlined when unselected,
  /// filled purple with a checkmark when selected. Matches the
  /// reference recording exactly (selection lives at the row's edge,
  /// not as a badge on the avatar).
  Widget _buildSelectionCircle(bool isSelected, Color textMuted) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? KoraColors.purple : Colors.transparent,
        border: Border.all(
          color: isSelected ? KoraColors.purple : textMuted.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 15) : null,
    );
  }
}
