import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// Chat lock settings screen to toggle chat locking persistence and explanation.
class ChatLockScreen extends StatefulWidget {
  const ChatLockScreen({super.key});

  @override
  State<ChatLockScreen> createState() => _ChatLockScreenState();
}

class _ChatLockScreenState extends State<ChatLockScreen> {
  static const String _key = 'chat_lock_enabled';
  static const String _privacyKey = 'kora_privacy_chat_lock';

  bool _enabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool(_key) ?? prefs.getBool(_privacyKey) ?? false;
      _isLoading = false;
    });
  }

  Future<void> _toggleLock(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, val);
    await prefs.setBool(_privacyKey, val);
    setState(() {
      _enabled = val;
    });
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
                      _bulletPoint('You can access them using Face ID, fingerprint, or your device passcode.', textSecondary),
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
