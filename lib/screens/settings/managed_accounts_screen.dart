import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

class ManagedAccountsScreen extends StatefulWidget {
  const ManagedAccountsScreen({super.key});
  @override
  State<ManagedAccountsScreen> createState() => _ManagedAccountsScreenState();
}

class _ManagedAccountsScreenState extends State<ManagedAccountsScreen> {
  final _accounts = [
    {'name': 'Tech Solutions Ltd', 'provider': 'Meta Business Partner', 'status': 'Active'},
    {'name': 'Global Retail Co', 'provider': 'Cloud Communication', 'status': 'Active'},
  ];

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: KoraColors.backgroundFor(b),
      appBar: AppBar(backgroundColor: KoraColors.backgroundFor(b),
        title: Text('Managed accounts', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
        iconTheme: IconThemeData(color: KoraColors.textPrimaryFor(b))),
      body: ListView(children: [
        Padding(padding: const EdgeInsets.all(16),
          child: Text('Allow a third-party provider to manage your business account on Kora.',
            style: TextStyle(color: KoraColors.textMutedFor(b), fontSize: 14))),
        ..._accounts.map((a) => Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: KoraColors.cardFor(b), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: KoraColors.purple.withValues(alpha: 0.15),
              child: Icon(Icons.business, color: KoraColors.purple)),
            title: Text(a['name']!, style: TextStyle(fontWeight: FontWeight.w600, color: KoraColors.textPrimaryFor(b))),
            subtitle: Text('${a['provider']} • ${a['status']}', style: TextStyle(color: KoraColors.textMutedFor(b))),
            trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(a['status']!, style: TextStyle(color: Colors.green, fontSize: 12))),)),
        const SizedBox(height: 16),
        Center(child: TextButton.icon(onPressed: () {},
          icon: Icon(Icons.add, color: KoraColors.purple),
          label: Text('Add managed account', style: TextStyle(color: KoraColors.purple)))),
      ]),
    );
  }
}
