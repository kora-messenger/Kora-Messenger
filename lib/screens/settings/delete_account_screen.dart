import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../services/account_deletion_service.dart';
import '../../config/kora_api.dart';
import '../../theme/kora_colors.dart';

/// Delete Account screen — permanently wipes the user's account,
/// phone registration, and Voice Vector Matrix from the server.
///
/// Requires password re-entry for security confirmation.
/// Shows a clear warning that this action is irreversible.
class DeleteAccountScreen extends StatefulWidget {
  final String userEmail;
  final String userKoraId;

  const DeleteAccountScreen({
    super.key,
    required this.userEmail,
    required this.userKoraId,
  });

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _checkboxAccepted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning icon
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded, size: 40, color: Colors.red.shade400),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Delete Your Account',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  widget.userEmail,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 28),

              // What will be deleted
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This will permanently delete:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    _deleteItem('Your Kora account and profile'),
                    _deleteItem('All conversations and message history'),
                    _deleteItem('Your Voice Vector Matrix from our servers'),
                    _deleteItem('Phone registration and FCM push tokens'),
                    _deleteItem('All device sessions and trusted devices'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Password confirmation
              const Text(
                'Enter your password to confirm',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmController,
                decoration: InputDecoration(
                  hintText: 'Type "DELETE" to confirm',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.text_fields),
                ),
                inputFormatters: [UpperCaseTextFormatter()],
              ),
              const SizedBox(height: 20),

              // Checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _checkboxAccepted,
                    onChanged: (v) => setState(() => _checkboxAccepted = v ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'I understand this action is irreversible and all my data will be permanently removed.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              // Delete button
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    elevation: 2,
                  ),
                  onPressed: _canDelete() ? _deleteAccount : null,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Delete Account Permanently',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // Account Deletion Policy link
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(KoraApi.accountDeletionPolicyUrl);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: Text(
                    'Read our Account Deletion Policy',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? KoraColors.purple
                          : KoraColors.purple,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canDelete() {
    return _passwordController.text.isNotEmpty &&
           _confirmController.text == 'DELETE' &&
           _checkboxAccepted &&
           !_isLoading;
  }

  Future<void> _deleteAccount() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final (success, error) = await AccountDeletionService.instance.deleteAccount(
      userEmail: widget.userEmail,
      userKoraId: widget.userKoraId,
      confirmPassword: _passwordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        // Navigate to login screen
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      } else {
        setState(() => _errorMessage = error ?? 'Deletion failed. Please try again.');
      }
    }
  }

  Widget _deleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.close, size: 16, color: Colors.red.shade400),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[700]))),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
