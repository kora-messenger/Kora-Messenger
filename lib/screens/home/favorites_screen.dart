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
    return Scaffold(
      backgroundColor: KoraColors.surface,
      appBar: AppBar(
        backgroundColor: KoraColors.surface,
        title: const Text('Favorites', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_rounded, size: 64, color: KoraColors.purple.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('No favorites yet', style: TextStyle(color: KoraColors.textMuted, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Tap and hold a contact to add them to favorites', style: TextStyle(color: KoraColors.textMuted, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _favorites.length,
              itemBuilder: (ctx, i) => ListTile(
                leading: CircleAvatar(backgroundColor: KoraColors.purple, child: Text(_favorites[i][0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                title: Text(_favorites[i], style: const TextStyle(color: Colors.white)),
                trailing: Icon(Icons.star_rounded, color: KoraColors.purple),
              ),
            ),
    );
  }
}
