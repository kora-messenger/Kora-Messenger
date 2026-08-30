import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

class WearOsScreen extends StatefulWidget {
  const WearOsScreen({super.key});
  @override
  State<WearOsScreen> createState() => _WearOsScreenState();
}

class _WearOsScreenState extends State<WearOsScreen> {
  bool _connected = false;
  bool _mirrorNotifs = true;
  bool _showPreviews = true;
  bool _callHaptics = true;
  bool _mutePhone = false;
  final _quickReplies = ['Yes', 'No', 'Thanks!', 'On my way', 'Call you later', '👍'];

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: KoraColors.backgroundFor(b),
      appBar: AppBar(backgroundColor: KoraColors.backgroundFor(b),
        title: Text('Wear OS', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
        iconTheme: IconThemeData(color: KoraColors.textPrimaryFor(b))),
      body: ListView(children: [
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: KoraColors.cardFor(b), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Icon(Icons.watch, size: 48, color: _connected ? KoraColors.purple : KoraColors.textMutedFor(b)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_connected ? 'Galaxy Watch 6 Pro' : 'No watch connected',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: KoraColors.textPrimaryFor(b))),
              Text(_connected ? 'Connected • 85% battery' : 'Pair your Wear OS watch',
                style: TextStyle(fontSize: 13, color: KoraColors.textMutedFor(b))),
            ])),
            if (!_connected) TextButton(onPressed: () => setState(() => _connected = true),
              child: Text('Pair', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.bold))),
          ])),
        if (!_connected) ...[
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Setup instructions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KoraColors.textMutedFor(b)))),
          _step('1', 'Install Kora on your Wear OS watch', b),
          _step('2', 'Open Kora companion app on watch', b),
          _step('3', 'Confirm the 4-digit pairing code', b),
        ] else ...[
          _switch('Mirror notifications', _mirrorNotifs, (v) => setState(() => _mirrorNotifs = v)),
          _switch('Show message previews', _showPreviews, (v) => setState(() => _showPreviews = v)),
          _switch('Call haptics', _callHaptics, (v) => setState(() => _callHaptics = v)),
          _switch('Mute phone when watch is connected', _mutePhone, (v) => setState(() => _mutePhone = v)),
          const SizedBox(height: 16),
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Quick replies on watch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KoraColors.textMutedFor(b)))),
          ..._quickReplies.map((r) => ListTile(dense: true,
            title: Text(r, style: TextStyle(color: KoraColors.textPrimaryFor(b))),
            trailing: Icon(Icons.reorder, color: KoraColors.textMutedFor(b)))),
        ],
      ]),
    );
  }

  Widget _step(String num, String text, Brightness b) {
    return ListTile(leading: CircleAvatar(radius: 14, backgroundColor: KoraColors.purple,
      child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 12))),
      title: Text(text, style: TextStyle(color: KoraColors.textPrimaryFor(b))));
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(value: value, onChanged: onChanged, title: Text(label,
      style: TextStyle(color: KoraColors.textPrimaryFor(Theme.of(context).brightness))),
      activeThumbColor: KoraColors.purple);
  }
}
