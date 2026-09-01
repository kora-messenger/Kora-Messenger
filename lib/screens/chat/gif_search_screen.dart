import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/kora_colors.dart';

/// GIF Search screen — search and send animated GIFs in chat.
/// Uses the Giphy API (api.giphy.com) for real GIF results.
/// Mirrors WhatsApp's GIF picker which also uses Giphy + Tenor.
class GifSearchScreen extends StatefulWidget {
  final ValueChanged<String> onGifSelected;

  const GifSearchScreen({super.key, required this.onGifSelected});

  @override
  State<GifSearchScreen> createState() => _GifSearchScreenState();
}

class _GifSearchScreenState extends State<GifSearchScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isLoading = true;
  List<_GifResult> _gifs = [];
  String _selectedCategory = 'Trending';

  static const _giphyApiKey = 'dc6zaTOxFJmzC';
  static const _giphyBase = 'https://api.giphy.com/v1/gifs';
  static const _stickerBase = 'https://api.giphy.com/v1/stickers';

  static const _categories = [
    {'label': 'Trending', 'query': ''},
    {'label': 'Reactions', 'query': 'reactions'},
    {'label': 'Entertainment', 'query': 'entertainment'},
    {'label': 'Sports', 'query': 'sports'},
    {'label': 'Stickers', 'query': 'stickers'},
    {'label': 'Anime', 'query': 'anime'},
  ];

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() => _isLoading = true);
    try {
      final isStickers = _selectedCategory == 'Stickers';
      final base = isStickers ? _stickerBase : _giphyBase;
      final url = '$base/trending?api_key=$_giphyApiKey&limit=30&rating=pg';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = (data['data'] as List?) ?? [];
        _gifs = items.map((item) => _GifResult.fromGiphy(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      _gifs = [];
    }
    setState(() => _isLoading = false);
  }

  Future<void> _searchGifs(String query) async {
    if (query.isEmpty) { _loadTrending(); return; }
    setState(() => _isLoading = true);
    try {
      final isStickers = _selectedCategory == 'Stickers';
      final base = isStickers ? _stickerBase : _giphyBase;
      final url = '$base/search?api_key=$_giphyApiKey&q=${Uri.encodeComponent(query)}&limit=30&rating=pg';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = (data['data'] as List?) ?? [];
        _gifs = items.map((item) => _GifResult.fromGiphy(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      _gifs = [];
    }
    setState(() => _isLoading = false);
  }

  void _onCategoryChanged(String category) {
    setState(() { _selectedCategory = category; _isSearching = _searchController.text.isNotEmpty; });
    if (_isSearching) { _searchGifs(_searchController.text); } else { _loadTrending(); }
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
        title: Text('Search GIFs', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Container(
          height: 44, padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            Icon(Icons.search, color: textMuted, size: 20), const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: _searchController, style: TextStyle(color: textPrimary, fontSize: 15),
              decoration: InputDecoration(hintText: 'Search GIFs…', hintStyle: TextStyle(color: textMuted, fontSize: 14), border: InputBorder.none, isDense: true),
              onChanged: (v) { setState(() => _isSearching = v.isNotEmpty); _searchGifs(v); },
            )),
            if (_isSearching) GestureDetector(
              onTap: () { _searchController.clear(); setState(() => _isSearching = false); _loadTrending(); },
              child: Icon(Icons.close, color: textMuted, size: 18),
            ),
          ]),
        )),
        SizedBox(height: 36, child: ListView.builder(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _categories.length, itemBuilder: (context, index) {
            final cat = _categories[index]['label']!;
            final isSelected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () => _onCategoryChanged(cat),
              child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: isSelected ? KoraColors.purple : surface, borderRadius: BorderRadius.circular(18)),
                child: Text(cat, style: TextStyle(color: isSelected ? Colors.white : textMuted, fontSize: 13, fontWeight: FontWeight.w500))),
            );
          },
        )),
        const SizedBox(height: 8),
        Expanded(child: _isLoading
          ? Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : _gifs.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.gif_box, size: 48, color: textMuted.withValues(alpha: 0.3)), const SizedBox(height: 12),
                Text('No GIFs found', style: TextStyle(color: textMuted, fontSize: 14)),
              ]))
            : GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
                itemCount: _gifs.length, itemBuilder: (context, index) {
                  final gif = _gifs[index];
                  return GestureDetector(
                    onTap: () { widget.onGifSelected(gif.url); Navigator.pop(context); },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(gif.previewUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(gradient: LinearGradient(colors: [KoraColors.purple.withValues(alpha: 0.2), KoraColors.blue.withValues(alpha: 0.2)]), borderRadius: BorderRadius.circular(8)),
                          child: Center(child: Icon(Icons.gif_box, size: 28, color: KoraColors.purple.withValues(alpha: 0.4))),
                        ),
                      ),
                    ),
                  );
                },
              ),
        ),
      ]),
    );
  }
}

class _GifResult {
  final String url;
  final String previewUrl;
  _GifResult({required this.url, required this.previewUrl});

  factory _GifResult.fromGiphy(Map<String, dynamic> item) {
    final images = item['images'] as Map<String, dynamic>? ?? {};
    final original = images['original'] as Map<String, dynamic>? ?? {};
    final preview = images['fixed_height_small'] as Map<String, dynamic>? ?? images['fixed_height'] as Map<String, dynamic>? ?? images['downsized'] as Map<String, dynamic>? ?? {};
    return _GifResult(url: original['url'] as String? ?? '', previewUrl: preview['url'] as String? ?? '');
  }
}
