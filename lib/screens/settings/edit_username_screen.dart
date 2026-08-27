import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// Screen to edit username with validation (min 3 chars, alphanumeric + underscore).
class EditUsernameScreen extends StatefulWidget {
  const EditUsernameScreen({super.key});

  @override
  State<EditUsernameScreen> createState() => _EditUsernameScreenState();
}

class _EditUsernameScreenState extends State<EditUsernameScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('kora_username') ?? '';
    _controller.text = stored;
    setState(() => _isLoading = false);
  }

  void _validate(String val) {
    val = val.trim();
    if (val.isEmpty) {
      setState(() => _errorText = 'Username cannot be empty');
      return;
    }
    if (val.length < 3) {
      setState(() => _errorText = 'Username must be at least 3 characters');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(val)) {
      setState(() => _errorText = 'Only letters, numbers, and underscores allowed');
      return;
    }
    setState(() => _errorText = null);
  }

  Future<void> _saveUsername() async {
    final text = _controller.text.trim();
    _validate(text);
    if (_errorText != null) return;

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kora_username', text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username saved successfully')),
      );
      Navigator.pop(context, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Edit username',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : Padding(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Choose a username',
                  style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'People on Kora will be able to search for you by this username.',
                  style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  onChanged: _validate,
                  style: TextStyle(color: textPrimary, fontSize: 16),
                  decoration: InputDecoration(
                    prefixText: '@',
                    prefixStyle: const TextStyle(color: KoraColors.purple, fontSize: 18, fontWeight: FontWeight.bold),
                    labelText: 'Username',
                    labelStyle: TextStyle(color: textSecondary),
                    errorText: _errorText,
                    filled: true,
                    fillColor: card,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: KoraColors.purple, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: KoraColors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: KoraColors.red, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KoraColors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: _isSaving ? null : _saveUsername,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Save', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
    );
  }
}
