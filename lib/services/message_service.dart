import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import '../models/chat_models.dart';

/// Manages all Kora conversations with local persistence.
///
/// Messages are stored in SharedPreferences as JSON arrays keyed by
/// chat ID. This replaces the old in-memory mock service — messages
/// now survive app restarts.
///
/// Two special chats are always present:
/// - kora_support: Kora Support AI — answers questions about Kora
/// - kora_ai: Kora AI — answers any question, inside or outside Kora
class MessageService {
  static final MessageService instance = MessageService._();
  MessageService._();

  static const _kPrefix = 'kora_msgs_';
  static const _kWelcomeSent = 'kora_welcome_sent';
  static const _kExpirySent = 'kora_expiry_sent';
  static const _kPremiumTrialStart = 'kora_premium_trial_start';
  static const _kPremiumTrialDays = 7;

  final Map<String, List<KoraMessage>> _cache = {};

  // ── Load / Save ────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final welcomeSent = prefs.getBool(_kWelcomeSent) ?? false;
    final expirySent = prefs.getBool(_kExpirySent) ?? false;

    if (!welcomeSent) {
      _seedWelcomeMessage();
      await prefs.setBool(_kWelcomeSent, true);
      await prefs.setString(
        _kPremiumTrialStart,
        DateTime.now().toIso8601String(),
      );
    }

    // Check if the 7-day trial has expired (and we haven't sent the expiry message yet)
    if (!expirySent) {
      final startStr = prefs.getString(_kPremiumTrialStart);
      if (startStr != null) {
        final start = DateTime.parse(startStr);
        final expiry = start.add(const Duration(days: _kPremiumTrialDays));
        if (DateTime.now().isAfter(expiry)) {
          _seedExpiryMessage();
          await prefs.setBool(_kExpirySent, true);
          // Revoke premium
          await prefs.setBool('kora_is_premium', false);
        }
      }
    }
  }

  /// Returns messages for a chat, loading from disk if not cached.
  List<KoraMessage> getMessages(String chatId) {
    if (_cache.containsKey(chatId)) return _cache[chatId]!;
    return []; // will be loaded async via loadMessages
  }

  /// Async load — fetches from SharedPreferences and populates cache.
  Future<List<KoraMessage>> loadMessages(String chatId) async {
    if (_cache.containsKey(chatId)) return _cache[chatId]!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kPrefix$chatId');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _cache[chatId] = list
            .map((e) => KoraMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _cache[chatId] = [];
      }
    } else {
      _cache[chatId] = [];
    }
    return _cache[chatId]!;
  }

  Future<void> _persist(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final msgs = _cache[chatId] ?? [];
    await prefs.setString(
      '$_kPrefix$chatId',
      jsonEncode(msgs.map((m) => m.toJson()).toList()),
    );
  }

  // ── Send / React / Delete ─────────────────────────────────

  Future<void> sendMessage(
    String chatId,
    String text, {
    String? replyToId,
    String? replyToText,
    String? replyToName,
  }) async {
    final messages = _cache.putIfAbsent(chatId, () []);
    messages.add(KoraMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.sent,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToName: replyToName,
    ));
    await _persist(chatId);
  }

  /// Adds an incoming message (used for AI replies).
  Future<void> addIncomingMessage(
    String chatId,
    String text, {
    bool isAi = false,
    String? actionLabel,
    String? actionType,
    KoraMessageType type = KoraMessageType.text,
  }) async {
    final messages = _cache.putIfAbsent(chatId, () []);
    messages.add(KoraMessage(
      id: 'in_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      timestamp: DateTime.now(),
      isMe: false,
      status: MessageStatus.none,
      isAi: isAi,
      type: type,
      actionLabel: actionLabel,
      actionType: actionType,
    ));
    await _persist(chatId);
  }

  Future<void> sendVoiceMessage(String chatId, String duration) async {
    final messages = _cache.putIfAbsent(chatId, () []);
    messages.add(KoraMessage(
      id: 'voice_${DateTime.now().millisecondsSinceEpoch}',
      text: '',
      timestamp: DateTime.now(),
      isMe: true,
      type: KoraMessageType.voice,
      status: MessageStatus.sent,
      voiceDuration: duration,
    ));
    await _persist(chatId);
  }

  Future<void> toggleReaction(String chatId, String messageId, String emoji) async {
    final messages = _cache[chatId];
    if (messages == null) return;
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final msg = messages[idx];
    messages[idx] = msg.copyWith(reaction: msg.reaction == emoji ? null : emoji);
    await _persist(chatId);
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    final messages = _cache[chatId];
    if (messages == null) return;
    messages.removeWhere((m) => m.id == messageId);
    await _persist(chatId);
  }

  Future<void> markAsRead(String chatId) async {
    final messages = _cache[chatId];
    if (messages == null) return;
    bool changed = false;
    for (int i = 0; i < messages.length; i++) {
      if (messages[i].isMe && messages[i].status != MessageStatus.read) {
        messages[i] = messages[i].copyWith(status: MessageStatus.read);
        changed = true;
      }
    }
    if (changed) await _persist(chatId);
  }

  // ── Welcome / Expiry messages ──────────────────────────────

  void _seedWelcomeMessage() {
    final now = DateTime.now();
    _cache['kora_support'] = [
      KoraMessage(
        id: 'welcome_1',
        text: 'Welcome to Kora Messenger! 🎉\n\n'
            'Congratulations — you\'ve been given 7 days of Kora Premium for free!\n\n'
            'With Premium you get: custom app icons, premium wallpapers, '
            'custom chat bubbles, animated emoji, real-time translation, '
            'infinite reactions, faster download speeds, a profile badge, '
            'priority support, and no ads.\n\n'
            'Your free Premium trial will expire in 7 days. '
            'Enjoy! ✨',
        timestamp: now,
        isMe: false,
        isAi: true,
        status: MessageStatus.none,
      ),
    ];
    _persist('kora_support');
  }

  void _seedExpiryMessage() {
    final messages = _cache.putIfAbsent('kora_support', () []);
    messages.add(KoraMessage(
      id: 'expiry_1',
      text: 'Your 7-day Kora Premium subscription has expired. 😔\n\n'
          'But don\'t worry — you can re-activate all your Premium features '
          'anytime by subscribing below.',
      timestamp: DateTime.now(),
      isMe: false,
      isAi: true,
      type: KoraMessageType.action,
      actionLabel: 'Subscribe to Kora Premium',
      actionType: 'subscribe_premium',
      status: MessageStatus.none,
    ));
    _persist('kora_support');
  }

  /// Clears all messages (used on logout).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_kPrefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
    await prefs.remove(_kWelcomeSent);
    await prefs.remove(_kExpirySent);
    await prefs.remove(_kPremiumTrialStart);
    _cache.clear();
  }
}
