import 'chat_models.dart';

/// Call type — voice or video.
enum CallType { voice, video }

/// Call status — how the call ended.
enum CallStatus {
  outgoing,    // User A called User B, call connected (answered)
  missed,      // User A called User B, User B didn't pick up
  incoming,    // User B called User A, call connected (answered)
  declined,    // User B called User A, User A declined
}

/// A single call log entry shown in the Calls tab.
class CallLog {
  final String id;
  final String contactName;
  final String? avatarAsset;
  final String? avatarUrl;
  final KoraBadgeType badge;
  final CallType type;
  final CallStatus status;
  final DateTime timestamp;
  final int? durationSeconds; // null if not connected

  const CallLog({
    required this.id,
    required this.contactName,
    this.avatarAsset,
    this.avatarUrl,
    this.badge = KoraBadgeType.none,
    required this.type,
    required this.status,
    required this.timestamp,
    this.durationSeconds,
  });

  /// True if the call was missed (outgoing, not picked up).
  bool get isMissed => status == CallStatus.missed;

  /// True if the call was connected/answered.
  bool get isConnected => status == CallStatus.outgoing || status == CallStatus.incoming;

  /// True if the current user initiated the call.
  bool get isOutgoing => status == CallStatus.outgoing || status == CallStatus.missed;

  Map<String, dynamic> toJson() => {
    'id': id,
    'contactName': contactName,
    'avatarAsset': avatarAsset,
    'avatarUrl': avatarUrl,
    'badge': badge.index,
    'type': type.index,
    'status': status.index,
    'timestamp': timestamp.toIso8601String(),
    'durationSeconds': durationSeconds,
  };

  factory CallLog.fromJson(Map<String, dynamic> j) => CallLog(
    id: j['id'] as String,
    contactName: j['contactName'] as String,
    avatarAsset: j['avatarAsset'] as String?,
    avatarUrl: j['avatarUrl'] as String?,
    badge: KoraBadgeType.values[j['badge'] as int? ?? 0],
    type: CallType.values[j['type'] as int? ?? 0],
    status: CallStatus.values[j['status'] as int? ?? 0],
    timestamp: DateTime.parse(j['timestamp'] as String),
    durationSeconds: j['durationSeconds'] as int?,
  );
}
