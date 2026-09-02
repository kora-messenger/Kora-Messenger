import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../theme/kora_colors.dart';

/// Input composer for AI chat — text input, voice button, send button.
class AIComposer extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isGenerating;
  final VoidCallback onSend;
  final VoidCallback onVoiceInput;
  final VoidCallback onStop;

  const AIComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isGenerating,
    required this.onSend,
    required this.onVoiceInput,
    required this.onStop,
  });

  @override
  State<AIComposer> createState() => _AIComposerState();
}

class _AIComposerState extends State<AIComposer> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return SafeArea(child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: surface, border: Border(top: BorderSide(color: textMuted.withValues(alpha: 0.1)))),
      child: Row(children: [
        GestureDetector(
          onLongPress: kIsWeb ? null : widget.onVoiceInput,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: KoraColors.purple.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.mic, color: KoraColors.purple, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24),
            border: Border.all(color: textMuted.withValues(alpha: 0.15))),
          child: TextField(
            controller: widget.controller, focusNode: widget.focusNode,
            style: TextStyle(color: textPrimary, fontSize: 15),
            minLines: 1, maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Ask Kora AI…',
              hintStyle: TextStyle(color: textMuted, fontSize: 15),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onSubmitted: (_) => widget.onSend(),
          ),
        )),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: widget.isGenerating ? widget.onStop : widget.onSend,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: widget.isGenerating ? null : KoraColors.brandGradient,
              color: widget.isGenerating ? Colors.red.withValues(alpha: 0.1) : null,
              shape: BoxShape.circle,
            ),
            child: Center(child: Icon(
              widget.isGenerating ? Icons.stop : Icons.send,
              color: widget.isGenerating ? Colors.red : Colors.white, size: 20,
            )),
          ),
        ),
      ]),
    ));
  }
}
