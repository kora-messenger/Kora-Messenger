import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_avatar.dart';
import '../../widgets/kora_badge.dart';
import '../../models/chat_models.dart';
import '../../theme/chat_theme_provider.dart';
import '../../services/session_manager.dart';
import '../settings/appearance_screen.dart';
import '../settings/account_screen.dart';
import '../settings/translation_settings_screen.dart';
import '../settings/voice_media_settings_screen.dart';
import '../settings/privacy_screen.dart';
import '../settings/edit_profile_screen.dart';
import '../settings/chat_settings_screen.dart';
import '../settings/notifications_settings_screen.dart';
import '../settings/about_kora_screen.dart';
import '../settings/business_tools_screen.dart';
import '../settings/future_features_screen.dart';
import '../settings/premium_subscribe_sheet.dart';
import '../settings/storage_data_screen.dart';
import '../settings/app_language_screen.dart';
import '../ai/kora_support_screen.dart';
import '../search_screen.dart';
import '../contacts/qr_code_screen.dart';

/// "Profile" tab — the user's own profile summary plus settings shortcuts.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _session;
  bool _loading = true;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await SessionManager.instance.loadSession();
    if (mounted) {
      setState(() {
        _session = session;
        _isPremium = ChatThemeProvider.instance.isPremium;
        _loading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ChatThemeProvider.instance.addListener(_onPremiumChanged);
  }

  @override
  void dispose() {
    ChatThemeProvider.instance.removeListener(_onPremiumChanged);
    super.dispose();
  }

  void _onPremiumChanged() {
    if (mounted) {
      setState(() => _isPremium = ChatThemeProvider.instance.isPremium);
    }
  }

  void _showQrCode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrCodeScreen()),
    );
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  void _openEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    ).then((_) => _loadSession());
  }

  void _openPremium() {
    if (_isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You are already a Kora Premium member'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PremiumSubscribeSheet(),
    );
  }

  void _openKoraSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KoraSupportScreen()),
    );
  }

  void _openAbout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AboutKoraScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    final fullName = _session?['fullName']?.toString() ?? 'Kora User';
    final username = _session?['username']?.toString() ?? 'user';
    final koraId = _session?['koraId']?.toString() ?? '';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Profile',
          style: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: textPrimary, size: 22),
            onPressed: _openSearch,
          ),
          IconButton(
            icon: Icon(Icons.qr_code_scanner_rounded, color: textPrimary, size: 22),
            onPressed: _showQrCode,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // Profile card — tappable to edit
            GestureDetector(
              onTap: _openEditProfile,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: KoraColors.purple),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          KoraAvatar(name: fullName, size: 62),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                KoraNameWithBadge(
                                  name: fullName,
                                  badge: ChatThemeProvider.instance.isOwnerAccount
                                      ? KoraBadgeType.officialPurple
                                      : (_isPremium ? KoraBadgeType.premiumBlue : KoraBadgeType.none),
                                  badgeSize: 25,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '@$username',
                                  style: TextStyle(color: textSecondary, fontSize: 13.5),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  koraId.isNotEmpty ? koraId : 'Tap to view your Kora ID',
                                  style: TextStyle(color: textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit_rounded, color: KoraColors.purple, size: 20),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // ── ACCOUNT section ──
            _sectionLabel('ACCOUNT', textMuted),
            _accountTile(context),
            _navTile(
              context,
              icon: Icons.privacy_tip_outlined,
              iconColor: KoraColors.purple,
              title: 'Privacy',
              subtitle: 'Last seen, read receipts, blocked contacts, app lock',
              screen: const PrivacyScreen(),
            ),
            _navTile(
              context,
              icon: Icons.chat_bubble_outline,
              title: 'Chats',
              subtitle: 'Display, archived chats, history, media, backup',
              screen: const ChatSettingsScreen(),
            ),
            _appearanceTile(context),
            _navTile(
              context,
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Message, group & call tones',
              screen: const NotificationsSettingsScreen(),
            ),
            _navTile(
              context,
              icon: Icons.storage_outlined,
              iconColor: KoraColors.purple,
              title: 'Storage and data',
              subtitle: 'Manage storage, network usage, auto-download',
              screen: const StorageDataScreen(),
            ),
            _navTile(
              context,
              icon: Icons.language_outlined,
              iconColor: KoraColors.purple,
              title: 'App language',
              subtitle: 'Language for Kora Messenger',
              screen: const AppLanguageScreen(),
            ),
            _navTile(
              context,
              icon: Icons.store_outlined,
              iconColor: KoraColors.purple,
              title: 'Business Tools',
              subtitle: 'Catalog, quick replies, labels, orders',
              screen: const BusinessToolsScreen(),
            ),
            const SizedBox(height: 20),

            // ── TRANSLATION & MEDIA section ──
            _sectionLabel('TRANSLATION & MEDIA', textMuted),
            _navTile(
              context,
              icon: Icons.translate_rounded,
              iconColor: KoraColors.purple,
              title: 'Translation',
              subtitle: 'Preferred language, auto-translate, voice notes',
              screen: const TranslationSettingsScreen(),
            ),
            _navTile(
              context,
              icon: Icons.graphic_eq_rounded,
              iconColor: KoraColors.purple,
              title: 'Voice & Media',
              subtitle: 'Upload your own audio or video',
              screen: const VoiceMediaSettingsScreen(),
            ),
            const SizedBox(height: 20),

            // ── KORA section ──
            _sectionLabel('KORA', textMuted),
            _tile(
              context,
              _isPremium ? Icons.workspace_premium : Icons.workspace_premium_outlined,
              'Kora Premium',
              _isPremium ? 'Premium active' : 'Unlock premium features',
              onTap: _openPremium,
            ),
            _tile(
              context,
              Icons.support_agent_outlined,
              'Kora Support',
              'Get help from the Kora team',
              onTap: _openKoraSupport,
            ),
            _tile(
              context,
              Icons.info_outline,
              'About Kora',
              'App version, terms & privacy',
              onTap: _openAbout,
            ),
            _navTile(
              context,
              icon: Icons.rocket_launch_outlined,
              iconColor: KoraColors.purple,
              title: 'Future Features',
              subtitle: 'AI image gen, AI stickers, Wear OS, Android Auto',
              screen: const FutureFeaturesScreen(),
            ),
            const SizedBox(height: 20),

            // ── Invite a friend ──
            _tile(
              context,
              Icons.person_add_outlined,
              'Invite a friend',
              'Share Kora Messenger with your contacts',
              onTap: _inviteFriend,
            ),
          ],
        ),
      ),
    );
  }

  void _inviteFriend() {
    const inviteText = 'Hey! I\'m using Kora Messenger — a secure, AI-powered messaging app. '
        'Download it and let\'s chat! https://app.base44.com/superagent/6a8225cb1baabb64463874c8';
    // Copy to clipboard for sharing
    Clipboard.setData(const ClipboardData(text: inviteText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _accountTile(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountScreen()),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KoraColors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_outline, color: KoraColors.purple, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Security, username, phone number',
                      style: TextStyle(color: textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: KoraColors.textMutedFor(brightness)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appearanceTile(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AppearanceScreen()),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KoraColors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.palette_outlined, color: KoraColors.purple, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chat theme, app icon, app theme',
                      style: TextStyle(color: textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KoraColors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: KoraColors.purple, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    Color iconColor = KoraColors.purple,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
