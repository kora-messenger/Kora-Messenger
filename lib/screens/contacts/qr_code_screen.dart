import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../theme/kora_colors.dart';
import '../../services/session_manager.dart';
import '../../widgets/kora_avatar.dart';
import '../../widgets/kora_menu_sheet.dart';
import '../../models/chat_models.dart';
import '../../services/contacts_service.dart';
import '../chat/contact_info_screen.dart';

/// Kora's "QR code" screen — same two-tab structure as the WhatsApp
/// screen it's modeled after ("My code" / "Scan code"), but dressed in
/// Kora's own identity: purple-to-blue gradient tab indicator, a
/// gradient avatar ring overlapping the code card, and the Kora mark
/// embedded at the center of the QR itself.
///
/// "My code" shows the signed-in user's own QR so others can scan it
/// to add them as a contact. "Scan code" runs the live camera scanner
/// inline in the same screen; a recognized Kora QR opens that
/// contact's profile.
class QrCodeScreen extends StatefulWidget {
  const QrCodeScreen({super.key});

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final MobileScannerController _scannerController = MobileScannerController(autoStart: true);
  final GlobalKey _codeCardKey = GlobalKey();
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, dynamic>? _session;
  bool _navigated = false;
  bool _sharing = false;

  // Screen brightness is boosted to max while the Scan Code tab is
  // active (like WhatsApp) so the camera has the best chance of
  // reading a QR code in a dim room, and restored the moment the
  // user leaves the tab or the screen.
  double? _originalBrightness;
  bool _brightnessBoosted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadSession();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && _tabController.index == 1) {
      _navigated = false;
      _boostBrightness();
    } else if (_tabController.index == 0) {
      _stopScanner();
      _restoreBrightness();
    }
    setState(() {});
  }

  Future<void> _startScanner() async {
    // With autoStart: true, the MobileScanner widget handles starting
    // automatically when it enters the tree. This method is kept for
    // any manual restart needs but the widget lifecycle is the primary driver.
    try {
      await _scannerController.start();
    } catch (_) {
      // Ignore — widget lifecycle handles this.
    }
  }

  Future<void> _stopScanner() async {
    try {
      await _scannerController.stop();
    } catch (_) {
      // Same guard — ignore if already stopped or disposing.
    }
  }

  Future<void> _boostBrightness() async {
    if (_brightnessBoosted) return;
    try {
      _originalBrightness ??= await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(1.0);
      _brightnessBoosted = true;
    } catch (_) {
      // Some devices/emulators don't support programmatic brightness —
      // fail silently, the scanner still works at normal brightness.
    }
  }

  Future<void> _restoreBrightness() async {
    if (!_brightnessBoosted) return;
    try {
      await ScreenBrightness().resetScreenBrightness();
    } catch (_) {
      // Ignore — nothing meaningful to recover from here.
    }
    _brightnessBoosted = false;
  }

  Future<void> _loadSession() async {
    final session = await SessionManager.instance.loadSession();
    if (!mounted) return;
    setState(() => _session = session);
  }

  Future<void> _toggleTorch() => _scannerController.toggleTorch();

  Future<void> _switchCamera() => _scannerController.switchCamera();

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final capture = await _scannerController.analyzeImage(picked.path);
      if (capture == null || capture.barcodes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No QR code found in that image'),
              backgroundColor: KoraColors.purple,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      _onDetect(capture);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn\'t read that image. Try another one.'),
            backgroundColor: KoraColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scannerController.dispose();
    // Best-effort restore — the screen is closing regardless, so this
    // doesn't need to be awaited.
    if (_brightnessBoosted) {
      ScreenBrightness().resetScreenBrightness();
    }
    super.dispose();
  }

  /// Tries to match a scanned Kora QR payload to a known contact.
  /// QR format: `kora://contact/<koraId>` or `kora://contact/<username>`.
  Future<Map<String, Object?>?> _findContactByQrData(String data) async {
    return ContactsService.instance.findByQrData(data);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_navigated) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    for (final barcode in barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      _findContactByQrData(raw).then((contact) {
        if (_navigated || !mounted) return;
        if (contact != null) {
          _navigated = true;
          _openContactProfile(contact);
          return;
        }

        if (raw.startsWith('kora://contact/')) {
          _navigated = true;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Contact not found on Kora'),
                backgroundColor: KoraColors.purple,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _navigated = false);
          });
        }
      });
      return;
    }
  }

  void _openContactProfile(Map<String, Object?> contact) {
    final name = contact['name'] as String;
    final koraId = contact['koraId'] as String;
    final username = contact['username'] as String? ?? '';
    final isPremium = contact['premium'] == true;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactInfoScreen(
          name: name,
          koraId: koraId.isNotEmpty ? koraId : null,
          username: username.isNotEmpty ? username : null,
          badge: isPremium ? KoraBadgeType.premiumBlue : KoraBadgeType.none,
          isOnline: true,
          about: 'Hey there! I\'m on Kora.',
        ),
      ),
    );
  }

  Future<void> _shareQrCode() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _codeCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = Uint8List.view(byteData.buffer);
      final tempDir = await getTemporaryDirectory();
      final fullName = _session?['fullName']?.toString() ?? 'Kora User';
      final safeName = fullName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final file = File('${tempDir.path}/kora_qr_$safeName.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Scan my Kora QR code to add me!',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn\'t share QR code. Try again.'),
            backgroundColor: KoraColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _openMenu() {
    KoraMenuSheet.show(context, [
      KoraMenuOption(
        icon: Icons.share_outlined,
        label: 'Share QR code',
        onTap: _shareQrCode,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.surfaceFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'QR code',
          style: TextStyle(color: textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: _sharing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: textPrimary),
                  )
                : Icon(Icons.share_outlined, color: textPrimary, size: 22),
            onPressed: _shareQrCode,
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: textPrimary),
            onPressed: _openMenu,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            color: card,
            child: TabBar(
              controller: _tabController,
              indicator: const _GradientTabIndicator(),
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: textPrimary,
              unselectedLabelColor: textSecondary,
              labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6),
              unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.6),
              tabs: const [
                Tab(text: 'MY CODE'),
                Tab(text: 'SCAN CODE'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyCodeTab(context, bg, card, textPrimary, textSecondary),
          _buildScanTab(context),
        ],
      ),
    );
  }

  // ── My Code ──────────────────────────────────────────────

  Widget _buildMyCodeTab(
    BuildContext context,
    Color bg,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    final fullName = _session?['fullName']?.toString() ?? 'Kora User';
    final username = _session?['username']?.toString() ?? 'user';
    final koraId = _session?['koraId']?.toString() ?? '';
    final avatarUrl = _session?['avatarUrl']?.toString();
    final qrData = koraId.isNotEmpty ? 'kora://contact/$koraId' : 'kora://contact/$username';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 44),
            Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 36),
                  child: RepaintBoundary(
                    key: _codeCardKey,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 52, 24, 28),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: KoraColors.purple.withValues(alpha: 0.14),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            fullName,
                            style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Kora contact',
                            style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 22),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: KoraColors.purple.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: QrImageView(
                              data: qrData,
                              version: QrVersions.auto,
                              size: 208,
                              errorCorrectionLevel: QrErrorCorrectLevel.H,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: KoraColors.deepNavy,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: KoraColors.deepNavy,
                              ),
                              embeddedImage: const AssetImage('assets/icon/kora_icon.png'),
                              embeddedImageStyle: const QrEmbeddedImageStyle(
                                size: Size(46, 46),
                              ),
                            ),
                          ),
                          if (koraId.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Text(
                              koraId,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // Gradient-ringed avatar overlapping the top of the card
                Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    gradient: KoraColors.brandGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                    child: KoraAvatar(name: fullName, imageUrl: avatarUrl, size: 64),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Your QR code is private. If you share it with someone, '
              'they can scan it with their Kora camera to add you as a contact.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.55),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Scan Code ────────────────────────────────────────────

  Widget _buildScanTab(BuildContext context) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final active = _tabController.index == 1;
        final screenWidth = MediaQuery.of(context).size.width;
        final boxSize = screenWidth * 0.76;

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: KoraColors.trueBlack),
            // Camera flip button — top-right, floating over the dark area
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: _switchCamera,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cameraswitch_outlined, color: Colors.white, size: 20),
                ),
              ),
            ),
            // Rounded-square camera viewfinder — WhatsApp-style, not full bleed
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 96),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: boxSize,
                        height: boxSize,
                        child: active
                            ? MobileScanner(
                                controller: _scannerController,
                                onDetect: _onDetect,
                                fit: BoxFit.cover,
                              )
                            : Container(color: KoraColors.trueBlack),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Scan a Kora QR code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom row — gallery (pick a QR from a photo) and torch toggle
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _pickFromGallery,
                      child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 24),
                    ),
                    ValueListenableBuilder<MobileScannerState>(
                      valueListenable: _scannerController,
                      builder: (context, state, _) {
                        final torchOn = state.torchState == TorchState.on;
                        return GestureDetector(
                          onTap: _toggleTorch,
                          child: Icon(
                            torchOn ? Icons.flash_on : Icons.flash_off,
                            color: Colors.white,
                            size: 24,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Gradient tab indicator ──────────────────────────────────

class _GradientTabIndicator extends Decoration {
  const _GradientTabIndicator();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _GradientTabPainter();
  }
}

class _GradientTabPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size!;
    const thickness = 3.0;
    final rect = Rect.fromLTWH(offset.dx, offset.dy + size.height - thickness, size.width, thickness);
    final paint = Paint()..shader = KoraColors.brandGradient.createShader(rect);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    canvas.drawRRect(rrect, paint);
  }
}

