import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/kora_colors.dart';
import '../theme/chat_theme_provider.dart';
import '../widgets/new_user_welcome_popup.dart';
import '../services/session_manager.dart';
import '../services/chat_sync_service.dart';
import 'home/calls_tab.dart';
import 'home/channels_tab.dart';
import 'home/chats_tab.dart';
import 'home/profile_tab.dart';
import 'home/status_tab.dart';
import '../services/permission_service.dart';

/// Main Kora experience — hosts the bottom navigation and a
/// horizontally swipeable [PageView] that lets the user scroll
/// between Chats, Calls, Status, Community, and Profile.
///
/// Swiping left/right changes the active tab; tapping a nav item
/// animates the page to that tab. Both stay in sync.
class KoraHomeScreen extends StatefulWidget {
  final bool isNewUser;

  const KoraHomeScreen({super.key, this.isNewUser = false});

  @override
  State<KoraHomeScreen> createState() => _KoraHomeScreenState();
}

class _KoraHomeScreenState extends State<KoraHomeScreen> {
  late final PageController _pageController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    // Ask for essential permissions once on first Home visit.
    KoraPermissionService.requestEssentialOnce();
    // Start polling for incoming messages (if not already running).
    ChatSyncService.instance.startPolling();
    // Show the new-user welcome popup if this is a first-time visitor.
    if (widget.isNewUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWelcomePopup();
      });
    }
  }

  @override
  void dispose() {
    ChatSyncService.instance.stopPolling();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _showWelcomePopup() async {
    if (!mounted) return;

    // Per-account flag so the popup only shows once per user.
    final prefs = await SharedPreferences.getInstance();
    final session = await SessionManager.instance.loadSession();
    final email = session?['email'] as String? ?? '';
    final popupKey = 'kora_welcome_popup_shown_$email';
    if (prefs.getBool(popupKey) == true) return;

    await prefs.setBool(popupKey, true);

    if (!mounted) return;

    final userName = (session?['fullName'] as String?) ?? '';
    if (mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          barrierDismissible: false,
          pageBuilder: (context, animation, secondaryAnimation) =>
              NewUserWelcomePopup(userFullName: userName),
        ),
      );
    }
  }

  void _goToProfile() => _goToTab(4);
  void _goToChannels() => _goToTab(3);

  /// Jump to a tab programmatically (used by child tabs that need
  /// to navigate the user to another section).
  /// Jump to a tab instantly — used by nav bar taps so they feel
  /// the same as before the swipe feature was added.
  void _goToTab(int index) {
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    final pages = [
      ChatsTab(onProfileTap: _goToProfile, onGoToChannels: _goToChannels),
      const CallsTab(),
      const StatusTab(),
      const ChannelsTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: bg,
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) => setState(() => _tabIndex = index),
        children: pages,
      ),
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
                _navItem(3, Icons.groups_outlined, Icons.groups, 'Community', textSecondary),
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
        onTap: () => _goToTab(index),
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
