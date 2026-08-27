import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/kora_api.dart';
import 'session_manager.dart';

/// Kora's Anti-Spam Protection Service.
///
/// Provides three layers of spam protection:
///
/// 1. **Content detection** — heuristic pattern matching for known
///    spam content (excessive links, scam phrases, repetitive text)
/// 2. **Rate limiting** — prevents users from sending messages too
///    fast (30/min to non-contacts, 5/min to new contacts)
/// 3. **User reporting** — users can report spammers; 3+ reports
///    auto-flags the sender
///
/// The service also maintains a local rate limiter for instant
/// feedback before the backend confirms.
class SpamProtectionService {
  static final SpamProtectionService instance = SpamProtectionService._();
  SpamProtectionService._();

  // Local rate limiter: tracks messages sent per minute per chatId
  final Map<String, List<int>> _sendTimestamps = {};

  static const int _localRateLimit = 20; // per minute, per chat
  static const int _newContactRateLimit = 5;
  static const Duration _window = Duration(minutes: 1);

  /// Check if a message can be sent locally (instant check, no network).
  /// Returns true if allowed, false if rate limited.
  bool canSendLocally(String chatId, {bool isNewContact = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowStart = now - _window.inMilliseconds;

    _sendTimestamps[chatId] ??= [];
    _sendTimestamps[chatId]!.removeWhere((ts) => ts < windowStart);

    final limit = isNewContact ? _newContactRateLimit : _localRateLimit;
    if (_sendTimestamps[chatId]!.length >= limit) {
      return false;
    }

    _sendTimestamps[chatId]!.add(now);
    return true;
  }

  /// Check rate limit on the backend. Call before sending a message
  /// for server-side enforcement. Returns { allowed, retryAfter, message }
  Future<Map<String, dynamic>> checkRateLimit({
    required String senderEmail,
    String? recipientEmail,
    bool isFirstMessage = false,
  }) async {
    try {
      final result = await KoraApi.postTo(KoraApi.antiSpamEndpoint, {
        'action': 'rateLimit',
        'senderEmail': senderEmail,
        'recipientEmail': recipientEmail,
        'isFirstMessage': isFirstMessage,
      });
      return {
        'allowed': result['allowed'] ?? true,
        'retryAfter': result['retryAfter'] ?? 0,
        'message': result['message'] ?? '',
        'currentCount': result['currentCount'] ?? 0,
        'limit': result['limit'] ?? 0,
      };
    } catch (e) {
      // On error, allow the message — don't block on backend failure
      return {'allowed': true, 'retryAfter': 0, 'message': ''};
    }
  }

  /// Detect spam content in a message. Returns { isSpam, score, matchedPatterns }
  Future<Map<String, dynamic>> detectSpam({
    required String text,
    String? senderEmail,
  }) async {
    try {
      final result = await KoraApi.postTo(KoraApi.antiSpamEndpoint, {
        'action': 'detectSpam',
        'text': text,
        'senderEmail': senderEmail,
      });
      return {
        'isSpam': result['isSpam'] ?? false,
        'score': result['score'] ?? 0,
        'matchedPatterns': result['matchedPatterns'] ?? [],
      };
    } catch (e) {
      // On error, don't flag as spam
      return {'isSpam': false, 'score': 0, 'matchedPatterns': []};
    }
  }

  /// Check if a user is flagged as a spammer. Call when opening a chat
  /// to show a spam warning banner.
  Future<Map<String, dynamic>> checkSpamStatus(String email) async {
    try {
      final result = await KoraApi.postTo(KoraApi.antiSpamEndpoint, {
        'action': 'checkSpam',
        'email': email,
      });
      return {
        'isSpammer': result['isSpammer'] ?? false,
        'spamScore': result['spamScore'] ?? 0,
        'spamScoreThreshold': result['spamScoreThreshold'] ?? 3,
      };
    } catch (e) {
      return {'isSpammer': false, 'spamScore': 0, 'spamScoreThreshold': 3};
    }
  }

  /// Report a user as spam. Called from the "Report spam" UI option.
  Future<Map<String, dynamic>> reportSpam({
    required String reportedEmail,
    String? chatId,
    String? messageId,
    String? messageText,
    String? reason,
  }) async {
    final reporterEmail = SessionManager.instance.currentEmail;
    if (reporterEmail.isEmpty) {
      return {'success': false, 'error': 'Not logged in'};
    }

    try {
      final result = await KoraApi.postTo(KoraApi.antiSpamEndpoint, {
        'action': 'reportSpam',
        'reporterEmail': reporterEmail,
        'reportedEmail': reportedEmail,
        'chatId': chatId,
        'messageId': messageId,
        'messageText': messageText,
        'reason': reason ?? 'spam',
      });
      return {
        'success': result['success'] ?? false,
        'reportCount': result['reportCount'] ?? 0,
        'autoFlagged': result['autoFlagged'] ?? false,
        'message': result['message'] ?? '',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Clear local rate limit tracking for a chat (on dispose or reset).
  void clearRateLimit(String chatId) {
    _sendTimestamps.remove(chatId);
  }

  /// Reset all local rate limiting.
  void reset() {
    _sendTimestamps.clear();
  }
}
