import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Report screen — report a message or user to moderation.
/// Includes reason categories and optional "also block" option.
/// Mirrors WhatsApp's Report flow.
class ReportScreen extends StatefulWidget {
  final String userName;
  final String? messageId;

  const ReportScreen({
    super.key,
    required this.userName,
    this.messageId,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? _selectedReason;
  final _detailsController = TextEditingController();
  bool _alsoBlock = false;

  static final _reasons = [
    ('spam', 'Spam', Icons.report),
    ('harassment', 'Harassment or bullying', Icons.report_problem_outlined),
    ('fake_account', 'Fake account', Icons.person_off_outlined),
    ('scam', 'Scam or fraud', Icons.security_outlined),
    ('inappropriate', 'Inappropriate content', Icons.visibility_off_outlined),
    ('hate_speech', 'Hate speech', Icons.block_outlined),
    ('violence', 'Violence or harm', Icons.dangerous_outlined),
    ('other', 'Other', Icons.more_horiz),
  ];

  void _submit() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_alsoBlock
            ? '${widget.userName} has been reported and blocked'
            : '${widget.userName} has been reported'),
        backgroundColor: KoraColors.purple,
      ),
    );
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Report ${widget.userName}',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Why are you reporting this contact?',
              style: TextStyle(color: textMuted, fontSize: 14),
            ),
          ),
          ..._reasons.map((reason) {
            final isSelected = _selectedReason == reason.$1;
            return ListTile(
              leading: Icon(reason.$3,
                  size: 22,
                  color: isSelected ? KoraColors.purple : textMuted),
              title: Text(reason.$2,
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: KoraColors.purple, size: 20)
                  : Icon(Icons.radio_button_off, color: textMuted, size: 20),
              onTap: () => setState(() => _selectedReason = reason.$1),
            );
          }),

          // Additional details
          if (_selectedReason != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _detailsController,
                maxLines: 3,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Add details (optional)…',
                  hintStyle: TextStyle(color: textMuted),
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],

          // Block option
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.block, size: 20, color: Colors.red.shade400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Also block ${widget.userName}',
                            style: TextStyle(
                                color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                        Text('Blocked contacts cannot send you messages or calls.',
                            style: TextStyle(color: textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _alsoBlock,
                    onChanged: (v) => setState(() => _alsoBlock = v),
                    activeColor: KoraColors.purple,
                  ),
                ],
              ),
            ),
          ),

          // Submit button
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedReason != null ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedReason != null
                      ? (_alsoBlock ? Colors.red.shade600 : KoraColors.purple)
                      : KoraColors.surfaceFor(brightness),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _alsoBlock ? 'Report & Block' : 'Report',
                  style: TextStyle(
                    color: _selectedReason != null
                        ? Colors.white
                        : textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
