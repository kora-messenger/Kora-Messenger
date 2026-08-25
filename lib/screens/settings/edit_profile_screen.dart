import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import '../../theme/kora_colors.dart';
import '../../services/session_manager.dart';
import '../../config/kora_api.dart';
import '../../theme/chat_theme_provider.dart';

/// Edit Profile screen — lets the user edit their name, bio, and avatar.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  Map<String, dynamic>? _session;
  bool _loading = true;
  bool _saving = false;

  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await SessionManager.instance.loadSession();
    if (mounted) {
      setState(() {
        _session = session;
        _nameController.text = session?['fullName']?.toString() ?? '';
        _usernameController.text = session?['username']?.toString() ?? '';
        _bioController.text = session?['bio']?.toString() ?? '';
        _avatarUrl = session?['avatarUrl']?.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Fallback avatar with initials on a gradient background.
  /// Used when the avatar file/URL is missing or fails to load.
  Widget _buildInitialsCircle() {
    final initials = _nameController.text.isNotEmpty
        ? _nameController.text[0].toUpperCase()
        : 'K';
    return Container(
      decoration: const BoxDecoration(gradient: KoraColors.brandGradient),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  bool _uploadingAvatar = false;

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (picked == null) return;

      // Read file bytes and convert to base64
      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = picked.mimeType ?? 'image/jpeg';

      setState(() => _uploadingAvatar = true);

      // Upload to server
      final response = await http.post(
        Uri.parse(KoraApi.uploadEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'uploadAvatar',
          'imageBase64': base64Image,
          'fileName': 'avatar_${_session?['id'] ?? DateTime.now().millisecondsSinceEpoch}.${mimeType.contains('png') ? 'png' : 'jpg'}',
          'fileType': mimeType,
        }),
      ).timeout(const Duration(seconds: 60));

      final data = jsonDecode(response.body);
      if (!mounted) return;

      if (data['success'] == true && data['url'] != null) {
        setState(() {
          _avatarUrl = data['url'] as String;
          _uploadingAvatar = false;
        });
      } else {
        setState(() => _uploadingAvatar = false);
        _showError(data['error'] as String? ?? 'Failed to upload image');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not pick or upload image. Check your connection.'),
          backgroundColor: KoraColors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final bio = _bioController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Name cannot be empty'),
          backgroundColor: KoraColors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Username cannot be empty'),
          backgroundColor: KoraColors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final result = await KoraApi.post({
        'action': 'saveProfile',
        'userId': _session?['id'],
        'fullName': name,
        'username': username,
        'bio': bio,
        'avatarUrl': _avatarUrl ?? '',
      });

      if (!mounted) return;

      if (result['success'] == true) {
        // Update local session
        await SessionManager.instance.updateSession({
          ...?_session,
          'fullName': name,
          'username': username,
          'bio': bio,
          'avatarUrl': _avatarUrl ?? '',
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: KoraColors.purple,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        _showError(result['error'] as String? ?? 'Failed to update profile');
      }
    } catch (e) {
      _showError('Network error. Check your connection and try again.');
    }

    if (mounted) setState(() => _saving = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: KoraColors.red,
        behavior: SnackBarBehavior.floating,
      ),
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
    final border = KoraColors.borderFor(brightness);

    final koraId = _session?['koraId']?.toString() ?? '';
    final isPremium = ChatThemeProvider.instance.isPremium;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: KoraColors.purple),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: KoraColors.purple,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                // Avatar
                Center(
                  child: GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: KoraColors.brandGradient,
                          ),
                          child: _uploadingAvatar
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : _avatarUrl != null && _avatarUrl!.isNotEmpty
                                  ? ClipOval(
                                      child: _avatarUrl!.startsWith('http')
                                          ? Image.network(_avatarUrl!, fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => _buildInitialsCircle(),
                                            )
                                          : (_avatarUrl!.startsWith('/') && File(_avatarUrl!).existsSync()
                                              ? Image.file(File(_avatarUrl!), fit: BoxFit.cover)
                                              : _buildInitialsCircle()),
                                    )
                                  : Center(
                                      child: Text(
                                        (_nameController.text.isNotEmpty
                                            ? _nameController.text[0].toUpperCase()
                                            : 'K'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 40,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: KoraColors.purple,
                              shape: BoxShape.circle,
                              border: Border.all(color: bg, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Tap to change photo',
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 28),

                // Name
                _buildField(
                  label: 'Name',
                  controller: _nameController,
                  card: card,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  border: border,
                ),
                const SizedBox(height: 16),

                // Username
                _buildField(
                  label: 'Username',
                  controller: _usernameController,
                  prefix: '@',
                  card: card,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  border: border,
                ),
                const SizedBox(height: 16),

                // Bio
                _buildField(
                  label: 'Bio',
                  controller: _bioController,
                  maxLines: 3,
                  card: card,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  border: border,
                ),
                const SizedBox(height: 24),

                // Kora ID (read-only)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: KoraColors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.alternate_email_rounded, color: KoraColors.purple, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kora ID',
                              style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              koraId.isNotEmpty ? koraId : 'Not set',
                              style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.lock_outline, color: KoraColors.purple, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your Kora ID is unique and cannot be changed.',
                  style: TextStyle(color: textMuted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? prefix,
    int maxLines = 1,
    required Color card,
    required Color textPrimary,
    required Color textMuted,
    required Color border,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              color: textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 0.5),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(color: textPrimary, fontSize: 15),
            decoration: InputDecoration(
              prefixText: prefix,
              prefixStyle: TextStyle(color: textMuted, fontSize: 15),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
              hintText: label,
              hintStyle: TextStyle(color: textMuted, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
