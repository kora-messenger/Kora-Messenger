import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../screens/settings/premium_subscribe_sheet.dart';
import '../theme/kora_colors.dart';

/// Kora's verified-account badge system.
/// Purple scalloped seal = official Kora accounts (Support, AI Assistant, etc.)
/// Blue scalloped seal = Kora Premium subscriber.
/// Rendered from bundled artwork (the classic scalloped verified-checkmark
/// seal, matching the reference designs) so it stays crisp and consistent
/// everywhere in the app (chat list, chat header, search results, profile).
///
/// Both badge types are tappable — this is built into the widget itself so
/// tapping behaves identically wherever the badge is shown:
///   • Premium badge → opens the Premium subscribe sheet.
///   • Official badge → shows a short explainer for what the seal means.
class KoraBadge extends StatelessWidget {
  final KoraBadgeType type;
  final double size;

  const KoraBadge({
    super.key,
    required this.type,
    this.size = 17,
  });

  void _onTap(BuildContext context) {
    if (type == KoraBadgeType.premiumBlue) {
      PremiumSubscribeSheet.show(context);
    } else if (type == KoraBadgeType.officialPurple) {
      _showOfficialBadgeInfo(context);
    }
  }

  void _showOfficialBadgeInfo(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Image.asset('assets/badges/official_badge.webp', width: 28, height: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Official Kora Account',
                    style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'This purple checkmark confirms this is an official Kora Messenger account, like Kora Support or Kora AI. Official accounts are verified and operated by the Kora team.',
                style: TextStyle(color: textSecondary, fontSize: 14, height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (type == KoraBadgeType.none) return const SizedBox.shrink();

    final assetPath = type == KoraBadgeType.officialPurple
        ? 'assets/badges/official_badge.webp'
        : 'assets/badges/premium_badge.webp';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTap(context),
      child: Padding(
        // Slightly enlarge the tap target beyond the visible icon size
        // so the badge is easy to hit without changing its rendered size.
        padding: const EdgeInsets.all(3),
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// A name row with an inline badge, used in chat list items, headers,
/// and search results — keeps name + badge spacing consistent. The
/// badge remains independently tappable (see [KoraBadge]).
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
          const SizedBox(width: 2),
          KoraBadge(type: badge, size: badgeSize),
        ],
      ],
    );
  }
}
