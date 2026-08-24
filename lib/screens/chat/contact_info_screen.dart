import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/kora_colors.dart';
import '../../models/chat_models.dart';
import '../../widgets/kora_avatar.dart';
import '../../widgets/kora_badge.dart';
import '../../widgets/secure_screen.dart';
import 'kora_chat_screen.dart';

/// Full-screen contact info — opens when the user taps the avatar or
/// name in a chat. Shows a large circular profile photo centered near
/// the top of the screen, followed by the contact's username and Kora ID.
///
/// Screenshot-protected via FLAG_SECURE on Android.
class ContactInfoScreen extends StatelessWidget {
  final String name;
  final String? avatarAsset;
  final String? avatarUrl;
  final KoraBadgeType badge;
  final bool isOnline;
  final String? lastSeen;
  final String? koraId;
  final String? username;
  final String? about;
  final String? phone;

  const ContactInfoScreen({
    super.key,
    required this.name,
    this.avatarAsset,
    this.avatarUrl,
    this.badge = KoraBadgeType.none,
    this.isOnline = false,
    this.lastSeen,
    this.koraId,
    this.username,
    this.about,
    this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return SecureScreen(
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──
              _buildTopBar(context, textPrimary),
              // ── Scrollable content ──
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Large circular profile avatar centered
                      KoraAvatar(
                        name: name,
                        assetPath: avatarAsset,
                        imageUrl: avatarUrl,
                        size: 120,
                        showOnlineDot: isOnline,
                      ),
                      const SizedBox(height: 16),
                      // Name with badge
                      KoraNameWithBadge(
                        name: name,
                        badge: badge,
                        badgeSize: 22,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Username
                      if (username != null)
                        GestureDetector(
                          onLongPress: () => _copyToClipboard(context, '@${username!}', 'Username'),
                          child: Text(
                            '@$username',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      // Kora ID
                      if (koraId != null)
                        GestureDetector(
                          onLongPress: () => _copyToClipboard(context, koraId!, 'Kora ID'),
                          child: Text(
                            koraId!,
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Online status
                      Text(
                        isOnline ? 'online' : (lastSeen ?? 'last seen recently'),
                        style: TextStyle(
                          color: isOnline ? KoraColors.purple : textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 28),
                      // ── Info section ──
                      _infoSection(card, textPrimary, textSecondary, border),
                      const SizedBox(height: 16),
                      // ── Action row ──
                      _actionRow(context, card, textPrimary, textSecondary, border),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Color textPrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: textPrimary, size: 24),
            onPressed: () => Navigator.pop(context),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.more_vert, color: textPrimary, size: 22),
            onPressed: () {},
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(Color card, Color textPrimary, Color textSecondary, Color border) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          if (about != null)
            _infoTile(Icons.info_outline, 'About', about!, textPrimary, textSecondary, border),
          if (phone != null)
            _infoTile(Icons.phone_outlined, 'Phone', phone!, textPrimary, textSecondary, border),
          if (username != null)
            _infoTile(Icons.alternate_email, 'Username', '@$username', textPrimary, textSecondary, border, isCopyable: true, copyLabel: 'Username'),
          if (koraId != null)
            _infoTile(Icons.badge_outlined, 'Kora ID', koraId!, textPrimary, textSecondary, border, isLast: true, isCopyable: true, copyLabel: 'Kora ID'),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, Color textPrimary, Color textSecondary, Color border, {bool isLast = false, bool isCopyable = false, String? copyLabel}) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: KoraColors.purple, size: 22),
          title: Text(label, style: TextStyle(color: textSecondary, fontSize: 13)),
          subtitle: Text(value, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
          onLongPress: isCopyable
              ? () => _copyToClipboard(context, value, copyLabel ?? label)
              : null,
        ),
        if (!isLast) Divider(height: 1, indent: 56, color: border),
      ],
    );
  }

  void _copyToClipboard(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _actionRow(BuildContext context, Color card, Color textPrimary, Color textSecondary, Color border) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _actionCard(
              card, textPrimary, textSecondary, border,
              Icons.chat_bubble_outline, 'Message',
              () {
                final chatId = (koraId != null && koraId!.isNotEmpty)
                    ? koraId!
                    : (username ?? phone ?? name);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => KoraChatScreen(
                      chatId: chatId,
                      name: name,
                      avatarUrl: avatarUrl,
                      badge: badge,
                      isOnline: isOnline,
                      lastSeen: lastSeen,
                    ),
                  ),
                );
              },
            ),
          ),
          [
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                card, textPrimary, textSecondary, border,
                Icons.call_outlined, 'Call',
                () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                card, textPrimary, textSecondary, border,
                Icons.videocam_outlined, 'Video',
                () => Navigator.pop(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionCard(Color card, Color textPrimary, Color textSecondary, Color border, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: KoraColors.purple, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
