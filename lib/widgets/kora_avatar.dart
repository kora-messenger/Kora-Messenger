import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';

/// Reusable circular avatar for Kora — shows an asset image, a network
/// image, or falls back to a gradient initials badge. Used in the chat
/// list, chat header, search results, and new-chat picker so avatars
/// look consistent everywhere.
class KoraAvatar extends StatelessWidget {
  final String name;
  final String? assetPath;
  final String? imageUrl;
  final double size;
  final bool showOnlineDot;

  const KoraAvatar({
    super.key,
    required this.name,
    this.assetPath,
    this.imageUrl,
    this.size = 52,
    this.showOnlineDot = false,
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

    if (!showOnlineDot) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
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
      ],
    );
  }

  Widget _buildContent() {
    if (assetPath != null) {
      return Image.asset(assetPath!, fit: BoxFit.cover);
    }
    if (imageUrl != null) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildInitials(),
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
