import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/translation_service.dart';
import '../../models/translation_models.dart';
import 'language_picker_screen.dart';

/// Pre-call translation configuration sheet.
///
/// Shows before starting a call when call translation is enabled.
/// Lets users pick:
/// - Their language (what they speak)
/// - Incoming translation language (what they want to hear/read)
/// - Outgoing translation language (what the other person receives)
///
/// Also accessible during a call to change languages without ending it.
class CallTranslationSheet extends StatefulWidget {
  final bool isInCall;

  const CallTranslationSheet({
    super.key,
    this.isInCall = false,
  });

  /// Shows the translation sheet as a modal bottom sheet ABOVE whatever
  /// screen called it (e.g. the active CallScreen) without navigating
  /// away from or rebuilding that screen. Returns the sheet's close
  /// [Future] so callers (like CallScreen) can know when it's dismissed —
  /// e.g. to make sure it's closed cleanly if the call ends while open.
  static Future<void> show(BuildContext context, {bool isInCall = false}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CallTranslationSheet(isInCall: isInCall),
    );
  }

  @override
  State<CallTranslationSheet> createState() => _CallTranslationSheetState();
}

class _CallTranslationSheetState extends State<CallTranslationSheet> {
  final _service = TranslationService.instance;
  late KoraLanguage _yourLanguage;
  late KoraLanguage _incomingLanguage;
  late KoraLanguage _outgoingLanguage;
  bool _captionsOn = true;

  @override
  void initState() {
    super.initState();
    _yourLanguage = _service.preferredLanguage;
    _incomingLanguage = _service.preferredLanguage;
    _outgoingLanguage = _service.preferredLanguage;
  }

  Future<KoraLanguage?> _pickLanguage(String title) async {
    return Navigator.push<KoraLanguage>(
      context,
      MaterialPageRoute(
        builder: (_) => LanguagePickerScreen(title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.phone_in_talk_rounded, color: KoraColors.purple, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Call Translation',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textMuted, size: 22),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: border),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kora Translate indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: KoraColors.purple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.language_rounded, size: 16, color: KoraColors.purple),
                        const SizedBox(width: 6),
                        Text(
                          'Kora Translate • ON',
                          style: TextStyle(
                            color: KoraColors.purple,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Your language
                  _langRow(
                    'Your language',
                    'What you speak',
                    _yourLanguage,
                    surface,
                    textPrimary,
                    textSecondary,
                    textMuted,
                    border,
                    () async {
                      final result = await _pickLanguage('Your Language');
                      if (result != null) setState(() => _yourLanguage = result);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Incoming
                  _langRow(
                    'Translate incoming to',
                    'What you want to hear/read',
                    _incomingLanguage,
                    surface,
                    textPrimary,
                    textSecondary,
                    textMuted,
                    border,
                    () async {
                      final result = await _pickLanguage('Translate Incoming To');
                      if (result != null) setState(() => _incomingLanguage = result);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Outgoing
                  _langRow(
                    'Translate your speech to',
                    'What the other person receives',
                    _outgoingLanguage,
                    surface,
                    textPrimary,
                    textSecondary,
                    textMuted,
                    border,
                    () async {
                      final result = await _pickLanguage('Translate Your Speech To');
                      if (result != null) setState(() => _outgoingLanguage = result);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Captions toggle
                  _switchRow(
                    'Live Captions',
                    'Show translated text during the call',
                    _captionsOn,
                    surface,
                    textPrimary,
                    textSecondary,
                    border,
                    (v) => setState(() => _captionsOn = v),
                  ),
                  const SizedBox(height: 20),

                  // Start/Apply button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: KoraColors.brandGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          widget.isInCall ? 'Apply Changes' : 'Start Call',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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

  Widget _langRow(
    String title,
    String subtitle,
    KoraLanguage lang,
    Color surface,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color border,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(lang.flag, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        lang.name,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: textMuted, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(
    String title,
    String subtitle,
    bool value,
    Color surface,
    Color textPrimary,
    Color textSecondary,
    Color border,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: KoraColors.purple,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

/// Live captions overlay for in-call translation.
///
/// Shows as a floating panel at the bottom of the call screen.
/// Displays:
/// - Speaker name
/// - Original speech text
/// - Translated text
///
/// Used by [_CallScreen] when call translation is active.
class LiveCaptionsOverlay extends StatefulWidget {
  final String speakerName;
  final double fontSize;
  /// Stream of incoming captions from the remote peer (via WebRTC data channel).
  /// Each event is a (text, isFinal) pair.
  final Stream<(String, bool)>? captionStream;
  /// Stream of the local user's own captions (for display on their own device).
  final Stream<(String, bool)>? localCaptionStream;

  const LiveCaptionsOverlay({
    super.key,
    required this.speakerName,
    this.fontSize = 14,
    this.captionStream,
    this.localCaptionStream,
  });

  @override
  State<LiveCaptionsOverlay> createState() => _LiveCaptionsOverlayState();
}

class _LiveCaptionsOverlayState extends State<LiveCaptionsOverlay>
    with SingleTickerProviderStateMixin {
  String _originalText = '';
  String _translatedText = '';
  late AnimationController _fadeController;
  StreamSubscription<(String, bool)>? _remoteSub;
  StreamSubscription<(String, bool)>? _localSub;
  Timer? _clearTimer;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeController.forward();
    _showWaitingMessage();

    // Subscribe to remote captions (from the other peer via data channel)
    if (widget.captionStream != null) {
      _remoteSub = widget.captionStream!.listen((data) {
        final (text, isFinal) = data;
        if (text.isNotEmpty) {
          _onRemoteCaption(text, isFinal);
        }
      });
    }

    // Subscribe to local captions (the user's own speech, for their reference)
    if (widget.localCaptionStream != null) {
      _localSub = widget.localCaptionStream!.listen((data) {
        final (text, isFinal) = data;
        if (text.isNotEmpty && mounted) {
          setState(() => _originalText = text);
          _resetClearTimer();
        }
      });
    }
  }

  void _showWaitingMessage() {
    if (!mounted) return;
    setState(() {
      _originalText = 'Listening…';
      _translatedText = '';
    });
  }

  /// Handle incoming remote caption — translate and display.
  void _onRemoteCaption(String text, bool isFinal) {
    if (!mounted) return;
    setState(() => _originalText = text);
    _resetClearTimer();

    if (isFinal) {
      // Translate the final utterance
      TranslationService.instance
          .translate(text, TranslationService.instance.preferredLanguageCode)
          .then((result) {
        if (mounted) {
          setState(() => _translatedText = result.translatedText);
          _fadeController.reset();
          _fadeController.forward();
        }
      });
    }
  }

  /// Auto-clear captions after 5 seconds of silence so the overlay
  /// doesn't show stale text indefinitely.
  void _resetClearTimer() {
    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _showWaitingMessage();
    });
  }

  @override
  void dispose() {
    _remoteSub?.cancel();
    _localSub?.cancel();
    _clearTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: KoraColors.purple.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Speaker + Kora Translate indicator
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: KoraColors.purple,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.speakerName,
                  style: const TextStyle(
                    color: KoraColors.purple,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.language_rounded, size: 12, color: Colors.white.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                Text(
                  'Kora Translate',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Original text
            if (_originalText.isNotEmpty)
              Text(
                _originalText,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: widget.fontSize - 1,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            // Translated text
            if (_translatedText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _translatedText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.fontSize,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
