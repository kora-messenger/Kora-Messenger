import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/kora_colors.dart';
import '../../models/business_models.dart';

class BusinessGreetingMessageScreen extends StatefulWidget {
  const BusinessGreetingMessageScreen({super.key});
  @override
  State<BusinessGreetingMessageScreen> createState() => _BusinessGreetingMessageScreenState();
}

class _BusinessGreetingMessageScreenState extends State<BusinessGreetingMessageScreen> {
  GreetingMessageSettings _settings = const GreetingMessageSettings();
  final _msgCtrl = TextEditingController();

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('kora_business_greeting');
    if (raw != null) { _settings = GreetingMessageSettings.fromJson(jsonDecode(raw)); _msgCtrl.text = _settings.message; setState(() {}); }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = GreetingMessageSettings(enabled: _settings.enabled, message: _msgCtrl.text, recipients: _settings.recipients);
    await prefs.setString('kora_business_greeting', jsonEncode(_settings.toJson()));
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

@override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: KoraColors.backgroundFor(b),
      appBar: AppBar(backgroundColor: KoraColors.backgroundFor(b),
        title: Text('Greeting message', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
        iconTheme: IconThemeData(color: KoraColors.textPrimaryFor(b))),
      body: ListView(children: [
        SwitchListTile(value: _settings.enabled,
          onChanged: (v) { setState(() => _settings = GreetingMessageSettings(enabled: v, message: _settings.message, recipients: _settings.recipients)); _save(); },
          title: Text('Send greeting message', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
          activeThumbColor: KoraColors.purple),
        if (_settings.enabled) ...[
          Padding(padding: const EdgeInsets.all(16), child: TextField(
            controller: _msgCtrl, maxLines: 4,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Enter your greeting message...'),
            onChanged: (v) => _save())),
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Recipients', style: TextStyle(fontSize: 13, color: KoraColors.textMutedFor(b), fontWeight: FontWeight.w600))),
          RadioListTile<String>(value: 'everyone', groupValue: _settings.recipients,
            title: Text('Everyone', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
            onChanged: (v) { setState(() => _settings = GreetingMessageSettings(enabled: _settings.enabled, message: _settings.message, recipients: v!)); _save(); }, activeColor: KoraColors.purple),
          RadioListTile<String>(value: 'new_contacts', groupValue: _settings.recipients,
            title: Text('New contacts only', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
            onChanged: (v) { setState(() => _settings = GreetingMessageSettings(enabled: _settings.enabled, message: _settings.message, recipients: v!)); _save(); }, activeColor: KoraColors.purple),
        ],
      ]),
    );
  }
}
