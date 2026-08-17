import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import 'home/calls_tab.dart';
import 'home/channels_tab.dart';
import 'home/chats_tab.dart';
import 'home/profile_tab.dart';
import 'home/status_tab.dart';

/// Main Kora experience — hosts the bottom navigation and switches
/// between Chats, Calls, Status, Channels, and Profile.
class KoraHomeScreen extends StatefulWidget {
  const KoraHomeScreen({super.key});

  @override
  State<KoraHomeScreen> createState() => _KoraHomeScreenState();
}

class _KoraHomeScreenState extends State<KoraHomeScreen> {
  int _tabIndex = 0;

  void _goToProfile() => setState(() => _tabIndex = 4);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    final tabs = [
      ChatsTab(onProfileTap: _goToProfile),
      const CallsTab(),
      const StatusTab(),
      const ChannelsTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: bg,
      body: IndexedStack(index: _tabIndex, children: tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: card,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                _navItem(0, Icons.chat_bubble_outline, Icons.chat_bubble, 'Chats', textSecondary),
                _navItem(1, Icons.call_outlined, Icons.call, 'Calls', textSecondary),
                _navItem(2, Icons.donut_large_outlined, Icons.donut_large, 'Status', textSecondary),
                _navItem(3, Icons.campaign_outlined, Icons.campaign, 'Channels', textSecondary),
                _navItem(4, Icons.person_outline, Icons.person, 'Profile', textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    int index,
    IconData outlineIcon,
    IconData filledIcon,
    String label,
    Color inactiveColor,
  ) {
    final isSelected = _tabIndex == index;
    final color = isSelected ? KoraColors.purple : inactiveColor;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected ? KoraColors.purple.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isSelected ? filledIcon : outlineIcon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
