import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/kora_colors.dart';
import '../theme/chat_theme_provider.dart';
import '../widgets/new_user_welcome_popup.dart';
import '../services/session_manager.dart';
import '../services/chat_sync_service.dart';
import '../services/service_notification_service.dart';
import 'home/calls_tab.dart';
import 'home/chats_tab.dart';
import 'home/status_tab.dart';
import 'home/channels_tab.dart';
import 'home/profile_tab.dart';
import '../services/permission_service.dart';

/// Main Kora experience — hosts the bottom navigation with 4 tabs
/// matching WhatsApp's 2026 layout:
///   Chats → Updates (Status + Channels) → Communities → Calls
///
/// Settings is accessed via the 3-dot menu on the Chats tab (like WhatsApp).
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
    KoraPermissionService.requestEssentialOnce();
    ChatSyncService.instance.startPolling();
    ServiceNotificationService.instance.init();
    if (widget.isNewUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWelcomePopup();
      });
    }
  }

  @override
  void dispose() {
    ChatSyncService.instance.stopPolling();
    ServiceNotificationService.instance.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _showWelcomePopup() async {
    if (!mounted) return;
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

  void _goToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileTab()),
    );
  }

  void _goToUpdates() => _goToTab(1);
  void _goToCommunities() => _goToTab(2);

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
      ChatsTab(onSettingsTap: _goToSettings, onGoToUpdates: _goToUpdates),
      const StatusTab(),
      const ChannelsTab(),
      const CallsTab(),
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
                _navItem(1, Icons.update_outlined, Icons.update, 'Updates', textSecondary),
                _navItem(2, Icons.groups_outlined, Icons.groups, 'Communities', textSecondary),
                _navItem(3, Icons.call_outlined, Icons.call, 'Calls', textSecondary),
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
