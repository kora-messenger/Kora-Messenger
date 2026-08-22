import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../../config/kora_api.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_button.dart';
import 'qr_code_screen.dart';
import '../chat/contact_info_screen.dart';
import '../../models/chat_models.dart';

/// A small dial-code entry for the country picker sheet.
class _DialCountry {
  final String name;
  final String iso;
  final String dialCode;
  const _DialCountry(this.name, this.iso, this.dialCode);
}

const List<_DialCountry> _kDialCountries = [
  _DialCountry('Nigeria', 'NG', '+234'),
  _DialCountry('United States', 'US', '+1'),
  _DialCountry('United Kingdom', 'GB', '+44'),
  _DialCountry('Ghana', 'GH', '+233'),
  _DialCountry('Kenya', 'KE', '+254'),
  _DialCountry('South Africa', 'ZA', '+27'),
  _DialCountry('Canada', 'CA', '+1'),
  _DialCountry('India', 'IN', '+91'),
  _DialCountry('Germany', 'DE', '+49'),
  _DialCountry('France', 'FR', '+33'),
  _DialCountry('United Arab Emirates', 'AE', '+971'),
  _DialCountry('Egypt', 'EG', '+20'),
];

/// Kora's "New contact" screen — add someone by name, Kora username/ID,
/// or phone number, with an optional toggle to sync them to the phone's
/// native contacts. Phone numbers are checked against the Kora backend
/// in real time to show whether the number is registered.
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

  _DialCountry _selectedCountry = _kDialCountries.first;
  bool _syncToPhone = false;
  bool _isSaving = false;

  // Phone number checking state
  Timer? _phoneCheckTimer;
  String _fullPhoneNumber = '';
  bool _isCheckingPhone = false;
  bool? _phoneRegistered; // null = not checked, true = registered, false = not registered
  Map<String, dynamic>? _matchedUser;

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_onChanged);
    _usernameController.addListener(_onChanged);
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onChanged() => setState(() {});

  void _onPhoneChanged() {
    final phone = _phoneController.text.trim();
    _fullPhoneNumber = phone.isEmpty ? '' : '$_selectedCountry.dialCode$phone';

    // Reset state
    setState(() {
      _phoneRegistered = null;
      _matchedUser = null;
    });

    // Cancel any pending check
    _phoneCheckTimer?.cancel();

    if (phone.isEmpty || phone.length < 4) return;

    // Debounce: check after 600ms of typing stopping
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
      if (data['success'] == true) {
        setState(() {
          _isCheckingPhone = false;
          _phoneRegistered = data['registered'] == true;
          _matchedUser = _phoneRegistered == true ? data['user'] : null;
        });
      } else {
        setState(() => _isCheckingPhone = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCheckingPhone = false);
    }
  }

  @override
  void dispose() {
    _phoneCheckTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _canSave {
    final hasName = _firstNameController.text.trim().isNotEmpty;
    final hasIdentifier = _usernameController.text.trim().isNotEmpty ||
        _phoneController.text.trim().isNotEmpty;
    return hasName && hasIdentifier;
  }

  Future<void> _pickCountry() async {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final border = KoraColors.borderFor(brightness);

    final picked = await showModalBottomSheet<_DialCountry>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Select a country',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: _kDialCountries.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: border),
                      itemBuilder: (context, index) {
                        final country = _kDialCountries[index];
                        return ListTile(
                          title: Text(country.name, style: TextStyle(color: textPrimary, fontSize: 15)),
                          trailing: Text(country.dialCode, style: TextStyle(color: textSecondary, fontSize: 15)),
                          onTap: () => Navigator.pop(context, country),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedCountry = picked);
      // Re-check phone with new dial code if there's a number entered
      if (_phoneController.text.trim().isNotEmpty) {
        _onPhoneChanged();
      }
    }
  }

  /// Syncs the contact to the phone's native address book using
  /// flutter_contacts. Requests the contacts permission first.
  Future<bool> _syncToPhoneContacts(String fullName, String phoneNumber) async {
    try {
      // Request permission
      final permission = await Permission.contacts.request();
      if (!permission.isGranted) return false;

      // Create a new contact in the device's address book
      final newContact = Contact(
        displayName: fullName,
        phones: [
          Phone(phoneNumber, label: PhoneLabel.mobile),
        ],
      );

      await newContact.insert();
      return true;
    } catch (e) {
      return false;
    }
  }

  void _save() async {
    if (!_canSave || _isSaving) return;
    setState(() => _isSaving = true);

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = lastName.isEmpty ? firstName : '$firstName $lastName';
    final phoneNumber = _phoneController.text.trim().isNotEmpty
        ? '${_selectedCountry.dialCode}${_phoneController.text.trim()}'
        : '';

    // If phone number is registered on Kora, open their profile directly
    if (_phoneRegistered == true && _matchedUser != null) {
      final user = _matchedUser!;
      final name = user['fullName'] as String? ?? fullName;
      final koraId = user['koraId'] as String? ?? '';
      final username = user['username'] as String? ?? '';

      // Still sync to phone if enabled
      if (_syncToPhone && phoneNumber.isNotEmpty) {
        await _syncToPhoneContacts(fullName, phoneNumber);
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      Navigator.pop(context); // Close NewContactScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContactInfoScreen(
            name: name,
            koraId: koraId,
            username: username,
            badge: KoraBadgeType.none,
            isOnline: true,
            about: 'Hey there! I\'m on Kora.',
          ),
        ),
      );
      return;
    }

    // Sync to phone contacts if enabled
    if (_syncToPhone && phoneNumber.isNotEmpty) {
      final synced = await _syncToPhoneContacts(fullName, phoneNumber);
      if (!mounted) return;
      if (synced) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fullName added to contacts and synced to phone'),
            backgroundColor: KoraColors.purple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fullName added to contacts (phone sync failed)'),
            backgroundColor: KoraColors.purple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$fullName added to contacts'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pop(context);
  }

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
              _iconFieldGroup(
                icon: Icons.alternate_email,
                children: [
                  _OutlinedField(
                    hintText: 'Username or Kora ID',
                    controller: _usernameController,
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                                    '${_selectedCountry.iso} ${_selectedCountry.dialCode}',
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
                              if (_phoneController.text.trim().isNotEmpty &&
                                  !_isCheckingPhone &&
                                  _phoneRegistered != null) ...[
                                const SizedBox(height: 8),
                                _buildPhoneStatus(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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

  /// Builds the suffix icon for the phone input field:
  /// - Loading spinner when checking
  /// - Green checkmark when registered
  /// - Nothing when not registered (description below handles it)
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
        child: Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 22,
        ),
      );
    }
    return null;
  }

  /// Builds the description text below the phone input:
  /// - "This number is on Kora Messenger" (green) when registered
  /// - "This phone number is not on Kora Messenger" (muted) when not registered
  Widget _buildPhoneStatus() {
    final brightness = Theme.of(context).brightness;

    if (_phoneRegistered == true) {
      return Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 15),
          const SizedBox(width: 6),
          Text(
            'This number is on Kora Messenger',
            style: TextStyle(
              color: Colors.green.shade600,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(
          Icons.info_outline,
          color: KoraColors.textSecondaryFor(brightness),
          size: 15,
        ),
        const SizedBox(width: 6),
        Text(
          'This phone number is not on Kora Messenger',
          style: TextStyle(
            color: KoraColors.textSecondaryFor(brightness),
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
class _OutlinedField extends StatelessWidget {
  final String hintText;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final Widget? suffixIcon;

  const _OutlinedField({
    required this.hintText,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final hintColor = KoraColors.hintFor(brightness);
    final border = KoraColors.borderFor(brightness);

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
          borderSide: BorderSide(color: border),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KoraColors.purple, width: 1.6),
        ),
      ),
    );
  }
}
