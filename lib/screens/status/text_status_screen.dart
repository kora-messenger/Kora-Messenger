import 'dart:math';
import 'package:flutter/material.dart';

import '../../theme/kora_colors.dart';
import '../../models/status_model.dart';
import '../../services/status_service.dart';

/// WhatsApp-style text status composer.
///
/// Full-screen colored background with centered text. User can:
/// - Type text
/// - Tap the T icon to cycle through fonts
/// - Tap the palette icon to cycle through background colors
/// - Tap the emoji icon to add emojis
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

  void _publish() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final item = StatusItem(
      id: 'status_${DateTime.now().millisecondsSinceEpoch}',
      type: StatusType.text,
      text: text,
      backgroundColor: _colors[_colorIndex],
      textColor: Colors.white,
      fontFamily: _fonts[_fontIndex],
      createdAt: DateTime.now(),
    );

    StatusService.instance.addStatusItem(item);
    Navigator.of(context).popUntil((r) => r.isFirst);
    // Pop to status tab — caller should handle refresh
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Status updated'),
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
                  // Color palette button
                  IconButton(
                    icon: const Icon(Icons.palette_outlined, color: Colors.white70),
                    onPressed: _cycleColor,
                  ),
                ],
              ),
            ),
            // Text input area
            Expanded(
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).requestFocus();
                },
                child: Container(
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
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
                ),
              ),
            ),
            // Bottom bar with font label + send
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
                  const Spacer(),
                  // Emoji button
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white70),
                    onPressed: () {
                      // Emoji picker would open here
                    },
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  GestureDetector(
                    onTap: _publish,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 22,
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
}
