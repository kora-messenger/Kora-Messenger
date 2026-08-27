import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/kora_api.dart';
import '../../services/session_manager.dart';
import '../../theme/kora_colors.dart';

/// Shows a QR code that another device can scan to link this device.
///
/// This is the "display" side of the Link Device flow. The user opens
/// this on their secondary device, and the primary device scans the QR.
class PairingQrScreen extends StatefulWidget {
  const PairingQrScreen({super.key});

  @override
  State<PairingQrScreen> createState() => _PairingQrScreenState();
}

class _PairingQrScreenState extends State<PairingQrScreen> {
  bool _loading = true;
  String? _error;
  String? _qrData;

  @override
  void initState() {
    super.initState();
    _generateToken();
  }

  Future<void> _generateToken() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = SessionManager.instance.currentEmail;
      if (email.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Not logged in';
        });
        return;
      }

      final result = await KoraApi.postTo(
        KoraApi.linkDeviceEndpoint,
        {
          'action': 'generatePairingToken',
          'email': email,
        },
      );

      if (result['success'] == true) {
        setState(() {
          _qrData = result['qrData'] as String?;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = result['error'] as String? ?? 'Could not generate pairing code';
        });
      }
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Network error. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final card = KoraColors.cardFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Pairing code',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, color: textSecondary, size: 40),
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: textPrimary, fontSize: 14)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _generateToken,
                          child: const Text('Retry', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Avatar
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: KoraColors.brandGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 36),
                          ),
                          const SizedBox(height: 20),

                          Text(
                            'Link a new device',
                            style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Scan this QR code from your other device to link it to your Kora account',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.5),
                          ),
                          const SizedBox(height: 28),

                          // QR code card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: _qrData ?? '',
                              version: QrVersions.auto,
                              size: 220,
                              gapless: true,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF6C5CE7),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF1A1A2E),
                              ),
                              embeddedImage: null,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Expiry notice
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: KoraColors.purple.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_outlined, color: KoraColors.purple, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Code expires in 5 minutes',
                                  style: TextStyle(color: KoraColors.purple, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Refresh button
                          TextButton.icon(
                            onPressed: _generateToken,
                            icon: Icon(Icons.refresh_rounded, color: textSecondary, size: 18),
                            label: Text(
                              'Generate new code',
                              style: TextStyle(color: textSecondary, fontSize: 13.5, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
