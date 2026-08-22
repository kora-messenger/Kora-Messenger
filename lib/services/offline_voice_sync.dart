import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';
import 'message_service.dart';
import 'connectivity_service.dart';

/// Manages offline voice-note queuing and automatic synchronisation.
///
/// When a user records and sends a voice note while offline:
/// 1. The message is saved locally with [MessageStatus.pendingOffline].
/// 2. It appears in the conversation with a sync-arrow icon.
/// 3. When connectivity returns, each pending note is "uploaded" in
///    the order it was created, then transitions to sent → delivered
///    → read like a normal voice message.
///
/// Pending notes persist across app restarts via SharedPreferences.
/// The queue is global (not per-chat) but maintains per-chat ordering
/// by processing notes sorted by their creation timestamp.
///
/// Call [init] once at startup. The service listens to
/// [ConnectivityService] and auto-syncs when network returns.
class OfflineVoiceSyncService {
  static final OfflineVoiceSyncService instance = OfflineVoiceSyncService._();
  OfflineVoiceSyncService._();

  static const _kQueueKey = 'kora_offline_voice_queue';

  /// Pending voice notes: { chatId, messageId, duration, createdAt }
  final List<OfflineVoiceEntry> _queue = [];
  bool _initialized = false;
  bool _syncing = false;

  StreamSubscription<bool>? _connectivitySub;

  /// Notifies listeners when a message's status changes (e.g. pending → sent).
  /// Chat screens listen to this to refresh their message lists.
  final StreamController<String> _syncController =
      StreamController<String>.broadcast();
  Stream<String> get syncStream => _syncController.stream;

  /// Initialise — load persisted queue and subscribe to connectivity.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _loadQueue();

    _connectivitySub =
        ConnectivityService.instance.statusStream.listen((isOnline) {
      if (isOnline) {
        syncPendingNotes();
      }
    });

    // If we're already online at startup, try syncing right away
    if (ConnectivityService.instance.isOnline) {
      syncPendingNotes();
    }
  }

  /// Enqueue a voice note for later synchronisation.
  /// Called by [MessageService.sendVoiceMessage] when offline.
  Future<void> enqueue({
    required String chatId,
    required String messageId,
    required String duration,
  }) async {
    final entry = OfflineVoiceEntry(
      chatId: chatId,
      messageId: messageId,
      duration: duration,
      createdAt: DateTime.now(),
    );
    _queue.add(entry);
    await _persistQueue();
  }

  /// Attempt to sync all pending voice notes.
  /// Notes are processed in FIFO order (oldest first).
  /// If the network drops mid-sync, remaining notes stay queued.
  Future<void> syncPendingNotes() async {
    if (_syncing || _queue.isEmpty) return;
    if (!ConnectivityService.instance.isOnline) return;

    _syncing = true;

    // Sort by creation time to maintain sending order
    _queue.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final List<OfflineVoiceEntry> completed = [];

    for (final entry in _queue) {
      // Re-check connectivity before each upload
      final online = await ConnectivityService.instance.checkNow();
      if (!online) break;

      // Flip to "uploading" right away so the bubble shows the live
      // progress ring — matters most for notes the user had cancelled
      // to the "tap to retry" state, which now auto-resume the moment
      // connectivity returns with no tap needed.
      await MessageService.instance.setVoiceTransferState(
        entry.chatId,
        entry.messageId,
        VoiceTransferState.uploading,
      );
      _syncController.add(entry.chatId);

      // Simulate upload with a short delay (would be a real file
      // upload in production)
      await Future.delayed(const Duration(milliseconds: 800));

      // Transition message: pendingOffline → sent
      await MessageService.instance.updateMessageStatus(
        entry.chatId,
        entry.messageId,
        MessageStatus.sent,
      );

      // Notify listeners that this chat was updated
      _syncController.add(entry.chatId);

      completed.add(entry);

      // Auto-progress: sent → delivered (1.5s) → read (4s)
      _scheduleStatusProgress(entry.chatId, entry.messageId);
    }

    // Remove completed entries from queue
    for (final entry in completed) {
      _queue.remove(entry);
    }
    await _persistQueue();

    _syncing = false;
  }

  /// Schedules the normal sent → delivered → read progression
  /// that [MessageService.sendVoiceMessage] does for online sends.
  void _scheduleStatusProgress(String chatId, String messageId) {
    Future.delayed(const Duration(milliseconds: 1500), () async {
      await MessageService.instance.updateMessageStatus(
        chatId,
        messageId,
        MessageStatus.delivered,
      );
      _syncController.add(chatId);
    });

    Future.delayed(const Duration(seconds: 4), () async {
      await MessageService.instance.updateMessageStatus(
        chatId,
        messageId,
        MessageStatus.read,
      );
      _syncController.add(chatId);
    });
  }

  /// Returns the number of pending offline voice notes for a chat.
  int pendingCountFor(String chatId) {
    return _queue.where((e) => e.chatId == chatId).length;
  }

  /// Returns true if a message is still in the offline queue.
  bool isPending(String chatId, String messageId) {
    return _queue.any(
      (e) => e.chatId == chatId && e.messageId == messageId,
    );
  }

  /// Removes a pending entry if the message is deleted before sync.
  Future<void> removePending(String chatId, String messageId) async {
    _queue.removeWhere(
      (e) => e.chatId == chatId && e.messageId == messageId,
    );
    await _persistQueue();
  }

  // ── Persistence ─────────────────────────────────────────────

  Future<void> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kQueueKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _queue.clear();
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          _queue.add(OfflineVoiceEntry(
            chatId: m['chatId'] as String,
            messageId: m['messageId'] as String,
            duration: m['duration'] as String,
            createdAt: DateTime.parse(m['createdAt'] as String),
          ));
        }
      } catch (_) {
        _queue.clear();
      }
    }
  }

  Future<void> _persistQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _queue
        .map((e) => {
              'chatId': e.chatId,
              'messageId': e.messageId,
              'duration': e.duration,
              'createdAt': e.createdAt.toIso8601String(),
            })
        .toList();
    await prefs.setString(_kQueueKey, jsonEncode(json));
  }

  void dispose() {
    _connectivitySub?.cancel();
    _syncController.close();
  }
}

/// A single pending offline voice note entry in the sync queue.
class OfflineVoiceEntry {
  final String chatId;
  final String messageId;
  final String duration;
  final DateTime createdAt;

  const OfflineVoiceEntry({
    required this.chatId,
    required this.messageId,
    required this.duration,
    required this.createdAt,
  });
}
