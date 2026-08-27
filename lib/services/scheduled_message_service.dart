import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'message_service.dart';
import 'chat_service.dart';
import '../models/message_model.dart';

/// Scheduled Messages Service — sends messages at a future datetime.
/// Mirrors WhatsApp's scheduled message feature.
///
/// Stores scheduled messages in SharedPreferences with their target
/// chat ID and send time. A periodic timer checks for due messages
/// and sends them via MessageService.
class ScheduledMessageService {
  static final ScheduledMessageService instance = ScheduledMessageService._();
  ScheduledMessageService._();

  static const _kPrefix = 'kora_scheduled_';
  Timer? _timer;

  /// A scheduled message entry.
  /// [chatId], [text], [sendAt] are required.
  /// [type] defaults to text. [replyToId] optional for scheduled replies.
  final List<ScheduledEntry> _pending = [];

  void init() {
    _loadPending();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkDue());
    debugPrint('[KoraScheduled] Service initialized');
  }

  void dispose() {
    _timer?.cancel();
  }

  /// Schedule a message to be sent at [sendAt].
  Future<void> scheduleMessage({
    required String chatId,
    required String text,
    required DateTime sendAt,
    KoraMessageType type = KoraMessageType.text,
    String? replyToId,
    String? replyToText,
    String? replyToName,
  }) async {
    final entry = ScheduledEntry(
      id: 'sched_${DateTime.now().millisecondsSinceEpoch}',
      chatId: chatId,
      text: text,
      sendAt: sendAt,
      type: type,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToName: replyToName,
    );
    _pending.add(entry);
    await _persist();
    debugPrint('[KoraScheduled] Scheduled for ${sendAt.toIso8601String()}');
  }

  /// Get all pending scheduled messages.
  List<ScheduledEntry> get pending => List.unmodifiable(_pending);

  /// Cancel a scheduled message.
  Future<void> cancel(String id) async {
    _pending.removeWhere((e) => e.id == id);
    await _persist();
  }

  /// Reschedule (update) a scheduled message.
  Future<void> reschedule(String id, DateTime newTime) async {
    final idx = _pending.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _pending[idx] = _pending[idx].copyWith(sendAt: newTime);
      await _persist();
    }
  }

  void _checkDue() {
    final now = DateTime.now();
    final due = _pending.where((e) => !now.isBefore(e.sendAt)).toList();
    for (final entry in due) {
      _sendNow(entry);
    }
  }

  Future<void> _sendNow(ScheduledEntry entry) async {
    try {
      await MessageService.instance.sendMessage(
        entry.chatId,
        entry.text,
        type: entry.type,
        replyToId: entry.replyToId,
        replyToText: entry.replyToText,
        replyToName: entry.replyToName,
      );
      _pending.removeWhere((e) => e.id == entry.id);
      await _persist();
      debugPrint('[KoraScheduled] Sent scheduled message to ${entry.chatId}');
    } catch (e) {
      debugPrint('[KoraScheduled] Failed to send: $e');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _pending.map((e) => e.toJson()).toList();
    await prefs.setString('kora_scheduled_list', jsonEncode(json));
  }

  Future<void> _loadPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('kora_scheduled_list');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _pending.clear();
        _pending.addAll(list.map((e) => ScheduledEntry.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
  }
}

/// A scheduled message entry.
class ScheduledEntry {
  final String id;
  final String chatId;
  final String text;
  final DateTime sendAt;
  final KoraMessageType type;
  final String? replyToId;
  final String? replyToText;
  final String? replyToName;

  ScheduledEntry({
    required this.id,
    required this.chatId,
    required this.text,
    required this.sendAt,
    this.type = KoraMessageType.text,
    this.replyToId,
    this.replyToText,
    this.replyToName,
  });

  ScheduledEntry copyWith({
    String? id,
    String? chatId,
    String? text,
    DateTime? sendAt,
    KoraMessageType? type,
    String? replyToId,
    String? replyToText,
    String? replyToName,
  }) {
    return ScheduledEntry(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      text: text ?? this.text,
      sendAt: sendAt ?? this.sendAt,
      type: type ?? this.type,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      replyToName: replyToName ?? this.replyToName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'chatId': chatId,
    'text': text,
    'sendAt': sendAt.toIso8601String(),
    'type': type.name,
    'replyToId': replyToId,
    'replyToText': replyToText,
    'replyToName': replyToName,
  };

  factory ScheduledEntry.fromJson(Map<String, dynamic> j) => ScheduledEntry(
    id: j['id'] as String,
    chatId: j['chatId'] as String,
    text: j['text'] as String,
    sendAt: DateTime.parse(j['sendAt'] as String),
    type: KoraMessageType.values.firstWhere(
      (e) => e.name == j['type'],
      orElse: () => KoraMessageType.text,
    ),
    replyToId: j['replyToId'] as String?,
    replyToText: j['replyToText'] as String?,
    replyToName: j['replyToName'] as String?,
  );
}
