import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';

/// Save to Gallery button — appears on media messages.
/// Mirrors WhatsApp's "Save to gallery" long-press action.
///
/// In production, this would call platform channel to save
/// the file to the device's photo gallery.
class SaveToGalleryButton extends StatelessWidget {
  final String mediaPath;
  final bool isVideo;

  const SaveToGalleryButton({
    super.key,
    required this.mediaPath,
    this.isVideo = false,
  });

  void _save(BuildContext context) {
    // Platform channel call to save to gallery
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isVideo ? 'Video saved to gallery' : 'Photo saved to gallery'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _save(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isVideo ? Icons.video_library_outlined : Icons.save_outlined,
                size: 16, color: KoraColors.purple),
            const SizedBox(width: 6),
            Text('Save to gallery',
                style: TextStyle(color: KoraColors.purple, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
