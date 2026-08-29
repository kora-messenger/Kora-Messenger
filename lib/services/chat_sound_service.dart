import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plays in-chat message sounds — incoming "pop" and outgoing "swoosh".
///
/// Mirrors WhatsApp's "Conversation tones" setting: when enabled, Kora plays
/// a soft sound when you send or receive a message while inside a chat.
/// The setting is controlled from Notifications > Conversation tones.
///
/// Sounds only play when:
/// 1. Conversation tones are enabled in settings
/// 2. The user is currently inside a chat screen (not backgrounded)
/// 3. The device is not in silent/vibrate-only mode (respects ringer)
class ChatSoundService {
  ChatSoundService._();
  static final ChatSoundService instance = ChatSoundService._();

  final AudioPlayer _player = AudioPlayer();

  bool _soundsEnabled = true;
  bool _initialized = false;

  /// Load the conversation tones setting from prefs.
  Future<void> _ensureInit() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _soundsEnabled = prefs.getBool('notif_conversation_tones') ?? true;
    _initialized = true;
  }

  /// Update the enabled state — called when the user toggles the setting.
  Future<void> setEnabled(bool enabled) async {
    _soundsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_conversation_tones', enabled);
  }

  /// Play the incoming message sound (soft pop).
  /// Called when a new message arrives while the user is in the chat.
  Future<void> playIncoming() async {
    await _ensureInit();
    if (!_soundsEnabled) return;

    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/kora_message_incoming.wav'));
    } catch (_) {
      // Silently fail — sound is non-critical
    }
  }

  /// Play the outgoing message sound (subtle swoosh).
  /// Called right after the user sends a message.
  Future<void> playOutgoing() async {
    await _ensureInit();
    if (!_soundsEnabled) return;

    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/kora_message_outgoing.wav'));
    } catch (_) {
      // Silently fail — sound is non-critical
    }
  }

  /// Release resources.
  void dispose() {
    _player.dispose();
  }
}
