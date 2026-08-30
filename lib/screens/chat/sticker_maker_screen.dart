import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// Sticker Maker screen — create custom stickers from photos.
/// Mirrors WhatsApp's sticker maker feature.
///
/// Lets users:
/// - Select a photo
/// - Auto-remove background (magic eraser)
/// - Add text overlay with color
/// - Export to personal "My Stickers" pack
class StickerMakerScreen extends StatefulWidget {
  final String imagePath;

  const StickerMakerScreen({super.key, required this.imagePath});

  @override
  State<StickerMakerScreen> createState() => _StickerMakerScreenState();
}

class _StickerMakerScreenState extends State<StickerMakerScreen> {
  bool _bgRemoved = false;
  String? _textOverlay;
  Color _textColor = Colors.white;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Sticker Maker', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _saveSticker,
            child: Text(_saved ? 'Saved!' : 'Save', style: TextStyle(color: _saved ? Colors.green : KoraColors.purple, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Preview
          Expanded(
            child: Center(
              child: Stack(
                children: [
                  // Checkerboard pattern for transparency
                  Container(
                    width: 240, height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _bgRemoved ? Colors.transparent : null,
                      gradient: _bgRemoved ? null : LinearGradient(
                        colors: [Colors.grey.shade800, Colors.grey.shade900],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.image, size: 64, color: Colors.white24),
                    ),
                  ),
                  if (_bgRemoved)
                    Container(
                      width: 240, height: 240,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0x33CCCCCC), Color(0x33FFFFFF)],
                        ),
                      ),
                    ),
                  if (_textOverlay != null)
                    Positioned(
                      bottom: 8, left: 0, right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_textOverlay!,
                              style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Tools
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _toolButton(Icons.auto_fix_high, 'Auto Cut', _bgRemoved, () => setState(() => _bgRemoved = !_bgRemoved)),
                _toolButton(Icons.text_fields, 'Text', _textOverlay != null, () => _addText()),
                _toolButton(Icons.palette, 'Color', false, () => _pickColor()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? KoraColors.purple : Colors.white70, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: active ? KoraColors.purple : Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  void _addText() {
    final controller = TextEditingController(text: _textOverlay ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Add Text', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Sticker text…',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.grey.shade800,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => _textOverlay = controller.text.isEmpty ? null : controller.text);
              Navigator.pop(context);
            },
            child: Text('Add', style: TextStyle(color: KoraColors.purple)),
          ),
        ],
      ),
    );
  }

  void _pickColor() {
    final colors = [Colors.white, Colors.black, Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12, runSpacing: 12,
            children: colors.map((c) => GestureDetector(
              onTap: () { setState(() => _textColor = c); Navigator.pop(context); },
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              ),
            )).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _saveSticker() async {
    // Save sticker to personal "My Stickers" pack
    final prefs = await SharedPreferences.getInstance();
    final myStickers = prefs.getStringList('kora_my_stickers') ?? [];

    final stickerData = jsonEncode({
      'path': widget.imagePath,
      'bgRemoved': _bgRemoved,
      'text': _textOverlay,
      'textColor': _textColor.value,
      'created': DateTime.now().millisecondsSinceEpoch,
    });
    myStickers.insert(0, stickerData);
    if (myStickers.length > 30) myStickers.removeLast();
    await prefs.setStringList('kora_my_stickers', myStickers);

    setState(() => _saved = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sticker saved to My Stickers pack'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.pop(context, stickerData);
  }
}
