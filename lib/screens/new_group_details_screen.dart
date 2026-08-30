import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/kora_colors.dart';
import '../widgets/kora_avatar.dart';
import '../services/contacts_service.dart';
import 'kora_home_screen.dart';
import 'chat/emoji_picker_sheet.dart';
import 'chat/disappearing_messages_screen.dart';
import 'group/group_permissions_screen.dart';
import '../services/chat_sync_service.dart';

/// Group-details screen — shown after selecting members on the New
/// Group screen. Lets the user name the group, add a group photo,
/// review/add/remove members, and create the group.
class NewGroupDetailsScreen extends StatefulWidget {
  final List<Map<String, Object?>> members;

  const NewGroupDetailsScreen({super.key, required this.members});

  @override
  State<NewGroupDetailsScreen> createState() => _NewGroupDetailsScreenState();
}

class _NewGroupDetailsScreenState extends State<NewGroupDetailsScreen> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();

  File? _groupPhoto;
  late List<Map<String, Object?>> _members;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _members = List<Map<String, Object?>>.from(widget.members);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Group photo ──────────────────────────────────────────────

  void _showPhotoOptions() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final isDark = brightness == Brightness.dark;
    final card = KoraColors.cardFor(brightness);

    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3A3A4E) : const Color(0xFFD0D0DC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _sheetOption(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                color: textPrimary,
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery();
                },
              ),
              _sheetOption(
                icon: Icons.camera_alt_outlined,
                label: 'Take Photo',
                color: textPrimary,
                onTap: () {
                  Navigator.pop(context);
                  _pickFromCamera();
                },
              ),
              if (_groupPhoto != null)
                _sheetOption(
                  icon: Icons.delete_outline,
                  label: 'Remove Photo',
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _groupPhoto = null);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 24),
      title: Text(label, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 384,
        maxHeight: 384,
        imageQuality: 70,
      );
      if (xfile != null && mounted) {
        setState(() => _groupPhoto = File(xfile.path));
      }
    } on Exception catch (_) {
      // Permission denied or picker cancelled — silently ignore
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 384,
        maxHeight: 384,
        imageQuality: 70,
      );
      if (xfile != null && mounted) {
        setState(() => _groupPhoto = File(xfile.path));
      }
    } on Exception catch (_) {
      // Permission denied or camera unavailable — silently ignore
    }
  }

  // ── Members ───────────────────────────────────────────────────

  Future<void> _showAddMembersSheet() async {
    final addedIds = _members.map((m) => m['koraId'] as String).toSet();
    final allContacts = await ContactsService.instance.getContacts();
    final available = allContacts.where((c) => !addedIds.contains(c['koraId'])).toList();
    final Set<String> pickedIds = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final brightness = Theme.of(sheetContext).brightness;
        final card = KoraColors.cardFor(brightness);
        final textPrimary = KoraColors.textPrimaryFor(brightness);
        final textSecondary = KoraColors.textSecondaryFor(brightness);
        final textMuted = KoraColors.textMutedFor(brightness);
        final isDark = brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF3A3A4E) : const Color(0xFFD0D0DC),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Text(
                              'Add Members',
                              style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            if (pickedIds.isNotEmpty)
                              Text(
                                '${pickedIds.length} selected',
                                style: const TextStyle(color: KoraColors.purple, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: available.isEmpty
                            ? Center(
                                child: Text(
                                  'Everyone has already been added',
                                  style: TextStyle(color: textSecondary, fontSize: 14),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: available.length,
                                itemBuilder: (context, index) {
                                  final contact = available[index];
                                  final koraId = contact['koraId'] as String;
                                  final isPicked = pickedIds.contains(koraId);
                                  final isPremium = contact['premium'] == true;

                                  return ListTile(
                                    leading: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          KoraAvatar(
                                            name: contact['name'] as String,
                                            size: 48,
                                            isPremium: isPremium,
                                          ),
                                          Positioned(
                                            right: -2,
                                            bottom: -2,
                                            child: Container(
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isPicked ? KoraColors.purple : Colors.transparent,
                                                border: Border.all(
                                                  color: isPicked ? KoraColors.purple : Colors.white,
                                                  width: 2,
                                                ),
                                              ),
                                              child: isPicked
                                                  ? const Icon(Icons.check, color: Colors.white, size: 13)
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    title: Text(
                                      contact['name'] as String,
                                      style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      '${contact['koraId']} · ${contact['username']}',
                                      style: TextStyle(color: textSecondary, fontSize: 13),
                                    ),
                                    onTap: () {
                                      setSheetState(() {
                                        if (isPicked) {
                                          pickedIds.remove(koraId);
                                        } else {
                                          pickedIds.add(koraId);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
                        child: SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: pickedIds.isEmpty
                                ? null
                                : () {
                                    final newMembers = available
                                        .where((c) => pickedIds.contains(c['koraId']))
                                        .toList();
                                    Navigator.pop(sheetContext);
                                    setState(() => _members.addAll(newMembers));
                                  },
                            style: TextButton.styleFrom(
                              backgroundColor: pickedIds.isEmpty
                                  ? textMuted.withValues(alpha: 0.15)
                                  : KoraColors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              pickedIds.isEmpty ? 'Add Members' : 'Add ${pickedIds.length} Member${pickedIds.length == 1 ? '' : 's'}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _removeMember(String koraId) {
    setState(() => _members.removeWhere((m) => m['koraId'] == koraId));
  }

  // ── Create group ──────────────────────────────────────────────

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a group name to continue.'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // No minimum member count required — creating solo is allowed;
    // more people can be added to the group afterward.
    setState(() => _creating = true);

    // Persist the group as a conversation via ChatSyncService.
    final chatId = 'group_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await ChatSyncService.instance.syncConversation(
        chatId: chatId,
        name: name,
        avatarAsset: _groupPhoto?.path,
        isOnline: false,
        lastMessageText: 'Group created',
        lastMessageType: 'system',
        isGroupChat: true,
      );
    } catch (_) {
      // Best-effort sync — group still works locally.
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const KoraHomeScreen()),
      (route) => false,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$name" group created'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon.'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final hint = KoraColors.hintFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: GestureDetector(
        onTap: _creating ? null : _createGroup,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: KoraColors.brandGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: KoraColors.purple.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _creating
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : const Icon(Icons.check_rounded, color: Colors.white, size: 28),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text(
                    'New Group',
                    style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Group photo + name + emoji
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _showPhotoOptions,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: surface,
                            border: Border.all(color: border, width: 1),
                          ),
                          child: ClipOval(
                            child: _groupPhoto != null
                                ? Image.file(_groupPhoto!, fit: BoxFit.cover)
                                : Icon(Icons.camera_alt_outlined, color: textMuted, size: 24),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              gradient: KoraColors.brandGradient,
                              shape: BoxShape.circle,
                              border: Border.all(color: bg, width: 2),
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      autofocus: true,
                      maxLength: 100,
                      style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Enter group name',
                        hintStyle: TextStyle(color: hint, fontSize: 15, fontWeight: FontWeight.w400),
                        counterText: '',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: border, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: border, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: KoraColors.purple, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () { showModalBottomSheet(context: context, builder: (_) => const EmojiPickerSheet()); },
                    child: Icon(Icons.emoji_emotions_outlined, color: textMuted, size: 26),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Divider(height: 1, color: border),

            // Disappearing messages
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DisappearingMessagesScreen())),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Disappearing messages',
                            style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text('Off', style: TextStyle(color: textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.timer_outlined, color: textMuted, size: 22),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: border),

            // Group permissions
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupPermissionsScreen())),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Group permissions',
                        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.settings_outlined, color: textMuted, size: 22),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: border),

            // Members section
            Expanded(
              child: Container(
                width: double.infinity,
                color: surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Text(
                        'Members: ${_members.isEmpty ? 'None' : _members.length}',
                        style: TextStyle(color: textSecondary, fontSize: 13.5),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _buildAddMemberTile(context, textPrimary),
                            ..._members.map((m) => _buildMemberTile(context, m, textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMemberTile(BuildContext context, Color textPrimary) {
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          GestureDetector(
            onTap: _showAddMembersSheet,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                gradient: KoraColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add',
            style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(BuildContext context, Map<String, Object?> member, Color textPrimary) {
    final koraId = member['koraId'] as String;
    final name = member['name'] as String;
    final isPremium = member['premium'] == true;
    final firstName = name.split(' ').first;

    return SizedBox(
      width: 68,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _removeMember(koraId),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                KoraAvatar(name: name, size: 56, isPremium: isPremium),
                Positioned(
                  left: -2,
                  top: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            firstName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
