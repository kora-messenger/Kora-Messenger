import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_empty_state.dart';

/// "Status" tab — placeholder until status/stories are built.
class StatusTab extends StatelessWidget {
  const StatusTab({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Status',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: KoraEmptyState(
                icon: Icons.donut_large_outlined,
                title: 'No status updates',
                message: 'Share a photo, video, or text update that disappears after 24 hours.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
