import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../theme/kora_colors.dart';
import '../../models/status_model.dart';
import '../../services/status_service.dart';
import 'package:image_picker/image_picker.dart';

/// WhatsApp 2026-style text status composer.
///
/// Full-screen colored background with centered text. User can:
/// - Type text
/// - Tap the T icon to cycle through fonts
/// - Tap the palette icon to cycle through background colors
/// - Tap the emoji icon to add emojis
/// - NEW: Add music to status
/// - NEW: Animated stickers
/// - Tap send to publish the status
class TextStatusScreen extends StatefulWidget {
  const TextStatusScreen({super.key});

  @override
  State<TextStatusScreen> createState() => _TextStatusScreenState();
}

class _TextStatusScreenState extends State<TextStatusScreen> {
  final _controller = TextEditingController();
  int _fontIndex = 0;
  int _colorIndex = 0;
  String? _selectedMusic;
  String _selectedMusicArtist = '';
  String? _backgroundImagePath; // WhatsApp-style: photo as text status background
  int _fontColorIndex = 0; // Independent text color cycling
  static const _fontColors = [
    Colors.white,
    Colors.black,
    Colors.yellow,
    Colors.red,
    Colors.green,
    Colors.blue,
  ];

  // WhatsApp's text status color palette
  static const _colors = [
    Color(0xFF8B5CF6), // Kora purple
    Color(0xFF3B82F6), // Kora blue
    Color(0xFF22C55E), // Green
    Color(0xFFEC4899), // Pink
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF14B8A6), // Teal
    Color(0xFF1E293B), // Dark navy
  ];

  static const _fonts = [
    null,         // Default system font
    'Serif',      // Serif
    'Monospace',  // Mono
    'Cursive',    // Cursive
  ];

  static const _fontLabels = ['Default', 'Serif', 'Mono', 'Cursive'];

  // Quick emojis for status
  static const _quickEmojis = ['❤️', '😂', '🔥', '👍', '🎉', '✨', '💯', '🙏'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cycleFont() {
    setState(() => _fontIndex = (_fontIndex + 1) % _fonts.length);
  }

  void _cycleColor() {
    setState(() => _colorIndex = (_colorIndex + 1) % _colors.length);
  }

  void _cycleFontColor() {
    // WhatsApp-style: cycle text color independently
    setState(() {
      _fontColorIndex = (_fontColorIndex + 1) % _fontColors.length;
    });
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final sel = _controller.selection.baseOffset;
    final newText = sel >= 0
        ? text.substring(0, sel) + emoji + text.substring(sel)
        : text + emoji;
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: newText.length);
    setState(() {});
  }

  void _openMusicPicker() {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    final trendingSongs = [
      {'title': 'Asake - Lonely At The Top', 'artist': 'Asake'},
      {'title': 'Burna Boy - City Boys', 'artist': 'Burna Boy'},
      {'title': 'Rema - Calm Down', 'artist': 'Rema'},
      {'title': 'Tems - Me & U', 'artist': 'Tems'},
      {'title': 'Davido - Unavailable', 'artist': 'Davido'},
      {'title': 'Wizkid - Essence', 'artist': 'Wizkid'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('Add music',
                      style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Icon(Icons.close, color: textSecondary, size: 22),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: textSecondary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search for songs',
                          hintStyle: TextStyle(color: textSecondary),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Trending now',
                    style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: trendingSongs.length,
                itemBuilder: (ctx, i) {
                  final song = trendingSongs[i];
                  return ListTile(
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: KoraColors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.music_note, color: KoraColors.purple, size: 22),
                    ),
                    title: Text(song['title']!,
                        style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text(song['artist']!,
                        style: TextStyle(color: textSecondary, fontSize: 13)),
                    trailing: _selectedMusic == song['title']
                        ? Icon(Icons.check_circle, color: KoraColors.purple, size: 22)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedMusic = song['title'];
                        _selectedMusicArtist = song['artist']!;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickBackgroundPhoto() async {
    final picker = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picker != null) {
      setState(() => _backgroundImagePath = picker.path);
    }
  }

  void _removeBackgroundPhoto() {
    setState(() => _backgroundImagePath = null);
  }

  void _publish() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final item = StatusItem(
      id: 'status_${DateTime.now().millisecondsSinceEpoch}',
      type: _backgroundImagePath != null ? StatusType.photo : StatusType.text,
      text: _backgroundImagePath != null ? null : text,
      mediaPath: _backgroundImagePath,
      caption: _backgroundImagePath != null ? text : null,
      backgroundColor: _colors[_colorIndex],
      textColor: _fontColors[_fontColorIndex],
      fontFamily: _fonts[_fontIndex],
      musicTitle: _selectedMusic,
      createdAt: DateTime.now(),
    );

    StatusService.instance.addStatusItem(item);
    Navigator.of(context).popUntil((r) => r.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_selectedMusic != null ? 'Status updated with music' : 'Status updated'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _colors[_colorIndex];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  // Font cycle button
                  IconButton(
                    icon: Text(
                      'T',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: _fonts[_fontIndex],
                      ),
                    ),
                    onPressed: _cycleFont,
                  ),
                  // Color palette button (background)
                  IconButton(
                    icon: const Icon(Icons.palette_outlined, color: Colors.white70),
                    onPressed: _cycleColor,
                  ),
                  // Font color button (text color)
                  IconButton(
                    icon: Icon(Icons.text_fields, color: _fontColors[_fontColorIndex]),
                    onPressed: _cycleFontColor,
                  ),
                  // Background photo button
                  IconButton(
                    icon: Icon(
                      _backgroundImagePath != null ? Icons.image : Icons.add_photo_alternate_outlined,
                      color: Colors.white70,
                    ),
                    onPressed: _pickBackgroundPhoto,
                  ),
                ],
              ),
            ),
            // Text input area
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).requestFocus(),
                child: Container(
                  decoration: _backgroundImagePath != null
                      ? BoxDecoration(
                          image: DecorationImage(
                            image: FileImage(File(_backgroundImagePath!)),
                            fit: BoxFit.cover,
                          ),
                        )
                      : BoxDecoration(color: Colors.transparent),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _controller,
                        maxLines: null,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _fontColors[_fontColorIndex],
                          fontSize: 28,
                          height: 1.4,
                          fontFamily: _fonts[_fontIndex],
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Type a status',
                          hintStyle: TextStyle(color: Colors.white54, fontSize: 28),
                        ),
                        cursorColor: Colors.white,
                        autofocus: true,
                      ),
                      // Music badge
                      if (_selectedMusic != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.music_note, color: Colors.white70, size: 16),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _selectedMusic!,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => setState(() {
                                  _selectedMusic = null;
                                  _selectedMusicArtist = '';
                                }),
                                child: const Icon(Icons.close, color: Colors.white54, size: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Quick emoji row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickEmojis.length,
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => _insertEmoji(_quickEmojis[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Center(
                        child: Text(_quickEmojis[i], style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Bottom bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Row(
                children: [
                  // Font label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _fontLabels[_fontIndex],
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Music button (NEW)
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        _selectedMusic != null ? Icons.music_note : Icons.music_note_outlined,
                        color: Colors.white70, size: 20,
                      ),
                      onPressed: _openMusicPicker,
                    ),
                  ),
                  const Spacer(),
                  // Emoji button
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  GestureDetector(
                    onTap: _publish,
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 1.5),
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 22),
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
}
