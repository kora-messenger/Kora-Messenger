import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Functional phone dialer keypad screen with KoraColors deep navy surface.
class KeypadScreen extends StatefulWidget {
  const KeypadScreen({super.key});

  @override
  State<KeypadScreen> createState() => _KeypadScreenState();
}

class _KeypadScreenState extends State<KeypadScreen> {
  String _dialedNumber = '';

  void _onKeyTap(String value) {
    if (_dialedNumber.length < 20) {
      setState(() {
        _dialedNumber += value;
      });
    }
  }

  void _onBackspace() {
    if (_dialedNumber.isNotEmpty) {
      setState(() {
        _dialedNumber = _dialedNumber.substring(0, _dialedNumber.length - 1);
      });
    }
  }

  void _onClear() {
    setState(() {
      _dialedNumber = '';
    });
  }

  void _makeCall() {
    if (_dialedNumber.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling $_dialedNumber...'),
        backgroundColor: KoraColors.waGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildKey(String number, String letters) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final card = KoraColors.cardFor(brightness);

    return InkWell(
      onTap: () => _onKeyTap(number),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: card,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              number,
              style: TextStyle(
                color: textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (letters.isNotEmpty)
              Text(
                letters,
                style: TextStyle(
                  color: KoraColors.textMutedFor(brightness),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = brightness == Brightness.dark ? KoraColors.deepNavy : KoraColors.lightBackground;
    final textPrimary = KoraColors.textPrimaryFor(brightness);

    final keys = [
      {'num': '1', 'letters': ''},
      {'num': '2', 'letters': 'ABC'},
      {'num': '3', 'letters': 'DEF'},
      {'num': '4', 'letters': 'GHI'},
      {'num': '5', 'letters': 'JKL'},
      {'num': '6', 'letters': 'MNO'},
      {'num': '7', 'letters': 'PQRS'},
      {'num': '8', 'letters': 'TUV'},
      {'num': '9', 'letters': 'WXYZ'},
      {'num': '*', 'letters': ''},
      {'num': '0', 'letters': '+'},
      {'num': '#', 'letters': ''},
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Keypad',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Display field for dialed number
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(
                        _dialedNumber.isEmpty ? ' ' : _dialedNumber,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  if (_dialedNumber.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.backspace_outlined, color: KoraColors.textSecondaryFor(brightness)),
                      onPressed: _onBackspace,
                      onLongPress: _onClear,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Keypad Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Wrap(
                spacing: 24,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: keys.map((k) => _buildKey(k['num']!, k['letters']!)).toList(),
              ),
            ),
            const SizedBox(height: 28),
            // Call Button (Kora brand gradient)
            GestureDetector(
              onTap: _makeCall,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: KoraColors.brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: KoraColors.purple.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.call,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
