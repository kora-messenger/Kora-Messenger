import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

class AndroidAutoScreen extends StatefulWidget {
  const AndroidAutoScreen({super.key});
  @override
  State<AndroidAutoScreen> createState() => _AndroidAutoScreenState();
}

class _AndroidAutoScreenState extends State<AndroidAutoScreen> {
  bool _connected = false;
  bool _voiceEnabled = true;
  bool _readAloud = true;
  bool _autoReply = false;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: KoraColors.backgroundFor(b),
      appBar: AppBar(backgroundColor: KoraColors.backgroundFor(b),
        title: Text('Android Auto', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
        iconTheme: IconThemeData(color: KoraColors.textPrimaryFor(b))),
      body: ListView(children: [
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: KoraColors.cardFor(b), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Icon(Icons.directions_car, size: 48, color: _connected ? KoraColors.purple : KoraColors.textMutedFor(b)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_connected ? 'Connected to car' : 'Not connected',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: KoraColors.textPrimaryFor(b))),
              Text(_connected ? 'USB • Android Auto' : 'Connect via USB or Wireless',
                style: TextStyle(fontSize: 13, color: KoraColors.textMutedFor(b))),
            ])),
          ])),
        if (!_connected) ...[
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Setup', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KoraColors.textMutedFor(b)))),
          _step('1', 'Connect your phone to your car via USB or wireless', b),
          _step('2', 'Open Android Auto on your car display', b),
          _step('3', 'Follow the on-screen instructions to pair', b),
          _step('4', 'Grant Kora Messenger permission to access Android Auto', b),
          const SizedBox(height: 16),
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Voice commands', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KoraColors.textMutedFor(b)))),
          _voiceCmd('"OK Google, send a Kora message"', b),
          _voiceCmd('"OK Google, read my Kora messages"', b),
          _voiceCmd('"OK Google, reply to Kora message"', b),
        ] else ...[
          _switch('Voice messaging', _voiceEnabled, (v) => setState(() => _voiceEnabled = v)),
          _switch('Read messages aloud', _readAloud, (v) => setState(() => _readAloud = v)),
          _switch('Auto-reply while driving', _autoReply, (v) => setState(() => _autoReply = v)),
        ],
      ]),
    );
  }

  Widget _step(String num, String text, Brightness b) {
    return ListTile(leading: CircleAvatar(radius: 14, backgroundColor: KoraColors.purple,
      child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 12))),
      title: Text(text, style: TextStyle(color: KoraColors.textPrimaryFor(b))));
  }

  Widget _voiceCmd(String cmd, Brightness b) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(cmd, style: TextStyle(color: KoraColors.purple, fontSize: 14)));
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(value: value, onChanged: onChanged, title: Text(label,
      style: TextStyle(color: KoraColors.textPrimaryFor(Theme.of(context).brightness))),
      activeThumbColor: KoraColors.purple);
  }
}
