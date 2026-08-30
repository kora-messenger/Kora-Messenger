import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_avatar.dart';
import '../../models/chat_models.dart';
import '../group/group_permissions_screen.dart';
import 'disappearing_messages_screen.dart';
import '../settings/default_chat_theme_screen.dart';
import 'e2ee_verification_screen.dart';

/// Group Chat Info screen — opens when the user taps a group name in
/// a chat. Mirrors WhatsApp's Group Info screen.
///
/// Layout:
/// - Large group avatar centered
/// - Group name + description
/// - Created date
/// - Mute / Disappearing / Permissions / Wallpaper / Encryption
/// - Media, links, and docs link
/// - Participants list with admin badges
/// - Add participant button
/// - 3-dot menu: Group info, Share invite, Mute, Report, Exit
class GroupChatInfoScreen extends StatefulWidget {
  final String groupName;
  final String? groupDescription;
  final String? avatarAsset;
  final String? avatarUrl;
  final List<GroupParticipant> participants;
  final DateTime createdAt;
  final String? chatId;

  const GroupChatInfoScreen({
    super.key,
    required this.groupName,
    this.groupDescription,
    this.avatarAsset,
    this.avatarUrl,
    this.participants = const [],
    required this.createdAt,
    this.chatId,
  });

  @override
  State<GroupChatInfoScreen> createState() => _GroupChatInfoScreenState();
}

class _GroupChatInfoScreenState extends State<GroupChatInfoScreen> {
  late List<GroupParticipant> _participants;
  bool _isMuted = false;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _participants = List.from(widget.participants);
    _loadMuteState();
  }

  Future<void> _loadMuteState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'muted_${widget.chatId ?? widget.groupName}';
    if (mounted) setState(() => _isMuted = prefs.getBool(key) ?? false);
  }

  Future<void> _toggleMute() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'muted_${widget.chatId ?? widget.groupName}';
    setState(() => _isMuted = !_isMuted);
    prefs.setBool(key, _isMuted);
  }

  void _openMenu() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: KoraColors.borderFor(brightness), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(leading: Icon(Icons.share, color: textPrimary), title: Text('Share invite link', style: TextStyle(color: textPrimary)), onTap: () { Navigator.pop(ctx); }),
          ListTile(leading: Icon(Icons.notifications_off_outlined, color: textPrimary), title: Text('Mute notifications', style: TextStyle(color: textPrimary)), onTap: () { Navigator.pop(ctx); _toggleMute(); }),
          ListTile(leading: Icon(Icons.report_outlined, color: textPrimary), title: Text('Report group', style: TextStyle(color: textPrimary)), onTap: () => Navigator.pop(ctx)),
          ListTile(leading: Icon(Icons.exit_to_app, color: Colors.redAccent), title: Text('Exit group', style: TextStyle(color: Colors.redAccent)), onTap: () { Navigator.pop(ctx); Navigator.pop(context); }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _addParticipant() {
    setState(() => _isAdding = true);
    // Simulate adding a contact
    final newParticipant = GroupParticipant(
      name: 'New Member',
      koraId: 'kora_${DateTime.now().millisecondsSinceEpoch}',
      isAdmin: false,
    );
    setState(() {
      _participants.add(newParticipant);
      _isAdding = false;
    });
  }

  void _removeParticipant(int index) {
    setState(() => _participants.removeAt(index));
  }

  void _toggleAdmin(int index) {
    setState(() => _participants[index] = _participants[index].copyWith(isAdmin: !_participants[index].isAdmin));
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

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: bg,
            pinned: true,
            leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
            title: Text('Group info', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
            actions: [
              IconButton(icon: Icon(Icons.more_vert, color: textPrimary), onPressed: _openMenu),
            ],
          ),

          // Avatar + Name + Description
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              color: surface,
              child: Column(
                children: [
                  Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      gradient: KoraColors.brandGradient,
                      shape: BoxShape.circle,
                    ),
                    child: widget.avatarUrl != null
                      ? ClipOval(child: Image.network(widget.avatarUrl!, fit: BoxFit.cover))
                      : widget.avatarAsset != null
                        ? ClipOval(child: Image.asset(widget.avatarAsset!, fit: BoxFit.cover))
                        : Center(child: Text(widget.groupName.isNotEmpty ? widget.groupName[0].toUpperCase() : 'G',
                            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700))),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.groupName, style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                  if (widget.groupDescription != null && widget.groupDescription!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(widget.groupDescription!, style: TextStyle(color: textSecondary, fontSize: 14), textAlign: TextAlign.center),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text('Created ${_formatDate(widget.createdAt)}', style: TextStyle(color: textMuted, fontSize: 13)),
                ],
              ),
            ),
          ),

          // Settings section
          SliverToBoxAdapter(child: const SizedBox(height: 8)),

          SliverToBoxAdapter(
            child: Container(
              color: surface,
              child: Column(
                children: [
                  _settingsTile(
                    icon: _isMuted ? Icons.notifications_off : Icons.notifications_active_outlined,
                    title: 'Mute notifications',
                    subtitle: _isMuted ? 'On' : 'Off',
                    color: textPrimary,
                    textMuted: textMuted,
                    border: border,
                    onTap: _toggleMute,
                  ),
                  _divider(border),
                  _settingsTile(
                    icon: Icons.timer_outlined,
                    title: 'Disappearing messages',
                    subtitle: 'Off',
                    color: textPrimary,
                    textMuted: textMuted,
                    border: border,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DisappearingMessagesScreen())),
                  ),
                  _divider(border),
                  _settingsTile(
                    icon: Icons.lock_outline,
                    title: 'Group permissions',
                    subtitle: 'Send messages, edit info',
                    color: textPrimary,
                    textMuted: textMuted,
                    border: border,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupPermissionsScreen(groupId: widget.chatId))),
                  ),
                  _divider(border),
                  _settingsTile(
                    icon: Icons.palette_outlined,
                    title: 'Wallpapers',
                    subtitle: 'Change chat wallpaper',
                    color: textPrimary,
                    textMuted: textMuted,
                    border: border,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DefaultChatThemeScreen())),
                  ),
                  _divider(border),
                  _settingsTile(
                    icon: Icons.lock,
                    title: 'Encryption',
                    subtitle: 'Messages are end-to-end encrypted',
                    color: textPrimary,
                    textMuted: textMuted,
                    border: border,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const E2eeVerificationScreen())),
                  ),
                ],
              ),
            ),
          ),

          // Media, links, docs
          SliverToBoxAdapter(child: const SizedBox(height: 8)),
          SliverToBoxAdapter(
            child: Container(
              color: surface,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.photo_library_outlined, color: textPrimary),
                    title: Text('Media, links, and docs', style: TextStyle(color: textPrimary, fontSize: 15)),
                    subtitle: Text('No media yet', style: TextStyle(color: textMuted, fontSize: 13)),
                    trailing: Icon(Icons.chevron_right, color: textMuted, size: 20),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

          // Participants
          SliverToBoxAdapter(child: const SizedBox(height: 8)),
          SliverToBoxAdapter(
            child: Container(
              color: surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('${_participants.length} participants',
                      style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  // Add participant
                  ListTile(
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: KoraColors.purple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_add_outlined, color: KoraColors.purple, size: 22),
                    ),
                    title: Text('Add participant', style: TextStyle(color: KoraColors.purple, fontSize: 15, fontWeight: FontWeight.w500)),
                    onTap: _addParticipant,
                  ),
                  _divider(border),
                  // Invite via link
                  ListTile(
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: KoraColors.purple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.link, color: KoraColors.purple, size: 22),
                    ),
                    title: Text('Invite via link', style: TextStyle(color: KoraColors.purple, fontSize: 15, fontWeight: FontWeight.w500)),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: const Text('Invite link copied to clipboard'), backgroundColor: KoraColors.purple),
                      );
                    },
                  ),
                  _divider(border),
                  // Participant list
                  ...List.generate(_participants.length, (i) {
                    final p = _participants[i];
                    return Column(
                      children: [
                        ListTile(
                          leading: KoraAvatar(name: p.name, size: 44),
                          title: Text(p.name, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                          subtitle: p.isAdmin
                            ? Text('Admin', style: TextStyle(color: KoraColors.purple, fontSize: 13, fontWeight: FontWeight.w500))
                            : null,
                          trailing: PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: textMuted, size: 20),
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'admin', child: Text(p.isAdmin ? 'Dismiss as admin' : 'Make admin')),
                              PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: Colors.redAccent))),
                            ],
                            onSelected: (action) {
                              if (action == 'admin') _toggleAdmin(i);
                              else if (action == 'remove') _removeParticipant(i);
                            },
                          ),
                        ),
                        if (i < _participants.length - 1) _divider(border),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),

          // Exit group
          SliverToBoxAdapter(child: const SizedBox(height: 8)),
          SliverToBoxAdapter(
            child: Container(
              color: surface,
              child: ListTile(
                leading: Icon(Icons.exit_to_app, color: Colors.redAccent),
                title: Text('Exit group', style: TextStyle(color: Colors.redAccent, fontSize: 15)),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: surface,
                      title: Text('Exit group?', style: TextStyle(color: textPrimary)),
                      content: Text('Only admins will be notified that you left the group.', style: TextStyle(color: textSecondary)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: textSecondary))),
                        TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: Text('Exit', style: TextStyle(color: Colors.redAccent))),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color textMuted,
    required Color border,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: KoraColors.purple),
      title: Text(title, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: textMuted, fontSize: 13)),
      trailing: Icon(Icons.chevron_right, color: textMuted, size: 20),
      onTap: onTap,
    );
  }

  Widget _divider(Color border) => Padding(padding: const EdgeInsets.only(left: 60), child: Divider(height: 1, color: border.withValues(alpha: 0.3)));

  String _formatDate(DateTime date) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// Data model for a group participant
class GroupParticipant {
  final String name;
  final String koraId;
  final bool isAdmin;

  GroupParticipant({required this.name, required this.koraId, this.isAdmin = false});

  GroupParticipant copyWith({String? name, String? koraId, bool? isAdmin}) {
    return GroupParticipant(
      name: name ?? this.name,
      koraId: koraId ?? this.koraId,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
