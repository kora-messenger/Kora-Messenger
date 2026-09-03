import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_models.dart';
import '../models/message_model.dart';
import 'conversation_directory.dart';
import 'message_service.dart';

/// Media filter chips shown under the home search bar (WhatsApp-style).
enum HomeSearchFilter { all, photos, videos, links, gifs, audio, documents }

/// Human labels for the filter chips, mirroring WhatsApp's search filters.
const Map<HomeSearchFilter, String> kHomeSearchFilterLabels = {
  HomeSearchFilter.all: 'All',
  HomeSearchFilter.photos: 'Photos',
  HomeSearchFilter.videos: 'Videos',
  HomeSearchFilter.links: 'Links',
  HomeSearchFilter.gifs: 'GIFs',
  HomeSearchFilter.audio: 'Audio',
  HomeSearchFilter.documents: 'Documents',
};

/// A message hit in the home-search results. Carries the chat metadata
/// (name/avatar/badge) plus the matched message so the row can render a
/// snippet and deep-link into the chat scrolled to that exact message.
class HomeMessageHit {
  final String chatId;
  final String chatName;
  final String? avatarAsset;
  final String? avatarUrl;
  final KoraBadgeType badge;
  final bool isGroupChat;
  final KoraMessage message;

  const HomeMessageHit({
    required this.chatId,
    required this.chatName,
    this.avatarAsset,
    this.avatarUrl,
    this.badge = KoraBadgeType.none,
    this.isGroupChat = false,
    required this.message,
  });
}

/// WhatsApp-style home screen search: chats by name/Kora ID/email,
/// full message-content search with media filter chips, and a
/// per-account recent-searches history.
class HomeSearchService {
  HomeSearchService._();
  static final HomeSearchService instance = HomeSearchService._();

  static const String _kHistoryKey = 'kora_search_history';
  static const int _kMaxHistory = 10;
  static const int _kMaxHits = 100;
  static const int _kMaxPerChat = 25;

  // ── Recent searches (WhatsApp "Recent searches" section) ──────────

  /// Newest first, capped at 10.
  Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHistoryKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      return list.take(_kMaxHistory).toList();
    } catch (_) {
      return [];
    }
  }

  /// Records a search query (called when the user opens a result).
  Future<void> addRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = await getRecentSearches();
    existing.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    existing.insert(0, q);
    await prefs.setString(
        _kHistoryKey, jsonEncode(existing.take(_kMaxHistory).toList()));
  }

  Future<void> removeRecentSearch(String query) async {
    final q = query.trim();
    final prefs = await SharedPreferences.getInstance();
    final existing = await getRecentSearches();
    existing.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    await prefs.setString(_kHistoryKey, jsonEncode(existing));
  }

  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHistoryKey);
  }

  // ── Chat search ─────────────────────────────────────────────────

  /// Case-insensitive match on chat name, Kora ID (chatId), email, and
  /// last message preview.
  List<ChatPreview> searchChats(List<ChatPreview> allChats, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return allChats;
    return allChats.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.id.toLowerCase().contains(q) ||
          (c.recipientEmail ?? '').toLowerCase().contains(q) ||
          c.lastMessage.toLowerCase().contains(q);
    }).toList();
  }

  // ── Message search ───────────────────────────────────────────────

  /// Searches message contents across every conversation (archived
  /// included, locked chats excluded — they're only reachable via the
  /// secret-code reveal). Returns hits newest-first, capped at 100.
  Future<List<HomeMessageHit>> searchMessages(
    String query, {
    HomeSearchFilter filter = HomeSearchFilter.all,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final directory = await ConversationDirectoryService.instance.getAll();
    final ms = MessageService.instance;
    final hits = <HomeMessageHit>[];

    // Most recent conversations first for responsive early results.
    final entries = directory.entries.toList()
      ..sort((a, b) {
        final tsA = _lastTimestamp(a.value);
        final tsB = _lastTimestamp(b.value);
        return tsB.compareTo(tsA);
      });

    for (final entry in entries) {
      // Locked chats never appear in search results — WhatsApp reveals
      // them only through the secret code typed in the search bar.
      if (entry.value['isLocked'] as bool? ?? false) continue;

      final messages = await ms.loadMessages(entry.key);
      var perChat = 0;
      for (var i = messages.length - 1; i >= 0 && perChat < _kMaxPerChat; i--) {
        final m = messages[i];
        if (m.type == KoraMessageType.system) continue;

        if (filter != HomeSearchFilter.all) {
          // Media filters match by category only (WhatsApp behavior —
          // the chip is the query, no text match required beyond it).
          final category = _mediaCategory(m);
          if (category != filter) continue;
        } else {
          if (!_matches(m, q)) continue;
        }

        hits.add(HomeMessageHit(
          chatId: entry.key,
          chatName: (entry.value['name'] as String?) ?? entry.key,
          avatarAsset: _nonEmpty(entry.value['avatarAsset'] as String?),
          avatarUrl: _nonEmpty(entry.value['avatarUrl'] as String?),
          badge: KoraBadgeType.values[entry.value['badge'] as int? ?? 0],
          isGroupChat: entry.value['isGroupChat'] as bool? ?? false,
          message: m,
        ));
        perChat++;
      }
      if (hits.length >= _kMaxHits) break;
    }

    hits.sort((a, b) => b.message.timestamp.compareTo(a.message.timestamp));
    return hits.take(_kMaxHits).toList();
  }

  /// The searchable text of a message: body text, attachment name, and
  /// any voice-note transcript.
  static String _searchableText(KoraMessage m) {
    return [m.text, m.attachmentName ?? '', m.voiceTranscript ?? '']
        .join(' ')
        .trim();
  }

  static bool _matches(KoraMessage m, String q) =>
      _searchableText(m).toLowerCase().contains(q);

  /// Maps a message to its media filter category (null = not media and
  /// not a link — only matched by plain text search on "All").
  static HomeSearchFilter? _mediaCategory(KoraMessage m) {
    switch (m.type) {
      case KoraMessageType.image:
        final url = (m.mediaUrl ?? '').toLowerCase();
        return url.contains('.gif') || url.contains('giphy')
            ? HomeSearchFilter.gifs
            : HomeSearchFilter.photos;
      case KoraMessageType.video:
      case KoraMessageType.videoNote:
        return HomeSearchFilter.videos;
      case KoraMessageType.voice:
        return HomeSearchFilter.audio;
      case KoraMessageType.document:
      case KoraMessageType.file:
        return HomeSearchFilter.documents;
      case KoraMessageType.text:
        final t = m.text.toLowerCase();
        return t.contains('http://') || t.contains('https://') || t.contains('www.')
            ? HomeSearchFilter.links
            : null;
      default:
        return null;
    }
  }

  static DateTime _lastTimestamp(Map<String, dynamic> meta) {
    final raw = meta['lastMessageTimestamp'] as String?;
    if (raw != null) {
      return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String? _nonEmpty(String? s) =>
      (s == null || s.isEmpty) ? null : s;
}
