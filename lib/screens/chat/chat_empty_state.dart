import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/kora_colors.dart';
import '../../config/kora_api.dart';

/// Shown when a conversation has no messages yet.
/// Displays a WhatsApp-style E2EE encryption notice with a date pill,
/// followed by a soft call-to-action to start the conversation.
class ChatEmptyState extends StatelessWidget {
  final String name;
  final bool isOfficial;

  const ChatEmptyState({
    super.key,
    required this.name,
    this.isOfficial = false,
  });

  String _todayLabel() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Date pill ──
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: KoraColors.cardFor(brightness).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                _todayLabel(),
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // ── E2EE encryption notice bubble ──
            Container(
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: brightness == Brightness.dark
                    ? const Color(0xFF1A2332).withValues(alpha: 0.95)
                    : const Color(0xFFFFF4D6).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock,
                    size: 14,
                    color: brightness == Brightness.dark
                        ? const Color(0xFF8E9AAE)
                        : const Color(0xFF6B6759),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          color: brightness == Brightness.dark
                              ? const Color(0xFFB4BECC)
                              : const Color(0xFF6B6759),
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Messages and calls are end-to-end encrypted. No one outside this chat, not even Kora, can read or listen to them. ',
                          ),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () async {
                                final url = Uri.parse(KoraApi.e2eePolicyUrl);
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Text(
                                'Learn more',
                                style: TextStyle(
                                  color: brightness == Brightness.dark
                                      ? const Color(0xFF6B9BD8)
                                      : const Color(0xFF3B6BA5),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: brightness == Brightness.dark
                                      ? const Color(0xFF6B9BD8)
                                      : const Color(0xFF3B6BA5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Friendly call-to-action ──
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    KoraColors.purple.withValues(alpha: 0.14),
                    KoraColors.purple.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: KoraColors.purple.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isOfficial ? Icons.support_agent : Icons.waving_hand_outlined,
                    color: KoraColors.purple,
                    size: 26,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isOfficial ? 'Start a conversation' : 'Say hi to $name',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOfficial
                  ? 'Send a message below to get started. $name is here to help.'
                  : 'Send your first message to begin this conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
