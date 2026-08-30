import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';

/// HD Quality toggle — choose between HD and Standard quality when sending media.
/// Mirrors WhatsApp's HD photo/video quality selector.
///
/// Shows a bottom sheet with quality options and file size estimates.
class HdQualityToggle extends StatelessWidget {
  final ValueChanged<bool> onQualityChanged;

  const HdQualityToggle({super.key, required this.onQualityChanged});

  void _showQualityPicker(BuildContext context, bool currentHD) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          bool selectedHD = currentHD;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Photo Quality',
                      style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const Divider(height: 1),
                _qualityOption(
                  'HD Quality', 'Best quality • ~3-5 MB', Icons.hd,
                  selectedHD, true, textPrimary, textMuted, surface,
                  (v) => setSheetState(() => selectedHD = v),
                ),
                _qualityOption(
                  'Standard Quality', 'Good quality • ~500 KB - 1 MB', Icons.sd,
                  !selectedHD, false, textPrimary, textMuted, surface,
                  (v) => setSheetState(() => selectedHD = !v),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton(
                      onPressed: () {
                        onQualityChanged(selectedHD);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KoraColors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Apply', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _qualityOption(
    String title, String subtitle, IconData icon,
    bool isSelected, bool isHD,
    Color textPrimary, Color textMuted, Color surface,
    ValueChanged<bool> onTap,
  ) {
    return ListTile(
      leading: Icon(icon, size: 24, color: isSelected ? KoraColors.purple : textMuted),
      title: Text(title, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: textMuted, fontSize: 13)),
      trailing: Icon(isSelected ? Icons.check_circle : Icons.radio_button_off,
          color: isSelected ? KoraColors.purple : textMuted, size: 20),
      onTap: () => onTap(isHD),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
