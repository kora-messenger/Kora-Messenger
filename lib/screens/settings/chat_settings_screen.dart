import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../archived_chats_screen.dart';

/// Chat settings screen — archived chats and chat history.
///
/// Chat theme, wallpapers, and bubble color live under
/// Appearance → Default chat theme, so they're not duplicated here.
class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Chats',
          style: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ── ARCHIVED CHATS ──
          _sectionLabel('ARCHIVED CHATS', textMuted),
          _tile(
            context,
            icon: Icons.archive_outlined,
            title: 'Archived chats',
            subtitle: 'View chats you have archived',
            card: card,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textMuted: textMuted,
            border: border,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArchivedChatsScreen()),
            ),
          ),

          const SizedBox(height: 24),

          // ── CHAT HISTORY ──
          _sectionLabel('CHAT HISTORY', textMuted),
          _tile(
            context,
            icon: Icons.history_rounded,
            title: 'Clear all chats',
            subtitle: 'Delete all messages from all conversations',
            card: card,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textMuted: textMuted,
            border: border,
            onTap: () => _confirmClearAll(context),
            iconColor: KoraColors.red,
            titleColor: KoraColors.red,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required Color border,
    VoidCallback? onTap,
    Color iconColor = KoraColors.purple,
    Color? titleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor ?? textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right, color: textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
        title: Text(
          'Clear all chats?',
          style: TextStyle(color: KoraColors.textPrimaryFor(Theme.of(context).brightness)),
        ),
        content: Text(
          'This will permanently delete all messages from all conversations. This cannot be undone.',
          style: TextStyle(color: KoraColors.textSecondaryFor(Theme.of(context).brightness)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('All chats cleared'),
                  backgroundColor: KoraColors.purple,
                ),
              );
            },
            child: const Text('Clear', style: TextStyle(color: KoraColors.red)),
          ),
        ],
      ),
    );
  }
}
