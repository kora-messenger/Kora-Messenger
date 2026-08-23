import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_empty_state.dart';

/// "Community" tab — placeholder until communities/broadcast are built.
class ChannelsTab extends StatelessWidget {
  const ChannelsTab({super.key});

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
                    'Community',
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
                icon: Icons.campaign_outlined,
                title: 'No channels yet',
                message: 'Follow channels from Kora and creators to see updates here.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
