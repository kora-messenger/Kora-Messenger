import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/kora_api.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_button.dart';
import 'qr_code_screen.dart';
import 'select_country_screen.dart';
import '../chat/contact_info_screen.dart';
import '../chat/kora_chat_screen.dart';
import '../../models/chat_models.dart';

/// Kora's "New contact" screen — add someone by name, Kora username/ID,
/// or phone number, with an optional toggle to sync them to the phone's
/// native contacts.
///
/// Real-time checking:
/// - Phone numbers are checked against the Kora backend
/// - Usernames are checked against the Kora backend
/// - Kora IDs are validated and checked against the Kora backend
///
/// Users can add a contact with only a username, Kora ID, or phone number
/// without filling in the name fields.
class NewContactScreen extends StatefulWidget {
  const NewContactScreen({super.key});

  @override
  State<NewContactScreen> createState() => _NewContactScreenState();
}

class _NewContactScreenState extends State<NewContactScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  CountryInfo _selectedCountry = allCountries.firstWhere((c) => c.iso == 'NG');
  bool _syncToPhone = false;
  bool _isSaving = false;

  // Phone number checking state
  Timer? _phoneCheckTimer;
  String _fullPhoneNumber = '';
  bool _isCheckingPhone = false;
  bool? _phoneRegistered;
  Map<String, dynamic>? _matchedPhoneUser;
  bool _phoneAlreadyContact = false;

  // Username / Kora ID checking state
  Timer? _usernameCheckTimer;
  bool _isCheckingUsername = false;
  bool? _usernameFound;
  String _usernameCheckType = ''; // 'username' or 'koraId'
  bool _usernameAlreadyContact = false;
  Map<String, dynamic>? _matchedUsernameUser;
  String _usernameErrorMessage = '';

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_onChanged);
    _usernameController.addListener(_onUsernameChanged);
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onChanged() => setState(() {});

  // ── Phone number checking ──────────────────────────────────

  void _onPhoneChanged() {
    final phone = _phoneController.text.trim();
    _fullPhoneNumber = phone.isEmpty ? '' : '$_selectedCountry.dialCode$phone';

    setState(() {
      _phoneRegistered = null;
      _matchedPhoneUser = null;
      _phoneAlreadyContact = false;
    });

    _phoneCheckTimer?.cancel();
    if (phone.isEmpty || phone.length < 4) return;

    _phoneCheckTimer = Timer(const Duration(milliseconds: 600), () {
      _checkPhoneNumber(_fullPhoneNumber);
    });
  }

  Future<void> _checkPhoneNumber(String phoneNumber) async {
    if (!mounted) return;
    setState(() => _isCheckingPhone = true);

    try {
      final res = await http.post(
        Uri.parse(KoraApi.authEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'checkPhoneNumber',
          'phoneNumber': phoneNumber,
        }),
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;
      final data = jsonDecode(res.body);

      if (data['success'] == true && data['registered'] == true) {
        final user = data['user'] as Map<String, dynamic>?;
        // Check if already in contacts
        bool alreadyContact = false;
        if (user != null) {
          alreadyContact = await _isAlreadyContact(
            koraId: user['koraId'] as String?,
            username: user['username'] as String?,
            phone: phoneNumber,
          );
        }
        setState(() {
          _isCheckingPhone = false;
          _phoneRegistered = true;
          _matchedPhoneUser = user;
          _phoneAlreadyContact = alreadyContact;
        });
      } else {
        setState(() {
          _isCheckingPhone = false;
          _phoneRegistered = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCheckingPhone = false);
    }
  }

  // ── Username / Kora ID checking ────────────────────────────

  void _onUsernameChanged() {
    final input = _usernameController.text.trim();

    setState(() {
      _usernameFound = null;
      _matchedUsernameUser = null;
      _usernameAlreadyContact = false;
      _usernameErrorMessage = '';
      _usernameCheckType = '';
    });

    _usernameCheckTimer?.cancel();
    if (input.isEmpty) return;

    _usernameCheckTimer = Timer(const Duration(milliseconds: 600), () {
      _checkUsernameOrKoraId(input);
    });
  }

  Future<void> _checkUsernameOrKoraId(String input) async {
    if (!mounted) return;
    setState(() {
      _isCheckingUsername = true;
      _usernameErrorMessage = '';
    });

    try {
      final res = await http.post(
        Uri.parse(KoraApi.lookupEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'lookupUser',
          'identifier': input,
        }),
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;
      final data = jsonDecode(res.body);

      if (data['success'] == true && data['found'] == true) {
        final user = data['user'] as Map<String, dynamic>?;
        final type = data['type'] as String? ?? 'username';
        bool alreadyContact = false;
        if (user != null) {
          alreadyContact = await _isAlreadyContact(
            koraId: user['koraId'] as String?,
            username: user['username'] as String?,
          );
        }
        setState(() {
          _isCheckingUsername = false;
          _usernameFound = true;
          _usernameCheckType = type;
          _matchedUsernameUser = user;
          _usernameAlreadyContact = alreadyContact;
        });
      } else if (data['success'] == true && data['found'] == false) {
        final type = data['type'] as String? ?? 'username';
        setState(() {
          _isCheckingUsername = false;
          _usernameFound = false;
          _usernameCheckType = type;
          if (type == 'koraId') {
            _usernameErrorMessage = 'Invalid Kora ID';
          }
        });
      } else {
        setState(() {
          _isCheckingUsername = false;
          _usernameFound = false;
          _usernameErrorMessage = data['error'] as String? ?? 'Check failed';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCheckingUsername = false);
    }
  }

  // ── Already-contact check ─────────────────────────────────

  /// Checks if a user (by koraId, username, or phone) is already saved
  /// in the local Kora contacts list (SharedPreferences).
  Future<bool> _isAlreadyContact({
    String? koraId,
    String? username,
    String? phone,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getStringList('kora_contacts') ?? [];

      for (final json in contactsJson) {
        try {
          final contact = jsonDecode(json) as Map<String, dynamic>;
          if (koraId != null && koraId.isNotEmpty) {
            if (contact['koraId'] == koraId) return true;
          }
          if (username != null && username.isNotEmpty) {
            if ((contact['username'] as String? ?? '').toLowerCase() ==
                username.toLowerCase()) {
              return true;
            }
          }
          if (phone != null && phone.isNotEmpty) {
            final storedPhone = (contact['phoneNumber'] as String? ?? '')
                .replaceAll(RegExp(r'\D'), '');
            final checkPhone = phone.replaceAll(RegExp(r'\D'), '');
            if (storedPhone.length >= 9 &&
                checkPhone.length >= 9 &&
                storedPhone.substring(storedPhone.length - 9) ==
                    checkPhone.substring(checkPhone.length - 9)) {
              return true;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return false;
  }

  /// Saves a contact to the local Kora contacts list (SharedPreferences).
  Future<void> _saveLocalContact(Map<String, dynamic> contact) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getStringList('kora_contacts') ?? [];
      contactsJson.add(jsonEncode(contact));
      await prefs.setStringList('kora_contacts', contactsJson);
    } catch (_) {}
  }

  // ── Lifecycle ──────────────────────────────────────────────

  @override
  void dispose() {
    _phoneCheckTimer?.cancel();
    _usernameCheckTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _canSave {
    // Name is optional — user can add with just username, Kora ID, or phone
    final hasIdentifier = _usernameController.text.trim().isNotEmpty ||
        _phoneController.text.trim().isNotEmpty;
    return hasIdentifier;
  }

  Future<void> _pickCountry() async {
    final picked = await Navigator.push<CountryInfo>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectCountryScreen(currentCountry: _selectedCountry),
      ),
    );

    if (picked != null) {
      setState(() => _selectedCountry = picked);
      if (_phoneController.text.trim().isNotEmpty) {
        _onPhoneChanged();
      }
    }
  }

  // ── Sync to phone contacts (optimized) ────────────────────

  Future<bool> _syncToPhoneContacts(String fullName, String phoneNumber) async {
    try {
      // Check permission first without requesting — if already granted, skip
      final status = await Permission.contacts.status;
      if (!status.isGranted) {
        final result = await Permission.contacts.request();
        if (!result.isGranted) return false;
      }

      // Insert directly without reading all contacts
      final newContact = Contact(
        displayName: fullName,
        phones: [Phone(number: phoneNumber)],
      );
      await FlutterContacts.insert(newContact);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Save ───────────────────────────────────────────────────

  void _save() async {
    if (!_canSave || _isSaving) return;
    setState(() => _isSaving = true);

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = lastName.isEmpty ? firstName : '$firstName $lastName';
    final phoneNumber = _phoneController.text.trim().isNotEmpty
        ? '${_selectedCountry.dialCode}${_phoneController.text.trim()}'
        : '';
    final identifier = _usernameController.text.trim();

    // Determine the matched user (from phone or username check)
    Map<String, dynamic>? matchedUser;
    String identifierLabel = '';

    if (_usernameFound == true && _matchedUsernameUser != null) {
      matchedUser = _matchedUsernameUser;
      if (_usernameCheckType == 'koraId') {
        identifierLabel = matchedUser!['koraId'] as String? ?? identifier;
      } else {
        identifierLabel = '@${matchedUser!['username'] as String? ?? identifier}';
      }
    } else if (_phoneRegistered == true && _matchedPhoneUser != null) {
      matchedUser = _matchedPhoneUser;
      identifierLabel = phoneNumber;
    }

    if (matchedUser != null) {
      final name = matchedUser['fullName'] as String? ?? fullName;
      final koraId = matchedUser['koraId'] as String? ?? '';
      final username = matchedUser['username'] as String? ?? '';
      final userPhone = matchedUser['phoneNumber'] as String? ?? phoneNumber;

      // Save to local Kora contacts
      await _saveLocalContact({
        'name': name,
        'koraId': koraId,
        'username': username,
        'phoneNumber': userPhone,
      });

      // Sync to phone if enabled
      if (_syncToPhone && phoneNumber.isNotEmpty) {
        await _syncToPhoneContacts(name.isNotEmpty ? name : fullName, phoneNumber);
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      // Show success snackbar with clickable "Message"
      final label = identifierLabel.isNotEmpty ? identifierLabel : name;
      _showSuccessSnackbar(label, matchedUser);
      return;
    }

    // No matched user — just save locally and sync if enabled
    if (_syncToPhone && phoneNumber.isNotEmpty) {
      await _syncToPhoneContacts(
        fullName.isNotEmpty ? fullName : identifier,
        phoneNumber,
      );
    }

    // Save local contact even if not on Kora
    await _saveLocalContact({
      'name': fullName.isNotEmpty ? fullName : identifier,
      'koraId': '',
      'username': identifier.startsWith('@') ? identifier.substring(1) : identifier,
      'phoneNumber': phoneNumber,
    });

    if (!mounted) return;
    setState(() => _isSaving = false);

    final label = fullName.isNotEmpty ? fullName : identifier;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label added to contacts'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  void _showSuccessSnackbar(String label, Map<String, dynamic> user) {
    final name = user['fullName'] as String? ?? label;
    final koraId = user['koraId'] as String? ?? '';
    final username = user['username'] as String? ?? '';
    final userPhone = user['phoneNumber'] as String? ?? '';

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(
              child: Text(
                '$label was added to your Kora contact.',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                Navigator.pop(context); // Close NewContactScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => KoraChatScreen(
                      chatId: koraId.isNotEmpty ? koraId : username,
                      name: name,
                      badge: KoraBadgeType.none,
                      isOnline: true,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Message',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );

    // Pop after a short delay so the user sees the snackbar
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void _viewContactProfile(Map<String, dynamic> user) {
    final name = user['fullName'] as String? ?? '';
    final koraId = user['koraId'] as String? ?? '';
    final username = user['username'] as String? ?? '';
    final userPhone = user['phoneNumber'] as String? ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactInfoScreen(
          name: name,
          koraId: koraId,
          username: username,
          phone: userPhone,
          badge: KoraBadgeType.none,
          isOnline: true,
          about: 'Hey there! I\'m on Kora.',
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New contact',
          style: TextStyle(color: textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_2_rounded, color: textPrimary, size: 26),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const QrCodeScreen()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconFieldGroup(
                icon: Icons.person_outline,
                children: [
                  _OutlinedField(hintText: 'First name', controller: _firstNameController),
                  const SizedBox(height: 12),
                  _OutlinedField(hintText: 'Last name', controller: _lastNameController),
                ],
              ),
              const SizedBox(height: 16),

              // ── Username / Kora ID field ──
              _iconFieldGroup(
                icon: Icons.alternate_email,
                children: [
                  _OutlinedField(
                    hintText: 'Username or Kora ID',
                    controller: _usernameController,
                    borderColor: _usernameFieldBorderColor(brightness),
                    suffixIcon: _buildUsernameSuffixIcon(),
                  ),
                  if (_usernameController.text.trim().isNotEmpty &&
                      !_isCheckingUsername) ...[
                    const SizedBox(height: 8),
                    _buildUsernameStatus(),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ── Phone number field with country picker ──
              _iconFieldGroup(
                icon: Icons.call_outlined,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _pickCountry,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Country',
                              style: TextStyle(color: textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 52,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              constraints: const BoxConstraints(minWidth: 96),
                              decoration: BoxDecoration(
                                border: Border.all(color: KoraColors.borderFor(brightness)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_selectedCountry.flagEmoji} ${_selectedCountry.dialCode}',
                                    style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.keyboard_arrow_down, color: textSecondary, size: 20),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _OutlinedField(
                                hintText: 'Phone',
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                suffixIcon: _buildPhoneSuffixIcon(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Phone status — full width below the entire row
                  if (_phoneController.text.trim().isNotEmpty &&
                      !_isCheckingPhone &&
                      _phoneRegistered != null) ...[
                    const SizedBox(height: 8),
                    _buildPhoneStatus(),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.sync, color: textSecondary, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sync contact to phone',
                          style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Only contacts with a phone number can be synced',
                          style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _syncToPhone,
                    onChanged: _phoneController.text.trim().isEmpty
                        ? null
                        : (value) => setState(() => _syncToPhone = value),
                    activeThumbColor: KoraColors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 40),
              KoraButton(
                label: 'Save',
                isLoading: _isSaving,
                onPressed: _canSave ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Username field helpers ──

  Color? _usernameFieldBorderColor(Brightness brightness) {
    if (_isCheckingUsername || _usernameController.text.trim().isEmpty) {
      return null; // default
    }
    if (_usernameFound == true) {
      return Colors.green;
    }
    if (_usernameFound == false) {
      return Colors.red;
    }
    return null;
  }

  Widget? _buildUsernameSuffixIcon() {
    if (_isCheckingUsername) {
      return const Padding(
        padding: EdgeInsets.only(right: 14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: KoraColors.purple,
          ),
        ),
      );
    }
    if (_usernameFound == true) {
      return const Padding(
        padding: EdgeInsets.only(right: 14),
        child: Icon(Icons.check_circle, color: Colors.green, size: 22),
      );
    }
    if (_usernameFound == false && _usernameController.text.trim().isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.only(right: 14),
        child: Icon(Icons.warning, color: Colors.red, size: 22),
      );
    }
    return null;
  }

  Widget _buildUsernameStatus() {
    final brightness = Theme.of(context).brightness;
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    if (_usernameFound == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 15),
              const SizedBox(width: 6),
              Text(
                'This username is on Kora Messenger',
                style: TextStyle(
                  color: Colors.green.shade600,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (_usernameAlreadyContact && _matchedUsernameUser != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _viewContactProfile(_matchedUsernameUser!),
              child: Row(
                children: [
                  Icon(Icons.person, color: KoraColors.purple, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    'This person is already in your Kora contact.',
                    style: TextStyle(
                      color: KoraColors.purple,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _viewContactProfile(_matchedUsernameUser!),
                    child: Text(
                      'View User Contact',
                      style: TextStyle(
                        color: KoraColors.purple,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    // Not found
    if (_usernameCheckType == 'koraId' && _usernameErrorMessage.isNotEmpty) {
      return Row(
        children: [
          const Icon(Icons.warning, color: Colors.red, size: 15),
          const SizedBox(width: 6),
          Text(
            _usernameErrorMessage,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.info_outline, color: textSecondary, size: 15),
        const SizedBox(width: 6),
        Text(
          'This username is not on Kora Messenger',
          style: TextStyle(
            color: textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Phone field helpers ──

  Widget? _buildPhoneSuffixIcon() {
    if (_isCheckingPhone) {
      return const Padding(
        padding: EdgeInsets.only(right: 14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: KoraColors.purple,
          ),
        ),
      );
    }
    if (_phoneRegistered == true) {
      return const Padding(
        padding: EdgeInsets.only(right: 14),
        child: Icon(Icons.check_circle, color: Colors.green, size: 22),
      );
    }
    if (_phoneRegistered == false) {
      return const Padding(
        padding: EdgeInsets.only(right: 14),
        child: Icon(Icons.info_outline, color: Colors.red, size: 22),
      );
    }
    return null;
  }

  Widget _buildPhoneStatus() {
    final brightness = Theme.of(context).brightness;
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    if (_phoneRegistered == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 15),
              const SizedBox(width: 6),
              Text(
                'This phone number is on Kora Messenger',
                style: TextStyle(
                  color: Colors.green.shade600,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (_phoneAlreadyContact && _matchedPhoneUser != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person, color: KoraColors.purple, size: 15),
                const SizedBox(width: 6),
                Text(
                  'This person is already in your Kora contact.',
                  style: TextStyle(
                    color: KoraColors.purple,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _viewContactProfile(_matchedPhoneUser!),
                  child: Text(
                    'View User Contact',
                    style: TextStyle(
                      color: KoraColors.purple,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.info_outline, color: textSecondary, size: 15),
        const SizedBox(width: 6),
        Text(
          'This phone number is not on Kora Messenger',
          style: TextStyle(
            color: textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _iconFieldGroup({required IconData icon, required List<Widget> children}) {
    final brightness = Theme.of(context).brightness;
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Icon(icon, color: textSecondary, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

/// Plain outlined field — rounded border, hint-only (no floating label),
/// matching the reference "New contact" design.
/// Supports a custom border color for validation states.
class _OutlinedField extends StatelessWidget {
  final String hintText;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final Color? borderColor;

  const _OutlinedField({
    required this.hintText,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final hintColor = KoraColors.hintFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final effectiveBorder = borderColor ?? border;
    final focusedColor = borderColor ?? KoraColors.purple;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: textPrimary, fontSize: 15.5, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: hintColor, fontSize: 15.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: effectiveBorder),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: effectiveBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: focusedColor, width: 1.6),
        ),
      ),
    );
  }
}
