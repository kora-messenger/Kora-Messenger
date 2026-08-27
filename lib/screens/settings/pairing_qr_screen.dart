import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/kora_api.dart';
import '../../services/session_manager.dart';
import '../../theme/kora_colors.dart';

/// Telegram-style pairing QR screen with auto-refresh.
///
/// The QR code refreshes every 25 seconds (before the 30-second token
/// expires). A countdown ring shows the remaining time. After a device
/// scans and accepts the code, this screen polls for confirmation and
/// auto-closes with a success state.
class PairingQrScreen extends StatefulWidget {
  const PairingQrScreen({super.key});

  @override
  State<PairingQrScreen> createState() => _PairingQrScreenState();
}

class _PairingQrScreenState extends State<PairingQrScreen> {
  bool _loading = true;
  bool _linking = false;
  bool _success = false;
  String? _error;
  String? _qrData;
  String? _currentToken;
  int _secondsLeft = 30;
  Timer? _refreshTimer;
  Timer? _pollTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _generateToken();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateToken() async {
    setState(() {
      _error = null;
      if (!_linking && !_success) {
        _loading = true;
      }
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
        final newToken = result['pairingToken'] as String?;
        final newQrData = result['qrData'] as String?;
        final ttl = result['ttlSeconds'] as int? ?? 30;

        setState(() {
          _currentToken = newToken;
          _qrData = newQrData;
          _secondsLeft = ttl;
          _loading = false;
          _error = null;
        });

        // Start auto-refresh: refresh 5 seconds before expiry
        _refreshTimer?.cancel();
        _refreshTimer = Timer(Duration(seconds: ttl - 5), _generateToken);

        // Start countdown
        _countdownTimer?.cancel();
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (mounted) {
            setState(() => _secondsLeft--);
            if (_secondsLeft <= 0) t.cancel();
          } else {
            t.cancel();
          }
        });

        // Start polling for acceptance
        _startPolling();
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

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      if (!mounted || _currentToken == null) {
        t.cancel();
        return;
      }

      try {
        final email = SessionManager.instance.currentEmail;
        final result = await KoraApi.postTo(
          KoraApi.linkDeviceEndpoint,
          {
            'action': 'pollPairingStatus',
            'pairingToken': _currentToken,
            'email': email,
          },
        );

        if (result['success'] == true) {
          final status = result['status'] as String?;
          if (status == 'accepted') {
            t.cancel();
            _refreshTimer?.cancel();
            _countdownTimer?.cancel();
            if (mounted) {
              setState(() {
                _success = true;
                _linking = false;
              });
              // Auto-close after showing success for 1.5s
              Timer(const Duration(milliseconds: 1500), () {
                if (mounted) Navigator.pop(context, true);
              });
            }
          } else if (status == 'expired') {
            // Token was refreshed — will get a new one from the refresh timer
            t.cancel();
          }
        }
      } catch (_) {
        // Ignore poll errors — will retry on next tick
      }
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
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, color: textSecondary, size: 40),
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: textPrimary, fontSize: 14)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _generateToken,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: KoraColors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
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
                          // App avatar
                          Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              gradient: KoraColors.brandGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 36),
                          ),
                          const SizedBox(height: 20),

                          Text(
                            _success ? 'Device linked!' : 'Scan to link device',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _success
                                ? 'A new device has been linked to your account'
                                : 'Open Kora on your other device and scan this code',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.5),
                          ),
                          const SizedBox(height: 28),

                          // QR code card with countdown ring
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // QR code
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Container(
                                  key: ValueKey(_qrData),
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
                                  child: _success
                                      ? const Icon(Icons.check_circle_rounded,
                                          color: Colors.green, size: 120)
                                      : QrImageView(
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
                                        ),
                                ),
                              ),

                              // Countdown ring overlay (top-right corner)
                              if (!_success)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: bg,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _secondsLeft <= 5
                                            ? Colors.redAccent
                                            : KoraColors.purple,
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$_secondsLeft',
                                        style: TextStyle(
                                          color: _secondsLeft <= 5
                                              ? Colors.redAccent
                                              : textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          if (_success)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Successfully linked',
                                    style: TextStyle(
                                      color: Colors.green.shade300,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            // Auto-refresh indicator
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    value: 1 - (_secondsLeft / 30),
                                    strokeWidth: 2,
                                    color: KoraColors.purple.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Code refreshes automatically',
                                  style: TextStyle(color: textMuted, fontSize: 12.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: _generateToken,
                              icon: Icon(Icons.refresh_rounded, color: textSecondary, size: 18),
                              label: Text(
                                'Generate new code',
                                style: TextStyle(color: textSecondary, fontSize: 13.5, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
