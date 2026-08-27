import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// Call Feedback screen — rate call quality after a call ends.
/// Mirrors WhatsApp's "Rate call quality" feature.
///
/// Shows a star rating (1-5) and optional issue tags:
/// - Poor audio quality
/// - Video freezing
/// - Echo/noise
/// - Connection issues
/// - Call dropped
/// Submits feedback to SharedPreferences for later sync.
class CallFeedbackScreen extends StatefulWidget {
  final String contactName;
  final int callDuration; // in seconds
  final bool wasVideo;

  const CallFeedbackScreen({
    super.key,
    required this.contactName,
    required this.callDuration,
    this.wasVideo = false,
  });

  @override
  State<CallFeedbackScreen> createState() => _CallFeedbackScreenState();
}

class _CallFeedbackScreenState extends State<CallFeedbackScreen> {
  int _rating = 0;
  final Set<String> _selectedIssues = {};

  static const _issues = [
    ('audio', 'Poor audio quality', Icons.mic_off_outlined),
    ('video', 'Video freezing', Icons.videocam_off_outlined),
    ('echo', 'Echo or noise', Icons.graphic_eq_outlined),
    ('connection', 'Connection issues', Icons.signal_wifi_off_outlined),
    ('dropped', 'Call dropped', Icons.call_end_outlined),
    ('delay', 'High delay', Icons.access_time_outlined),
  ];

  void _submit() async {
    final prefs = await SharedPreferences.getInstance();
    final feedback = {
      'contact': widget.contactName,
      'rating': _rating,
      'issues': _selectedIssues.toList(),
      'duration': widget.callDuration,
      'wasVideo': widget.wasVideo,
      'timestamp': DateTime.now().toIso8601String(),
    };
    // Store in a list of feedback entries
    final existing = prefs.getStringList('kora_call_feedback') ?? [];
    existing.add(feedback.toString());
    await prefs.setStringList('kora_call_feedback', existing);

    if (mounted) Navigator.pop(context);
  }

  String get _durationText {
    final m = (widget.callDuration / 60).floor();
    final s = widget.callDuration % 60;
    return '${m}m ${s}s';
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
        title: Text('Call Feedback',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.close, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Contact info
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [KoraColors.purple, KoraColors.blue]),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.contactName.isNotEmpty
                      ? widget.contactName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(widget.contactName,
                style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${_durationText} • ${widget.wasVideo ? "Video" : "Voice"} call',
                style: TextStyle(color: textMuted, fontSize: 13)),

            const SizedBox(height: 32),

            // Star rating
            Text('How was the call quality?',
                style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final star = index + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = star),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      star <= _rating ? Icons.star : Icons.star_border,
                      size: 40,
                      color: star <= _rating ? KoraColors.purple : textMuted,
                    ),
                  ),
                );
              }),
            ),

            if (_rating > 0 && _rating <= 3) ...[
              const SizedBox(height: 32),
              Text('What went wrong?',
                  style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _issues.map((issue) {
                  final isSelected = _selectedIssues.contains(issue.$1);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedIssues.remove(issue.$1);
                        } else {
                          _selectedIssues.add(issue.$1);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? KoraColors.purple.withValues(alpha: 0.15)
                            : surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? KoraColors.purple
                              : KoraColors.borderFor(brightness),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(issue.$3, size: 16,
                              color: isSelected ? KoraColors.purple : textMuted),
                          const SizedBox(width: 6),
                          Text(issue.$2,
                              style: TextStyle(
                                  color: isSelected ? KoraColors.purple : textPrimary,
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _rating > 0 ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _rating > 0 ? KoraColors.purple : surface,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Submit Feedback',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _rating > 0 ? Colors.white : textMuted),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Skip', style: TextStyle(color: textMuted, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
