import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../models/chat_models.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';
import 'voice_translation_sheet.dart';
import '../../theme/chat_theme_provider.dart';
import '../settings/premium_subscribe_sheet.dart';
import '../../services/audio_playback_service.dart';

/// Kora's voice message bubble — clean, single-stream playback.
///
/// Supports:
/// - Play/Pause with live waveform progress and tap-to-seek
/// - Playback speed (1x / 1.5x / 2x)
/// - Download state for received notes not yet on device
/// - Upload state (uploading spinner, not-sent retry)
/// - Played/unplayed indicator for incoming notes
/// - Context menu (long-press): Translate, Play, Download, Share, Delete
/// - Voice translation (Transcribe + Translate Voice)
class VoiceMessageBubble extends StatefulWidget {
  final KoraMessage message;
  /// Color for icons/text on sent voice bubbles. Defaults to white
  /// (for dark sent bubbles like Kora purple). Pass dark gray when the
  /// active theme has a light sent bubble (e.g. WhatsApp green).
  final Color sentAccentColor;
  final VoidCallback? onTranslate;
  final VoidCallback? onCancelUpload;
  final Future<bool> Function()? onRetryUpload;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final Future<void> Function(String localPath)? onMarkPlayed;

  /// Called when a play-once voice note has finished playing and should
  /// be auto-deleted from the conversation. Only fires for incoming
  /// play-once notes — the sender sees their own note as normal.
  final VoidCallback? onSelfDestruct;

  const VoiceMessageBubble({
    super.key,
    required this.message,
    this.sentAccentColor = Colors.white,
    this.onTranslate,
    this.onCancelUpload,
    this.onRetryUpload,
    this.onDownload,
    this.onDelete,
    this.onShare,
    this.onMarkPlayed,
    this.onSelfDestruct,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final _playback = AudioPlaybackService.instance;
  StreamSubscription<PlaybackState>? _sub;

  bool _isPlaying = false;
  bool _isLoading = false;
  double _progress = 0.0;
  double _speed = 1.0;
  bool _manualRetryChecking = false;
  bool _isDownloading = false;
  bool _hasBeenPlayed = false;
  bool _viewOnceConsumed = false;  // true after a view-once note has been played once

  bool get _isPremium => ChatThemeProvider.instance.isPremium;
  Color get _sentAccent => widget.sentAccentColor;
  Color get _sentSubdued => _sentAccent.withValues(alpha: 0.55);
  Color get _sentFaint => _sentAccent.withValues(alpha: 0.15);
  bool get _isPendingOffline =>
      widget.message.status == MessageStatus.pendingOffline;

  /// The effective audio source: local file if it exists, else remote URL.
  String? get _audioSource {
    final localPath = widget.message.voiceFilePath;
    if (localPath != null && localPath.isNotEmpty) {
      try {
        if (File(localPath).existsSync()) return localPath;
      } catch (_) {}
    }
    return widget.message.voiceFileUrl;
  }

  /// True if the audio is available locally and ready to play.
  bool get _isReadyLocally {
    final localPath = widget.message.voiceFilePath;
    if (localPath == null || localPath.isEmpty) return false;
    try {
      return File(localPath).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// True if we have a remote URL to download from.
  bool get _hasRemoteUrl =>
      widget.message.voiceFileUrl != null &&
      widget.message.voiceFileUrl!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _hasBeenPlayed = widget.message.isVoicePlayed;
    _sub = _playback.stateStream.listen((state) {
      if (!mounted) return;
      final myId = widget.message.id;
      final isMine = state.playingId == myId;

      setState(() {
        _isPlaying = isMine && state.isPlaying;
        _isLoading = isMine && state.isLoading;
        if (isMine) {
          _progress = state.progress;
          _speed = state.speed;
          if (state.isCompleted) {
            _progress = 0.0;
            if (!_hasBeenPlayed && !widget.message.isMe) {
              _hasBeenPlayed = true;
              widget.onMarkPlayed?.call(widget.message.id);
            }
            // Auto-delete play-once notes after playback finishes
            if (widget.message.isPlayOnce && !widget.message.isMe) {
              widget.onSelfDestruct?.call();
            }
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _playback.stopIfActive(widget.message.id);
    super.dispose();
  }

  void _showVoiceTranslation(BuildContext context,
      {required String voiceDuration,
      required bool autoTranslate,
      String? voiceId,
      String? transcript}) {
    if (!_isPremium) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const PremiumSubscribeSheet(),
      );
      return;
    }
    VoiceTranslationSheet.show(
      context,
      voiceDuration: voiceDuration,
      autoTranslate: autoTranslate,
      voiceId: voiceId,
      transcript: transcript,
    );
  }

  Future<void> _togglePlay() async {
    final source = _audioSource;
    if (source == null) return;

    if (_isPlaying) {
      await _playback.pause();
    } else {
      await _playback.play(source, messageId: widget.message.id);
      await _playback.setSpeed(_speed);
      if (!_hasBeenPlayed && !widget.message.isMe) {
        _hasBeenPlayed = true;
        widget.onMarkPlayed?.call(widget.message.id);
      }
    }
  }

  Future<void> _handleDownload() async {
    if (_isDownloading || !_hasRemoteUrl) return;
    setState(() => _isDownloading = true);

    // Call the download callback if provided
    if (widget.onDownload != null) {
      widget.onDownload!();
    }

    // The actual download will be handled by the parent widget which
    // updates the message's voiceFilePath. For now, we show the
    // downloading state until the parent updates the message.
  }

  Future<void> _seekToFraction(double fraction) async {
    await _playback.seekToFraction(fraction);
  }

  String get _speedLabel {
    if (_speed == 1.5) return '1.5x';
    if (_speed == 2.0) return '2x';
    return '1x';
  }

  void _cycleSpeed() async {
    setState(() {
      if (_speed == 1.0) {
        _speed = 1.5;
      } else if (_speed == 1.5) {
        _speed = 2.0;
      } else {
        _speed = 1.0;
      }
    });
    await _playback.setSpeed(_speed);
  }

  int _parseDuration(String d) {
    final parts = d.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return m * 60 + s;
    }
    return int.tryParse(d) ?? 5;
  }

  String get _totalDuration => widget.message.voiceDuration ?? '0:05';

  String get _elapsedString {
    final total = _parseDuration(_totalDuration);
    final elapsed = (total * _progress).floor();
    final m = (elapsed ~/ 60).toString();
    final s = (elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _formattedSize {
    final bytes = widget.message.estimatedSizeBytes;
    final kb = (bytes / 1024).round().clamp(1, 999999);
    return '$kb kB';
  }

  Future<void> _handleRetryTap() async {
    if (_manualRetryChecking || widget.onRetryUpload == null) return;
    setState(() => _manualRetryChecking = true);

    final results = await Future.wait([
      widget.onRetryUpload!(),
      Future.delayed(const Duration(milliseconds: 600)),
    ]);
    final online = results[0] as bool;

    if (!mounted) return;
    setState(() => _manualRetryChecking = false);

    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.wifi_off_rounded, color: _sentAccent, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Failed to load. Check your internet connection.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: KoraColors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Context menu — long-press on the voice bubble.
  void _showContextMenu(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isMe = widget.message.isMe;

    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.cardFor(brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _sentFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Play / Pause
              ListTile(
                leading: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: KoraColors.purple,
                ),
                title: Text(_isPlaying ? 'Pause' : 'Play',
                    style: TextStyle(color: KoraColors.textPrimaryFor(brightness))),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _togglePlay();
                },
              ),

              // Translate Voice
              ListTile(
                leading: const Icon(Icons.translate_rounded, color: KoraColors.purple),
                title: Text('Translate Voice',
                    style: TextStyle(color: KoraColors.textPrimaryFor(brightness))),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showVoiceTranslation(
                    context,
                    voiceDuration: _totalDuration,
                    autoTranslate: true,
                    voiceId: widget.message.id,
                    transcript: widget.message.voiceTranscript,
                  );
                },
              ),

              // Transcribe
              ListTile(
                leading: const Icon(Icons.mic_outlined, color: KoraColors.purple),
                title: Text('Transcribe',
                    style: TextStyle(color: KoraColors.textPrimaryFor(brightness))),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showVoiceTranslation(
                    context,
                    voiceDuration: _totalDuration,
                    autoTranslate: false,
                    voiceId: widget.message.id,
                    transcript: widget.message.voiceTranscript,
                  );
                },
              ),

              // Download (only if not local and has remote URL)
              if (!_isReadyLocally && _hasRemoteUrl)
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: KoraColors.purple),
                  title: Text('Download',
                      style: TextStyle(color: KoraColors.textPrimaryFor(brightness))),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handleDownload();
                  },
                ),

              // Share / Forward
              if (widget.onShare != null)
                ListTile(
                  leading: Icon(Icons.share_rounded,
                      color: KoraColors.textSecondaryFor(brightness)),
                  title: Text('Share',
                      style: TextStyle(color: KoraColors.textPrimaryFor(brightness))),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    widget.onShare!();
                  },
                ),

              // Delete
              if (widget.onDelete != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: KoraColors.red),
                  title: const Text('Delete', style: TextStyle(color: KoraColors.red)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    widget.onDelete!();
                  },
                ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.message.isMe;
    final brightness = Theme.of(context).brightness;
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    // ── Pending offline states (outgoing, not yet uploaded) ──
    if (_isPendingOffline) {
      return widget.message.voiceTransferState == VoiceTransferState.notSent
          ? _buildNotSentView(isMe, brightness)
          : _buildUploadingView(isMe, brightness);
    }

    final textPrimary = KoraColors.textPrimaryFor(brightness);

    // -- View-once consumed state: show faded "1" icon with "Played" label --
    if (!isMe && widget.message.isViewOnce && _viewOnceConsumed) {
      return GestureDetector(
        onLongPress: () => _showContextMenu(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_outlined,
                size: 20, color: textSecondary.withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            Text(
              'View once voice note played',
              style: TextStyle(
                color: textSecondary.withValues(alpha: 0.5),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    // Neutral, WhatsApp-style grayscale palette for received notes;
    // adapts to the sent bubble's text color for outgoing notes.
    final iconColor = isMe ? _sentAccent : textPrimary;
    final playedColor = isMe ? _sentAccent : textPrimary;
    final unplayedColor = isMe
        ? _sentAccent.withValues(alpha: 0.28)
        : textSecondary.withValues(alpha: 0.35);
    final durationColor = isMe ? _sentSubdued.withValues(alpha: 0.9) : textSecondary;

    // -- Download state (received, not yet on device) --
    final showDownloadState = !isMe && !_isReadyLocally && _hasRemoteUrl;
    final showLoadingState = !isMe && _isDownloading;

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play-once badge
          if (widget.message.isPlayOnce) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_clock_rounded,
                    size: 12,
                    color: KoraColors.purple.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isMe ? 'Play once' : 'View once',
                    style: TextStyle(
                      color: KoraColors.purple.withValues(alpha: 0.8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Translated badge
          if (widget.message.translatedLanguageName != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.language_rounded,
                      size: 12, color: KoraColors.purple.withValues(alpha: 0.8)),
                  const SizedBox(width: 3),
                  Text(
                    'Translated to ${widget.message.translatedLanguageName}',
                    style: TextStyle(
                      color: KoraColors.purple.withValues(alpha: 0.8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // View-once "1" badge for incoming notes — replaces the
              // unplayed dot when isViewOnce is set.
              if (!isMe && widget.message.isViewOnce && !_viewOnceConsumed) ...[
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: KoraColors.waGreen,
                      width: 1.5,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '1',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: KoraColors.waGreen,
                      ),
                    ),
                  ),
                ),
              ] else if (!isMe && !_hasBeenPlayed && !widget.message.isViewOnce) ...[
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    color: KoraColors.waGreen,
                    shape: BoxShape.circle,
                  ),
                ),
              ],

              // Speed pill
              GestureDetector(
                onTap: _cycleSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isMe
                        ? _sentFaint
                        : KoraColors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _speedLabel,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Play/Pause/Download/Loading button
              _buildMainButton(isMe, iconColor, showDownloadState, showLoadingState),

              const SizedBox(width: 8),

              // Waveform — uses LayoutBuilder for correct tap-to-seek
              LayoutBuilder(
                builder: (context, constraints) {
                  final waveWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : 140.0;
                  return GestureDetector(
                    onTapDown: _isReadyLocally ? (details) {
                      final fraction = (details.localPosition.dx / waveWidth)
                          .clamp(0.0, 1.0);
                      _seekToFraction(fraction);
                    } : null,
                    child: SizedBox(
                      width: waveWidth,
                      height: 30,
                      child: KoraWaveform(
                        isLive: false,
                        progress: _progress,
                        barCount: 30,
                        height: 30,
                        barWidth: 2.5,
                        barGap: 2.5,
                        playedColor: playedColor,
                        unplayedColor: unplayedColor,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              if (isMe && widget.message.isViewOnce) ...[
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _sentAccent.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '1',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _sentAccent.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],
              Text(
                _isPlaying ? '$_elapsedString / $_totalDuration' : _totalDuration,
                style: TextStyle(
                  color: durationColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (!widget.message.isPlayOnce) ...[
            const SizedBox(height: 6),
            // Translate / Transcribe actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAction(
                  isMe: isMe,
                  icon: Icons.mic_outlined,
                  label: 'Transcribe',
                  onTap: () => _showVoiceTranslation(
                    context,
                    voiceDuration: _totalDuration,
                    autoTranslate: false,
                    voiceId: widget.message.id,
                    transcript: widget.message.voiceTranscript,
                  ),
                ),
                const SizedBox(width: 12),
                _buildAction(
                  isMe: isMe,
                  icon: Icons.translate_rounded,
                  label: 'Translate Voice',
                  onTap: () => _showVoiceTranslation(
                    context,
                    voiceDuration: _totalDuration,
                    autoTranslate: true,
                    voiceId: widget.message.id,
                    transcript: widget.message.voiceTranscript,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// The main button — a plain icon with no filled circle backdrop,
  /// matching WhatsApp's minimal voice-bubble look. Shows download
  /// arrow, loading spinner, or play/pause depending on the state.
  Widget _buildMainButton(
      bool isMe, Color iconColor, bool showDownload, bool showLoading) {
    // Download state — show download arrow
    if (showDownload && !showLoading) {
      return GestureDetector(
        onTap: _handleDownload,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.download_rounded, color: iconColor, size: 24),
        ),
      );
    }

    // Loading / downloading state
    if (showLoading || _isLoading) {
      return SizedBox(
        width: 32,
        height: 32,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(iconColor),
          ),
        ),
      );
    }

    // Normal play/pause — bare triangle/pause glyph, no background.
    return GestureDetector(
      onTap: _togglePlay,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(
          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: iconColor,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildAction({
    required bool isMe,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final color = isMe ? _sentSubdued.withValues(alpha: 0.9) : KoraColors.purple;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingView(bool isMe, Brightness brightness) {
    final textMuted = KoraColors.textMutedFor(brightness);
    final iconColor =
        isMe ? _sentAccent.withValues(alpha: 0.85) : KoraColors.purple;
    final waveformColor = isMe
        ? _sentFaint
        : KoraColors.purple.withValues(alpha: 0.15);
    final sizeColor = isMe ? _sentSubdued.withValues(alpha: 0.8) : textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onCancelUpload,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    backgroundColor: iconColor.withValues(alpha: 0.18),
                  ),
                ),
                Icon(Icons.close_rounded, color: iconColor, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: SizedBox(
            width: 140,
            height: 30,
            child: KoraWaveform(
              isLive: false,
              progress: 0,
              barCount: 30,
              height: 30,
              barWidth: 2.5,
              barGap: 2.5,
              playedColor: waveformColor,
              unplayedColor: waveformColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formattedSize,
          style: TextStyle(
            color: sizeColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildNotSentView(bool isMe, Brightness brightness) {
    final textMuted = KoraColors.textMutedFor(brightness);
    final iconColor =
        isMe ? _sentAccent.withValues(alpha: 0.85) : KoraColors.purple;
    final waveformColor = isMe
        ? _sentFaint
        : KoraColors.purple.withValues(alpha: 0.15);
    final durationColor =
        isMe ? _sentSubdued.withValues(alpha: 0.8) : textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _handleRetryTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.12)
                  : KoraColors.purple.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: _manualRetryChecking
                ? Padding(
                    padding: const EdgeInsets.all(9),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  )
                : Icon(Icons.file_upload_rounded, color: iconColor, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: SizedBox(
            width: 140,
            height: 30,
            child: KoraWaveform(
              isLive: false,
              progress: 0,
              barCount: 30,
              height: 30,
              barWidth: 2.5,
              barGap: 2.5,
              playedColor: waveformColor,
              unplayedColor: waveformColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          widget.message.voiceDuration ?? '0:05',
          style: TextStyle(
            color: durationColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
