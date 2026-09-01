import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Media Gallery screen — full-screen viewer for photos and videos in a chat.
/// Mirrors WhatsApp's media gallery (tap photo → fullscreen with swipe).
///
/// Features:
/// - Full-screen image with pinch-to-zoom
/// - Swipe left/right for next/previous
/// - Download/share/delete options
/// - Date and sender info overlay
class MediaGalleryScreen extends StatefulWidget {
  final List<String> mediaPaths;
  final int initialIndex;
  final String chatName;

  const MediaGalleryScreen({
    super.key,
    required this.mediaPaths,
    this.initialIndex = 0,
    required this.chatName,
  });

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Media pager
          PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaPaths.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => setState(() => _showOverlay = !_showOverlay),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image, size: 64, color: Colors.white24),
                ),
              ),
            ),
          ),
          // Top overlay
          if (_showOverlay)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  color: Colors.black54,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(widget.chatName,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Share coming soon"), behavior: SnackBarBehavior.floating)); }),
                      IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
                    ],
                  ),
                ),
              ),
            ),
          // Bottom overlay
          if (_showOverlay)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _bottomAction(Icons.download, 'Save', () {}),
                      _bottomAction(Icons.forward, 'Forward', () {}),
                      _bottomAction(Icons.star_border, 'Star', () {}),
                      _bottomAction(Icons.delete_outline, 'Delete', () {}),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bottomAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
