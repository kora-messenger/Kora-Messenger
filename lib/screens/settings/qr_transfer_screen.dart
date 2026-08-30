import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// QR Transfer screen — dedicated QR scanner for chat transfer.
/// Mirrors WhatsApp's QR transfer flow.
///
/// This is the scanner view shown when receiving chats on a new phone.
/// Shows a camera viewfinder with a QR scanning frame.
class QrTransferScreen extends StatefulWidget {
  final ValueChanged<String>? onScanned;

  const QrTransferScreen({super.key, this.onScanned});

  @override
  State<QrTransferScreen> createState() => _QrTransferScreenState();
}

class _QrTransferScreenState extends State<QrTransferScreen> {
  bool _scanning = false;
  bool _found = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Scan QR Code',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Camera viewfinder background
          Container(color: Colors.black87),

          // Scanning frame
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 250, height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: _found ? Colors.green : KoraColors.purple, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    if (!_scanning)
                      Icon(Icons.qr_code_scanner, size: 80, color: Colors.white.withValues(alpha: 0.3)),
                    if (_scanning && !_found)
                      SizedBox(
                        width: 250, height: 250,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(seconds: 2),
                              builder: (context, value, child) {
                                return Stack(
                                  children: [
                                    Positioned(
                                      left: 0, right: 0,
                                      top: value * 230,
                                      child: Container(
                                        height: 2,
                                        margin: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [
                                            Colors.transparent,
                                            KoraColors.purple,
                                            Colors.transparent,
                                          ]),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    if (_found)
                      const Icon(Icons.check_circle, size: 64, color: Colors.green),
                  ],
                ),
                const SizedBox(height: 24),
                if (!_found) ...[
                  Text(
                    _scanning ? 'Scanning...' : 'Point your camera at the QR code\non your old device',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  if (!_scanning)
                    ElevatedButton(
                      onPressed: _startScan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KoraColors.purple, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Start Scan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                ] else ...[
                  Text('QR Code Found!',
                      style: TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Connecting to device...',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 16),
                  CircularProgressIndicator(color: KoraColors.purple),
                ],
              ],
            ),
          ),

          // Bottom info bar
          Positioned(
            bottom: 24, left: 24, right: 24,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi, color: KoraColors.purple, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keep both devices on the same Wi-Fi network',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
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

  void _startScan() async {
    setState(() => _scanning = true);
    // Simulate finding QR code after 3 seconds
    await Future.delayed(const Duration(seconds: 3));
    setState(() => _found = true);
    await Future.delayed(const Duration(seconds: 2));
    if (widget.onScanned != null) {
      widget.onScanned!('kora_transfer_token_${DateTime.now().millisecondsSinceEpoch}');
    }
    if (mounted) Navigator.pop(context);
  }
}
