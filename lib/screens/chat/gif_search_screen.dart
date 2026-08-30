import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// GIF Search screen — search and send animated GIFs in chat.
/// Mirrors WhatsApp's GIF picker.
///
/// Features:
/// - Search bar for trending/specific GIFs
/// - Grid of GIF thumbnails
/// - Category chips
/// - Tap to preview, send to chat
class GifSearchScreen extends StatefulWidget {
  final ValueChanged<String> onGifSelected;

  const GifSearchScreen({super.key, required this.onGifSelected});

  @override
  State<GifSearchScreen> createState() => _GifSearchScreenState();
}

class _GifSearchScreenState extends State<GifSearchScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'Trending';
  bool _isSearching = false;

  static const _categories = ['Trending', 'Reactions', 'Entertainment', 'Sports', 'Stickers', 'Anime'];

  // Placeholder GIF grid — in production these would be Giphy/Tenor API results
  final List<String> _gifs = List.generate(20, (i) => 'gif_${i + 1}');

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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Search GIFs',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: textMuted, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search GIFs…',
                        hintStyle: TextStyle(color: textMuted, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _isSearching = v.isNotEmpty),
                    ),
                  ),
                  if (_isSearching)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _isSearching = false);
                      },
                      child: Icon(Icons.close, color: textMuted, size: 18),
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
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? KoraColors.purple : surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(cat,
                        style: TextStyle(
                            color: isSelected ? Colors.white : textMuted,
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // GIF grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _gifs.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    widget.onGifSelected(_gifs[index]);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          KoraColors.purple.withValues(alpha: 0.1 + (index % 3) * 0.05),
                          KoraColors.blue.withValues(alpha: 0.08 + (index % 3) * 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(Icons.gif_box, size: 32, color: KoraColors.purple.withValues(alpha: 0.4)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
