import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/kora_colors.dart';
import '../../models/business_models.dart';
import 'business_hours_screen.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});
  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  BusinessProfile _profile = const BusinessProfile();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _cats = ['Shopping', 'Food & Drink', 'Services', 'Health', 'Education', 'Technology', 'Finance', 'Other'];
  String _selectedCat = 'Shopping';

  @override void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('kora_business_profile');
    if (raw != null) {
      _profile = BusinessProfile.fromJson(jsonDecode(raw));
      _nameCtrl.text = _profile.businessName;
      _descCtrl.text = _profile.description;
      _addrCtrl.text = _profile.address;
      _emailCtrl.text = _profile.email;
      _selectedCat = _profile.category.isNotEmpty ? _profile.category : 'Shopping';
      setState(() {});
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    _profile = _profile.copyWith(
      businessName: _nameCtrl.text, category: _selectedCat,
      description: _descCtrl.text, address: _addrCtrl.text, email: _emailCtrl.text,
    );
    await prefs.setString('kora_business_profile', jsonEncode(_profile.toJson()));
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addrCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

@override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: KoraColors.backgroundFor(brightness),
      appBar: AppBar(
        backgroundColor: KoraColors.backgroundFor(brightness),
        title: Text('Business profile', style: TextStyle(color: KoraColors.textPrimaryFor(brightness))),
        iconTheme: IconThemeData(color: KoraColors.textPrimaryFor(brightness)),
        actions: [TextButton(onPressed: _save, child: Text('SAVE', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.bold)))],
      ),
      body: ListView(children: [
        const SizedBox(height: 20),
        Center(child: Stack(children: [
          CircleAvatar(radius: 50, backgroundColor: KoraColors.purple.withValues(alpha: 0.2),
            child: Icon(Icons.business, size: 50, color: KoraColors.purple)),
          Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 18,
            backgroundColor: KoraColors.purple, child: Icon(Icons.camera_alt, size: 16, color: Colors.white))),
        ])),
        const SizedBox(height: 20),
        _field('Business name', _nameCtrl, 'Enter business name'),
        _dropdown('Category', _selectedCat, _cats, (v) => setState(() => _selectedCat = v!)),
        _field('Description', _descCtrl, 'Tell customers about your business', maxLines: 3),
        _field('Address', _addrCtrl, 'Street address'),
        _field('Email', _emailCtrl, 'business@example.com'),
        _field('Website', _websiteCtrl, 'https://'),
        ListTile(
          title: Text('Business hours', style: TextStyle(color: KoraColors.textPrimaryFor(brightness))),
          subtitle: Text('Set your operating hours', style: TextStyle(color: KoraColors.textMutedFor(brightness))),
          trailing: Icon(Icons.chevron_right, color: KoraColors.textMutedFor(brightness)),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessHoursScreen())),
        ),
      ]),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint, {int maxLines = 1}) {
    final brightness = Theme.of(context).brightness;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 13, color: KoraColors.textMutedFor(brightness))),
        const SizedBox(height: 4),
        TextField(controller: ctrl, maxLines: maxLines,
          style: TextStyle(color: KoraColors.textPrimaryFor(brightness)),
          decoration: InputDecoration(hintText: hint,
            hintStyle: TextStyle(color: KoraColors.textMutedFor(brightness)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: KoraColors.borderFor(brightness))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: KoraColors.purple)))),
      ]));
  }

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    final brightness = Theme.of(context).brightness;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 13, color: KoraColors.textMutedFor(brightness))),
        DropdownButton<String>(value: value, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged, underline: Container(height: 1, color: KoraColors.borderFor(brightness))),
      ]));
  }
}
