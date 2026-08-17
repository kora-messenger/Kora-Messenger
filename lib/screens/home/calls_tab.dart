import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_empty_state.dart';

/// "Calls" tab — placeholder until voice/video calling is built.
class CallsTab extends StatelessWidget {
  const CallsTab({super.key});

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
                    'Calls',
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
                icon: Icons.call_outlined,
                title: 'No calls yet',
                message: 'Voice and video calls with your contacts will show up here.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
