import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import 'emoji_sticker_panel.dart';

/// EmojiPickerSheet — thin wrapper that shows the full KoraEmojiPanel
/// in a bottom sheet. Used by screens that only need emoji selection
/// (not stickers/GIFs).
///
/// This replaces the old basic emoji picker with the full-featured
/// panel including search, skin tones, and recent emojis.
class EmojiPickerSheet extends StatefulWidget {
  final Function(String)? onEmojiSelected;

  const EmojiPickerSheet({super.key, this.onEmojiSelected});

  @override
  State<EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<EmojiPickerSheet> {
  @override
  Widget build(BuildContext context) {
    return KoraEmojiPanel(
      onEmojiSelected: (emoji) {
        if (widget.onEmojiSelected != null) {
          widget.onEmojiSelected!(emoji);
        } else {
          Navigator.pop(context, emoji);
        }
      },
      onStickerSelected: (_) {},
    );
  }
}
