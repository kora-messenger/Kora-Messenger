import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/chat_vault_service.dart';
import '../../theme/kora_colors.dart';

/// Chat lock settings screen to toggle chat locking persistence,
/// set a Secret Code, hide locked chats, and explain vault features.
class ChatLockScreen extends StatefulWidget {
  const ChatLockScreen({super.key});

  @override
  State<ChatLockScreen> createState() => _ChatLockScreenState();
}

class _ChatLockScreenState extends State<ChatLockScreen> {
  static const String _key = 'chat_lock_enabled';
  static const String _privacyKey = 'kora_privacy_chat_lock';

  bool _enabled = false;
  bool _hideLocked = false;
  bool _hasSecretCode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final hideLocked = await ChatVaultService.instance.isHidden();
    final hasCode = await ChatVaultService.instance.hasSecretCode();

    if (mounted) {
      setState(() {
        _enabled = prefs.getBool(_key) ?? prefs.getBool(_privacyKey) ?? false;
        _hideLocked = hideLocked;
        _hasSecretCode = hasCode;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLock(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, val);
    await prefs.setBool(_privacyKey, val);
    if (!val) {
      await ChatVaultService.instance.setHidden(false);
    }
    setState(() {
      _enabled = val;
      if (!val) _hideLocked = false;
    });
  }

  Future<void> _toggleHideLocked(bool val) async {
    if (val && !_hasSecretCode) {
      // Prompt user to set secret code first
      final success = await _showSecretCodeDialog();
      if (!success) return; // User cancelled
    }

    await ChatVaultService.instance.setHidden(val);
    setState(() {
      _hideLocked = val;
    });
  }

  Future<bool> _showSecretCodeDialog() async {
    final controller = TextEditingController();
    bool obscure = true;
    String? errorMessage;

    final code = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final brightness = Theme.of(context).brightness;
            final card = KoraColors.cardFor(brightness);
            final textPrimary = KoraColors.textPrimaryFor(brightness);
            final textSecondary = KoraColors.textSecondaryFor(brightness);

            return AlertDialog(
              backgroundColor: card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                _hasSecretCode ? 'Change Secret Code' : 'Set Secret Code',
                style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter a 4 to 8 character secret code to hide your locked chats.',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    autofocus: true,
                    maxLength: 8,
                    style: TextStyle(color: textPrimary, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Secret code',
                      labelStyle: TextStyle(color: textSecondary),
                      errorText: errorMessage,
                      counterText: '',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: KoraColors.borderFor(brightness)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: KoraColors.purple, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: textSecondary),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Cancel', style: TextStyle(color: textSecondary)),
                ),
                TextButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.length < 4 || text.length > 8) {
                      setDialogState(() {
                        errorMessage = 'Code must be 4 to 8 characters';
                      });
                      return;
                    }
                    Navigator.pop(dialogCtx, text);
                  },
                  child: const Text('Save', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
controller.dispose();

    if (code != null && code.isNotEmpty) {
      await ChatVaultService.instance.setSecretCode(code);
      if (mounted) {
        setState(() {
          _hasSecretCode = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Secret code saved'),
            backgroundColor: KoraColors.purple,
            duration: Duration(seconds: 1),
          ),
        );
      }
      return true;
    }
    return false;
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
          'Chat lock',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Lock toggle card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_person_outlined, color: KoraColors.purple, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lock and hide chats',
                              style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Keep your most personal chats locked and hidden behind biometrics. Notification contents will be hidden when locked.',
                              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _enabled,
                        activeTrackColor: KoraColors.purple,
                        onChanged: _toggleLock,
                      ),
                    ],
                  ),
                ),
                if (_enabled) ...[
                  const SizedBox(height: 16),

                  // Secret Code Section
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: const Icon(Icons.password_outlined, color: KoraColors.purple, size: 24),
                          title: Text(
                            'Secret code',
                            style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            _hasSecretCode
                                ? 'Secret code is active. Tap to change.'
                                : 'Set a secret code (4-8 chars) to hide locked chats.',
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                          trailing: TextButton(
                            onPressed: _showSecretCodeDialog,
                            child: Text(
                              _hasSecretCode ? 'Change' : 'Set code',
                              style: const TextStyle(color: KoraColors.purple, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Divider(height: 1, color: border),
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          secondary: const Icon(Icons.visibility_off_outlined, color: KoraColors.purple, size: 24),
                          title: Text(
                            'Hide locked chats',
                            style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'To reveal locked chats when hidden, type your secret code into the search bar on the Chats tab.',
                            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.3),
                          ),
                          value: _hideLocked,
                          activeColor: KoraColors.purple,
                          onChanged: _toggleHideLocked,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How chat lock works',
                        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _bulletPoint('Locked chats are kept separate in a Locked Chats folder at top of chat list.', textSecondary),
                      const SizedBox(height: 8),
                      _bulletPoint('You can access them using Face ID, fingerprint, or your secret code.', textSecondary),
                      const SizedBox(height: 8),
                      _bulletPoint('Photos and media in locked chats will not automatically save to your device gallery.', textSecondary),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _bulletPoint(String text, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(color: KoraColors.purple, fontSize: 16, fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(text, style: TextStyle(color: textColor, fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }
}
