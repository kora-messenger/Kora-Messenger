import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/kora_colors.dart';
import '../../models/business_models.dart';

class BusinessLabelsScreen extends StatefulWidget {
  const BusinessLabelsScreen({super.key});
  @override
  State<BusinessLabelsScreen> createState() => _BusinessLabelsScreenState();
}

class _BusinessLabelsScreenState extends State<BusinessLabelsScreen> {
  List<BusinessLabel> _labels = [];
  final _colors = [Colors.red, Colors.orange, Colors.amber, Colors.green, Colors.teal, Colors.blue, Colors.indigo, Colors.purple];
  final _defaultLabels = ['New customer', 'New order', 'Pending payment', 'Paid', 'Order complete'];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('kora_business_labels');
    if (raw != null) {
      _labels = (jsonDecode(raw) as List).map((e) => BusinessLabel.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      _labels = _defaultLabels.asMap().entries.map((e) => BusinessLabel(id: e.key.toString(), name: e.value, colorIndex: e.key % _colors.length)).toList();
      await _saveLabels();
    }
    setState(() {});
  }

  Future<void> _saveLabels() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kora_business_labels', jsonEncode(_labels.map((e) => e.toJson()).toList()));
  }

  void _addLabel() {
    final nameCtrl = TextEditingController();
    int selectedColor = 0;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: Text('New label', style: TextStyle(color: KoraColors.purple)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Label name')),
        const SizedBox(height: 16),
        Wrap(spacing: 8, children: _colors.asMap().entries.map((e) => GestureDetector(
          onTap: () => setS(() => selectedColor = e.key),
          child: CircleAvatar(radius: 16, backgroundColor: e.value,
            child: selectedColor == e.key ? const Icon(Icons.check, size: 16, color: Colors.white) : null))).toList()),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () {
          if (nameCtrl.text.isNotEmpty) {
            _labels.add(BusinessLabel(id: DateTime.now().millisecondsSinceEpoch.toString(), name: nameCtrl.text, colorIndex: selectedColor));
            _saveLabels(); setState(() {}); Navigator.pop(ctx);
          }
        }, child: Text('Add', style: TextStyle(color: KoraColors.purple))),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: KoraColors.backgroundFor(b),
      appBar: AppBar(backgroundColor: KoraColors.backgroundFor(b),
        title: Text('Labels', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
        iconTheme: IconThemeData(color: KoraColors.textPrimaryFor(b))),
      body: ListView(children: [
        Padding(padding: const EdgeInsets.all(16), child: Text('Organize chats with color-coded labels.',
          style: TextStyle(color: KoraColors.textMutedFor(b), fontSize: 14))),
        ..._labels.map((label) => ListTile(
          leading: CircleAvatar(backgroundColor: _colors[label.colorIndex % _colors.length].withValues(alpha: 0.2),
            child: Icon(Icons.label, color: _colors[label.colorIndex % _colors.length])),
          title: Text(label.name, style: TextStyle(color: KoraColors.textPrimaryFor(b))),
          trailing: IconButton(icon: Icon(Icons.delete_outline, color: KoraColors.textMutedFor(b)),
            onPressed: () { _labels.remove(label); _saveLabels(); setState(() {}); }),
        )),
        const SizedBox(height: 16),
        Center(child: TextButton.icon(onPressed: _addLabel,
          icon: Icon(Icons.add, color: KoraColors.purple),
          label: Text('Add label', style: TextStyle(color: KoraColors.purple)))),
      ]),
    );
  }
}
