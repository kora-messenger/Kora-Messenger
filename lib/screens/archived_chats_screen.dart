import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_empty_state.dart';

/// Archived chats screen — shows chats the user has archived.
class ArchivedChatsScreen extends StatefulWidget {
  const ArchivedChatsScreen({super.key});

  @override
  State<ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<ArchivedChatsScreen> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Archived Chats',
          style: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const KoraEmptyState(
        icon: Icons.archive_outlined,
        title: 'No archived chats',
        message: 'Long-press a chat and select "Archive" to move it here.',
      ),
    );
  }
}
