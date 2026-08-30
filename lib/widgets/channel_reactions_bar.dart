import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';

/// Channel Reactions Bar — shows reaction counts on channel posts.
/// Mirrors WhatsApp's channel post reactions.
///
/// In WhatsApp channels, followers can react with emoji to posts.
/// Shows top 3 reactions with counts, and a "react" button.
class ChannelReactionsBar extends StatefulWidget {
  final Map<String, int> reactions; // emoji → count
  final ValueChanged<String> onReact;

  const ChannelReactionsBar({
    super.key,
    required this.reactions,
    required this.onReact,
  });

  @override
  State<ChannelReactionsBar> createState() => _ChannelReactionsBarState();
}

class _ChannelReactionsBarState extends State<ChannelReactionsBar>
    with SingleTickerProviderStateMixin {
  bool _showPicker = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  static const _reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _togglePicker() {
    if (_showPicker) {
      _animController.reverse().then((_) => setState(() => _showPicker = false));
    } else {
      setState(() => _showPicker = true);
      _animController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    // Sort reactions by count, take top 3
    final sorted = widget.reactions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topReactions = sorted.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reaction chips
        Row(
          children: [
            ...topReactions.map((entry) => _reactionChip(entry.key, entry.value, surface)),
            if (topReactions.isEmpty)
              GestureDetector(
                onTap: _togglePicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_reaction_outlined, size: 16, color: textMuted),
                      const SizedBox(width: 4),
                      Text('React', style: TextStyle(color: textMuted, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            const SizedBox(width: 8),
            // React button
            GestureDetector(
              onTap: _togglePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.emoji_emotions_outlined, size: 18, color: textMuted),
              ),
            ),
          ],
        ),
        // Emoji picker popup
        if (_showPicker) ...[
          const SizedBox(height: 8),
          ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _reactionEmojis.map((emoji) => GestureDetector(
                  onTap: () {
                    widget.onReact(emoji);
                    _togglePicker();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                )).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _reactionChip(String emoji, int count, Color surface) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(
            count > 999 ? '${(count / 1000).toStringAsFixed(1)}K' : count.toString(),
            style: TextStyle(color: KoraColors.purple, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
