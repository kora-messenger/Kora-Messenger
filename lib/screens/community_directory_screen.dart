import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';

/// Community Directory Screen — browse, search, and join communities.
/// Mirrors WhatsApp's community directory feature.
///
/// Shows:
/// - Recommended communities
/// - Communities you've joined
/// - Search by name/category
/// - Create new community button
class CommunityDirectoryScreen extends StatefulWidget {
  const CommunityDirectoryScreen({super.key});

  @override
  State<CommunityDirectoryScreen> createState() => _CommunityDirectoryScreenState();
}

class _CommunityDirectoryScreenState extends State<CommunityDirectoryScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';

  static const _categories = ['All', 'Tech', 'Gaming', 'Education', 'Entertainment', 'Sports', 'Business'];

  final List<_Community> _communities = [
    _Community(name: 'Kora Developers', members: 1200, category: 'Tech', icon: 'K', isJoined: true),
    _Community(name: 'Flutter Community', members: 5400, category: 'Tech', icon: 'F'),
    _Community(name: 'Mobile Gaming Hub', members: 8900, category: 'Gaming', icon: 'G'),
    _Community(name: 'Learn Together', members: 2300, category: 'Education', icon: 'L'),
    _Community(name: 'Movie Fans', members: 4500, category: 'Entertainment', icon: 'M'),
    _Community(name: 'Football League', members: 6700, category: 'Sports', icon: 'F'),
    _Community(name: 'Startup Network', members: 3100, category: 'Business', icon: 'S'),
  ];

  List<_Community> get _filtered {
    final q = _searchController.text.toLowerCase();
    return _communities.where((c) {
      final matchesSearch = q.isEmpty || c.name.toLowerCase().contains(q);
      final matchesCategory = _selectedCategory == 'All' || c.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    final joined = _communities.where((c) => c.isJoined).toList();
    final discover = _filtered.where((c) => !c.isJoined).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Communities',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: textPrimary),
            onPressed: () => _showSearch(surface, textPrimary, textMuted),
          ),
          IconButton(
            icon: Icon(Icons.add, color: textPrimary),
            onPressed: () => Navigator.pop(context, 'create'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(22)),
              child: Row(
                children: [
                  Icon(Icons.search, color: textMuted, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search communities…',
                        hintStyle: TextStyle(color: textMuted, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Category chips
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (context, i) {
                final isSelected = _selectedCategory == _categories[i];
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = _categories[i]),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? KoraColors.purple : surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(_categories[i],
                        style: TextStyle(color: isSelected ? Colors.white : textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Joined communities
          if (joined.isNotEmpty) ...[
            _sectionHeader('JOINED (${joined.length})', textMuted),
            ...joined.map((c) => _communityTile(c, surface, textPrimary, textMuted)),
          ],

          // Discover communities
          if (discover.isNotEmpty) ...[
            _sectionHeader('DISCOVER', textMuted),
            ...discover.map((c) => _communityTile(c, surface, textPrimary, textMuted)),
          ],

          if (_filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: textMuted),
                    const SizedBox(height: 12),
                    Text('No communities found', style: TextStyle(color: textMuted, fontSize: 15)),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context, 'create'),
        backgroundColor: KoraColors.purple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _sectionHeader(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label, style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    );
  }

  Widget _communityTile(_Community c, Color surface, Color textPrimary, Color textMuted) {
    return ListTile(
      leading: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [KoraColors.purple, KoraColors.blue]),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(c.icon, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
        ),
      ),
      title: Text(c.name, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text('${c.members} members • ${c.category}', style: TextStyle(color: textMuted, fontSize: 13)),
      trailing: c.isJoined
          ? Icon(Icons.check_circle, color: KoraColors.purple, size: 24)
          : TextButton(
              onPressed: () => setState(() => c.isJoined = true),
              child: const Text('Join', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600)),
            ),
      onTap: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Community details coming soon"), behavior: SnackBarBehavior.floating)); },
    );
  }

  void _showSearch(Color surface, Color textPrimary, Color textMuted) {
    // Focus the search bar
  }
}

class _Community {
  final String name;
  final int members;
  final String category;
  final String icon;
  bool isJoined;

  _Community({
    required this.name,
    required this.members,
    required this.category,
    required this.icon,
    this.isJoined = false,
  });
}
