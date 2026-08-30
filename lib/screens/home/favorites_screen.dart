import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<String> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favorites = prefs.getStringList('kora_favorites') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Favorites', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: textPrimary),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_rounded, size: 64, color: KoraColors.purple.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('No favorites yet', style: TextStyle(color: textMuted, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Tap and hold a contact to add them to favorites', style: TextStyle(color: textMuted, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _favorites.length,
              itemBuilder: (ctx, i) {
                final isLast = i == _favorites.length - 1;
                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: KoraColors.purple.withValues(alpha: 0.15),
                        child: Text(_favorites[i][0].toUpperCase(), style: const TextStyle(color: KoraColors.purple)),
                      ),
                      title: Text(_favorites[i], style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                      trailing: Icon(Icons.star_rounded, color: KoraColors.purple, size: 22),
                    ),
                    if (!isLast)
                      Padding(
                        padding: const EdgeInsets.only(left: 72),
                        child: Divider(height: 1, color: border),
                      ),
                  ],
                );
              },
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
          onPressed: () => Navigator.pop(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
