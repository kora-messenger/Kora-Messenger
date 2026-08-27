import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

class DisappearingMessagesScreen extends StatefulWidget {
  final String? chatId;
  const DisappearingMessagesScreen({super.key, this.chatId});
  @override
  State<DisappearingMessagesScreen> createState() => _DisappearingMessagesScreenState();
}

class _DisappearingMessagesScreenState extends State<DisappearingMessagesScreen> {
  int _selectedDuration = 0;
  static const _options = [
    (0, 'Off', 'Messages stay forever'),
    (86400, '24 hours', 'Messages disappear after 24 hours'),
    (604800, '7 days', 'Messages disappear after 7 days'),
    (7776000, '90 days', 'Messages disappear after 90 days'),
  ];

  @override
  void initState() {
    super.initState();
    _loadTimer();
  }

  Future<void> _loadTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final key = widget.chatId != null ? 'disappearing_${widget.chatId}' : 'disappearing_timer';
    setState(() => _selectedDuration = prefs.getInt(key) ?? 0);
  }

  Future<void> _setTimer(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    final key = widget.chatId != null ? 'disappearing_${widget.chatId}' : 'disappearing_timer';
    await prefs.setInt(key, seconds);
    setState(() => _selectedDuration = seconds);
    if (mounted) Navigator.pop(context, seconds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.surface,
      appBar: AppBar(
        backgroundColor: KoraColors.surface,
        title: const Text('Disappearing messages', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'When enabled, new messages sent and received in this chat will disappear after the selected duration.',
              style: TextStyle(color: KoraColors.textMuted, fontSize: 14),
            ),
          ),
          ..._options.map((opt) {
            final isSelected = _selectedDuration == opt.$1;
            return ListTile(
              leading: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? KoraColors.purple : KoraColors.textMuted,
              ),
              title: Text(opt.$2, style: const TextStyle(color: Colors.white)),
              subtitle: Text(opt.$3, style: TextStyle(color: KoraColors.textMuted, fontSize: 12)),
              onTap: () => _setTimer(opt.$1),
            );
          }),
        ],
      ),
    );
  }
}
