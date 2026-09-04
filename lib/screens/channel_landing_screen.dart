import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import 'new_community_screen.dart';

/// Channel landing screen — entry point for creating a community.
/// Shows a premium intro with a "Get Started" button that starts
/// the New Community flow.
class ChannelLandingScreen extends StatefulWidget {
  const ChannelLandingScreen({super.key});

  @override
  State<ChannelLandingScreen> createState() => _ChannelLandingScreenState();
}

class _ChannelLandingScreenState extends State<ChannelLandingScreen> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: textPrimary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text('Communities',
                      style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            // Center content
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Community icon
                      Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(
                          gradient: KoraColors.brandGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: KoraColors.purple.withValues(alpha: 0.3), blurRadius: 32, offset: const Offset(0, 12)),
                          ],
                        ),
                        child: const Icon(Icons.groups_rounded, color: Colors.white, size: 44),
                      ),
                      const SizedBox(height: 28),
                      Text('Create a new community',
                          style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      const SizedBox(height: 12),
                      Text('Bring people together around topics you care about. Organize multiple groups under one community, share announcements, and keep conversations structured.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textSecondary, fontSize: 15, height: 1.5)),
                      const SizedBox(height: 40),
                      // Feature highlights
                      _featureRow(Icons.campaign_outlined, 'Announcement group for updates'),
                      const SizedBox(height: 16),
                      _featureRow(Icons.group_outlined, 'Organize up to 50 groups'),
                      const SizedBox(height: 16),
                      _featureRow(Icons.link, 'Invite members via shareable link'),
                      const SizedBox(height: 40),
                      // Get Started button
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const NewCommunityScreen()),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: KoraColors.brandGradient,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(color: KoraColors.purple.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Center(
                            child: Text('Get started',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: KoraColors.purple, size: 20),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
