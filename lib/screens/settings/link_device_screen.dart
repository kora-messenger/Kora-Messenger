import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../config/kora_api.dart';
import '../../services/session_manager.dart';
import '../../services/device_manager.dart';
import '../../theme/kora_colors.dart';

/// Telegram-style "Link a device" QR scanner screen.
///
/// Flow:
/// 1. User opens this on the NEW device they want to link
/// 2. Camera opens with a QR viewfinder and scanning animation
/// 3. User scans the QR code displayed on their primary device
/// 4. Kora validates the pairing token and registers the device session
/// 5. On success, the user's account data is returned and they're logged in
class LinkDeviceScreen extends StatefulWidget {
  const LinkDeviceScreen({super.key});

  @override
  State<LinkDeviceScreen> createState() => _LinkDeviceScreenState();
}

class _LinkDeviceScreenState extends State<LinkDeviceScreen> {
  late final MobileScannerController _scannerController;
  bool _scanning = true;
  bool _linking = false;
  bool _success = false;
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
    bool isWebPair = false;

    if (data.startsWith('kora://link')) {
      final uri = Uri.parse(data);
      token = uri.queryParameters['token'];
      email = uri.queryParameters['email'];
      // Web companion QR codes include web=true
      isWebPair = uri.queryParameters['web'] == 'true';
    } else {
      token = data.trim();
    }

    if (token == null || token.isEmpty) {
      setState(() => _error = 'Invalid QR code. Make sure you are scanning a Kora pairing code.');
      return;
    }

    setState(() {
      _scanning = false;
      _error = null;
    });

    try {
      final myDeviceId = await DeviceManager.getDeviceId();
      final myDeviceName = await DeviceManager.getDeviceName();
      final myPlatform = DeviceManager.getPlatform();
      final myEmail = email ?? SessionManager.instance.currentEmail;

      // Route to the correct endpoint:
      // - Web companion QR → koraWebPair/acceptPair
      // - Phone-to-phone QR → koraLinkDevice/linkDevice
      final String endpoint;
      final Map<String, dynamic> requestBody;

      if (isWebPair) {
        // Telegram-style: the account owner must explicitly confirm the link.
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final brightness = Theme.of(context).brightness;
            final textPrimary = KoraColors.textPrimaryFor(brightness);
            final textSecondary = KoraColors.textSecondaryFor(brightness);
            final card = KoraColors.cardFor(brightness);

            return AlertDialog(
              backgroundColor: card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Link this device?',
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
              content: Text(
                'A web browser is asking to access your Kora account. '
                'If you weren\'t expecting this, cancel.',
                style: TextStyle(color: textSecondary, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel', style: TextStyle(color: textSecondary)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Link device',
                      style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
        if (confirmed != true) {
          if (mounted) setState(() => _scanning = true);
          return;
        }

        setState(() => _linking = true);

        endpoint = KoraApi.webPairEndpoint;
        requestBody = {
          'action': 'acceptPair',
          'pairingToken': token,
          'ownerEmail': myEmail,
          'deviceId': myDeviceId,
        };
      } else {
        endpoint = KoraApi.linkDeviceEndpoint;
        requestBody = {
          'action': 'linkDevice',
          'pairingToken': token,
          'ownerEmail': myEmail,
          'newDeviceId': myDeviceId,
          'newDeviceName': myDeviceName,
          'newPlatform': myPlatform,
        };
      }

      final result = await KoraApi.postTo(endpoint, requestBody);

      if (result['success'] == true) {
        setState(() {
          _success = true;
          _linking = false;
        });
        // Show success state briefly then pop
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
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

  void _retry() {
    setState(() {
      _error = null;
      _scanning = true;
      _linking = false;
      _success = false;
    });
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
                _success
                    ? 'Device linked to your Kora account successfully'
                    : 'Point your camera at the QR code on the device you want to link',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _success ? Colors.green : textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Camera / scanner area
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Camera or overlay
                  if (_scanning && !_success)
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: _onDetect,
                    )
                  else
                    Container(color: Colors.black87),

                  // Viewfinder frame with scanning line
                  if (_scanning && !_success) _buildViewfinderFrame(),

                  // Success overlay
                  if (_success)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.5),
                                    blurRadius: 30,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Linked!',
                              style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),

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
                  if (_error != null && !_linking && !_success)
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
                              icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 18),
                              onPressed: _retry,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Flash toggle
                  if (_scanning && !_success)
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
                        decoration: TextDecoration.underline,
                        decorationColor: KoraColors.purple.withValues(alpha: 0.3),
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

  Widget _buildViewfinderFrame() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(
            color: KoraColors.purple.withValues(alpha: 0.4),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // Corner brackets
            ..._buildCornerBrackets(),
            // Scanning line animation
            _ScanningLine(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCornerBrackets() {
    const bracketSize = 30.0;
    const bracketWidth = 3.0;
    final color = KoraColors.purple;

    return [
      // Top-left
      Positioned(
        top: 0, left: 0,
        child: Container(
          width: bracketSize, height: bracketSize,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: bracketWidth),
              left: BorderSide(color: color, width: bracketWidth),
            ),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16)),
          ),
        ),
      ),
      // Top-right
      Positioned(
        top: 0, right: 0,
        child: Container(
          width: bracketSize, height: bracketSize,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: bracketWidth),
              right: BorderSide(color: color, width: bracketWidth),
            ),
            borderRadius: const BorderRadius.only(topRight: Radius.circular(16)),
          ),
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 0, left: 0,
        child: Container(
          width: bracketSize, height: bracketSize,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: bracketWidth),
              left: BorderSide(color: color, width: bracketWidth),
            ),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16)),
          ),
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: 0, right: 0,
        child: Container(
          width: bracketSize, height: bracketSize,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: bracketWidth),
              right: BorderSide(color: color, width: bracketWidth),
            ),
            borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
          ),
        ),
      ),
    ];
  }

  void _showHowToLinkSheet(Color textPrimary, Color textSecondary, Color card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to link a device',
              style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _buildStep(1, 'Open Kora on your other device and go to Settings > Devices', textPrimary, textSecondary),
            _buildStep(2, 'Tap "Show pairing code" to display a QR code', textPrimary, textSecondary),
            _buildStep(3, 'Point this device\'s camera at the QR code', textPrimary, textSecondary),
            _buildStep(4, 'Confirm the link and you\'re logged in on both devices', textPrimary, textSecondary),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KoraColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int n, String text, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(
              gradient: KoraColors.brandGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
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

/// Animated scanning line that moves up and down inside the viewfinder.
class _ScanningLine extends StatefulWidget {
  @override
  State<_ScanningLine> createState() => _ScanningLineState();
}

class _ScanningLineState extends State<_ScanningLine> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: 8,
          right: 8,
          top: 8 + (_controller.value * 226),
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  KoraColors.purple.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
