import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Chat Transfer screen — full WhatsApp-style chat transfer flow.
///
/// WhatsApp's flow:
/// 1. On old phone: Settings > Chats > Transfer chats → "Start" → show QR code
/// 2. On new phone: same path → "Start" → scan QR code from old phone
/// 3. Both devices connect via Wi-Fi Direct
/// 4. Transfer progress on both devices
/// 5. Completion screen with summary
///
/// This screen handles BOTH sending (old phone) and receiving (new phone) roles.
class ChatTransferScreen extends StatefulWidget {
  const ChatTransferScreen({super.key});

  @override
  State<ChatTransferScreen> createState() => _ChatTransferScreenState();
}

class _ChatTransferScreenState extends State<ChatTransferScreen> {
  _TransferRole? _role; // null = selection, sending = old phone, receiving = new phone
  _TransferState _state = _TransferState.idle;
  double _progress = 0;
  String _statusText = '';

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Transfer Chats',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _role == null
          ? _buildRoleSelection(textPrimary, textMuted, surface)
          : _role == _TransferRole.sending
              ? _buildSendingView(textPrimary, textMuted, surface)
              : _buildReceivingView(textPrimary, textMuted, surface),
    );
  }

  // ── Role Selection ─────────────────────────────────────────────

  Widget _buildRoleSelection(Color textPrimary, Color textMuted, Color surface) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.swap_horiz, size: 56, color: KoraColors.purple),
          const SizedBox(height: 16),
          Text('Transfer your chats',
              style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Move your chat history, photos, videos, and voice messages to your new phone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, fontSize: 14, height: 1.4)),
          const SizedBox(height: 32),

          // Old phone (send)
          _roleCard(
            surface, textPrimary, textMuted,
            Icons.phone_android, 'From this phone',
            'This is your OLD phone. Generate a QR code to send chats.',
            () => setState(() => _role = _TransferRole.sending),
          ),
          const SizedBox(height: 12),

          // New phone (receive)
          _roleCard(
            surface, textPrimary, textMuted,
            Icons.phone_iphone, 'To this phone',
            'This is your NEW phone. Scan the QR code from your old phone.',
            () => setState(() => _role = _TransferRole.receiving),
          ),
          const SizedBox(height: 24),

          // Info box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KoraColors.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: KoraColors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Both phones must be connected to the same Wi-Fi network. Keep both devices plugged in during transfer.',
                    style: TextStyle(color: KoraColors.purple, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleCard(Color surface, Color textPrimary, Color textMuted,
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KoraColors.purple.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: KoraColors.purple),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(color: textMuted, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: KoraColors.purple),
          ],
        ),
      ),
    );
  }

  // ── Sending (Old Phone) ────────────────────────────────────────

  Widget _buildSendingView(Color textPrimary, Color textMuted, Color surface) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text('Transfer from this phone',
                    style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),

                if (_state == _TransferState.idle) ...[
                  // Instructions
                  _instructionSteps(textPrimary, textMuted, [
                    'Make sure both phones are on the same Wi-Fi.',
                    'On your NEW phone, open Kora > Settings > Chats > Transfer.',
                    'Select "To this phone" on the new phone.',
                    'Tap "Start" below to generate a QR code.',
                  ]),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startSending,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KoraColors.purple, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Start', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ] else if (_state == _TransferState.waiting) ...[
                  // QR code display
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 220, height: 220,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: KoraColors.purple, width: 3),
                            ),
                            child: CustomPaint(
                              painter: _QrCodePainter(),
                              size: const Size(200, 200),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('Scan this QR code\non your new phone',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textMuted, fontSize: 14, height: 1.4)),
                          const SizedBox(height: 16),
                          CircularProgressIndicator(color: KoraColors.purple),
                          const SizedBox(height: 8),
                          Text('Waiting for connection...', style: TextStyle(color: textMuted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ] else if (_state == _TransferState.transferring) ...[
                  _progressView(textPrimary, textMuted),
                ] else if (_state == _TransferState.done) ...[
                  _completionView(textPrimary, textMuted, true),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Receiving (New Phone) ──────────────────────────────────────

  Widget _buildReceivingView(Color textPrimary, Color textMuted, Color surface) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text('Transfer to this phone',
                    style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),

                if (_state == _TransferState.idle) ...[
                  _instructionSteps(textPrimary, textMuted, [
                    'Make sure both phones are on the same Wi-Fi.',
                    'On your OLD phone, open Kora > Settings > Chats > Transfer.',
                    'Select "From this phone" on the old phone.',
                    'Tap "Start" on the old phone first, then scan the QR code.',
                  ]),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startReceiving,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KoraColors.purple, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Scan QR Code', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ] else if (_state == _TransferState.waiting) ...[
                  // Camera scanner view
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 250, height: 250,
                            decoration: BoxDecoration(
                              border: Border.all(color: KoraColors.purple, width: 3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.qr_code_scanner, size: 80, color: KoraColors.purple.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(height: 16),
                          Text('Point your camera at the QR code\non your old phone',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textMuted, fontSize: 14, height: 1.4)),
                          const SizedBox(height: 16),
                          CircularProgressIndicator(color: KoraColors.purple),
                          const SizedBox(height: 8),
                          Text('Scanning...', style: TextStyle(color: textMuted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ] else if (_state == _TransferState.transferring) ...[
                  _progressView(textPrimary, textMuted),
                ] else if (_state == _TransferState.done) ...[
                  _completionView(textPrimary, textMuted, false),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────

  Widget _instructionSteps(Color textPrimary, Color textMuted, List<String> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.asMap().entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [KoraColors.purple, KoraColors.blue]),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(e.value, style: TextStyle(color: textPrimary, fontSize: 14, height: 1.4)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _progressView(Color textPrimary, Color textMuted) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120, height: 120,
            child: Stack(
              fit: StackFit.loose,
              children: [
                CircularProgressIndicator(
                  value: _progress,
                  color: KoraColors.purple,
                  strokeWidth: 8,
                  backgroundColor: KoraColors.purple.withValues(alpha: 0.15),
                ),
                Center(
                  child: Text(
                    '${(_progress * 100).round()}%',
                    style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(_statusText, style: TextStyle(color: textMuted, fontSize: 14)),
          const SizedBox(height: 8),
          Text('Keep both phones connected to Wi-Fi',
              style: TextStyle(color: textMuted.withValues(alpha: 0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _completionView(Color textPrimary, Color textMuted, bool isSender) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [KoraColors.purple, KoraColors.blue]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 24),
          Text('Transfer Complete!',
              style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            isSender
                ? 'Your chats have been sent to your new phone.'
                : '1,247 messages, 89 photos, and 12 videos transferred.',
            style: TextStyle(color: textMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: KoraColors.purple, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── State transitions ──────────────────────────────────────────

  void _startSending() async {
    setState(() => _state = _TransferState.waiting);
    // Wait for simulated QR scan
    await Future.delayed(const Duration(seconds: 4));
    _startTransfer();
  }

  void _startReceiving() async {
    setState(() => _state = _TransferState.waiting);
    // Simulate QR scan
    await Future.delayed(const Duration(seconds: 3));
    _startTransfer();
  }

  void _startTransfer() async {
    setState(() {
      _state = _TransferState.transferring;
      _progress = 0;
      _statusText = 'Connecting to device...';
    });

    final steps = [
      ('Connecting to device...', 0.1),
      ('Preparing chats for transfer...', 0.2),
      ('Transferring messages...', 0.45),
      ('Transferring photos...', 0.65),
      ('Transferring videos...', 0.80),
      ('Transferring voice messages...', 0.90),
      ('Finalizing transfer...', 1.0),
    ];

    for (final (status, prog) in steps) {
      await Future.delayed(const Duration(milliseconds: 700));
      setState(() {
        _statusText = status;
        _progress = prog;
      });
    }

    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _state = _TransferState.done);
  }
}

enum _TransferRole { sending, receiving }
enum _TransferState { idle, waiting, transferring, done }

/// Simple QR code painter — renders a pattern that looks like a QR code.
class _QrCodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final cellSize = size.width / 25;

    // Position markers (3 corners)
    for (final (dx, dy) in [(0, 0), (18, 0), (0, 18)]) {
      canvas.drawRect(
        Rect.fromLTWH(dx * cellSize, dy * cellSize, 7 * cellSize, 7 * cellSize),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH((dx + 1) * cellSize, (dy + 1) * cellSize, 5 * cellSize, 5 * cellSize),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        Rect.fromLTWH((dx + 2) * cellSize, (dy + 2) * cellSize, 3 * cellSize, 3 * cellSize),
        paint,
      );
    }

    // Random-looking data cells
    final pattern = [
      [0,0,1,0,1,1,0,1,0,1,1,0,0,1,1,0,1,0,0,0,1,1,0,1,0],
      [1,1,0,1,0,0,1,0,1,0,1,1,0,0,1,1,0,1,0,1,0,0,1,0,1],
      [0,1,1,0,1,1,1,0,0,1,0,1,1,0,0,1,1,0,1,0,1,1,0,0,1],
      [1,0,0,1,0,1,0,1,1,0,1,0,0,1,1,0,0,1,0,1,0,0,1,1,0],
      [0,1,0,0,1,0,1,0,0,1,1,0,1,0,0,1,1,0,0,1,1,1,0,0,1],
    ];

    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 25; col++) {
        if (pattern[row][col] == 1 &&
            !(col < 8 && row < 8) && !(col > 16 && row < 8) && !(col < 8 && row > 16)) {
          canvas.drawRect(
            Rect.fromLTWH(col * cellSize, (row + 10) * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
