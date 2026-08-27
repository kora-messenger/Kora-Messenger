import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../config/kora_api.dart';
import '../../services/session_manager.dart';
import '../../services/device_manager.dart';
import '../../theme/kora_colors.dart';

/// WhatsApp-style "Link a device" screen.
///
/// Flow:
/// 1. User opens this screen from Settings -> Devices -> "Link a device"
/// 2. Camera opens with a QR viewfinder (WhatsApp companion mode)
/// 3. User scans the QR code displayed on the device they want to link
/// 4. Kora validates the pairing token via the backend and registers
///    the new device session
class LinkDeviceScreen extends StatefulWidget {
  const LinkDeviceScreen({super.key});

  @override
  State<LinkDeviceScreen> createState() => _LinkDeviceScreenState();
}

class _LinkDeviceScreenState extends State<LinkDeviceScreen> {
  late final MobileScannerController _scannerController;
  bool _scanning = true;
  bool _linking = false;
  String? _error;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(autoStart: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_scanning || _linking) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    for (final bc in barcodes) {
      final raw = bc.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _handleScannedData(raw);
        return;
      }
    }
  }

  Future<void> _handleScannedData(String data) async {
    String? token;
    String? email;

    if (data.startsWith('kora://link')) {
      final uri = Uri.parse(data);
      token = uri.queryParameters['token'];
      email = uri.queryParameters['email'];
    } else {
      token = data.trim();
    }

    if (token == null || token.isEmpty) {
      setState(() => _error = 'Invalid QR code. Make sure you are scanning a Kora pairing code.');
      return;
    }

    setState(() {
      _scanning = false;
      _linking = true;
      _error = null;
    });

    try {
      final myDeviceId = await DeviceManager.getDeviceId();
      final myDeviceName = await DeviceManager.getDeviceName();
      final myPlatform = DeviceManager.getPlatform();
      final myEmail = SessionManager.instance.currentEmail;

      final result = await KoraApi.post({
        'action': 'linkDevice',
        'pairingToken': token,
        'ownerEmail': email ?? myEmail,
        'newDeviceId': myDeviceId,
        'newDeviceName': myDeviceName,
        'newPlatform': myPlatform,
      });

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Device linked successfully'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: KoraColors.purple,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _linking = false;
          _scanning = true;
          _error = result['error'] as String? ?? 'Could not link device. The code may have expired.';
        });
      }
    } catch (_) {
      setState(() {
        _linking = false;
        _scanning = true;
        _error = 'Network error. Please check your connection and try again.';
      });
    }
  }

  void _toggleTorch() {
    _torchOn = !_torchOn;
    _scannerController.toggleTorch();
    setState(() {});
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
          'Link a device',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Info banner
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                'Point your camera at the QR code displayed on the device you want to link.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.5),
              ),
            ),
            const SizedBox(height: 8),

            // Camera viewfinder
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_scanning)
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: _onDetect,
                    )
                  else
                    Container(color: Colors.black87),

                  // Viewfinder frame overlay
                  if (_scanning) _buildViewfinderFrame(),

                  // Linking spinner
                  if (_linking)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Colors.white),
                            const SizedBox(height: 16),
                            Text(
                              'Linking device...',
                              style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Error banner
                  if (_error != null && !_linking)
                    Positioned(
                      top: 16,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.redAccent.shade200, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                              onPressed: () => setState(() => _error = null),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Flash toggle
                  if (_scanning)
                    Positioned(
                      bottom: 24,
                      right: 24,
                      child: GestureDetector(
                        onTap: _toggleTorch,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: card,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
                            ],
                          ),
                          child: Icon(
                            _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            color: textPrimary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom info section
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, color: textMuted, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your linked device will stay logged in until you remove it from Devices.',
                          style: TextStyle(color: textMuted, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _showHowToLinkSheet(textPrimary, textSecondary, card),
                    child: Text(
                      'How to link a device',
                      style: TextStyle(
                        color: KoraColors.purple,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// WhatsApp-style viewfinder: dark overlay with transparent rounded square
  /// and animated corner brackets.
  Widget _buildViewfinderFrame() {
    return IgnorePointer(
      child: Stack(
        children: [
          // Dark overlay with transparent center (srcOut blend)
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.5),
              BlendMode.srcOut,
            ),
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          // Corner brackets
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: CustomPaint(painter: _CornerBracketPainter()),
            ),
          ),
        ],
      ),
    );
  }

  void _showHowToLinkSheet(Color textPrimary, Color textSecondary, Color card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to link a device',
              style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _howToStep('1', 'On your other device, open Kora and go to Settings', textPrimary, textSecondary),
            _howToStep('2', 'Tap "Devices" then "Link a device"', textPrimary, textSecondary),
            _howToStep('3', 'A QR code will appear on that device', textPrimary, textSecondary),
            _howToStep('4', 'Scan that QR code with this phone', textPrimary, textSecondary),
            _howToStep('5', 'Wait for the confirmation and you are linked!', textPrimary, textSecondary),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: KoraColors.purple.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Got it', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _howToStep(String num, String text, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: KoraColors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(num, style: const TextStyle(color: KoraColors.purple, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: textSecondary, fontSize: 14, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

/// Paints L-shaped corner brackets around the viewfinder cutout.
class _CornerBracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = KoraColors.purple
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 28.0;
    const radius = 20.0;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(radius, 0)
        ..lineTo(cornerLen, 0)
        ..moveTo(0, cornerLen)
        ..lineTo(0, radius),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(w - cornerLen, 0)
        ..lineTo(w - radius, 0)
        ..moveTo(w, cornerLen)
        ..lineTo(w, radius),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, h - cornerLen)
        ..lineTo(0, h - radius)
        ..moveTo(cornerLen, h)
        ..lineTo(radius, h),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w - cornerLen, h)
        ..lineTo(w - radius, h)
        ..moveTo(w, h - cornerLen)
        ..lineTo(w, h - radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
