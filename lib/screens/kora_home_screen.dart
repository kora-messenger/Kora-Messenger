import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';

/// Main Kora experience — placeholder for now.
/// This is where the chat list / conversations will live.
class KoraHomeScreen extends StatelessWidget {
  const KoraHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.trueBlack,
      appBar: AppBar(
        backgroundColor: KoraColors.trueBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Kora',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, color: Color(0xFF4A4A5E), size: 64),
            SizedBox(height: 16),
            Text(
              'Welcome to Kora Messenger',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Your conversations will appear here.',
              style: TextStyle(color: Color(0xFF6B6B80), fontSize: 14),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: KoraColors.purple,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }
}
