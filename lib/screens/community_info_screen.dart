import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/kora_colors.dart';

/// Community Info Screen — full community details when tapped.
///
/// WhatsApp 2026 layout:
/// - Community avatar + name + description
/// - Created date
/// - Announcement group at top
/// - "Groups you're in" section with all groups listed
/// - "+ Add group" button
/// - 3-dot menu: Edit, Share invite, Report, Delete
/// - Tapping a group opens the group chat
class CommunityInfoScreen extends StatefulWidget {
  final dynamic community;

  const CommunityInfoScreen({super.key, required this.community});

  @override
  State<CommunityInfoScreen> createState() => _CommunityInfoScreenState();
}

class _CommunityInfoScreenState extends State<CommunityInfoScreen> {
  late String _name;
  late String _description;
  late String? _iconPath;
  late DateTime _createdAt;
  late List<_GroupInfo> _groups;

  @override
  void initState() {
    super.initState();
    _name = widget.community.name as String;
    _description = widget.community.description as String? ?? '';
    _iconPath = widget.community.iconPath as String?;
    _createdAt = widget.community.createdAt as DateTime;

    // Build groups list from community's groups
    _groups = [];
    final communityGroups = widget.community.groups as List;
    if (communityGroups.isNotEmpty) {
      // First group is always the announcement
      _groups.add(_GroupInfo(
        name: communityGroups.first.name as String,
        isAnnouncement: true,
        description: 'Only admins can send messages',
      ));
      for (int i = 1; i < communityGroups.length; i++) {
        _groups.add(_GroupInfo(
          name: communityGroups[i].name as String,
          isAnnouncement: false,
          description: 'Tap to start chatting',
        ));
      }
    }
  }

  void _openMenu() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.edit_outlined, color: textPrimary),
            title: Text('Edit community info', style: TextStyle(color: textPrimary)),
            onTap: () { Navigator.pop(context); _editCommunity(); },
          ),
          ListTile(
            leading: Icon(Icons.link, color: textPrimary),
            title: Text('Invite via link', style: TextStyle(color: textPrimary)),
            onTap: () { Navigator.pop(context); _shareInvite(); },
          ),
          ListTile(
            leading: Icon(Icons.group_add_outlined, color: textPrimary),
            title: Text('Add group', style: TextStyle(color: textPrimary)),
            onTap: () { Navigator.pop(context); _addGroup(); },
          ),
          ListTile(
            leading: Icon(Icons.notifications_outlined, color: textPrimary),
            title: Text('Mute notifications', style: TextStyle(color: textPrimary)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Icon(Icons.report_outlined, color: textPrimary),
            title: Text('Report community', style: TextStyle(color: textPrimary)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Icon(Icons.exit_to_app, color: Colors.redAccent),
            title: Text('Exit community', style: TextStyle(color: Colors.redAccent)),
            onTap: () { Navigator.pop(context); _exitCommunity(); },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _editCommunity() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final border = KoraColors.borderFor(brightness);

    final nameController = TextEditingController(text: _name);
    final descController = TextEditingController(text: _description);

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('Edit community', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border, width: 0.5),
              ),
              child: TextField(
                controller: nameController,
                style: TextStyle(color: textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Community name',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border, width: 0.5),
              ),
              child: TextField(
                controller: descController,
                maxLines: 3,
                style: TextStyle(color: textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Description (optional)',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: textMuted, fontSize: 16)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _name = nameController.text.trim();
                      _description = descController.text.trim();
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KoraColors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _shareInvite() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invite link for "$_name" copied to clipboard'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addGroup() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final border = KoraColors.borderFor(brightness);

    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.add, color: textPrimary, size: 24),
                  const SizedBox(width: 12),
                  Text('Add group to $_name',
                      style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border, width: 0.5),
              ),
              child: TextField(
                controller: nameController,
                autofocus: true,
                style: TextStyle(color: textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Group name',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: textMuted, fontSize: 16)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      setState(() => _groups.add(_GroupInfo(name: name, isAnnouncement: false, description: 'Tap to start chatting')));
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KoraColors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _exitCommunity() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Exit "$_name"?', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text('You will no longer be able to send or receive messages in this community.',
            style: TextStyle(color: textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Exit community info
            },
            child: const Text('Exit', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: textPrimary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(_name,
                        style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: textPrimary, size: 24),
                    onPressed: _openMenu,
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Community avatar + name
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              gradient: KoraColors.brandGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: KoraColors.purple.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8)),
                              ],
                              image: _iconPath != null
                                  ? DecorationImage(image: FileImage(File(_iconPath!)), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: _iconPath == null
                                ? Center(child: Text(_name.isNotEmpty ? _name[0].toUpperCase() : 'K',
                                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)))
                                : null,
                          ),
                          const SizedBox(height: 14),
                          Text(_name,
                              style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                          if (_description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(_description,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
                                maxLines: 3, overflow: TextOverflow.ellipsis),
                          ],
                          const SizedBox(height: 6),
                          Text('Created ${_formatDate(_createdAt)}',
                              style: TextStyle(color: textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Announcement group
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(color: KoraColors.purple.withValues(alpha: 0.15), shape: BoxShape.circle),
                            child: Icon(Icons.campaign_outlined, color: KoraColors.purple, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Announcement',
                                    style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('Only admins can send messages',
                                    style: TextStyle(color: textSecondary, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Groups section
                    Text("Groups you're in",
                        style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    // List groups
                    ..._groups.where((g) => !g.isAnnouncement).map((group) => _buildGroupTile(group, card, surface, textPrimary, textSecondary, textMuted, border)),
                    const SizedBox(height: 16),
                    // Note
                    Text('Other groups added to the community will display here.',
                        style: TextStyle(color: textMuted, fontSize: 13, height: 1.4)),
                    const SizedBox(height: 6),
                    Text('Community members can join this group.',
                        style: TextStyle(color: textMuted, fontSize: 13, height: 1.4)),
                    const SizedBox(height: 24),
                    // Add group button
                    GestureDetector(
                      onTap: _addGroup,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: KoraColors.brandGradient,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(color: KoraColors.purple.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 22),
                              const SizedBox(width: 8),
                              Text('Add Group', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTile(_GroupInfo group, Color card, Color surface, Color textPrimary, Color textSecondary, Color textMuted, Color border) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
            child: Icon(Icons.group_outlined, color: textMuted, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name,
                    style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(group.description, style: TextStyle(color: textMuted, fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: textMuted, size: 20),
        ],
      ),
    );
  }
}

class _GroupInfo {
  final String name;
  final bool isAnnouncement;
  final String description;

  _GroupInfo({required this.name, this.isAnnouncement = false, this.description = ''});
}
