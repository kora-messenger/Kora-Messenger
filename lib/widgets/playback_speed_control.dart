import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';

/// Playback Speed control — a popup menu for changing media playback speed.
/// Mirrors WhatsApp's playback speed control on videos and voice messages.
///
/// Speeds: 0.5x, 1.0x, 1.5x, 2.0x
class PlaybackSpeedControl extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedChanged;

  const PlaybackSpeedControl({
    super.key,
    required this.currentSpeed,
    required this.onSpeedChanged,
  });

  static const _speeds = [0.5, 1.0, 1.5, 2.0];

  void _showSpeedPicker(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Playback Speed',
                  style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1),
            ..._speeds.map((speed) {
              final isSelected = (currentSpeed - speed).abs() < 0.01;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_off,
                  color: isSelected ? KoraColors.purple : textMuted,
                  size: 20,
                ),
                title: Text('${speed}x',
                    style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                onTap: () {
                  onSpeedChanged(speed);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSpeedPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: KoraColors.purple.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${currentSpeed}x',
          style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
