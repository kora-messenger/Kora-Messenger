import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/kora_colors.dart';
import '../../services/session_manager.dart';
import '../../widgets/kora_avatar.dart';
import '../../models/chat_models.dart';
import '../../data/mock_contacts.dart';
import '../chat/contact_info_screen.dart';

/// Kora's "My Code" screen — shows the signed-in user's own QR code so
/// others can scan it to add them as a contact. The "Scan code" button
/// opens the camera scanner; when a valid Kora QR is detected, it
/// automatically opens the contact's profile screen.
class QrCodeScreen extends StatefulWidget {
  const QrCodeScreen({super.key});

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  Map<String, dynamic>? _session;
  bool _scanning = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await SessionManager.instance.loadSession();
    if (!mounted) return;
    setState(() => _session = session);
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Tries to match a scanned Kora QR payload to a known mock contact.
  /// QR format: `kora://contact/<koraId>` or `kora://contact/<username>`.
  Map<String, Object>? _findContactByQrData(String data) {
    // Parse the QR data
    if (!data.startsWith('kora://contact/')) return null;
    final identifier = data.substring('kora://contact/'.length).toLowerCase();

    for (final contact in koraMockContacts) {
      final koraId = (contact['koraId'] as String).toLowerCase();
      final username = (contact['username'] as String).toLowerCase();
      final usernameClean = username.replaceAll('@', '');
      if (koraId == identifier || username == identifier || usernameClean == identifier) {
        return contact;
      }
    }
    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_navigated) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    for (final barcode in barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      final contact = _findContactByQrData(raw);
      if (contact != null) {
        _navigated = true;
        _openContactProfile(contact);
        return;
      }

      // If it's a Kora QR but no match, show a message
      if (raw.startsWith('kora://contact/')) {
        _navigated = true;
        if (mounted) {
          setState(() => _scanning = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contact not found on Kora'),
              backgroundColor: KoraColors.purple,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _navigated = false);
          }
        });
        return;
      }
    }
  }

  void _openContactProfile(Map<String, Object> contact) {
    final name = contact['name'] as String;
    final koraId = contact['koraId'] as String;
    final username = contact['username'] as String;
    final isPremium = contact['premium'] as bool;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ContactInfoScreen(
          name: name,
          koraId: koraId,
          username: username,
          badge: isPremium ? KoraBadgeType.premiumBlue : KoraBadgeType.none,
          isOnline: true,
          about: 'Hey there! I\'m on Kora.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);

    final fullName = _session?['fullName']?.toString() ?? 'Kora User';
    final username = _session?['username']?.toString() ?? 'user';
    final koraId = _session?['koraId']?.toString() ?? '';
    final qrData = koraId.isNotEmpty ? 'kora://contact/$koraId' : 'kora://contact/$username';

    if (_scanning) {
      return _buildScanner(context, bg, textPrimary, textSecondary);
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Code',
          style: TextStyle(color: textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                'Let others scan this code to add you on Kora',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: KoraColors.purple.withValues(alpha: 0.12),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    KoraAvatar(name: fullName, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      fullName,
                      style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: TextStyle(color: textSecondary, fontSize: 13.5),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: KoraColors.deepNavy,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: KoraColors.deepNavy,
                        ),
                      ),
                    ),
                    if (koraId.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        koraId,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    _scanning = true;
                    _navigated = false;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, color: KoraColors.purple, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Scan code',
                        style: TextStyle(
                          color: KoraColors.purple,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanner(BuildContext context, Color bg, Color textPrimary, Color textSecondary) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() => _scanning = false);
          },
        ),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          // Camera scanner
          MobileScanner(
            onDetect: _onDetect,
            fit: BoxFit.cover,
          ),
          // Scanning frame overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: KoraColors.purple, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          // Instruction text
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Text(
              'Point your camera at a Kora QR code',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
