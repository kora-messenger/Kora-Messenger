import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'conversation_directory.dart';
import 'device_contacts_service.dart';

/// Real contacts service — replaces the old mock contacts list.
///
/// Pulls from three sources:
/// 1. `kora_contacts` SharedPreferences — contacts the user explicitly
///    saved via the New Contact screen.
/// 2. `ConversationDirectoryService` — people the user has actually
///    chatted with (each conversation carries display metadata).
/// 3. `DeviceContactsService` — WhatsApp-style phone-book contacts who
///    are registered on Kora (matched via the backend's phone-number
///    lookup). Their phone-book display name wins, like WhatsApp.
///
/// The lists are merged and de-duplicated by koraId / email so each
/// person appears once. Conversations are marked `recent: true` so the
/// New Group screen can show them under "RECENT".
class ContactsService {
  static final ContactsService instance = ContactsService._();
  ContactsService._();

  static const _kContactsKey = 'kora_contacts';

  /// Returns a unified, de-duplicated contact list.
  ///
  /// Each entry is a `Map<String, Object?>` with keys:
  /// - `name` (String)
  /// - `koraId` (String — may be empty)
  /// - `username` (String — may be empty, includes leading @)
  /// - `email` (String? — recipient email if known)
  /// - `phoneNumber` (String? — if saved)
  /// - `avatarUrl` (String? — remote avatar URL)
  /// - `premium` (bool)
  /// - `recent` (bool — true if the user has chatted with them)
  Future<List<Map<String, Object?>>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRaw = prefs.getStringList(_kContactsKey) ?? [];

    // 1. Parse saved contacts
    final savedContacts = <Map<String, Object?>>[];
    for (final json in savedRaw) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        final usernameRaw = (map['username'] as String? ?? '').trim();
        savedContacts.add({
          'name': (map['name'] as String? ?? '').trim(),
          'koraId': (map['koraId'] as String? ?? '').trim(),
          'username': usernameRaw.isNotEmpty
              ? (usernameRaw.startsWith('@') ? usernameRaw : '@$usernameRaw')
              : '',
          'email': map['email'] as String?,
          'phoneNumber': map['phoneNumber'] as String?,
          'premium': false,
          'recent': false,
        });
      } catch (_) {}
    }

    // 2. Parse conversation directory (people the user has chatted with)
    final directory = await ConversationDirectoryService.instance.getAll();
    final chatContacts = <Map<String, Object?>>[];
    for (final entry in directory.entries) {
      final chatId = entry.key;
      final meta = entry.value;

      // Skip built-in AI chats
      if (chatId == 'kora_support' || chatId == 'kora_ai') continue;

      final name = (meta['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;

      final recipientEmail = meta['recipientEmail'] as String?;
      final badgeIndex = meta['badge'] as int? ?? 0;

      chatContacts.add({
        'name': name,
        'koraId': chatId,
        'username': '',
        'email': recipientEmail,
        'phoneNumber': null,
        'avatarUrl': meta['avatarUrl'] as String?,
        'premium': badgeIndex == 1, // KoraBadgeType.premiumBlue
        'recent': true,
      });
    }

    // 3. Phone-book contacts registered on Kora (WhatsApp-style
    //    contact discovery). Uses the local cache — the Select-contact
    //    screen triggers a fresh sync before calling getContacts().
    final deviceMatches = await DeviceContactsService.instance.getCachedMatches();

    // 4. Merge and de-duplicate
    // Key: koraId if non-empty, otherwise email, otherwise name
    final seen = <String>{};
    final merged = <Map<String, Object?>>[];

    // Add chat contacts first (they're "recent")
    for (final c in chatContacts) {
      final key = _dedupeKey(c);
      if (key.isNotEmpty && seen.add(key)) {
        merged.add(c);
      }
    }

    // Add saved contacts, merging into existing entries if matched
    for (final c in savedContacts) {
      final key = _dedupeKey(c);
      if (key.isEmpty) {
        merged.add(c);
        continue;
      }
      if (seen.add(key)) {
        merged.add(c);
      } else {
        // Merge: fill in missing fields from the saved contact
        final existing = merged.firstWhere(
          (m) => _dedupeKey(m) == key,
          orElse: () => c,
        );
        if (((existing['username'] as String?) ?? '') == '' &&
            ((c['username'] as String?) ?? '') != '') {
          existing['username'] = c['username']!;
        }
        if (existing['email'] == null && c['email'] != null) {
          existing['email'] = c['email']!;
        }
        if (existing['phoneNumber'] == null && c['phoneNumber'] != null) {
          existing['phoneNumber'] = c['phoneNumber']!;
        }
      }
    }

    // Add device matches last — the phone-book name wins over any
    // previously stored display name (WhatsApp behavior), and missing
    // fields are filled in for existing entries.
    for (final c in deviceMatches) {
      final key = _dedupeKey(c);
      if (key.isEmpty) {
        merged.add(c);
        continue;
      }
      if (seen.add(key)) {
        merged.add(c);
      } else {
        final existing = merged.firstWhere(
          (m) => _dedupeKey(m) == key,
          orElse: () => c,
        );
        // Phone-book name wins (it's the name the user saved).
        final phoneName = (c['name'] as String?) ?? '';
        if (phoneName.isNotEmpty) {
          existing['name'] = phoneName;
        }
        if (existing['avatarUrl'] == null || (existing['avatarUrl'] as String?)!.isEmpty) {
          existing['avatarUrl'] = c['avatarUrl'];
        }
        if (((existing['username'] as String?) ?? '') == '' &&
            ((c['username'] as String?) ?? '') != '') {
          existing['username'] = c['username']!;
        }
        if (existing['email'] == null && c['email'] != null) {
          existing['email'] = c['email']!;
        }
        if (existing['phoneNumber'] == null && c['phoneNumber'] != null) {
          existing['phoneNumber'] = c['phoneNumber']!;
        }
        existing['premium'] = (existing['premium'] == true) || (c['premium'] == true);
        if (c['verified'] == true) {
          existing['verified'] = true;
        }
      }
    }

    return merged;
  }

  /// Returns only contacts the user has recently chatted with.
  Future<List<Map<String, Object?>>> getRecentContacts() async {
    final all = await getContacts();
    return all.where((c) => c['recent'] == true).toList();
  }

  /// Finds a contact by QR payload — tries local contacts first.
  ///
  /// QR format: `kora://contact/<koraId>` or `kora://contact/<username>`
  Future<Map<String, Object?>?> findByQrData(String data) async {
    if (!data.startsWith('kora://contact/')) return null;
    final identifier = data.substring('kora://contact/'.length).toLowerCase();

    final contacts = await getContacts();
    for (final contact in contacts) {
      final koraId = (contact['koraId'] as String).toLowerCase();
      final username = (contact['username'] as String).toLowerCase();
      final usernameClean = username.replaceAll('@', '');
      if (koraId == identifier ||
          username == identifier ||
          usernameClean == identifier) {
        return contact;
      }
    }

    return null;
  }

  String _dedupeKey(Map<String, Object?> c) {
    final koraId = (c['koraId'] as String?) ?? '';
    if (koraId.isNotEmpty) return 'kid:$koraId';
    final email = (c['email'] as String?) ?? '';
    if (email.isNotEmpty) return 'email:$email';
    return '';
  }
}
