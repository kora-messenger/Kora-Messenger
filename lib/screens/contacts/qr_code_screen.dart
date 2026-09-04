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

/// Kora's QR code screen — matches WhatsApp's 2026 QR screen design.
///
/// Two tabs: "MY CODE" and "SCAN CODE".
///
/// My Code:
/// - Gradient-ringed avatar overlapping a white card
/// - QR code with Kora logo embedded at center
/// - User's name, Kora ID, privacy note
/// - Share + 3-dot menu (Reset QR code)
///
/// Scan Code:
/// - Full-screen dark background
/// - Rounded-square camera viewfinder with animated scan line + corner brackets
/// - Gallery pick, flash toggle, camera flip
/// - "Scan a Kora QR code" hint text
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
  bool _resetting = false;

  // QR data that can be reset
  String _qrSeed = '';

  // Screen brightness boost for scanning
  double? _originalBrightness;
  bool _brightnessBoosted = false;

  // Animated scan line
  late final AnimationController _scanAnimController;
  late final Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    _scanAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _scanAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanAnimController, curve: Curves.easeInOut),
    );

    _loadSession();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && _tabController.index == 1) {
      _navigated = false;
      _boostBrightness();
      _scanAnimController.repeat();
    } else if (_tabController.index == 0) {
      _stopScanner();
      _restoreBrightness();
      _scanAnimController.stop();
    }
    setState(() {});
  }

  Future<void> _startScanner() async {
    try {
      await _scannerController.start();
    } catch (_) {}
  }

  Future<void> _stopScanner() async {
    try {
      await _scannerController.stop();
    } catch (_) {}
  }

  Future<void> _boostBrightness() async {
    if (_brightnessBoosted) return;
    try {
      _originalBrightness ??= await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(1.0);
      _brightnessBoosted = true;
    } catch (_) {}
  }

  Future<void> _restoreBrightness() async {
    if (!_brightnessBoosted) return;
    try {
      await ScreenBrightness().resetScreenBrightness();
    } catch (_) {}
    _brightnessBoosted = false;
  }

  Future<void> _loadSession() async {
    final session = await SessionManager.instance.loadSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _qrSeed = session?['koraId']?.toString() ?? session?['username']?.toString() ?? 'user';
    });
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
              content: Text('No valid QR code detected'),
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

  void _resetQrCode() {
    // Generate a new random seed for the QR code
    final newSeed = 'kora_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _qrSeed = newSeed;
      _resetting = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The previous QR code has been reset and a new QR code has been created.'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset QR code?',
          style: TextStyle(
            color: KoraColors.textPrimaryFor(Theme.of(context).brightness),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Your existing QR code will no longer work.',
          style: TextStyle(
            color: KoraColors.textSecondaryFor(Theme.of(context).brightness),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: KoraColors.textSecondaryFor(Theme.of(context).brightness)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetQrCode();
            },
            child: const Text('Reset', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scannerController.dispose();
    _scanAnimController.dispose();
    if (_brightnessBoosted) {
      ScreenBrightness().resetScreenBrightness();
    }
    super.dispose();
  }

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
          chatId: koraId.isNotEmpty ? koraId : username,
          koraId: koraId.isNotEmpty ? koraId : null,
          username: username.isNotEmpty ? username : null,
          badge: isPremium ? KoraBadgeType.premiumBlue : KoraBadgeType.none,
          isOnline: true,
          about: 'Hey there! I am using Kora.',
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
        text: 'Add me as a contact on Kora.',
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
      KoraMenuOption(
        icon: Icons.refresh_rounded,
        label: 'Reset QR code',
        onTap: _showResetDialog,
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
            onPressed: _sharing ? null : _shareQrCode,
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
                Tab(text: 'My code'),
                Tab(text: 'Scan code'),
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
    final qrData = 'kora://contact/$_qrSeed';

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
                              embeddedImage: const AssetImage('assets/icon/kora_icon.webp'),
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
      animation: Listenable.merge([_tabController, _scanAnim]),
      builder: (context, _) {
        final active = _tabController.index == 1;
        final screenWidth = MediaQuery.of(context).size.width;
        final boxSize = screenWidth * 0.72;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Dark background
            Container(color: KoraColors.trueBlack),

            // Camera flip button — top-right
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

            // Centered viewfinder with scan line + corner brackets
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 96),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        // Camera view
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
                        // Corner brackets (WhatsApp-style)
                        _buildCornerBrackets(boxSize),
                        // Animated scan line
                        if (active)
                          Positioned(
                            left: 8,
                            right: 8,
                            top: 8 + (_scanAnim.value * (boxSize - 16)),
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    KoraColors.purple.withValues(alpha: 0.8),
                                    KoraColors.blue.withValues(alpha: 0.8),
                                    Colors.transparent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: KoraColors.purple.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
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

            // Bottom row — gallery pick + flash toggle
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: _pickFromGallery,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Gallery',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _scannerController,
                        builder: (context, state, _) {
                          final torchOn = state.torchState == TorchState.on;
                          return GestureDetector(
                            onTap: _toggleTorch,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: torchOn
                                        ? KoraColors.purple.withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    torchOn ? Icons.flash_on : Icons.flash_off,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  torchOn ? 'Flash on' : 'Flash off',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// WhatsApp-style corner brackets around the scan area
  Widget _buildCornerBrackets(double size) {
    const bracketLen = 28.0;
    const bracketThick = 3.0;
    const bracketColor = Colors.white;
    final radius = BorderRadius.circular(20);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Top-left
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: bracketLen,
              height: bracketThick,
              decoration: BoxDecoration(
                color: bracketColor,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(6)),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: bracketThick,
              height: bracketLen,
              decoration: BoxDecoration(
                color: bracketColor,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(6)),
              ),
            ),
          ),
          // Top-right
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: bracketLen,
              height: bracketThick,
              decoration: BoxDecoration(
                color: bracketColor,
                borderRadius: BorderRadius.only(topRight: Radius.circular(6)),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: bracketThick,
              height: bracketLen,
              decoration: BoxDecoration(
                color: bracketColor,
                borderRadius: BorderRadius.only(topRight: Radius.circular(6)),
              ),
            ),
          ),
          // Bottom-left
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: bracketLen,
              height: bracketThick,
              decoration: BoxDecoration(
                color: bracketColor,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(6)),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: bracketThick,
              height: bracketLen,
              decoration: BoxDecoration(
                color: bracketColor,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(6)),
              ),
            ),
          ),
          // Bottom-right
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: bracketLen,
              height: bracketThick,
              decoration: BoxDecoration(
                color: bracketColor,
                borderRadius: BorderRadius.only(bottomRight: Radius.circular(6)),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: bracketThick,
              height: bracketLen,
              decoration: BoxDecoration(
                color: bracketColor,
                borderRadius: BorderRadius.only(bottomRight: Radius.circular(6)),
              ),
            ),
          ),
        ],
      ),
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
