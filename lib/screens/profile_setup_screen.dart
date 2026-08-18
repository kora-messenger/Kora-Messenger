import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/kora_colors.dart';
import '../widgets/kora_button.dart';
import '../widgets/kora_input.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import 'kora_home_screen.dart';

/// Profile Setup — shown after successful registration verification.
///
/// Lets the user add a profile photo, confirm their name and username
/// (with live availability checking), see their generated Kora ID, and
/// write an optional bio before entering the main Kora experience.
///
/// Adapts to both light and dark mode via [Theme.of].
class ProfileSetupScreen extends StatefulWidget {
  final String email;
  final Map<String, dynamic>? userData;

  const ProfileSetupScreen({
    super.key,
    required this.email,
    this.userData,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final AuthService _auth = AuthService.instance;
  final ImagePicker _picker = ImagePicker();

  // Controllers
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  // State
  late final String _koraId;
  File? _photo;
  UsernameStatus _usernameStatus = UsernameStatus.idle;
  String _usernameMessage = '';
  Timer? _usernameTimer;
  bool _isContinuing = false;

  // Constants
  static const int _bioLimit = 150;

  @override
  void initState() {
    super.initState();
    _koraId = _auth.generateKoraId();

    // Pre-fill from signup data if available
    final name = widget.userData?['fullName'] as String? ?? '';
    final username = widget.userData?['username'] as String? ?? '';
    _nameController.text = name;
    _usernameController.text = username;

    // If username came from signup, it was already validated — mark as
    // available so the user isn't told their own username is taken.
    if (username.isNotEmpty) {
      _usernameStatus = UsernameStatus.available;
      _usernameMessage = 'Available';
    }
  }

  @override
  void dispose() {
    _usernameTimer?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ── Theme helpers ──────────────────────────────────────────

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => KoraColors.backgroundFor(Theme.of(context).brightness);
  Color get _card => KoraColors.cardFor(Theme.of(context).brightness);
  Color get _surface => KoraColors.surfaceFor(Theme.of(context).brightness);
  Color get _textPrimary => KoraColors.textPrimaryFor(Theme.of(context).brightness);
  Color get _textSecondary => KoraColors.textSecondaryFor(Theme.of(context).brightness);
  Color get _textMuted => KoraColors.textMutedFor(Theme.of(context).brightness);
  Color get _border => KoraColors.borderFor(Theme.of(context).brightness);

  // ── Username availability ─────────────────────────────────

  void _onUsernameChanged(String value) {
    _usernameTimer?.cancel();

    setState(() {
      if (value.isEmpty) {
        _usernameStatus = UsernameStatus.idle;
        _usernameMessage = '';
      } else if (value.length < 3) {
        _usernameStatus = UsernameStatus.tooShort;
        _usernameMessage = 'Too short';
      } else {
        _usernameStatus = UsernameStatus.checking;
        _usernameMessage = 'Checking...';
        _usernameTimer = Timer(const Duration(milliseconds: 500), () {
          _checkUsernameAvailability(value);
        });
      }
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    final result = await _auth.checkUsername(username);
    if (mounted) {
      setState(() {
        _usernameStatus = result.status;
        _usernameMessage = result.message;
      });
    }
  }

  // ── Profile photo ──────────────────────────────────────────

  void _showPhotoOptions() {
    final isDark = _isDark;
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
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
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery();
                },
              ),
              _sheetOption(
                icon: Icons.camera_alt_outlined,
                label: 'Take Photo',
                onTap: () {
                  Navigator.pop(context);
                  _pickFromCamera();
                },
              ),
              if (_photo != null)
                _sheetOption(
                  icon: Icons.delete_outline,
                  label: 'Remove Photo',
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _photo = null);
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
    Color? color,
  }) {
    final c = color ?? _textPrimary;
    return ListTile(
      leading: Icon(icon, color: c, size: 24),
      title: Text(
        label,
        style: TextStyle(
          color: c,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (xfile != null && mounted) {
        setState(() => _photo = File(xfile.path));
      }
    } on Exception catch (_) {
      // Permission denied or picker cancelled — silently ignore
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (xfile != null && mounted) {
        setState(() => _photo = File(xfile.path));
      }
    } on Exception catch (_) {
      // Permission denied or camera unavailable — silently ignore
    }
  }

  // ── Validation ─────────────────────────────────────────────

  bool get _canContinue {
    return _nameController.text.trim().isNotEmpty &&
        _usernameStatus == UsernameStatus.available;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  // ── Continue ───────────────────────────────────────────────

  Future<void> _continue() async {
    if (!_canContinue) return;

    setState(() => _isContinuing = true);

    final userId = widget.userData?['id']?.toString() ?? '';
    if (userId.isEmpty) {
      // No user ID from signup — go straight to home
      _navigateHome();
      return;
    }

    final result = await _auth.saveProfile(
      userId: userId,
      fullName: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      bio: _bioController.text.trim(),
      avatarUrl: '', // TODO: upload photo to storage, then pass URL
    );

    if (!mounted) return;

    if (result.success) {
      // Save the updated session so the app remembers login on restart
      if (result.user != null) {
        await SessionManager.instance.saveSession(result.user!);
      }
      _navigateHome();
    } else {
      setState(() => _isContinuing = false);
      _showError(result.error ?? 'Failed to save profile. Please try again.');
    }
  }

  void _navigateHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const KoraHomeScreen()),
      (route) => false,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Heading
                        Text(
                'Set Up Your Profile',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
                        Text(
                'Tell people a little about you. You can change these details later in Settings.',
                style: TextStyle(color: _textSecondary, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 32),

              // Profile photo
              _buildPhotoSection(),
              const SizedBox(height: 32),

              // Full name (required)
              _buildSectionLabel('Full Name', required: true),
              const SizedBox(height: 8),
              KoraInput(
                label: 'Full Name',
                controller: _nameController,
                keyboardType: TextInputType.name,
                validator: _validateName,
                adaptive: true,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.person_outline, color: _textMuted, size: 22),
                ),
              ),
              const SizedBox(height: 20),

              // Username (required) with availability
              _buildSectionLabel('Username', required: true),
              const SizedBox(height: 8),
              _buildUsernameField(),
              const SizedBox(height: 20),

              // Kora ID
              _buildAutoLabel('Kora ID'),
              const SizedBox(height: 8),
              _buildKoraIdSection(),
              const SizedBox(height: 20),

              // Bio (optional)
              _buildSectionLabel('Bio', required: false),
              const SizedBox(height: 8),
              _buildBioField(),
              const SizedBox(height: 28),

              // Continue
              KoraButton(
                label: 'Continue',
                onPressed: _canContinue ? _continue : null,
                isLoading: _isContinuing,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: _textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  // ── Section label ───────────────────────────────────────────

  Widget _buildSectionLabel(String label, {bool required = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(color: KoraColors.purple, fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ] else ...[
          const SizedBox(width: 6),
          Text(
            '(optional)',
            style: TextStyle(color: _textMuted, fontSize: 13),
          ),
        ],
      ],
    );
  }

  /// A label for auto-generated, non-editable fields (no optional text, no asterisk).
  Widget _buildAutoLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: _textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ── Profile photo section ──────────────────────────────────

  Widget _buildPhotoSection() {
    final initials = _getInitials(_nameController.text);

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showPhotoOptions,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _surface,
                border: Border.all(
                  color: _photo != null ? KoraColors.purple : _border,
                  width: _photo != null ? 2.5 : 2,
                ),
              ),
              child: ClipOval(
                child: _photo != null
                    ? Image.file(_photo!, fit: BoxFit.cover)
                    : _buildDefaultAvatar(initials),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _showPhotoOptions,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _photo != null ? Icons.edit : Icons.camera_alt_outlined,
                  color: KoraColors.purple,
                  size: 16,
                ),
                const SizedBox(width: 6),
                          Text(
                  _photo != null ? 'Change Photo' : 'Add Photo',
                  style: const TextStyle(
                    color: KoraColors.purple,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(String initials) {
    return Container(
      decoration: const BoxDecoration(gradient: KoraColors.brandGradient),
      child: Center(
        child: initials.isNotEmpty
            ? Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                ),
              )
            : const Icon(Icons.person, color: Colors.white, size: 44),
      ),
    );
  }

  // ── Username field with availability ───────────────────────

  Widget _buildUsernameField() {
    return Column(
      children: [
        KoraInput(
          label: 'Username',
          controller: _usernameController,
          keyboardType: TextInputType.text,
          adaptive: true,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(Icons.alternate_email, color: _textMuted, size: 22),
          ),
          suffixIcon: _buildUsernameSuffix(),
          hintText: 'e.g. john_doe',
          onChanged: _onUsernameChanged,
        ),
        if (_usernameStatus != UsernameStatus.idle &&
            _usernameStatus != UsernameStatus.checking)
          _buildUsernameStatusRow(),
        if (_usernameStatus == UsernameStatus.checking)
          _buildUsernameCheckingRow(),
      ],
    );
  }

  Widget? _buildUsernameSuffix() {
    switch (_usernameStatus) {
      case UsernameStatus.checking:
        return const Padding(
          padding: EdgeInsets.only(right: 14),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: KoraColors.purple),
          ),
        );
      case UsernameStatus.available:
        return const Padding(
          padding: EdgeInsets.only(right: 14),
          child: Icon(Icons.check_circle, color: Colors.green, size: 22),
        );
      case UsernameStatus.taken:
      case UsernameStatus.reserved:
      case UsernameStatus.invalid:
      case UsernameStatus.tooShort:
        return const Padding(
          padding: EdgeInsets.only(right: 14),
          child: Icon(Icons.cancel, color: Colors.redAccent, size: 22),
        );
      case UsernameStatus.idle:
        return null;
    }
  }

  Widget _buildUsernameStatusRow() {
    final isPositive = _usernameStatus == UsernameStatus.available;
    final color = isPositive ? Colors.green : Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.check : Icons.error_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 6),
                    Text(
            _usernameMessage,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameCheckingRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: KoraColors.purple),
          ),
          const SizedBox(width: 6),
                    Text(
            _usernameMessage,
            style: TextStyle(color: _textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Kora ID section ────────────────────────────────────────

  Widget _buildKoraIdSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KoraColors.purple.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: KoraColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fingerprint, color: KoraColors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                              Text(
                      _koraId,
                      style: const TextStyle(
                        color: KoraColors.purple,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                              Text(
                      'Your unique identity on Kora',
                      style: TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
                    Text(
            'Others can find and connect with you using this ID.',
            style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.3),
          ),
        ],
      ),
    );
  }

  // ── Bio field ──────────────────────────────────────────────

  Widget _buildBioField() {
    return KoraInput(
      label: 'Bio',
      controller: _bioController,
      keyboardType: TextInputType.multiline,
      adaptive: true,
      maxLines: 3,
      maxLength: _bioLimit,
      hintText: 'Write a short description about yourself...',
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10, top: 14),
        child: Icon(Icons.edit_outlined, color: _textMuted, size: 22),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else {
      return trimmed[0].toUpperCase();
    }
  }
}
