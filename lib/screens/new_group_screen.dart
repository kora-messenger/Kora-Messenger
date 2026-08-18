import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import '../widgets/kora_avatar.dart';

/// New Group screen — shows frequently connected Kora users and contacts.
/// Search bar filters by Name, Kora ID, or @Username.
/// Back arrow at bottom-right returns to home.
class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Mock contacts — replace with real data later
  final List<Map<String, String>> _contacts = [
    {'name': 'Amara Chukwu', 'koraId': 'KM-830192746', 'username': '@amara_c', 'avatar': ''},
    {'name': 'David Okoro', 'koraId': 'KM-471038291', 'username': '@davido', 'avatar': ''},
    {'name': 'Grace Adeyemi', 'koraId': 'KM-205918374', 'username': '@grace_a', 'avatar': ''},
    {'name': 'Emeka Nwosu', 'koraId': 'KM-673920184', 'username': '@emeka_n', 'avatar': ''},
    {'name': 'Chidi Okafor', 'koraId': 'KM-918273645', 'username': '@chidi_o', 'avatar': ''},
    {'name': 'Fatima Bello', 'koraId': 'KM-384756102', 'username': '@fatima_b', 'avatar': ''},
    {'name': 'Tunde Bakare', 'koraId': 'KM-561029384', 'username': '@tunde_b', 'avatar': ''},
    {'name': 'Ngozi Eze', 'koraId': 'KM-728394016', 'username': '@ngozi_e', 'avatar': ''},
    {'name': 'Kola Adekunle', 'koraId': 'KM-193847562', 'username': '@kola_a', 'avatar': ''},
    {'name': 'Zainab Ibrahim', 'koraId': 'KM-640192837', 'username': '@zainab_i', 'avatar': ''},
  ];

  List<Map<String, String>> get _filtered {
    if (_query.isEmpty) return _contacts;
    final q = _query.toLowerCase();
    return _contacts.where((c) {
      final name = c['name']!.toLowerCase();
      final koraId = c['koraId']!.toLowerCase();
      final username = c['username']!.toLowerCase();
      return name.contains(q) || koraId.contains(q) || username.contains(q);
    }).toList();
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
                      'New Group',
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
            // Back arrow at bottom-right
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 20, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
                        Icons.arrow_back,
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
    final filtered = _filtered;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_outlined, size: 48, color: textMuted),
            const SizedBox(height: 12),
            Text('No contacts found', style: TextStyle(color: textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(left: 76),
        child: Divider(height: 1, color: textMuted.withValues(alpha: 0.08)),
      ),
      itemBuilder: (context, index) {
        final contact = filtered[index];
        return ListTile(
          leading: KoraAvatar(name: contact['name']!, size: 48),
          title: Text(
            contact['name']!,
            style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${contact['koraId']} · ${contact['username']}',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          onTap: () {
            // TODO: Start group creation with selected contact
          },
        );
      },
    );
  }
}
