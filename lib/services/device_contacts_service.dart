import 'dart:convert';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/kora_api.dart';

/// WhatsApp-style device contact discovery.
///
/// Reads the phone's contact book (after a just-in-time permission
/// request), batches every phone number to the backend's
/// `checkPhoneNumbers` matcher, and caches the contacts who are
/// registered on Kora. ContactsService then merges them into the
/// "Contacts on Kora" list, exactly like WhatsApp's contact sync.
///
/// The phone-book display name wins (WhatsApp shows the name you
/// saved in your phone), while the Kora profile supplies the username,
/// Kora ID, avatar, and premium badge.
class DeviceContactsService {
  static final DeviceContactsService instance = DeviceContactsService._();
  DeviceContactsService._();

  static const _kCacheKey = 'kora_matched_contacts';
  static const _kLastSyncKey = 'kora_matched_contacts_last_sync';

  /// Re-sync at most once a day — opening the screen uses the cache
  /// instantly and refreshes in the background when stale.
  static const _staleAfter = Duration(hours: 24);

  /// Phone numbers per backend batch (koraAuth checkPhoneNumbers).
  static const _batchSize = 200;

  /// Whether contacts access has been granted.
  Future<bool> hasPermission() async {
    try {
      return await FlutterContacts.checkPermission();
    } catch (_) {
      return false;
    }
  }

  /// Cached matches from the last successful sync. Returns [] when
  /// the device has never synced (or permission was never granted).
  Future<List<Map<String, Object?>>> getCachedMatches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCacheKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>().map(_fromCache).toList();
    } catch (_) {
      return [];
    }
  }

  /// Whether the cached matches are older than [_staleAfter].
  Future<bool> isCacheStale() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kLastSyncKey) ?? 0;
    if (last == 0) return true;
    return DateTime.now().millisecondsSinceEpoch - last > _staleAfter.inMilliseconds;
  }

  /// Runs a full sync when the cache is stale (or missing); otherwise
  /// returns the cache without touching the device book.
  Future<({List<Map<String, Object?>> matches, bool granted})> ensureFresh() async {
    final granted = await hasPermission();
    if (!granted) {
      return (matches: await getCachedMatches(), granted: false);
    }
    if (await isCacheStale()) {
      return syncMatches();
    }
    return (matches: await getCachedMatches(), granted: true);
  }

  /// Full sync: read the device contact book, match every number
  /// against registered Kora users, cache the result.
  Future<({List<Map<String, Object?>> matches, bool granted})> syncMatches() async {
    var granted = await hasPermission();
    if (!granted) {
      // Just-in-time request — only fires when the user actually
      // needs contact discovery (opening Select contact).
      try {
        granted = await FlutterContacts.requestPermission();
      } catch (_) {
        granted = false;
      }
    }
    if (!granted) {
      return (matches: await getCachedMatches(), granted: false);
    }

    final List<Contact> deviceContacts;
    try {
      deviceContacts = await FlutterContacts.getContacts(withProperties: true);
    } catch (_) {
      return (matches: await getCachedMatches(), granted: false);
    }

    // Collect unique phone numbers with the phone-book name that owns
    // them. Later entries don't overwrite an earlier name for the
    // same number.
    final phoneToName = <String, String>{};
    for (final c in deviceContacts) {
      var name = (c.displayName ?? '').trim();
      if (name.isEmpty) {
        name = ([c.name.first, c.name.last].where((p) => p.trim().isNotEmpty).join(' ')).trim();
      }
      for (final phone in c.phones) {
        final digits = _digits(phone.number);
        if (digits.length < 7) continue; // skip short/invalid numbers
        phoneToName.putIfAbsent(digits, () => name);
      }
    }
    if (phoneToName.isEmpty) {
      await _saveCache([]);
      return (matches: const [], granted: true);
    }

    // Batch-match against the backend.
    final matchedByKoraId = <String, Map<String, Object?>>{};
    final numbers = phoneToName.keys.toList();
    for (var i = 0; i < numbers.length; i += _batchSize) {
      final batch = numbers.sublist(
        i,
        (i + _batchSize) < numbers.length ? i + _batchSize : numbers.length,
      );
      try {
        final response = await http
            .post(
              Uri.parse(KoraApi.authEndpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'action': 'checkPhoneNumbers', 'phoneNumbers': batch}),
            )
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as Map<String, dynamic>? ?? {};
        for (final entry in results.values) {
          final r = entry as Map<String, dynamic>;
          if (r['registered'] != true) continue;
          final user = r['user'] as Map<String, dynamic>? ?? {};
          final koraId = (user['koraId'] as String?) ?? '';
          final key = koraId.isNotEmpty ? koraId : ((user['email'] as String?) ?? '');
          if (key.isEmpty || matchedByKoraId.containsKey(key)) continue;

          final phonebookName = nameForAnyNumber(batch, (user['phoneNumber'] as String?) ?? '', phoneToName);
          final username = ((user['username'] as String?) ?? '').trim();
          matchedByKoraId[key] = {
            'name': phonebookName.isNotEmpty
                ? phonebookName
                : ((user['fullName'] as String?) ?? '').trim(),
            'koraId': koraId,
            'username': username.isEmpty ? '' : (username.startsWith('@') ? username : '@$username'),
            'email': user['email'] as String?,
            'phoneNumber': (user['phoneNumber'] as String?) ?? '',
            'avatarUrl': (user['avatarUrl'] as String?) ?? '',
            'premium': user['isPremium'] == true,
            'verified': user['isVerified'] == true,
            'viaPhone': true,
            'recent': false,
          };
        }
      } catch (_) {
        // Network hiccup on one batch — keep whatever matched so far.
      }
    }

    final matches = matchedByKoraId.values.toList();
    matches.sort((a, b) => ((a['name'] as String?) ?? '').toLowerCase().compareTo(
          ((b['name'] as String?) ?? '').toLowerCase(),
        ));
    await _saveCache(matches);
    return (matches: matches, granted: true);
  }

  /// Finds the phone-book owner name for a matched user: try their
  /// registered number's digits first, then any number in the batch
  /// whose last-10 digits line up (the backend matches on last 10).
  static String nameForAnyNumber(
    List<String> batch,
    String registeredPhone,
    Map<String, String> phoneToName,
  ) {
    final regDigits = _digits(registeredPhone);
    if (regDigits.isNotEmpty && phoneToName.containsKey(regDigits)) {
      return phoneToName[regDigits]!;
    }
    final regLast10 = regDigits.length >= 10 ? regDigits.substring(regDigits.length - 10) : '';
    for (final number in batch) {
      final digits = _digits(number);
      final last10 = digits.length >= 10 ? digits.substring(digits.length - 10) : '';
      if (regLast10.isNotEmpty && last10 == regLast10 && phoneToName.containsKey(number)) {
        return phoneToName[number]!;
      }
    }
    return '';
  }

  static String _digits(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _saveCache(List<Map<String, Object?>> matches) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kCacheKey,
      jsonEncode(matches.map((m) => _toCache(m)).toList()),
    );
    await prefs.setInt(_kLastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Cache entries are Map<String, dynamic> after the JSON round trip.
  static Map<String, dynamic> _toCache(Map<String, Object?> m) =>
      m.map((k, v) => MapEntry(k, v));

  static Map<String, Object?> _fromCache(Map<String, dynamic> m) =>
      m.map((k, v) => MapEntry(k, v));

  /// Clears the cached matches (used when permission is revoked via
  /// the system settings, or the account is purged).
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCacheKey);
    await prefs.remove(_kLastSyncKey);
  }
}
