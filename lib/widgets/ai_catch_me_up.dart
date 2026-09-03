import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/kora_colors.dart';
import '../services/ai_features_service.dart';
import '../models/message_model.dart';

/// "Catch Me Up" — AI-powered summary of unread messages in a chat.
/// Shows when opening a chat with many unread messages.
///
/// Accessible via:
/// - Chat options menu → "✨ Catch me up"
/// - Auto-prompt when opening a chat with >20 unread messages
class AiCatchMeUp extends StatelessWidget {
  final List<KoraMessage> messages;
  final String chatName;

  const AiCatchMeUp({super.key, required this.messages, required this.chatName});

  /// Shows the catch-me-up sheet
  static Future<void> show(BuildContext context, List<KoraMessage> messages, String chatName) async {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    // Show loading state first
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          String result = '';
          bool loading = true;
          String? error;

          if (loading && result.isEmpty && error == null) {
            // Trigger AI summary
            final messageMaps = messages
                .map((m) => {
                      'text': m.text,
                      'isMe': m.isMe,
                      'senderName': m.isMe ? 'You' : (m.isAi ? 'Kora AI' : chatName),
                    })
                .toList();
            AiFeaturesService.instance.summarizeChat(messageMaps).then((summary) {
              if (summary != null) {
                setState(() { result = summary; loading = false; });
              } else {
                setState(() { error = 'Could not generate summary. Please try again.'; loading = false; });
              }
            }).catchError((e) {
              setState(() { error = 'Kora AI is unavailable right now.'; loading = false; });
            });
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(gradient: KoraColors.brandGradient, shape: BoxShape.circle),
                      child: const Center(child: Icon(Icons.auto_awesome, color: Colors.white, size: 18))),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Catch Me Up — $chatName',
                      style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700))),
                    IconButton(icon: Icon(Icons.close, color: textMuted), onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const SizedBox(height: 16),
                  if (loading)
                    Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(children: [
                      CircularProgressIndicator(color: KoraColors.purple),
                      const SizedBox(height: 16),
                      Text('Analyzing ${messages.length} messages…', style: TextStyle(color: textMuted, fontSize: 14)),
                    ])))
                  else if (error != null)
                    Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
                      Icon(Icons.error_outline, color: Colors.red.withValues(alpha: 0.5), size: 40),
                      const SizedBox(height: 12),
                      Text(error!, style: TextStyle(color: textMuted, fontSize: 14), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                    ])))
                  else ...[
                    // Summary content
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: KoraColors.purple.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(result, style: TextStyle(color: textPrimary, fontSize: 15, height: 1.5)),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Dismiss')),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () { Clipboard.setData(ClipboardData(text: result)); Navigator.pop(ctx); },
                        icon: const Icon(Icons.copy, size: 16), label: const Text('Copy')),
                    ]),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
