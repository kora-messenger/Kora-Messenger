import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Sticker Store screen — browse and download sticker packs.
/// Mirrors WhatsApp's Sticker Store feature.
class StickerStoreScreen extends StatefulWidget {
  const StickerStoreScreen({super.key});

  @override
  State<StickerStoreScreen> createState() => _StickerStoreScreenState();
}

class _StickerStoreScreenState extends State<StickerStoreScreen> {
  final List<StickerPack> _packs = [
    StickerPack(id: 'kora_classic', name: 'Kora Classic', creator: 'Kora',
      stickers: ['😊', '😂', '❤️', '👍', '🎉', '🔥', '😎', '😭', '🙏', '💯'],
      isInstalled: true),
    StickerPack(id: 'cute_animals', name: 'Cute Animals', creator: 'Kora Studio',
      stickers: ['🐱', '🐶', '🐰', '🐼', '🦊', '🐨', '🐯', '🦁', '🐸', '🐵'],
      isInstalled: false),
    StickerPack(id: 'food_love', name: 'Food Love', creator: 'Kora Studio',
      stickers: ['🍕', '🍔', '🌮', '🍣', '🍩', '🍦', '☕', '🍓', '🥑', '🍳'],
      isInstalled: false),
    StickerPack(id: 'reactions', name: 'Reactions', creator: 'Kora',
      stickers: ['👀', '🤔', '😏', '🙄', '😮', '😱', '🤯', '🥳', '🤝', '💪'],
      isInstalled: false),
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Sticker Store',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _packs.length,
        itemBuilder: (context, index) {
          final pack = _packs[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Preview grid
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: KoraColors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(pack.stickers.first, style: const TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pack.name, style: TextStyle(
                          color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                      Text('${pack.stickers.length} stickers • by ${pack.creator}',
                          style: TextStyle(color: textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                // Install/Installed button
                pack.isInstalled
                    ? Icon(Icons.check_circle, color: KoraColors.purple, size: 28)
                    : TextButton(
                        onPressed: () => setState(() => pack.isInstalled = true),
                        child: Text('Get', style: TextStyle(
                            color: KoraColors.purple, fontWeight: FontWeight.w600)),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Sticker pack data.
class StickerPack {
  final String id;
  final String name;
  final String creator;
  final List<String> stickers;
  bool isInstalled;

  StickerPack({
    required this.id,
    required this.name,
    required this.creator,
    required this.stickers,
    this.isInstalled = false,
  });
}

/// Gradient Wallpaper picker — choose a gradient wallpaper for chats.
class GradientWallpaperScreen extends StatefulWidget {
  const GradientWallpaperScreen({super.key});

  @override
  State<GradientWallpaperScreen> createState() => _GradientWallpaperScreenState();
}

class _GradientWallpaperScreenState extends State<GradientWallpaperScreen> {
  int _selected = 0;

  static const _gradients = [
    [Color(0xFF6C63FF), Color(0xFF4A90D9)], // Kora default
    [Color(0xFF667eea), Color(0xFF764ba2)], // Purple dream
    [Color(0xFFf093fb), Color(0xFFf5576c)], // Sunset
    [Color(0xFF4facfe), Color(0xFF00f2fe)], // Ocean
    [Color(0xFF43e97b), Color(0xFF38f9d7)], // Mint
    [Color(0xFFfa709a), Color(0xFFfee140)], // Peach
    [Color(0xFF30cfd0), Color(0xFF330867)], // Deep blue
    [Color(0xFF1a1a2e), Color(0xFF16213e)], // Dark navy
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Wallpaper',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context, _gradients[_selected]),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _gradients.length,
        itemBuilder: (context, index) {
          final isSelected = _selected == index;
          return GestureDetector(
            onTap: () => setState(() => _selected = index),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _gradients[index],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 3,
                ),
              ),
              child: isSelected
                  ? const Center(child: Icon(Icons.check, color: Colors.white, size: 24))
                  : null,
            ),
          );
        },
      ),
    );
  }
}

/// Media Gallery screen — browse all media (photos, videos, documents)
/// from a specific chat. Mirrors WhatsApp's "Media, links, and docs" view.
class MediaGalleryScreen extends StatefulWidget {
  final String chatName;

  const MediaGalleryScreen({super.key, required this.chatName});

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  int _selectedTab = 0; // 0=Media, 1=Links, 2=Docs

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Media, links, and docs',
            style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          currentIndex: _selectedTab,
          onTap: (i) => setState(() => _selectedTab = i),
          tabs: const ['Media', 'Links', 'Docs'],
          activeColor: KoraColors.purple,
          inactiveColor: textMuted,
        ),
      ),
      body: _selectedTab == 0
          ? _buildMediaGrid(surface, textMuted)
          : _selectedTab == 1
              ? _buildLinksList(textPrimary, textMuted, surface)
              : _buildDocsList(textPrimary, textMuted, surface),
    );
  }

  Widget _buildMediaGrid(Color surface, Color textMuted) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: 30,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.image, color: textMuted.withValues(alpha: 0.3), size: 32),
        );
      },
    );
  }

  Widget _buildLinksList(Color textPrimary, Color textMuted, Color surface) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: Icon(Icons.link, color: KoraColors.purple),
          title: Text('https://kora.chat', style: TextStyle(color: textPrimary, fontSize: 14)),
          subtitle: Text('Kora Messenger — Welcome', style: TextStyle(color: textMuted, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildDocsList(Color textPrimary, Color textMuted, Color surface) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: Icon(Icons.description, color: KoraColors.purple),
          title: Text('Kora Privacy Policy.pdf', style: TextStyle(color: textPrimary, fontSize: 14)),
          subtitle: Text('245 KB', style: TextStyle(color: textMuted, fontSize: 13)),
        ),
      ],
    );
  }
}

/// Simple TabBar widget for the media gallery.
class _TabBarImpl extends StatelessWidget implements PreferredSizeWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<String> tabs;
  final Color activeColor;
  final Color inactiveColor;

  const _TabBarImpl({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final i = entry.key;
          final label = entry.value;
          final isActive = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? activeColor : inactiveColor,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Extension to use TabBar with simple API
extension on AppBar {
  static TabBar get bottom => TabBar();
}
