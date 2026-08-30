import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/kora_colors.dart';
import '../../models/chat_models.dart';
import '../../widgets/kora_avatar.dart';
import '../../widgets/kora_badge.dart';
import '../../widgets/secure_screen.dart';
import 'kora_chat_screen.dart';
import 'disappearing_messages_screen.dart';
import 'e2ee_verification_screen.dart';
import '../settings/default_chat_theme_screen.dart';
import '../../utils/kora_page_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Full-screen contact info — opens when the user taps the avatar or
/// name in a chat. Mirrors WhatsApp's Contact Info screen.
///
/// Layout (top to bottom):
/// 1. Top bar: back + 3-dot menu (Share, Block, Report)
/// 2. Large profile photo
/// 3. Name + badge, username, Kora ID, online status
/// 4. Action row: Message, Call, Video, Search
/// 5. About section
/// 6. Media, links, and docs (count)
/// 7. Mute notifications, Disappearing messages, Chat wallpaper, Encryption
/// 8. Block / Report section
class ContactInfoScreen extends StatefulWidget {
  final String name;
  final String? avatarAsset;
  final String? avatarUrl;
  final KoraBadgeType badge;
  final bool isOnline;
  final String? lastSeen;
  final String? koraId;
  final String? username;
  final String? about;
  final String? phone;
  final String? chatId;
  final String? recipientEmail;
  final bool isAiChat;

  const ContactInfoScreen({
    super.key,
    required this.name,
    this.chatId,
    this.avatarAsset,
    this.avatarUrl,
    this.badge = KoraBadgeType.none,
    this.isOnline = false,
    this.lastSeen,
    this.koraId,
    this.username,
    this.about,
    this.phone,
    this.recipientEmail,
    this.isAiChat = false,
  });

  @override
  State<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends State<ContactInfoScreen> {
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _loadMuteState();
  }

  Future<void> _loadMuteState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'muted_${widget.chatId ?? widget.koraId ?? widget.name}';
    if (mounted) setState(() => _isMuted = prefs.getBool(key) ?? false);
  }

  Future<void> _toggleMute() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'muted_${widget.chatId ?? widget.koraId ?? widget.name}';
    setState(() => _isMuted = !_isMuted);
    prefs.setBool(key, _isMuted);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return SecureScreen(
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──
              _buildTopBar(context, textPrimary, surface, border),
              // ── Scrollable content ──
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Large circular profile avatar centered
                      KoraAvatar(
                        name: widget.name,
                        assetPath: widget.avatarAsset,
                        imageUrl: widget.avatarUrl,
                        size: 120,
                        showOnlineDot: widget.isOnline,
                      ),
                      const SizedBox(height: 16),
                      // Name with badge
                      KoraNameWithBadge(
                        name: widget.name,
                        badge: widget.badge,
                        badgeSize: 18,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Username
                      if (widget.username != null)
                        GestureDetector(
                          onLongPress: () => _copyToClipboard(context, '@${widget.username!}', 'Username'),
                          child: Text(
                            '@${widget.username!}',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      // Kora ID
                      if (widget.koraId != null)
                        GestureDetector(
                          onLongPress: () => _copyToClipboard(context, widget.koraId!, 'Kora ID'),
                          child: Text(
                            widget.koraId!,
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Online status
                      Text(
                        widget.isOnline ? 'online' : (widget.lastSeen ?? 'last seen recently'),
                        style: TextStyle(
                          color: widget.isOnline ? KoraColors.purple : textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // ── Action row ──
                      _actionRow(context, surface, textPrimary, textSecondary, border),
                      const SizedBox(height: 16),
                      // ── About section ──
                      if (widget.about != null)
                        _sectionTile(surface, textPrimary, textSecondary, textMuted, border,
                          Icons.info_outline, 'About', widget.about!),
                      const SizedBox(height: 8),
                      // ── Phone section ──
                      if (widget.phone != null)
                        _sectionTile(surface, textPrimary, textSecondary, textMuted, border,
                          Icons.phone_outlined, 'Phone', widget.phone!),
                      if (widget.phone != null)
                        const SizedBox(height: 8),
                      // ── Media, links, and docs ──
                      _sectionTile(surface, textPrimary, textSecondary, textMuted, border,
                        Icons.photo_library_outlined, 'Media, links, and docs', 'None'),
                      const SizedBox(height: 8),
                      // ── Settings section ──
                      _settingsSection(surface, textPrimary, textSecondary, textMuted, border),
                      const SizedBox(height: 8),
                      // ── Block / Report ──
                      if (!widget.isAiChat) ...[
                        _blockReportSection(surface, border),
                        const SizedBox(height: 32),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Color textPrimary, Color surface, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: textPrimary, size: 24),
            onPressed: () => Navigator.pop(context),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const Spacer(),
          if (!widget.isAiChat)
            IconButton(
              icon: Icon(Icons.more_vert, color: textPrimary, size: 22),
              onPressed: () => _showTopMenu(context, surface, border),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
        ],
      ),
    );
  }

  void _showTopMenu(BuildContext context, Color surface, Color border) {
    final textPrimary = KoraColors.textPrimaryFor(Theme.of(context).brightness);
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.share, color: textPrimary),
            title: Text('Share', style: TextStyle(color: textPrimary)),
            onTap: () => Navigator.pop(ctx),
          ),
          ListTile(
            leading: Icon(Icons.block, color: Colors.redAccent),
            title: Text('Block', style: TextStyle(color: Colors.redAccent)),
            onTap: () => Navigator.pop(ctx),
          ),
          ListTile(
            leading: Icon(Icons.report_outlined, color: Colors.redAccent),
            title: Text('Report', style: TextStyle(color: Colors.redAccent)),
            onTap: () => Navigator.pop(ctx),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _actionRow(BuildContext context, Color surface, Color textPrimary, Color textSecondary, Color border) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _actionCard(
              surface, textPrimary, textSecondary, border,
              Icons.chat_bubble_outline, 'Message',
              () {
                final chatId = (widget.koraId != null && widget.koraId!.isNotEmpty)
                    ? widget.koraId!
                    : (widget.username ?? widget.phone ?? widget.name);
                pushSlideUp(
                  context,
                  KoraChatScreen(
                    isGroupChat: false,
                    chatId: chatId,
                    name: widget.name,
                    avatarUrl: widget.avatarUrl,
                    badge: widget.badge,
                    isOnline: widget.isOnline,
                    lastSeen: widget.lastSeen,
                  ),
                );
              },
            ),
          ),
          if (!widget.isAiChat) ...[
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                surface, textPrimary, textSecondary, border,
                Icons.call_outlined, 'Call',
                () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                surface, textPrimary, textSecondary, border,
                Icons.videocam_outlined, 'Video',
                () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                surface, textPrimary, textSecondary, border,
                Icons.search, 'Search',
                () => Navigator.pop(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionCard(Color surface, Color textPrimary, Color textSecondary, Color border, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: KoraColors.purple, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTile(Color surface, Color textPrimary, Color textSecondary, Color textMuted, Color border,
      IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: KoraColors.purple, size: 22),
        title: Text(label, style: TextStyle(color: textSecondary, fontSize: 13)),
        subtitle: Text(value, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
        onLongPress: () => _copyToClipboard(context, value, label),
      ),
    );
  }

  Widget _settingsSection(Color surface, Color textPrimary, Color textSecondary, Color textMuted, Color border) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Mute notifications
          SwitchListTile(
            secondary: Icon(
              _isMuted ? Icons.notifications_off : Icons.notifications_active_outlined,
              color: KoraColors.purple,
              size: 22,
            ),
            title: Text('Mute notifications', style: TextStyle(color: textPrimary, fontSize: 15)),
            subtitle: Text(_isMuted ? 'On' : 'Off', style: TextStyle(color: textMuted, fontSize: 13)),
            value: _isMuted,
            onChanged: (_) => _toggleMute(),
            activeColor: KoraColors.purple,
          ),
          Divider(height: 1, indent: 56, color: border),
          // Disappearing messages
          ListTile(
            leading: Icon(Icons.timer_outlined, color: KoraColors.purple, size: 22),
            title: Text('Disappearing messages', style: TextStyle(color: textPrimary, fontSize: 15)),
            subtitle: Text('Off', style: TextStyle(color: textMuted, fontSize: 13)),
            trailing: Icon(Icons.chevron_right, color: textMuted, size: 20),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => DisappearingMessagesScreen(chatId: widget.chatId ?? widget.koraId),
            )),
          ),
          Divider(height: 1, indent: 56, color: border),
          // Chat wallpaper
          ListTile(
            leading: Icon(Icons.palette_outlined, color: KoraColors.purple, size: 22),
            title: Text('Chat wallpaper', style: TextStyle(color: textPrimary, fontSize: 15)),
            trailing: Icon(Icons.chevron_right, color: textMuted, size: 20),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const DefaultChatThemeScreen(),
            )),
          ),
          Divider(height: 1, indent: 56, color: border),
          // Encryption
          ListTile(
            leading: Icon(Icons.lock_outline, color: KoraColors.purple, size: 22),
            title: Text('Encryption', style: TextStyle(color: textPrimary, fontSize: 15)),
            subtitle: Text('Messages are end-to-end encrypted', style: TextStyle(color: textMuted, fontSize: 13)),
            trailing: Icon(Icons.chevron_right, color: textMuted, size: 20),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => E2eeVerificationScreen(
                chatId: widget.chatId ?? widget.koraId ?? widget.name,
                chatName: widget.name,
                peerPublicKey: '',
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _blockReportSection(Color surface, Color border) {
    final textPrimary = KoraColors.textPrimaryFor(Theme.of(context).brightness);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.block, color: Colors.redAccent, size: 22),
            title: Text('Block ${widget.name}', style: TextStyle(color: Colors.redAccent, fontSize: 15)),
            onTap: () => Navigator.pop(context),
          ),
          Divider(height: 1, indent: 56, color: border),
          ListTile(
            leading: Icon(Icons.report_outlined, color: Colors.redAccent, size: 22),
            title: Text('Report ${widget.name}', style: TextStyle(color: Colors.redAccent, fontSize: 15)),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
