import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/kora_colors.dart';
import '../../models/business_models.dart';

class BusinessTemplatesScreen extends StatefulWidget {
  const BusinessTemplatesScreen({super.key});
  @override
  State<BusinessTemplatesScreen> createState() => _BusinessTemplatesScreenState();
}

class _BusinessTemplatesScreenState extends State<BusinessTemplatesScreen> {
  List<MessageTemplate> _templates = [];
  final _shortcutCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('kora_business_templates');
    if (raw != null) {
      _templates = (jsonDecode(raw) as List).map((e) => MessageTemplate.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {});
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kora_business_templates', jsonEncode(_templates.map((e) => e.toJson()).toList()));
  }

  void _addTemplate() {
    _shortcutCtrl.clear(); _messageCtrl.clear();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('New quick reply', style: TextStyle(color: KoraColors.purple)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _shortcutCtrl, decoration: const InputDecoration(hintText: 'Shortcut (e.g. /thanks)')),
        TextField(controller: _messageCtrl, decoration: const InputDecoration(hintText: 'Message'), maxLines: 3),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () {
          if (_shortcutCtrl.text.isNotEmpty) {
            _templates.add(MessageTemplate(shortcut: _shortcutCtrl.text, message: _messageCtrl.text));
            _save(); setState(() {}); Navigator.pop(ctx);
          }
        }, child: Text('Save', style: TextStyle(color: KoraColors.purple))),
      ],
    ));
  }

  @override
  void dispose() {
    _shortcutCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

@override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: KoraColors.backgroundFor(b),
      appBar: AppBar(backgroundColor: KoraColors.backgroundFor(b),
        title: Text('Quick replies', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
        iconTheme: IconThemeData(color: KoraColors.textPrimaryFor(b))),
      body: ListView(children: [
        Padding(padding: const EdgeInsets.all(16), child: Text('Create shortcuts for messages you send frequently.',
          style: TextStyle(color: KoraColors.textMutedFor(b), fontSize: 14))),
        ..._templates.map((t) => ListTile(
          leading: CircleAvatar(backgroundColor: KoraColors.purple.withValues(alpha: 0.15),
            child: Text((t.shortcut.replaceAll('/', '').isNotEmpty ? t.shortcut.replaceAll('/', '').substring(0, 1) : '?').toUpperCase(), style: TextStyle(color: KoraColors.purple))),
          title: Text(t.shortcut, style: TextStyle(color: KoraColors.textPrimaryFor(b), fontWeight: FontWeight.w600)),
          subtitle: Text(t.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: KoraColors.textMutedFor(b))),
          trailing: IconButton(icon: Icon(Icons.delete_outline, color: KoraColors.textMutedFor(b)),
            onPressed: () { _templates.remove(t); _save(); setState(() {}); }),
        )),
        const SizedBox(height: 16),
        Center(child: TextButton.icon(onPressed: _addTemplate,
          icon: Icon(Icons.add, color: KoraColors.purple),
          label: Text('Add quick reply', style: TextStyle(color: KoraColors.purple)))),
      ]),
    );
  }
}
