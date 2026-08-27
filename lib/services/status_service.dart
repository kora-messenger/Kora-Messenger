import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/status_model.dart';
import '../theme/kora_colors.dart';

/// Manages Kora's Status feature — the WhatsApp-style "disappearing
/// after 24h" story system. Handles creating, viewing, replying to,
/// and deleting status updates.
///
/// All data is persisted locally via SharedPreferences (temporary until
/// backend migration). Statuses auto-expire after 24 hours.
class StatusService {
  StatusService._();
  static final StatusService instance = StatusService._();

  static const _kMyStatusesKey = 'kora_my_status_items';
  static const _kContactStatusesKey = 'kora_contact_statuses';
  static const _kStatusPrivacyKey = 'kora_status_privacy';

  // ── My Status ────────────────────────────────────────────────

  List<StatusItem> _myStatusItems = [];
  List<StatusItem> get myStatusItems => List.unmodifiable(_myStatusItems);

  bool get hasStatus => _myStatusItems.any((i) => !i.isExpired && !i.isDeleted);

  /// Add a new status item to my status.
  Future<void> addStatusItem(StatusItem item) async {
    _myStatusItems.add(item);
    _cleanupExpired();
    await _persistMyStatuses();
  }

  /// Delete a specific status item.
  Future<void> deleteStatusItem(String itemId) async {
    _myStatusItems.removeWhere((i) => i.id == itemId);
    await _persistMyStatuses();
  }

  /// Clear all my status items.
  Future<void> clearMyStatus() async {
    _myStatusItems.clear();
    await _persistMyStatuses();
  }

  /// Record a view on my own status item (from a contact viewing it).
  Future<void> recordViewOnMyStatus(String itemId, StatusView view) async {
    final idx = _myStatusItems.indexWhere((i) => i.id == itemId);
    if (idx >= 0) {
      if (!_myStatusItems[idx].viewedBy.contains(view.viewerEmail)) {
        _myStatusItems[idx].viewedBy.add(view.viewerEmail);
      }
      if (view.reaction != null) _myStatusItems[idx].likeCount++;
      if (view.replyText != null) _myStatusItems[idx].replyCount++;
      await _persistMyStatuses();
    }
  }

  // ── Contact Statuses ──────────────────────────────────────────

  List<KoraStatus> _contactStatuses = [];
  List<KoraStatus> get contactStatuses => List.unmodifiable(_contactStatuses);

  /// Get unviewed contact statuses (green ring).
  List<KoraStatus> get recentUpdates =>
      _contactStatuses.where((s) => s.viewStatus == StatusViewStatus.unviewed && !s.isMuted).toList();

  /// Get viewed contact statuses (gray ring).
  List<KoraStatus> get viewedUpdates =>
      _contactStatuses.where((s) => s.viewStatus == StatusViewStatus.viewed && !s.isMuted).toList();

  /// Get muted contact statuses.
  List<KoraStatus> get mutedUpdates =>
      _contactStatuses.where((s) => s.isMuted).toList();

  /// Mark a contact's status as viewed.
  Future<void> markStatusViewed(String statusId, String statusItemId) async {
    final sIdx = _contactStatuses.indexWhere((s) => s.id == statusId);
    if (sIdx < 0) return;
    final status = _contactStatuses[sIdx];
    final iIdx = status.items.indexWhere((i) => i.id == statusItemId);
    if (iIdx >= 0 && !status.items[iIdx].viewedBy.contains('me')) {
      status.items[iIdx].viewedBy.add('me');
    }
    // If all items are viewed, mark the whole status as viewed
    if (status.items.isNotEmpty && status.items.every((i) => i.viewedBy.contains('me'))) {
      status.viewStatus = StatusViewStatus.viewed;
    }
    await _persistContactStatuses();
  }

  /// Mute/unmute a contact's status.
  Future<void> toggleMute(String statusId) async {
    final idx = _contactStatuses.indexWhere((s) => s.id == statusId);
    if (idx >= 0) {
      _contactStatuses[idx].isMuted = !_contactStatuses[idx].isMuted;
      await _persistContactStatuses();
    }
  }

  // ── Status Privacy ────────────────────────────────────────────

  StatusPrivacy _privacy = StatusPrivacy.myContacts;
  List<String> _excludedContactIds = [];
  List<String> _includedContactIds = [];

  StatusPrivacy get privacy => _privacy;
  List<String> get excludedContactIds => List.unmodifiable(_excludedContactIds);
  List<String> get includedContactIds => List.unmodifiable(_includedContactIds);

  Future<void> setPrivacy(
    StatusPrivacy privacy, {
    List<String>? excluded,
    List<String>? included,
  }) async {
    _privacy = privacy;
    if (excluded != null) _excludedContactIds = excluded;
    if (included != null) _includedContactIds = included;
    await _persistPrivacy();
  }

  // ── Reply to a status ─────────────────────────────────────────

  /// Reply to a contact's status item — increments reply count.
  Future<void> replyToStatus(String statusId, String statusItemId, String replyText) async {
    final sIdx = _contactStatuses.indexWhere((s) => s.id == statusId);
    if (sIdx < 0) return;
    final iIdx = _contactStatuses[sIdx].items.indexWhere((i) => i.id == statusItemId);
    if (iIdx >= 0) {
      _contactStatuses[sIdx].items[iIdx].replyCount++;
      await _persistContactStatuses();
    }
  }

  // ── Persistence ───────────────────────────────────────────────

  Future<void> init() async {
    await _loadMyStatuses();
    await _loadContactStatuses();
    await _loadPrivacy();
    _cleanupExpired();
  }

  void _cleanupExpired() {
    _myStatusItems.removeWhere((i) => i.isExpired || i.isDeleted);
    for (final status in _contactStatuses) {
      status.items.removeWhere((i) => i.isExpired || i.isDeleted);
    }
    _contactStatuses.removeWhere((s) => s.items.isEmpty);
  }

  Future<void> _persistMyStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_myStatusItems.map((i) => i.toJson()).toList());
    await prefs.setString(_kMyStatusesKey, json);
  }

  Future<void> _loadMyStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_kMyStatusesKey);
    if (str != null) {
      final list = jsonDecode(str) as List;
      _myStatusItems = list.map((j) => StatusItem.fromJson(j as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _persistContactStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_contactStatuses.map((s) => s.toJson()).toList());
    await prefs.setString(_kContactStatusesKey, json);
  }

  Future<void> _loadContactStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_kContactStatusesKey);
    if (str != null) {
      final list = jsonDecode(str) as List;
      _contactStatuses = list.map((j) => KoraStatus.fromJson(j as Map<String, dynamic>)).toList();
    }
    if (_contactStatuses.isEmpty) {
      _seedDemoStatuses();
    }
  }

  Future<void> _persistPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode({
      'privacy': _privacy.name,
      'excluded': _excludedContactIds,
      'included': _includedContactIds,
    });
    await prefs.setString(_kStatusPrivacyKey, json);
  }

  Future<void> _loadPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_kStatusPrivacyKey);
    if (str != null) {
      final data = jsonDecode(str) as Map<String, dynamic>;
      _privacy = StatusPrivacy.values.firstWhere(
        (p) => p.name == data['privacy'],
        orElse: () => StatusPrivacy.myContacts,
      );
      _excludedContactIds = (data['excluded'] as List?)?.cast<String>() ?? [];
      _includedContactIds = (data['included'] as List?)?.cast<String>() ?? [];
    }
  }

  // ── Demo data ─────────────────────────────────────────────────

  void _seedDemoStatuses() {
    _contactStatuses = [
      KoraStatus(
        id: 'status_001',
        userEmail: 'ada@kora.app',
        username: '@ada',
        fullName: 'Ada Nwosu',
        avatarUrl: null,
        items: [
          StatusItem(
            id: 'si_001',
            type: StatusType.text,
            text: 'Good morning, Kora! ☀️',
            backgroundColor: KoraColors.purple,
            textColor: Colors.white,
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          StatusItem(
            id: 'si_002',
            type: StatusType.text,
            text: 'Building something great today 💜',
            backgroundColor: KoraColors.blue,
            textColor: Colors.white,
            createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 50)),
          ),
        ],
        lastUpdatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        privacy: StatusPrivacy.myContacts,
      ),
      KoraStatus(
        id: 'status_002',
        userEmail: 'tunde@kora.app',
        username: '@tunde',
        fullName: 'Tunde Okafor',
        avatarUrl: null,
        items: [
          StatusItem(
            id: 'si_003',
            type: StatusType.text,
            text: 'Game day! ⚽',
            backgroundColor: const Color(0xFF22C55E),
            textColor: Colors.white,
            createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          ),
        ],
        lastUpdatedAt: DateTime.now().subtract(const Duration(hours: 5)),
        privacy: StatusPrivacy.myContacts,
      ),
      KoraStatus(
        id: 'status_003',
        userEmail: 'zara@kora.app',
        username: '@zara',
        fullName: 'Zara Bello',
        avatarUrl: null,
        items: [
          StatusItem(
            id: 'si_004',
            type: StatusType.text,
            text: 'Coffee thoughts ☕',
            backgroundColor: const Color(0xFFEC4899),
            textColor: Colors.white,
            createdAt: DateTime.now().subtract(const Duration(hours: 8)),
          ),
        ],
        lastUpdatedAt: DateTime.now().subtract(const Duration(hours: 8)),
        privacy: StatusPrivacy.myContacts,
        viewStatus: StatusViewStatus.viewed,
      ),
    ];
  }
}
