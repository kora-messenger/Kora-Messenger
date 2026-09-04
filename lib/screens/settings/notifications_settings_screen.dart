import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';
import '../../services/chat_sound_service.dart';

/// Notifications settings screen — matches native Android notification
/// settings layout: a general section, then per-surface sections
/// (Messages, Groups, Calls, Status, Channels) each with their own
/// tone/vibrate/light/priority controls. All persisted to SharedPreferences.
class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  static const _kToneOptions = ['Default (Kora Chime)', 'None', 'Aurora', 'Pulse', 'Nova', 'Marimba'];
  static const _kVibrateOptions = ['Default', 'Short', 'Long', 'None'];
  static const _kLightOptions = ['White', 'Kora Purple', 'Kora Blue', 'Off'];
  static const _kRingtoneOptions = ['Default (Kora Ring)', 'Classic', 'Chime', 'Pulse', 'None'];

  // General
  bool _conversationTones = true;
  bool _reminders = true;

  // Messages
  String _msgTone = _kToneOptions.first;
  String _msgVibrate = _kVibrateOptions.first;
  String _msgLight = _kLightOptions.first;
  bool _msgHighPriority = true;
  bool _msgReactions = true;

  // Groups
  String _groupTone = _kToneOptions.first;
  String _groupVibrate = _kVibrateOptions.first;
  String _groupLight = _kLightOptions.first;
  bool _groupHighPriority = true;
  bool _groupReactions = true;

  // Calls
  String _callRingtone = _kRingtoneOptions.first;
  String _callVibrate = _kVibrateOptions.first;

  // Status
  String _statusTone = _kToneOptions.first;
  String _statusVibrate = _kVibrateOptions.first;
  bool _statusHighPriority = true;
  bool _statusReactions = true;

  // Channels
  bool _recommendedChannels = true;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _conversationTones = prefs.getBool('notif_conversation_tones') ?? true;
      _reminders = prefs.getBool('notif_reminders') ?? true;

      _msgTone = prefs.getString('notif_msg_tone') ?? _kToneOptions.first;
      _msgVibrate = prefs.getString('notif_msg_vibrate') ?? _kVibrateOptions.first;
      _msgLight = prefs.getString('notif_msg_light') ?? _kLightOptions.first;
      _msgHighPriority = prefs.getBool('notif_msg_high_priority') ?? true;
      _msgReactions = prefs.getBool('notif_msg_reactions') ?? true;

      _groupTone = prefs.getString('notif_group_tone') ?? _kToneOptions.first;
      _groupVibrate = prefs.getString('notif_group_vibrate') ?? _kVibrateOptions.first;
      _groupLight = prefs.getString('notif_group_light') ?? _kLightOptions.first;
      _groupHighPriority = prefs.getBool('notif_group_high_priority') ?? true;
      _groupReactions = prefs.getBool('notif_group_reactions') ?? true;

      _callRingtone = prefs.getString('notif_call_ringtone') ?? _kRingtoneOptions.first;
      _callVibrate = prefs.getString('notif_call_vibrate') ?? _kVibrateOptions.first;

      _statusTone = prefs.getString('notif_status_tone') ?? _kToneOptions.first;
      _statusVibrate = prefs.getString('notif_status_vibrate') ?? _kVibrateOptions.first;
      _statusHighPriority = prefs.getBool('notif_status_high_priority') ?? true;
      _statusReactions = prefs.getBool('notif_status_reactions') ?? true;

      _recommendedChannels = prefs.getBool('notif_recommended_channels') ?? true;

      _loading = false;
    });
  }

  Future<void> _setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
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
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                const SizedBox(height: 4),
                _toggleRow(
                  title: 'Conversation tones',
                  subtitle: 'Play sounds for incoming and outgoing messages.',
                  value: _conversationTones,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onChanged: (v) {
                    setState(() => _conversationTones = v);
                    _setBool('notif_conversation_tones', v);
                    ChatSoundService.instance.setEnabled(v);
                  },
                ),
                _toggleRow(
                  title: 'Reminders',
                  subtitle: "Get occasional reminders about messages, calls or status updates you haven't seen",
                  value: _reminders,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onChanged: (v) {
                    setState(() => _reminders = v);
                    _setBool('notif_reminders', v);
                  },
                ),

                _divider(border),
                _sectionLabel('Messages', textMuted),
                _pickerRow(
                  title: 'Notification tone',
                  value: _msgTone,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _showOptionPicker(
                    title: 'Notification tone',
                    options: _kToneOptions,
                    current: _msgTone,
                    onSelected: (v) {
                      setState(() => _msgTone = v);
                      _setString('notif_msg_tone', v);
                    },
                  ),
                ),
                _pickerRow(
                  title: 'Vibrate',
                  value: _msgVibrate,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _showOptionPicker(
                    title: 'Vibrate',
                    options: _kVibrateOptions,
                    current: _msgVibrate,
                    onSelected: (v) {
                      setState(() => _msgVibrate = v);
                      _setString('notif_msg_vibrate', v);
                    },
                  ),
                ),
                _disabledRow(
                  title: 'Popup notification',
                  subtitle: 'Not available',
                  textMuted: textMuted,
                ),
                _pickerRow(
                  title: 'Light',
                  value: _msgLight,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _showOptionPicker(
                    title: 'Light',
                    options: _kLightOptions,
                    current: _msgLight,
                    onSelected: (v) {
                      setState(() => _msgLight = v);
                      _setString('notif_msg_light', v);
                    },
                  ),
                ),
                _toggleRow(
                  title: 'Use high priority notifications',
                  subtitle: 'Show previews of notifications at the top of the screen',
                  value: _msgHighPriority,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onChanged: (v) {
                    setState(() => _msgHighPriority = v);
                    _setBool('notif_msg_high_priority', v);
                  },
                ),
                _toggleRow(
                  title: 'Reaction notifications',
                  subtitle: 'Show notifications for reactions to messages you send',
                  value: _msgReactions,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onChanged: (v) {
                    setState(() => _msgReactions = v);
                    _setBool('notif_msg_reactions', v);
                  },
                ),

                _divider(border),
                _sectionLabel('Groups', textMuted),
                _pickerRow(
                  title: 'Notification tone',
                  value: _groupTone,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _showOptionPicker(
                    title: 'Notification tone',
                    options: _kToneOptions,
                    current: _groupTone,
                    onSelected: (v) {
                      setState(() => _groupTone = v);
                      _setString('notif_group_tone', v);
                    },
                  ),
                ),
                _pickerRow(
                  title: 'Vibrate',
                  value: _groupVibrate,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _showOptionPicker(
                    title: 'Vibrate',
                    options: _kVibrateOptions,
                    current: _groupVibrate,
                    onSelected: (v) {
                      setState(() => _groupVibrate = v);
                      _setString('notif_group_vibrate', v);
                    },
                  ),
                ),
                _pickerRow(
                  title: 'Light',
                  value: _groupLight,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _showOptionPicker(
                    title: 'Light',
                    options: _kLightOptions,
                    current: _groupLight,
                    onSelected: (v) {
                      setState(() => _groupLight = v);
                      _setString('notif_group_light', v);
                    },
                  ),
                ),
                _toggleRow(
                  title: 'Use high priority notifications',
                  subtitle: 'Show previews of notifications at the top of the screen',
                  value: _groupHighPriority,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onChanged: (v) {
                    setState(() => _groupHighPriority = v);
                    _setBool('notif_group_high_priority', v);
                  },
                ),
                _toggleRow(
                  title: 'Reaction notifications',
                  subtitle: 'Show notifications for reactions to messages you send',
                  value: _groupReactions,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onChanged: (v) {
                    setState(() => _groupReactions = v);
                    _setBool('notif_group_reactions', v);
                  },
                ),

                _divider(border),
                _sectionLabel('Calls', textMuted),
                _pickerRow(
                  title: 'Ringtone',
                  value: _callRingtone,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _showOptionPicker(
                    title: 'Ringtone',
                    options: _kRingtoneOptions,
                    current: _callRingtone,
                    onSelected: (v) {
                      setState(() => _callRingtone = v);
                      _setString('notif_call_ringtone', v);
                    },
                  ),
                ),
                _pickerRow(
                  title: 'Vibrate',
                  value: _callVibrate,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _showOptionPicker(
                    title: 'Vibrate',
                    options: _kVibrateOptions,
                    current: _callVibrate,
                    onSelected: (v) {
                      setState(() => _callVibrate = v);
                      _setString('notif_call_vibrate', v);
                    },
                  ),
                ),

                _divider(border),
                _sectionLabel('Status', textMuted),
                _pickerRow(
                  title: 'Notification tone',
                  value: _statusTone,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _showOptionPicker(
                    title: 'Notification tone',
                    options: _kToneOptions,
                    current: _statusTone,
                    onSelected: (v) {
                      setState(() => _statusTone = v);
                      _setString('notif_status_tone', v);
                    },
                  ),
                ),
                _pickerRow(
                  title: 'Vibrate',
                  value: _statusVibrate,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _showOptionPicker(
                    title: 'Vibrate',
                    options: _kVibrateOptions,
                    current: _statusVibrate,
                    onSelected: (v) {
                      setState(() => _statusVibrate = v);
                      _setString('notif_status_vibrate', v);
                    },
                  ),
                ),
                _toggleRow(
                  title: 'Use high priority notifications',
                  subtitle: 'Show previews of notifications at the top of the screen',
                  value: _statusHighPriority,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onChanged: (v) {
                    setState(() => _statusHighPriority = v);
                    _setBool('notif_status_high_priority', v);
                  },
                ),
                _toggleRow(
                  title: 'Reactions',
                  subtitle: 'Show notifications when you get likes on a status',
                  value: _statusReactions,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onChanged: (v) {
                    setState(() => _statusReactions = v);
                    _setBool('notif_status_reactions', v);
                  },
                ),

                _divider(border),
                _infoRow(
                  title: 'App icon badge',
                  subtitle: 'Clears when you open Kora Messenger',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),

                _divider(border),
                _sectionLabel('Channels', textMuted),
                _toggleRow(
                  title: 'Recommended channels',
                  subtitle: 'Find out about channels that may interest you.',
                  value: _recommendedChannels,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onChanged: (v) {
                    setState(() => _recommendedChannels = v);
                    _setBool('notif_recommended_channels', v);
                  },
                ),

                _divider(border),
                _sectionLabel('RESET', textMuted),
                _actionRow(
                  title: 'Reset notification settings',
                  subtitle: 'Restore all notification preferences to their defaults',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: _resetNotificationSettings,
                ),
              ],
            ),
    );
  }

  Future<void> _resetNotificationSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
        title: Text('Reset notification settings?',
            style: TextStyle(color: KoraColors.textPrimaryFor(Theme.of(context).brightness), fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text('This will restore all notification preferences to their default values.',
            style: TextStyle(color: KoraColors.textSecondaryFor(Theme.of(context).brightness), fontSize: 14, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('notif_')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
    await _loadPrefs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification settings reset')),
      );
    }
  }

  Widget _actionRow({
    required String title,
    required String subtitle,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      title: Text(title, style: TextStyle(color: textPrimary, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 12.5)),
      dense: true,
    );
  }

  // ── Row builders ───────────────────────────────────────────

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _divider(Color border) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(color: border, height: 1, thickness: 1),
    );
  }

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required Color textPrimary,
    required Color textSecondary,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: textSecondary, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: KoraColors.purple,
          ),
        ],
      ),
    );
  }

  Widget _pickerRow({
    required String title,
    required String value,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(color: textSecondary, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _disabledRow({
    required String title,
    required String subtitle,
    required Color textMuted,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: textMuted, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: textMuted, fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required String title,
    required String subtitle,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: textSecondary, fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  void _showOptionPicker({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final brightness = Theme.of(sheetContext).brightness;
        final textPrimary = KoraColors.textPrimaryFor(brightness);
        final textSecondary = KoraColors.textSecondaryFor(brightness);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              ...options.map((opt) {
                final isSelected = opt == current;
                return ListTile(
                  onTap: () {
                    onSelected(opt);
                    Navigator.pop(sheetContext);
                  },
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? KoraColors.purple : textSecondary,
                    size: 22,
                  ),
                  title: Text(
                    opt,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
