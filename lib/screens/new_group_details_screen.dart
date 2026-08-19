import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import '../widgets/kora_avatar.dart';

/// Group-details screen — shown after selecting members on the New
/// Group screen. Placeholder for now; will be rebuilt once the final
/// design is provided.
class NewGroupDetailsScreen extends StatelessWidget {
  final List<Map<String, Object>> members;

  const NewGroupDetailsScreen({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: textPrimary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'New Group',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${members.length} member${members.length == 1 ? '' : 's'} selected',
                  style: TextStyle(color: textSecondary, fontSize: 13.5),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final m = members[index];
                  return ListTile(
                    leading: KoraAvatar(name: m['name'] as String, size: 44),
                    title: Text(
                      m['name'] as String,
                      style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${m['koraId']} · ${m['username']}',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Text(
                'Group name, photo, and creation are coming up next.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
