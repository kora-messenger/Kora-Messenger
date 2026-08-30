import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// QR Transfer screen — camera scanner for chat transfer pairing.
/// Matches WhatsApp's QR code scanner interface for chat transfer.
class QrTransferScreen extends StatefulWidget {
  final ValueChanged<String>? onScanned;

  const QrTransferScreen({super.key, this.onScanned});

  @override
  State<QrTransferScreen> createState() => _QrTransferScreenState();
}

class _QrTransferScreenState extends State<QrTransferScreen>
    with SingleTickerProviderStateMixin {
  bool _scanning = true;
  bool _found = false;
  bool _flashOn = false;
  late AnimationController _animController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Auto-scan simulation
    _startScanTimer();
  }

  void _startScanTimer() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted && _scanning && !_found) {
      _onCodeDetected();
    }
  }

  void _onCodeDetected() async {
    setState(() {
      _scanning = false;
      _found = true;
    });
    _animController.stop();

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      final token = 'kora_transfer_token_${DateTime.now().millisecondsSinceEpoch}';
      if (widget.onScanned != null) {
        widget.onScanned!(token);
      }
      Navigator.pop(context, token);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _flashOn ? Icons.flash_on : Icons.flash_off,
              color: _flashOn ? Colors.yellow : Colors.white,
            ),
            onPressed: () => setState(() => _flashOn = !_flashOn),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Viewfinder simulation
          Container(
            color: Colors.black,
            child: Center(
              child: Opacity(
                opacity: _flashOn ? 0.3 : 0.1,
                child: const Icon(Icons.camera_alt, size: 160, color: Colors.white),
              ),
            ),
          ),

          // Central scanning box
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Scanner box border
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _found
                              ? Colors.green
                              : KoraColors.purple.withValues(alpha: 0.8),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_found ? Colors.green : KoraColors.purple)
                                .withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),

                    // Scanning laser line
                    if (_scanning && !_found)
                      SizedBox(
                        width: 240,
                        height: 240,
                        child: AnimatedBuilder(
                          animation: _scanAnimation,
                          builder: (context, child) {
                            return Stack(
                              children: [
                                Positioned(
                                  top: _scanAnimation.value * 220,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          KoraColors.purple,
                                          KoraColors.blue,
                                          Colors.transparent,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: KoraColors.purple.withValues(alpha: 0.8),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                    // Found checkmark
                    if (_found)
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 50, color: Colors.white),
                      ),
                  ],
                ),

                const SizedBox(height: 32),

                // Status text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        _found
                            ? 'Pairing confirmed!'
                            : 'Scan the QR code shown on your old phone',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _found ? Colors.green : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _found
                            ? 'Connecting devices and transferring chats...'
                            : 'Point your camera at the screen to start transfer',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom tip bar
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KoraColors.purple.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi, color: KoraColors.purple, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Both phones must be connected to the same Wi-Fi network',
                      style: TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
