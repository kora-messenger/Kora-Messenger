import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// Notifications settings screen — toggles for message, group, call,
/// preview, and vibration notifications. All persisted to SharedPreferences.
class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  bool _messageNotif = true;
  bool _groupNotif = true;
  bool _callTones = true;
  bool _previewMessage = true;
  bool _vibrate = true;
  bool _loading = true;

  static const _kPrefs = {
    'notif_messages': 'messageNotif',
    'notif_groups': 'groupNotif',
    'notif_call_tones': 'callTones',
    'notif_preview': 'previewMessage',
    'notif_vibrate': 'vibrate',
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _messageNotif = prefs.getBool('notif_messages') ?? true;
        _groupNotif = prefs.getBool('notif_groups') ?? true;
        _callTones = prefs.getBool('notif_call_tones') ?? true;
        _previewMessage = prefs.getBool('notif_preview') ?? true;
        _vibrate = prefs.getBool('notif_vibrate') ?? true;
        _loading = false;
      });
    }
  }

  Future<void> _setPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Notifications',
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _sectionLabel('MESSAGES', textMuted),
                _toggleTile(
                  icon: Icons.chat_bubble_outline,
                  title: 'Message Notifications',
                  subtitle: 'Show notifications for new messages',
                  value: _messageNotif,
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  border: border,
                  onChanged: (v) {
                    setState(() => _messageNotif = v);
                    _setPref('notif_messages', v);
                  },
                ),
                _toggleTile(
                  icon: Icons.group_outlined,
                  title: 'Group Notifications',
                  subtitle: 'Show notifications for group messages',
                  value: _groupNotif,
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  border: border,
                  onChanged: (v) {
                    setState(() => _groupNotif = v);
                    _setPref('notif_groups', v);
                  },
                ),
                _toggleTile(
                  icon: Icons.message_outlined,
                  title: 'Show Message Preview',
                  subtitle: 'Display message content in notifications',
                  value: _previewMessage,
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  border: border,
                  onChanged: (v) {
                    setState(() => _previewMessage = v);
                    _setPref('notif_preview', v);
                  },
                ),
                const SizedBox(height: 20),
                _sectionLabel('CALLS', textMuted),
                _toggleTile(
                  icon: Icons.call_outlined,
                  title: 'Call Tones',
                  subtitle: 'Play sound for incoming calls',
                  value: _callTones,
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  border: border,
                  onChanged: (v) {
                    setState(() => _callTones = v);
                    _setPref('notif_call_tones', v);
                  },
                ),
                const SizedBox(height: 20),
                _sectionLabel('GENERAL', textMuted),
                _toggleTile(
                  icon: Icons.vibration_rounded,
                  title: 'Vibrate',
                  subtitle: 'Vibrate device for notifications',
                  value: _vibrate,
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  border: border,
                  onChanged: (v) {
                    setState(() => _vibrate = v);
                    _setPref('notif_vibrate', v);
                  },
                ),
              ],
            ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(14),
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
              child: Icon(icon, color: KoraColors.purple, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: KoraColors.purple,
            ),
          ],
        ),
      ),
    );
  }
}
