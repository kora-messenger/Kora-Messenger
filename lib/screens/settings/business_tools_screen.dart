import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/kora_colors.dart';
import '../../models/business_models.dart';
import 'business_profile_screen.dart';
import 'business_catalog_screen.dart';
import 'business_templates_screen.dart';
import 'business_away_message.dart';
import 'business_greeting_message.dart';
import 'business_labels_screen.dart';
import 'business_hours_screen.dart';

class BusinessToolsScreen extends StatefulWidget {
  const BusinessToolsScreen({super.key});
  @override
  State<BusinessToolsScreen> createState() => _BusinessToolsScreenState();
}

class _BusinessToolsScreenState extends State<BusinessToolsScreen> {
  bool _hasProfile = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('kora_business_profile');
    _hasProfile = raw != null && BusinessProfile.fromJson(jsonDecode(raw)).businessName.isNotEmpty;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final isDark = b == Brightness.dark;
    return Scaffold(
      backgroundColor: KoraColors.backgroundFor(b),
      appBar: AppBar(backgroundColor: KoraColors.backgroundFor(b),
        title: Text('Business Tools', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
        iconTheme: IconThemeData(color: KoraColors.textPrimaryFor(b))),
      body: ListView(children: [
        // Profile card
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [KoraColors.purple, KoraColors.blue]),
            borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            CircleAvatar(radius: 30, backgroundColor: Colors.white.withValues(alpha: 0.3),
              child: const Icon(Icons.business, color: Colors.white, size: 28)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_hasProfile ? 'Business profile' : 'Set up your business',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(_hasProfile ? 'Your profile is set up' : 'Get started with business tools',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
            ])),
          ])),
        // Sections
        _sectionLabel('Profile', b),
        _tile(Icons.person_outline, 'Business profile', 'Name, category, address', b, () => _nav(const BusinessProfileScreen())),
        _tile(Icons.storefront_outlined, 'Catalog', 'Showcase your products', b, () => _nav(const BusinessCatalogScreen())),
        _sectionLabel('Messaging tools', b),
        _tile(Icons.chat_bubble_outline, 'Away message', 'Auto-reply when unavailable', b, () => _nav(const BusinessAwayMessageScreen())),
        _tile(Icons.waving_hand_outlined, 'Greeting message', 'Welcome new customers', b, () => _nav(const BusinessGreetingMessageScreen())),
        _tile(Icons.quickreply_outlined, 'Quick replies', 'Shortcuts for frequent messages', b, () => _nav(const BusinessTemplatesScreen())),
        _sectionLabel('Organization', b),
        _tile(Icons.label_outline, 'Labels', 'Organize chats with colors', b, () => _nav(const BusinessLabelsScreen())),
        _tile(Icons.schedule_outlined, 'Business hours', 'Set operating hours', b, () => _nav(const BusinessHoursScreen())),
      ]),
    );
  }

  void _nav(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Widget _sectionLabel(String label, Brightness b) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KoraColors.textMutedFor(b))));
  }

  Widget _tile(IconData icon, String title, String subtitle, Brightness b, VoidCallback onTap) {
    return ListTile(leading: Icon(icon, color: KoraColors.purple),
      title: Text(title, style: TextStyle(color: KoraColors.textPrimaryFor(b))),
      subtitle: Text(subtitle, style: TextStyle(color: KoraColors.textMutedFor(b), fontSize: 13)),
      trailing: Icon(Icons.chevron_right, color: KoraColors.textMutedFor(b)), onTap: onTap);
  }
}
