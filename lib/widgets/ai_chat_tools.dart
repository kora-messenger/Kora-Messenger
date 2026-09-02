import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import '../services/kora_ai_service.dart';
import '../services/ai_features_service.dart';
import 'package:flutter/services.dart';

/// In-chat AI tools that appear when long-pressing a message.
/// Provides: Explain, Translate, Summarize, Rewrite, Reply, Improve
///
/// This is the "Kora AI inside normal chats" feature — contextual AI
/// assistance without leaving the conversation.
class AiChatTools {
  /// Shows the AI tools bottom sheet for a given message.
  static void show(BuildContext context, String messageText, {String? chatName}) {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Container(width: 32, height: 32,
                decoration: BoxDecoration(gradient: KoraColors.brandGradient, shape: BoxShape.circle),
                child: const Center(child: Icon(Icons.auto_awesome, color: Colors.white, size: 16))),
              const SizedBox(width: 10),
              Text('Ask Kora AI', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(icon: Icon(Icons.close, color: textMuted), onPressed: () => Navigator.pop(ctx)),
            ]),
          ),
          // Message preview
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KoraColors.purple.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(messageText, style: TextStyle(color: textMuted, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 8),
          // AI options
          _AiOption(icon: Icons.lightbulb_outline, label: 'Explain', color: KoraColors.purple,
            onTap: () { Navigator.pop(ctx); _handleAiAction(context, 'explain', messageText); }),
          _AiOption(icon: Icons.translate, label: 'Translate', color: KoraColors.blue,
            onTap: () { Navigator.pop(ctx); _handleAiAction(context, 'translate', messageText); }),
          _AiOption(icon: Icons.summarize, label: 'Summarize', color: KoraColors.purple,
            onTap: () { Navigator.pop(ctx); _handleAiAction(context, 'summarize', messageText); }),
          _AiOption(icon: Icons.edit, label: 'Rewrite', color: KoraColors.blue,
            onTap: () { Navigator.pop(ctx); _handleAiAction(context, 'rewrite', messageText); }),
          _AiOption(icon: Icons.reply, label: 'Reply', color: KoraColors.purple,
            onTap: () { Navigator.pop(ctx); _handleAiAction(context, 'reply', messageText); }),
          _AiOption(icon: Icons.auto_fix_high, label: 'Improve', color: KoraColors.blue,
            onTap: () { Navigator.pop(ctx); _handleAiAction(context, 'improve', messageText); }),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  static void _handleAiAction(BuildContext context, String action, String messageText) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
          const SizedBox(width: 12),
          Text('Kora AI is ${action == 'translate' ? 'translating' : 'processing'}…'),
        ]),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      String result = '';
      switch (action) {
        case 'explain':
          final r = await KoraAiService.instance.sendAiMessage(
            message: 'Explain this message in simple terms: "$messageText"',
            conversationId: 'in_chat_ai',
          );
          result = r.success ? r.response : r.error ?? 'Failed to explain';
        case 'translate':
          final r = await AiFeaturesService.instance.rewriteText(text: messageText, mode: 'translate_to_french');
          result = r ?? 'Translation failed';
        case 'summarize':
          final r = await AiFeaturesService.instance.summarizeChat(messages: [messageText]);
          result = r ?? 'Summarization failed';
        case 'rewrite':
          final r = await AiFeaturesService.instance.rewriteText(text: messageText);
          result = r ?? 'Rewrite failed';
        case 'reply':
          final r = await AiFeaturesService.instance.getReplySuggestions(message: messageText);
          result = r?.join('\n\n') ?? 'No suggestions';
        case 'improve':
          final r = await AiFeaturesService.instance.rewriteText(text: messageText, mode: 'improve');
          result = r ?? 'Improvement failed';
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showResult(context, action, result);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kora AI couldn\'t complete that request. Please try again.'),
            backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  static void _showResult(BuildContext context, String action, String result) {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(width: 32, height: 32,
                decoration: BoxDecoration(gradient: KoraColors.brandGradient, shape: BoxShape.circle),
                child: const Center(child: Icon(Icons.auto_awesome, color: Colors.white, size: 16))),
              const SizedBox(width: 10),
              Text('Kora AI — ${_actionLabel(action)}',
                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.copy, size: 20), onPressed: () {
                Clipboard.setData(ClipboardData(text: result));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)),
                );
              }),
            ]),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: SingleChildScrollView(child: Text(result, style: TextStyle(color: textPrimary, fontSize: 15, height: 1.5))),
            ),
            const SizedBox(height: 16),
            Row(children: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Dismiss')),
              const Spacer(),
              TextButton.icon(
                onPressed: () { Clipboard.setData(ClipboardData(text: result)); Navigator.pop(ctx); },
                icon: const Icon(Icons.copy, size: 16), label: const Text('Copy')),
            ]),
          ]),
        ),
      ),
    );
  }

  static String _actionLabel(String action) {
    switch (action) {
      case 'explain': return 'Explanation';
      case 'translate': return 'Translation';
      case 'summarize': return 'Summary';
      case 'rewrite': return 'Rewritten';
      case 'reply': return 'Reply Suggestions';
      case 'improve': return 'Improved';
      default: return 'Result';
    }
  }
}

class _AiOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AiOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(width: 36, height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Center(child: Icon(icon, color: color, size: 18))),
      title: Text(label, style: TextStyle(color: KoraColors.textPrimaryFor(Theme.of(context).brightness), fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right, color: KoraColors.textMutedFor(Theme.of(context).brightness), size: 20),
      onTap: onTap,
    );
  }
}
