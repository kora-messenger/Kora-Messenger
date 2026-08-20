import 'package:flutter/material.dart';
import '../models/chat_models.dart';

/// Kora's verified-account badge system.
/// Purple scalloped seal = official Kora accounts (Support, AI Assistant, etc.)
/// Blue scalloped seal = Kora Premium subscriber.
/// Rendered from bundled artwork (the classic scalloped verified-checkmark
/// seal, matching the reference designs) so it stays crisp and consistent
/// everywhere in the app (chat list, chat header, search results, profile).
class KoraBadge extends StatelessWidget {
  final KoraBadgeType type;
  final double size;

  const KoraBadge({
    super.key,
    required this.type,
    this.size = 15,
  });

  @override
  Widget build(BuildContext context) {
    if (type == KoraBadgeType.none) return const SizedBox.shrink();

    final assetPath = type == KoraBadgeType.officialPurple
        ? 'assets/badges/official_badge.png'
        : 'assets/badges/premium_badge.png';

    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// A name row with an inline badge, used in chat list items, headers,
/// and search results — keeps name + badge spacing consistent.
class KoraNameWithBadge extends StatelessWidget {
  final String name;
  final KoraBadgeType badge;
  final TextStyle? style;
  final double badgeSize;

  const KoraNameWithBadge({
    super.key,
    required this.name,
    this.badge = KoraBadgeType.none,
    this.style,
    this.badgeSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            style: style,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        if (badge != KoraBadgeType.none) ...[
          const SizedBox(width: 4),
          KoraBadge(type: badge, size: badgeSize),
        ],
      ],
    );
  }
}
