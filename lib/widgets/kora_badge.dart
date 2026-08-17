import 'package:flutter/material.dart';
import '../models/chat_models.dart';

/// Kora's verified-account badge system.
/// Purple checkmark = official Kora accounts (Support, AI Assistant, etc.)
/// Blue checkmark = Kora Premium subscriber.
/// Kept as ONE small reusable widget so it stays visually consistent
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

    final color = type == KoraBadgeType.officialPurple
        ? KoraBadgeColors.official
        : KoraBadgeColors.premium;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 1.2,
        ),
      ),
      child: Icon(
        Icons.check,
        size: size * 0.65,
        color: Colors.white,
      ),
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
    this.badgeSize = 15,
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
