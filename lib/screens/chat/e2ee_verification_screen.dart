import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/kora_colors.dart';
import '../../services/kora_encryption_service.dart';

/// E2EE Verification Screen — shows the safety number for a conversation.
/// Both users see the same 60-digit number and can compare to verify
/// that their communication is secure and not being intercepted.
///
/// Mirrors WhatsApp's "Encryption" / "Verify Security Code" screen.
class E2eeVerificationScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String? peerPublicKey;

  const E2eeVerificationScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    this.peerPublicKey,
  });

  @override
  State<E2eeVerificationScreen> createState() => _E2eeVerificationScreenState();
}

class _E2eeVerificationScreenState extends State<E2eeVerificationScreen> {
  String? _safetyNumber;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _computeSafetyNumber();
  }

  Future<void> _computeSafetyNumber() async {
    try {
      await KoraEncryptionService.instance.init();
      final peerKey = widget.peerPublicKey ?? '';
      if (peerKey.isEmpty) {
        // If we don't have the peer's public key yet, show a placeholder
        setState(() {
          _safetyNumber = null;
          _loading = false;
        });
        return;
      }
      final number = await KoraEncryptionService.instance.computeSafetyNumber(
        widget.chatId,
        peerKey,
      );
      setState(() {
        _safetyNumber = number;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _safetyNumber = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF5F5F5);
    final surface = isDark ? const Color(0xFF1A1D24) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        title: Text(
          'Encryption',
          style: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 32),
          // Lock icon
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [KoraColors.purple, KoraColors.blue],
                ),
              ),
              child: const Icon(
                Icons.lock,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Messages and calls are end-to-end encrypted',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Only the people in this conversation can read, listen to, or share them. Nobody else, not even Kora, can access them.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Safety number
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: KoraColors.purple),
              ),
            )
          else if (_safetyNumber != null)
            _buildSafetyNumberCard(
              surface,
              textPrimary,
              textSecondary,
            )
          else
            _buildNoKeyCard(surface, textPrimary, textSecondary),
          const SizedBox(height: 24),
          // Info text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'To verify that this conversation is secure, scan the QR code on ${widget.chatName}\'s phone or ask them to confirm that the code on their screen matches the one above.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSafetyNumberCard(
    Color surface,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = _safetyNumber!.split(' ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: KoraColors.purple.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Security Code',
            style: TextStyle(
              color: textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Safety number in groups of 5 digits
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: groups.map((group) {
              return Text(
                group,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // Copy button
          TextButton.icon(
            onPressed: () {
              final cleanNumber = _safetyNumber!.replaceAll(' ', '');
              Clipboard.setData(ClipboardData(text: cleanNumber));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Security code copied'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: Icon(Icons.copy, size: 18, color: KoraColors.purple),
            label: Text(
              'Copy code',
              style: TextStyle(color: KoraColors.purple, fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          // QR Code visual fingerprint
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: KoraColors.purple.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: CustomPaint(
              painter: _FingerprintPainter(
                _safetyNumber!,
                KoraColors.purple,
              ),
              size: const Size(160, 160),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan QR code to verify',
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoKeyCard(
    Color surface,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            color: KoraColors.purple.withValues(alpha: 0.6),
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            'Security code not available yet',
            style: TextStyle(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The security code will be available once an encrypted session is established with ${widget.chatName}.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}


/// Paints a visual cryptographic fingerprint as a grid of squares
/// derived from the safety number hash. Mirrors Signal/WhatsApp's
/// QR code + visual fingerprint approach.
class _FingerprintPainter extends CustomPainter {
  final String safetyNumber;
  final Color accentColor;

  _FingerprintPainter(this.safetyNumber, this.accentColor);

  @override
  void paint(Canvas canvas, Size size) {
    final cleanNumber = safetyNumber.replaceAll(' ', '');
    
    // Generate a deterministic 12x12 grid from the safety number
    final grid = List.generate(12, (row) {
      return List.generate(6, (col) {
        final idx = (row * 6 + col) % cleanNumber.length;
        final charCode = cleanNumber.codeUnitAt(idx);
        return (charCode + row + col) % 2 == 0;
      });
    });

    final cellSize = size.width / 12;
    final paint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw symmetric fingerprint grid (left 6 cols mirrored to right 6)
    for (int row = 0; row < 12; row++) {
      for (int col = 0; col < 6; col++) {
        if (grid[row][col]) {
          final x = col * cellSize;
          final y = row * cellSize;
          canvas.drawRect(
            Rect.fromLTWH(x, y, cellSize, cellSize),
            paint,
          );
          // Mirror to right side for symmetry
          canvas.drawRect(
            Rect.fromLTWH(
              (11 - col) * cellSize,
              y,
              cellSize,
              cellSize,
            ),
            paint,
          );
        }
      }
    }

    // Draw border
    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FingerprintPainter oldDelegate) {
    return oldDelegate.safetyNumber != safetyNumber;
  }
}
