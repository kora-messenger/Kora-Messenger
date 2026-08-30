import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

class InteropScreen extends StatefulWidget {
  const InteropScreen({super.key});
  @override
  State<InteropScreen> createState() => _InteropScreenState();
}

class _InteropScreenState extends State<InteropScreen> {
  bool _enabled = false;
  final _platforms = {'WhatsApp': false, 'Telegram': false, 'Signal': false, 'Threema': false};

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: KoraColors.backgroundFor(b),
      appBar: AppBar(backgroundColor: KoraColors.backgroundFor(b),
        title: Text('Cross-platform', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
        iconTheme: IconThemeData(color: KoraColors.textPrimaryFor(b))),
      body: ListView(children: [
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: KoraColors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(Icons.info_outline, color: KoraColors.purple),
            const SizedBox(width: 12),
            Expanded(child: Text('Cross-platform messaging lets you chat with people on other messaging apps. Your messages remain end-to-end encrypted.',
              style: TextStyle(color: KoraColors.textPrimaryFor(b), fontSize: 14))),
          ])),
        SwitchListTile(value: _enabled, onChanged: (v) => setState(() => _enabled = v),
          title: Text('Enable cross-platform messaging', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
          activeThumbColor: KoraColors.purple),
        if (_enabled) ...[
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Choose platforms', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KoraColors.textMutedFor(b)))),
          ..._platforms.keys.map((p) => SwitchListTile(
            value: _platforms[p]!, onChanged: (v) => setState(() => _platforms[p] = v),
            title: Text(p, style: TextStyle(color: KoraColors.textPrimaryFor(b))),
            activeThumbColor: KoraColors.purple)),
        ],
      ]),
    );
  }
}
