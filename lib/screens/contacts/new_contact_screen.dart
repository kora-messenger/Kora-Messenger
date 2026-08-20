import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_button.dart';
import 'qr_code_screen.dart';
import '../chat/contact_info_screen.dart';
import '../../models/chat_models.dart';
import '../../data/mock_contacts.dart';

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
/// native contacts. Matches Kora's design language: adaptive light/dark
/// surfaces, purple accent, rounded-outline fields with a leading icon.
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

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_onChanged);
    _usernameController.addListener(_onChanged);
    _phoneController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
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
    }
  }

  /// Tries to match the entered username/Kora ID to a known Kora
  /// user. If found, opens their profile screen directly.
  /// Otherwise, saves the contact with the entered info and shows
  /// a confirmation.
  void _save() {
    if (!_canSave || _isSaving) return;
    setState(() => _isSaving = true);

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = lastName.isEmpty ? firstName : '$firstName $lastName';
    final identifier = _usernameController.text.trim().toLowerCase();

    // Try to find the user on Kora by username/Kora ID
    Map<String, Object>? match;
    if (identifier.isNotEmpty) {
      for (final contact in koraMockContacts) {
        final koraId = (contact['koraId'] as String).toLowerCase();
        final username = (contact['username'] as String).toLowerCase();
        final usernameClean = username.replaceAll('@', '');
        if (koraId == identifier || username == identifier || usernameClean == identifier) {
          match = contact;
          break;
        }
      }
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _isSaving = false);

      if (match != null) {
        // Contact found on Kora — pop the New Contact screen and
        // immediately open their profile.
        final name = match['name'] as String;
        final koraId = match['koraId'] as String;
        final username = match['username'] as String;
        final isPremium = match['premium'] as bool;

        Navigator.pop(context); // Close NewContactScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContactInfoScreen(
              name: name,
              koraId: koraId,
              username: username,
              badge: isPremium ? KoraBadgeType.premiumBlue : KoraBadgeType.none,
              isOnline: true,
              about: 'Hey there! I\'m on Kora.',
            ),
          ),
        );
      } else {
        // No match — save as a local contact
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fullName added to contacts'),
            backgroundColor: KoraColors.purple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
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
                          child: _OutlinedField(
                            hintText: 'Phone',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
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

  const _OutlinedField({
    required this.hintText,
    required this.controller,
    this.keyboardType = TextInputType.text,
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
