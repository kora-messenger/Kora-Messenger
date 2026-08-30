import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/kora_colors.dart';
import '../../models/business_models.dart';

class BusinessAwayMessageScreen extends StatefulWidget {
  const BusinessAwayMessageScreen({super.key});
  @override
  State<BusinessAwayMessageScreen> createState() => _BusinessAwayMessageScreenState();
}

class _BusinessAwayMessageScreenState extends State<BusinessAwayMessageScreen> {
  AwayMessageSettings _settings = const AwayMessageSettings();
  final _msgCtrl = TextEditingController();

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('kora_business_away');
    if (raw != null) {
      _settings = AwayMessageSettings.fromJson(jsonDecode(raw));
      _msgCtrl.text = _settings.message;
      setState(() {});
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = _settings.copyWith(message: _msgCtrl.text);
    await prefs.setString('kora_business_away', jsonEncode(_settings.toJson()));
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: KoraColors.backgroundFor(b),
      appBar: AppBar(backgroundColor: KoraColors.backgroundFor(b),
        title: Text('Away message', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
        iconTheme: IconThemeData(color: KoraColors.textPrimaryFor(b))),
      body: ListView(children: [
        SwitchListTile(value: _settings.enabled,
          onChanged: (v) { setState(() => _settings = AwayMessageSettings(enabled: v, message: _settings.message, schedule: _settings.schedule, recipients: _settings.recipients)); _save(); },
          title: Text('Send away message', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
          activeThumbColor: KoraColors.purple),
        if (_settings.enabled) ...[
          Padding(padding: const EdgeInsets.all(16), child: TextField(
            controller: _msgCtrl, maxLines: 4,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Enter your away message...'),
            onChanged: (v) => _save())),
          _section('Schedule', b, [
            _radio('Always send', 'always', b),
            _radio('Custom schedule', 'custom', b),
            _radio('Outside business hours', 'outside_hours', b),
          ]),
          _section('Recipients', b, [
            _radio('Everyone', 'everyone', b),
            _radio('My contacts', 'my_contacts', b),
          ]),
        ],
      ]),
    );
  }

  Widget _section(String title, Brightness b, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title, style: TextStyle(fontSize: 13, color: KoraColors.textMutedFor(b), fontWeight: FontWeight.w600))),
      ...children,
    ]);
  }

  Widget _radio(String label, String value, Brightness b) {
    return RadioListTile<String>(value: value, groupValue: _settings.schedule == value ? value : (_settings.recipients == value ? value : null),
      title: Text(label, style: TextStyle(color: KoraColors.textPrimaryFor(b))),
      onChanged: (v) { setState(() {}); _save(); }, activeColor: KoraColors.purple);
  }
}
