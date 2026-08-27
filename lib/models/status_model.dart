import 'dart:convert';
import 'package:flutter/material.dart';

import '../theme/kora_colors.dart';

/// Type of content shared in a status update.
enum StatusType { text, photo, video, voice }

/// Privacy level for who can see a user's status.
enum StatusPrivacy { myContacts, myContactsExcept, onlyShareWith }

/// Whether a contact's status has been viewed by the current user.
enum StatusViewStatus { unviewed, viewed }

/// A single status update — one item in a story-like sequence.
/// Statuses auto-expire 24 hours after creation.
class StatusItem {
  final String id;
  final StatusType type;
  final String? text;
  final String? mediaPath;
  final String? mediaUrl;
  final String? mediaThumbnailPath;
  final Color? backgroundColor;
  final Color? textColor;
  final String? fontFamily;
  final String? musicTitle;
  final String? caption;
  final DateTime createdAt;
  final Duration? duration;
  final bool isViewOnce;
  final List<String> viewedBy;
  final int likeCount;
  final int replyCount;
  final bool isDeleted;

  StatusItem({
    required this.id,
    required this.type,
    this.text,
    this.mediaPath,
    this.mediaUrl,
    this.mediaThumbnailPath,
    this.backgroundColor,
    this.textColor,
    this.fontFamily,
    this.musicTitle,
    this.caption,
    required this.createdAt,
    this.duration,
    this.isViewOnce = false,
    List<String>? viewedBy,
    this.likeCount = 0,
    this.replyCount = 0,
    this.isDeleted = false,
  }) : viewedBy = viewedBy ?? [];

  DateTime get expiresAt => createdAt.add(const Duration(hours: 24));
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  StatusItem copyWith({
    String? id,
    StatusType? type,
    String? text,
    String? mediaPath,
    String? mediaUrl,
    String? mediaThumbnailPath,
    Color? backgroundColor,
    Color? textColor,
    String? fontFamily,
    String? caption,
    DateTime? createdAt,
    Duration? duration,
    bool? isViewOnce,
    List<String>? viewedBy,
    int? likeCount,
    int? replyCount,
    bool? isDeleted,
  }) {
    return StatusItem(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaThumbnailPath: mediaThumbnailPath ?? this.mediaThumbnailPath,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      fontFamily: fontFamily ?? this.fontFamily,
      musicTitle: musicTitle ?? this.musicTitle,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      duration: duration ?? this.duration,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      viewedBy: viewedBy ?? this.viewedBy,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'text': text,
      'mediaPath': mediaPath,
      'mediaUrl': mediaUrl,
      'mediaThumbnailPath': mediaThumbnailPath,
      'backgroundColor': backgroundColor?.value,
      'textColor': textColor?.value,
      'fontFamily': fontFamily,
      'caption': caption,
      'createdAt': createdAt.toIso8601String(),
      'duration': duration?.inSeconds,
      'isViewOnce': isViewOnce,
      'viewedBy': viewedBy,
      'likeCount': likeCount,
      'replyCount': replyCount,
      'isDeleted': isDeleted,
    };
  }

  factory StatusItem.fromJson(Map<String, dynamic> json) {
    return StatusItem(
      id: json['id'] as String,
      type: StatusType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => StatusType.text,
      ),
      text: json['text'] as String?,
      mediaPath: json['mediaPath'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      mediaThumbnailPath: json['mediaThumbnailPath'] as String?,
      backgroundColor: json['backgroundColor'] != null
          ? Color(json['backgroundColor'] as int)
          : null,
      textColor: json['textColor'] != null
          ? Color(json['textColor'] as int)
          : null,
      fontFamily: json['fontFamily'] as String?,
      caption: json['caption'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      duration: json['duration'] != null
          ? Duration(seconds: json['duration'] as int)
          : null,
      isViewOnce: json['isViewOnce'] as bool? ?? false,
      viewedBy: (json['viewedBy'] as List?)?.cast<String>() ?? [],
      likeCount: json['likeCount'] as int? ?? 0,
      replyCount: json['replyCount'] as int? ?? 0,
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }
}

/// Represents a user's complete status — a collection of StatusItems
/// that form a story-like sequence.
class KoraStatus {
  final String id;
  final String userEmail;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final List<StatusItem> items;
  DateTime lastUpdatedAt;
  StatusPrivacy privacy;
  List<String> excludedContactIds;
  List<String> includedContactIds;
  bool isMuted;
  StatusViewStatus viewStatus;

  KoraStatus({
    required this.id,
    required this.userEmail,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    required this.items,
    required this.lastUpdatedAt,
    this.privacy = StatusPrivacy.myContacts,
    List<String>? excludedContactIds,
    List<String>? includedContactIds,
    this.isMuted = false,
    this.viewStatus = StatusViewStatus.unviewed,
  })  : excludedContactIds = excludedContactIds ?? [],
        includedContactIds = includedContactIds ?? [];

  bool get hasUnviewed =>
      items.any((i) => !i.viewedBy.contains('me') && !i.isExpired);

  bool get isViewed => !hasUnviewed;

  String get timeAgo {
    final diff = DateTime.now().difference(lastUpdatedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  KoraStatus copyWith({
    String? id,
    String? userEmail,
    String? username,
    String? fullName,
    String? avatarUrl,
    List<StatusItem>? items,
    DateTime? lastUpdatedAt,
    StatusPrivacy? privacy,
    List<String>? excludedContactIds,
    List<String>? includedContactIds,
    bool? isMuted,
    StatusViewStatus? viewStatus,
  }) {
    return KoraStatus(
      id: id ?? this.id,
      userEmail: userEmail ?? this.userEmail,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      items: items ?? this.items,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      privacy: privacy ?? this.privacy,
      excludedContactIds: excludedContactIds ?? this.excludedContactIds,
      includedContactIds: includedContactIds ?? this.includedContactIds,
      isMuted: isMuted ?? this.isMuted,
      viewStatus: viewStatus ?? this.viewStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userEmail': userEmail,
      'username': username,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'items': items.map((i) => i.toJson()).toList(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      'privacy': privacy.name,
      'excludedContactIds': excludedContactIds,
      'includedContactIds': includedContactIds,
      'isMuted': isMuted,
      'viewStatus': viewStatus.name,
    };
  }

  factory KoraStatus.fromJson(Map<String, dynamic> json) {
    return KoraStatus(
      id: json['id'] as String,
      userEmail: json['userEmail'] as String,
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      items: (json['items'] as List)
          .map((i) => StatusItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      lastUpdatedAt: DateTime.parse(json['lastUpdatedAt'] as String),
      privacy: StatusPrivacy.values.firstWhere(
        (p) => p.name == json['privacy'],
        orElse: () => StatusPrivacy.myContacts,
      ),
      excludedContactIds:
          (json['excludedContactIds'] as List?)?.cast<String>() ?? [],
      includedContactIds:
          (json['includedContactIds'] as List?)?.cast<String>() ?? [],
      isMuted: json['isMuted'] as bool? ?? false,
      viewStatus: StatusViewStatus.values.firstWhere(
        (v) => v.name == json['viewStatus'],
        orElse: () => StatusViewStatus.unviewed,
      ),
    );
  }
}

/// Record of who viewed a status item.
class StatusView {
  final String statusItemId;
  final String viewerEmail;
  final String viewerName;
  final String? viewerAvatarUrl;
  final DateTime viewedAt;
  final int? reaction;
  final String? replyText;

  StatusView({
    required this.statusItemId,
    required this.viewerEmail,
    required this.viewerName,
    this.viewerAvatarUrl,
    required this.viewedAt,
    this.reaction,
    this.replyText,
  });

  Map<String, dynamic> toJson() {
    return {
      'statusItemId': statusItemId,
      'viewerEmail': viewerEmail,
      'viewerName': viewerName,
      'viewerAvatarUrl': viewerAvatarUrl,
      'viewedAt': viewedAt.toIso8601String(),
      'reaction': reaction,
      'replyText': replyText,
    };
  }

  factory StatusView.fromJson(Map<String, dynamic> json) {
    return StatusView(
      statusItemId: json['statusItemId'] as String,
      viewerEmail: json['viewerEmail'] as String,
      viewerName: json['viewerName'] as String,
      viewerAvatarUrl: json['viewerAvatarUrl'] as String?,
      viewedAt: DateTime.parse(json['viewedAt'] as String),
      reaction: json['reaction'] as int?,
      replyText: json['replyText'] as String?,
    );
  }
}
