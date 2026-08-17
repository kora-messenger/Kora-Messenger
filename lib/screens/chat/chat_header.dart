import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_avatar.dart';
import '../../widgets/kora_badge.dart';
import '../../widgets/kora_menu_sheet.dart';

/// Kora's chat header — back button, avatar, name + badge,
/// status text (online / last seen), call buttons, three-dot menu.
/// Distinctly Kora: gradient accents, custom layout, no WhatsApp clone.
class ChatHeader extends StatelessWidget {
  final String name;
  final String? avatarAsset;
  final String? avatarUrl;
  final KoraBadgeType badge;
  final bool isOnline;
  final String? lastSeen;
  final bool isTyping;
  final VoidCallback onBack;
  final VoidCallback onAvatarTap;
  final VoidCallback onVoiceCall;
  final VoidCallback onVideoCall;
  final List<KoraMenuOption> menuOptions;

  const ChatHeader({
    super.key,
    required this.name,
    this.avatarAsset,
    this.avatarUrl,
    this.badge = KoraBadgeType.none,
    this.isOnline = false,
    this.lastSeen,
    this.isTyping = false,
    required this.onBack,
    required this.onAvatarTap,
    required this.onVoiceCall,
    required this.onVideoCall,
    required this.menuOptions,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final surface = KoraColors.cardFor(brightness);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(
            color: KoraColors.borderFor(brightness),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: textPrimary, size: 24),
                onPressed: onBack,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              const SizedBox(width: 2),
              GestureDetector(
                onTap: onAvatarTap,
                child: KoraAvatar(
                  name: name,
                  assetPath: avatarAsset,
                  imageUrl: avatarUrl,
                  size: 40,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onAvatarTap,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KoraNameWithBadge(
                        name: name,
                        badge: badge,
                        badgeSize: 14,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isTyping
                            ? 'typing…'
                            : isOnline
                                ? 'online'
                                : (lastSeen ?? ''),
                        style: TextStyle(
                          color: isTyping || isOnline
                              ? KoraColors.purple
                              : textSecondary,
                          fontSize: 12.5,
                          fontWeight: isTyping || isOnline
                              ? FontWeight.w500
                              : FontWeight.w400,
                          fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.call_outlined, color: textPrimary, size: 22),
                onPressed: onVoiceCall,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              IconButton(
                icon: Icon(Icons.videocam_outlined, color: textPrimary, size: 22),
                onPressed: onVideoCall,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              IconButton(
                icon: Icon(Icons.more_vert, color: textPrimary, size: 22),
                onPressed: () => KoraMenuSheet.show(context, menuOptions),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
