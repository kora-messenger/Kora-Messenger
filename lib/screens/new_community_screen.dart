import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/kora_colors.dart';

/// New Community screen — setup community profile, name, and description.
///
/// WhatsApp 2026 flow:
/// - Back arrow + "New Community" title
/// - Community profile image picker (circle, tap to add photo)
/// - Community name (100 chars max, placeholder inside field)
/// - Description (3000 chars max, placeholder inside field, optional)
/// - Continue arrow at the bottom → goes to add groups screen
class NewCommunityScreen extends StatefulWidget {
  const NewCommunityScreen({super.key});

  @override
  State<NewCommunityScreen> createState() => _NewCommunityScreenState();
}

class _NewCommunityScreenState extends State<NewCommunityScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String? _iconPath;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _canContinue => _nameController.text.trim().isNotEmpty;

  void _pickImage() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (photo != null && mounted) {
      setState(() => _iconPath = photo.path);
    }
  }

  void _goToAddGroups() {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AddGroupsScreen(
          communityName: name,
          communityDescription: desc,
          iconPath: _iconPath,
        ),
      ),
    ).then((communityData) {
      if (communityData != null && mounted) {
        Navigator.pop(context, communityData);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header with back arrow
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: textPrimary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text('New Community',
                      style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    // Community profile image picker
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          color: surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: border, width: 1.5),
                          image: _iconPath != null
                              ? DecorationImage(
                                  image: FileImage(File(_iconPath!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _iconPath == null
                            ? Icon(Icons.camera_alt_outlined, color: textMuted, size: 36)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Tap to add photo', style: TextStyle(color: textMuted, fontSize: 13)),
                    const SizedBox(height: 36),
                    // Community name field
                    Container(
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border, width: 0.5),
                      ),
                      child: TextField(
                        controller: _nameController,
                        maxLength: 100,
                        style: TextStyle(color: textPrimary, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Community name',
                          hintStyle: TextStyle(color: textMuted, fontSize: 16),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          counterStyle: TextStyle(color: textMuted, fontSize: 11),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Description field
                    Container(
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border, width: 0.5),
                      ),
                      child: TextField(
                        controller: _descController,
                        maxLength: 3000,
                        maxLines: 4,
                        style: TextStyle(color: textPrimary, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Description (optional)',
                          hintStyle: TextStyle(color: textMuted, fontSize: 16),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          counterStyle: TextStyle(color: textMuted, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Provide a description to help people understand your community.',
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            // Continue arrow at bottom
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _canContinue ? _goToAddGroups : null,
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        gradient: _canContinue ? KoraColors.brandGradient : null,
                        color: _canContinue ? null : KoraColors.purple.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        boxShadow: _canContinue
                            ? [BoxShadow(color: KoraColors.purple.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))]
                            : null,
                      ),
                      child: Icon(Icons.arrow_forward,
                          color: _canContinue ? Colors.white : textMuted, size: 26),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add groups to a new community.
/// User can create new groups or add existing groups to the community.
class _AddGroupsScreen extends StatefulWidget {
  final String communityName;
  final String communityDescription;
  final String? iconPath;

  const _AddGroupsScreen({
    required this.communityName,
    required this.communityDescription,
    this.iconPath,
  });

  @override
  State<_AddGroupsScreen> createState() => _AddGroupsScreenState();
}

class _AddGroupsScreenState extends State<_AddGroupsScreen> {
  final List<Map<String, dynamic>> _selectedGroups = [
    {'name': 'General', 'icon': Icons.group_outlined, 'isExisting': false},
  ];

  void _addNewGroup() {
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
                  Text('Add new group',
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
                  hintStyle: TextStyle(color: textMuted),
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
                      setState(() => _selectedGroups.add({'name': name, 'icon': Icons.group_outlined, 'isExisting': false}));
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

  void _addExistingGroup() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.group_outlined, color: textPrimary, size: 24),
                  const SizedBox(width: 12),
                  Text('Add existing group',
                      style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Icon(Icons.close, color: textMuted, size: 22),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: 5,
                itemBuilder: (ctx, i) {
                  final groupNames = ['Kora Beta Testers', 'Design Team', 'Naija Devs', 'Friends Chat', 'Family Group'];
                  final isSelected = _selectedGroups.any((g) => g['name'] == groupNames[i]);
                  return ListTile(
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: KoraColors.purple.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Icon(Icons.group_outlined, color: KoraColors.purple, size: 20),
                    ),
                    title: Text(groupNames[i], style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500)),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: KoraColors.purple, size: 22)
                        : GestureDetector(
                            onTap: () {
                              setState(() => _selectedGroups.add({
                                'name': groupNames[i],
                                'icon': Icons.group_outlined,
                                'isExisting': true,
                              }));
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: KoraColors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Add', style: TextStyle(color: KoraColors.purple, fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createCommunity() {
    final communityData = {
      'name': widget.communityName,
      'description': widget.communityDescription,
      'iconPath': widget.iconPath,
      'groups': _selectedGroups.map((g) => g['name'] as String).toList(),
    };
    Navigator.pop(context, communityData);
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: textPrimary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text('Add groups',
                      style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
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
                    Text('Add groups to your community',
                        style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('You can add up to 50 groups to a community.',
                        style: TextStyle(color: textSecondary, fontSize: 14)),
                    const SizedBox(height: 24),
                    // Announcement group (default, not removable)
                    Container(
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
                            decoration: BoxDecoration(
                              color: KoraColors.purple.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.campaign_outlined, color: KoraColors.purple, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Announcement',
                                    style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                                Text('Only admins can send messages',
                                    style: TextStyle(color: textSecondary, fontSize: 13)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: KoraColors.purple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Required',
                                style: TextStyle(color: KoraColors.purple, fontSize: 10, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Selected groups
                    ..._selectedGroups.where((g) => g['name'] != 'General').toList().asMap().entries.map((entry) {
                      final i = entry.key;
                      final group = entry.value;
                      return Container(
                        key: ValueKey(group['name']),
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
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: surface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(group['icon'] as IconData, color: textMuted, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(group['name'] as String,
                                  style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _selectedGroups.removeWhere((g) => g['name'] == group['name'])),
                              child: Icon(Icons.close, color: textMuted, size: 20),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    // Add group options
                    GestureDetector(
                      onTap: _addNewGroup,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: KoraColors.purple.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: KoraColors.purple.withValues(alpha: 0.2), width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: KoraColors.purple.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.add, color: KoraColors.purple, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Text('Create new group',
                                style: TextStyle(color: KoraColors.purple, fontSize: 15, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _addExistingGroup,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: KoraColors.blue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: KoraColors.blue.withValues(alpha: 0.2), width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: KoraColors.blue.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.group_add_outlined, color: KoraColors.blue, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Text('Add existing group',
                                style: TextStyle(color: KoraColors.blue, fontSize: 15, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            // Create button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _createCommunity,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KoraColors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    elevation: 0,
                  ),
                  child: Text('Create community',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
