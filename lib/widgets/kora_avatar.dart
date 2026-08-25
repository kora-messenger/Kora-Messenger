import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/kora_colors.dart';

/// Reusable circular avatar for Kora — shows an asset image, a cached
/// network image, or falls back to a gradient initials badge. Used in
/// the chat list, chat header, search results, and new-chat picker so
/// avatars look consistent everywhere.
///
/// Uses CachedNetworkImage for network avatars to minimize data usage:
/// images are cached on-device after first download, so repeated
/// views of the same avatar don't re-download bytes.
class KoraAvatar extends StatelessWidget {
  final String name;
  final String? assetPath;
  final String? imageUrl;
  final double size;
  final bool showOnlineDot;

  /// Shows a small blue Premium badge at the top-right corner of the
  /// avatar, for Kora Premium subscribers.
  final bool isPremium;

  const KoraAvatar({
    super.key,
    required this.name,
    this.assetPath,
    this.imageUrl,
    this.size = 52,
    this.showOnlineDot = false,
    this.isPremium = false,
  });

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: _buildContent(),
      ),
    );

    if (!showOnlineDot && !isPremium) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        if (showOnlineDot)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
        if (isPremium)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: size * 0.32,
              height: size * 0.32,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.star_rounded,
                color: Colors.white,
                size: size * 0.2,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (assetPath != null) {
      return Image.asset(assetPath!, fit: BoxFit.cover);
    }
    // Guard against stale local device paths that were saved before
    // the cloud upload was working.  A real avatar URL is always http(s).
    if (imageUrl != null && imageUrl!.isNotEmpty && imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildInitials(),
        errorWidget: (_, __, ___) => _buildInitials(),
        // Data saving: cap both in-memory and disk cache width.
        // For a 50px avatar, we only need ~100px of resolution.
        memCacheWidth: (size * 2).toInt(),
        maxWidthDiskCache: (size * 2).toInt(),
        maxHeightDiskCache: (size * 2).toInt(),
        // Disable fadeIn to reduce unnecessary repaints
        fadeInDuration: const Duration(milliseconds: 0),
      );
    }
    return _buildInitials();
  }

  Widget _buildInitials() {
    return Container(
      decoration: const BoxDecoration(gradient: KoraColors.brandGradient),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
