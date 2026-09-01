import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import '../models/poll_model.dart';

/// Poll widget — renders a poll in the chat with options, vote counts,
/// and tap-to-vote. Matches WhatsApp's poll UI.
///
/// Features:
/// - Question at the top
/// - Options with radio/checkbox indicators
/// - Vote bars showing percentage
/// - Total voter count at the bottom
/// - Tap an option to vote/unvote
class PollWidget extends StatefulWidget {
  final PollMessage poll;
  final String currentUserId;
  final bool isMe;
  final ValueChanged<PollMessage> onVote;

  const PollWidget({
    super.key,
    required this.poll,
    required this.currentUserId,
    required this.isMe,
    required this.onVote,
  });

  @override
  State<PollWidget> createState() => _PollWidgetState();
}

class _PollWidgetState extends State<PollWidget> {
  late PollMessage _poll;

  @override
  void initState() {
    super.initState();
    _poll = widget.poll;
  }

  void _toggleVote(String optionId) {
    final hasVoted = _poll.hasVoted(optionId, widget.currentUserId);
    if (hasVoted) {
      _poll = _poll.removeVote(optionId, widget.currentUserId);
    } else {
      _poll = _poll.castVote(optionId, widget.currentUserId);
    }
    widget.onVote(_poll);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poll question
          Text(
            _poll.question,
            style: TextStyle(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Options
          ..._poll.options.map((option) => _buildOption(option)),

          const SizedBox(height: 8),

          // Footer: voter count
          Row(
            children: [
              Icon(Icons.how_to_vote, size: 13, color: textMuted),
              const SizedBox(width: 4),
              Text(
                '${_poll.totalVoters} ${_poll.totalVoters == 1 ? "vote" : "votes"}',
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
              const Spacer(),
              Icon(
                _poll.allowMultipleAnswers
                    ? Icons.check_box_outline_blank
                    : Icons.radio_button_off,
                size: 13,
                color: textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                _poll.allowMultipleAnswers ? 'Multiple' : 'Single',
                style: TextStyle(color: textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOption(PollOption option) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final hasVoted = _poll.hasVoted(option.id, widget.currentUserId);
    final count = _poll.voteCount(option.id);
    final percent = _poll.votePercentage(option.id);
    final showResults = _poll.totalVoters > 0;

    return GestureDetector(
      onTap: () => _toggleVote(option.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _poll.allowMultipleAnswers
                      ? (hasVoted ? Icons.check_box : Icons.check_box_outline_blank)
                      : (hasVoted ? Icons.radio_button_checked : Icons.radio_button_off),
                  size: 18,
                  color: hasVoted ? KoraColors.purple : textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    option.text,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: hasVoted ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (showResults)
                  Text(
                    '${percent.round()}%',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            if (showResults) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 4,
                  backgroundColor: textMuted.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    hasVoted ? KoraColors.purple : textMuted.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}
