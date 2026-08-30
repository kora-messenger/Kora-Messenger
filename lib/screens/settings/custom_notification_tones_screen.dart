import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// Custom Notification Tones screen — per-contact notification sound picker.
/// Mirrors WhatsApp's individual contact notification settings.
///
/// Lets the user pick a custom ringtone for messages from a specific contact,
/// override mute settings, and set a custom vibration pattern.
class CustomNotificationTonesScreen extends StatefulWidget {
  final String contactName;
  final String contactId;

  const CustomNotificationTonesScreen({
    super.key,
    required this.contactName,
    required this.contactId,
  });

  @override
  State<CustomNotificationTonesScreen> createState() =>
      _CustomNotificationTonesScreenState();
}

class _CustomNotificationTonesScreenState
    extends State<CustomNotificationTonesScreen> {
  String _selectedTone = 'Default';
  bool _useCustom = false;
  bool _muteNotifications = false;
  String _vibrationPattern = 'Default';
  bool _showPreview = true;
  bool _highPriority = false;

  static const _tones = [
    ('Default', 'system_default'),
    ('None', 'none'),
    ('Chime', 'chime'),
    ('Bell', 'bell'),
    ('Pulse', 'pulse'),
    ('Echo', 'echo'),
    ('Crystal', 'crystal'),
    ('Kora', 'kora_tone'),
    ('Gentle', 'gentle'),
    ('Marimba', 'marimba'),
  ];

  static const _vibrations = ['Default', 'Short', 'Long', 'Double', 'None'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useCustom = prefs.getBool('custom_notif_${widget.contactId}') ?? false;
      _selectedTone = prefs.getString('notif_tone_${widget.contactId}') ?? 'Default';
      _muteNotifications = prefs.getBool('mute_notif_${widget.contactId}') ?? false;
      _vibrationPattern = prefs.getString('vibrate_${widget.contactId}') ?? 'Default';
      _showPreview = prefs.getBool('show_preview_${widget.contactId}') ?? true;
      _highPriority = prefs.getBool('high_priority_${widget.contactId}') ?? false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  void _playTone(String toneName) {
    // Preview the tone — in production this would play the actual sound
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing: $toneName'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Custom Notifications',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Contact header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [KoraColors.purple.withValues(alpha: 0.12), KoraColors.blue.withValues(alpha: 0.08)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [KoraColors.purple, KoraColors.blue]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.contactName.isNotEmpty
                          ? widget.contactName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.contactName,
                      style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // Use custom notifications toggle
          _sectionLabel('NOTIFICATIONS', textMuted),
          SwitchListTile(
            title: Text('Use custom notifications',
                style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
            subtitle: Text('Customize notification settings for ${widget.contactName}',
                style: TextStyle(color: textMuted, fontSize: 13)),
            value: _useCustom,
            onChanged: (v) {
              setState(() => _useCustom = v);
              _saveSetting('custom_notif_${widget.contactId}', v);
            },
            activeColor: KoraColors.purple,
          ),

          if (_useCustom) ...[
            const Divider(height: 1),

            // Mute toggle
            SwitchListTile(
              title: Text('Mute notifications',
                  style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
              subtitle: Text('Silence all notifications from this contact',
                  style: TextStyle(color: textMuted, fontSize: 13)),
              value: _muteNotifications,
              onChanged: (v) {
                setState(() => _muteNotifications = v);
                _saveSetting('mute_notif_${widget.contactId}', v);
              },
              activeColor: KoraColors.purple,
            ),

            if (!_muteNotifications) ...[
              const Divider(height: 1),

              // Notification tone
              _sectionLabel('NOTIFICATION TONE', textMuted),
              ListTile(
                leading: Icon(Icons.notifications_active, color: KoraColors.purple, size: 22),
                title: Text('Ringtone', style: TextStyle(color: textPrimary, fontSize: 15)),
                subtitle: Text(_selectedTone, style: TextStyle(color: textMuted, fontSize: 13)),
                trailing: Icon(Icons.chevron_right, color: textMuted, size: 18),
                onTap: () => _showTonePicker(surface, textPrimary, textMuted),
              ),

              // Vibration pattern
              ListTile(
                leading: Icon(Icons.vibration, color: KoraColors.purple, size: 22),
                title: Text('Vibration', style: TextStyle(color: textPrimary, fontSize: 15)),
                subtitle: Text(_vibrationPattern, style: TextStyle(color: textMuted, fontSize: 13)),
                trailing: Icon(Icons.chevron_right, color: textMuted, size: 18),
                onTap: () => _showVibrationPicker(surface, textPrimary, textMuted),
              ),

              // Show preview toggle
              const Divider(height: 1),
              _sectionLabel('PREVIEW', textMuted),
              SwitchListTile(
                title: Text('Show notification preview',
                    style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                subtitle: Text('Display message content in notifications',
                    style: TextStyle(color: textMuted, fontSize: 13)),
                value: _showPreview,
                onChanged: (v) {
                  setState(() => _showPreview = v);
                  _saveSetting('show_preview_${widget.contactId}', v);
                },
                activeColor: KoraColors.purple,
              ),

              // High priority toggle
              SwitchListTile(
                title: Text('High priority notifications',
                    style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                subtitle: Text('Show at the top of notification panel',
                    style: TextStyle(color: textMuted, fontSize: 13)),
                value: _highPriority,
                onChanged: (v) {
                  setState(() => _highPriority = v);
                  _saveSetting('high_priority_${widget.contactId}', v);
                },
                activeColor: KoraColors.purple,
              ),
            ],
          ],

          const SizedBox(height: 24),

          // Info note
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'These settings only apply to ${widget.contactName}. Your global notification settings are unaffected.',
                    style: TextStyle(color: textMuted, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label,
          style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    );
  }

  void _showTonePicker(Color surface, Color textPrimary, Color textMuted) {
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.backgroundFor(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Notification Tone',
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const Divider(height: 1),
              ..._tones.map((tone) {
                final isSelected = _selectedTone == tone.$1;
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? KoraColors.purple : textMuted,
                    size: 20,
                  ),
                  title: Text(tone.$1, style: TextStyle(color: textPrimary, fontSize: 15)),
                  trailing: IconButton(
                    icon: Icon(Icons.play_circle_outline, color: textMuted, size: 22),
                    onPressed: () => _playTone(tone.$1),
                  ),
                  onTap: () {
                    setState(() => _selectedTone = tone.$1);
                    _saveSetting('notif_tone_${widget.contactId}', tone.$1);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showVibrationPicker(Color surface, Color textPrimary, Color textMuted) {
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.backgroundFor(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Vibration Pattern',
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const Divider(height: 1),
              ..._vibrations.map((pattern) {
                final isSelected = _vibrationPattern == pattern;
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? KoraColors.purple : textMuted,
                    size: 20,
                  ),
                  title: Text(pattern, style: TextStyle(color: textPrimary, fontSize: 15)),
                  onTap: () {
                    setState(() => _vibrationPattern = pattern);
                    _saveSetting('vibrate_${widget.contactId}', pattern);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
