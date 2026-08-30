import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';

/// Channel Roles Screen — manage channel admins and their roles.
/// Mirrors WhatsApp's channel admin management.
///
/// Roles hierarchy:
/// - Owner: full control (create, delete, add/remove admins, post, edit)
/// - Admin: can post, edit own posts, manage followers
/// - Member: can follow, react, and share (read-only)
class ChannelRolesScreen extends StatefulWidget {
  final String channelName;

  const ChannelRolesScreen({super.key, required this.channelName});

  @override
  State<ChannelRolesScreen> createState() => _ChannelRolesScreenState();
}

class _ChannelRolesScreenState extends State<ChannelRolesScreen> {
  final List<_ChannelMember> _members = [
    _ChannelMember(name: 'You', email: 'you@kora.com', role: ChannelRole.owner, isYou: true),
    _ChannelMember(name: 'Admin User', email: 'admin@kora.com', role: ChannelRole.admin),
    _ChannelMember(name: 'Member One', email: 'm1@kora.com', role: ChannelRole.member),
    _ChannelMember(name: 'Member Two', email: 'm2@kora.com', role: ChannelRole.member),
    _ChannelMember(name: 'Member Three', email: 'm3@kora.com', role: ChannelRole.member),
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    final owners = _members.where((m) => m.role == ChannelRole.owner).toList();
    final admins = _members.where((m) => m.role == ChannelRole.admin).toList();
    final members = _members.where((m) => m.role == ChannelRole.member).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Admins & Roles',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Channel header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [KoraColors.purple.withValues(alpha: 0.1), KoraColors.blue.withValues(alpha: 0.08)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [KoraColors.purple, KoraColors.blue]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(widget.channelName.isNotEmpty ? widget.channelName[0].toUpperCase() : 'C',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.channelName,
                      style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // Owners section
          _sectionHeader('OWNER', textMuted),
          ...owners.map((m) => _memberTile(m, surface, textPrimary, textMuted)),

          // Admins section
          _sectionHeader('ADMINS (${admins.length})', textMuted),
          ...admins.map((m) => _memberTile(m, surface, textPrimary, textMuted)),
          // Add admin button
          ListTile(
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_add_outlined, color: KoraColors.purple),
            ),
            title: Text('Add Admin', style: TextStyle(color: KoraColors.purple, fontSize: 15, fontWeight: FontWeight.w500)),
            onTap: () => _addAdmin(),
          ),

          // Members section
          _sectionHeader('FOLLOWERS (${members.length})', textMuted),
          ...members.map((m) => _memberTile(m, surface, textPrimary, textMuted)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label, style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    );
  }

  Widget _memberTile(_ChannelMember member, Color surface, Color textPrimary, Color textMuted) {
    return ListTile(
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [KoraColors.purple.withValues(alpha: 0.15), KoraColors.blue.withValues(alpha: 0.1)]),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
              style: TextStyle(color: KoraColors.purple, fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
      title: Text(member.isYou ? 'You' : member.name, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(member.email, style: TextStyle(color: textMuted, fontSize: 13)),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: textMuted, size: 20),
        onSelected: (value) => _handleRoleAction(value, member),
        itemBuilder: (context) => [
          if (member.role == ChannelRole.member)
            const PopupMenuItem(value: 'promote', child: Text('Promote to Admin')),
          if (member.role == ChannelRole.admin)
            const PopupMenuItem(value: 'demote', child: Text('Demote to Member')),
          if (member.role == ChannelRole.admin || member.role == ChannelRole.owner)
            const PopupMenuItem(value: 'remove', child: Text('Remove Admin')),
        ],
      ),
    );
  }

  void _handleRoleAction(String action, _ChannelMember member) {
    setState(() {
      switch (action) {
        case 'promote':
          member.role = ChannelRole.admin;
          break;
        case 'demote':
          member.role = ChannelRole.member;
          break;
        case 'remove':
          _members.remove(member);
          break;
      }
    });
  }

  void _addAdmin() {
    // In production, this would open a contact picker
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Select a follower to promote to admin'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

enum ChannelRole { owner, admin, member }

class _ChannelMember {
  String name;
  String email;
  ChannelRole role;
  bool isYou;

  _ChannelMember({
    required this.name,
    required this.email,
    required this.role,
    this.isYou = false,
  });
}
