import 'dart:convert';

/// A single option in a poll message.
class PollOption {
  final String id;
  final String text;
  final int voteCount;
  final List<String> voterIds;

  const PollOption({
    required this.id,
    required this.text,
    this.voteCount = 0,
    this.voterIds = const [],
  });

  PollOption copyWith({
    String? id,
    String? text,
    int? voteCount,
    List<String>? voterIds,
  }) {
    return PollOption(
      id: id ?? this.id,
      text: text ?? this.text,
      voteCount: voteCount ?? this.voteCount,
      voterIds: voterIds ?? this.voterIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'voteCount': voteCount,
        'voterIds': voterIds,
      };

  factory PollOption.fromJson(Map<String, dynamic> j) => PollOption(
        id: j['id'] as String? ?? '',
        text: j['text'] as String? ?? '',
        voteCount: j['voteCount'] as int? ?? 0,
        voterIds: (j['voterIds'] as List?)?.cast<String>() ?? const [],
      );
}

/// A poll message attached to a Kora conversation.
class PollMessage {
  final String id;
  final String question;
  final List<PollOption> options;
  final bool allowMultipleAnswers;
  final int totalVotes;

  const PollMessage({
    required this.id,
    required this.question,
    required this.options,
    this.allowMultipleAnswers = false,
    this.totalVotes = 0,
  });

  PollMessage copyWith({
    String? id,
    String? question,
    List<PollOption>? options,
    bool? allowMultipleAnswers,
    int? totalVotes,
  }) {
    return PollMessage(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      allowMultipleAnswers: allowMultipleAnswers ?? this.allowMultipleAnswers,
      totalVotes: totalVotes ?? this.totalVotes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'options': options.map((o) => o.toJson()).toList(),
        'allowMultipleAnswers': allowMultipleAnswers,
        'totalVotes': totalVotes,
      };

  factory PollMessage.fromJson(Map<String, dynamic> j) => PollMessage(
        id: j['id'] as String? ?? '',
        question: j['question'] as String? ?? '',
        options: (j['options'] as List?)
                ?.map((o) => PollOption.fromJson(o as Map<String, dynamic>))
                .toList() ??
            const [],
        allowMultipleAnswers: j['allowMultipleAnswers'] as bool? ?? false,
        totalVotes: j['totalVotes'] as int? ?? 0,
      );

  // ── Poll helper methods used by poll_widget.dart ──

  bool hasVoted(String optionId, String userId) {
    final opt = options.where((o) => o.id == optionId).firstOrNull;
    return opt?.voterIds.contains(userId) ?? false;
  }

  void castVote(String optionId, String userId) {}
  void removeVote(String optionId, String userId) {}

  int get totalVoters {
    final allVoters = <String>{};
    for (final opt in options) {
      allVoters.addAll(opt.voterIds);
    }
    return allVoters.length;
  }

  int voteCount(String optionId) {
    final opt = options.where((o) => o.id == optionId).firstOrNull;
    return opt?.voteCount ?? 0;
  }

  double votePercentage(String optionId) {
    final total = totalVoters;
    if (total == 0) return 0;
    return (voteCount(optionId) / total) * 100;
  }
}
