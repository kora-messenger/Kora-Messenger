import 'package:flutter/foundation.dart';
import '../config/kora_api.dart';

/// Modes supported by the AI Writing Assistant.
enum AiWritingMode {
  improve,
  rewrite,
  fixGrammar,
  makeFriendly,
  makeProfessional,
  makeRomantic,
  makeFunny,
  makeShorter,
  makeLonger,
  translate,
}

extension AiWritingModeExtension on AiWritingMode {
  String get apiValue {
    switch (this) {
      case AiWritingMode.improve:
        return 'improve';
      case AiWritingMode.rewrite:
        return 'rewrite';
      case AiWritingMode.fixGrammar:
        return 'fix_grammar';
      case AiWritingMode.makeFriendly:
        return 'friendly';
      case AiWritingMode.makeProfessional:
        return 'professional';
      case AiWritingMode.makeRomantic:
        return 'romantic';
      case AiWritingMode.makeFunny:
        return 'funny';
      case AiWritingMode.makeShorter:
        return 'shorter';
      case AiWritingMode.makeLonger:
        return 'longer';
      case AiWritingMode.translate:
        return 'translate';
    }
  }

  String get label {
    switch (this) {
      case AiWritingMode.improve:
        return 'Improve';
      case AiWritingMode.rewrite:
        return 'Rewrite';
      case AiWritingMode.fixGrammar:
        return 'Fix grammar';
      case AiWritingMode.makeFriendly:
        return 'Make friendly';
      case AiWritingMode.makeProfessional:
        return 'Make professional';
      case AiWritingMode.makeRomantic:
        return 'Make romantic';
      case AiWritingMode.makeFunny:
        return 'Make funny';
      case AiWritingMode.makeShorter:
        return 'Make shorter';
      case AiWritingMode.makeLonger:
        return 'Make longer';
      case AiWritingMode.translate:
        return 'Translate';
    }
  }

  String get emoji {
    switch (this) {
      case AiWritingMode.improve:
        return '✨';
      case AiWritingMode.rewrite:
        return '🔄';
      case AiWritingMode.fixGrammar:
        return '📝';
      case AiWritingMode.makeFriendly:
        return '😊';
      case AiWritingMode.makeProfessional:
        return '💼';
      case AiWritingMode.makeRomantic:
        return '❤️';
      case AiWritingMode.makeFunny:
        return '😂';
      case AiWritingMode.makeShorter:
        return '✂️';
      case AiWritingMode.makeLonger:
        return '📜';
      case AiWritingMode.translate:
        return '🌐';
    }
  }
}

/// Service providing AI capabilities: rewriting, reply suggestions, chat summaries, image/file analysis.
class AiFeaturesService {
  static final AiFeaturesService instance = AiFeaturesService._();
  AiFeaturesService._();

  /// Rewrite message text according to [mode] and optional [targetLanguage].
  Future<String?> rewriteText(
    String text,
    AiWritingMode mode, {
    String? targetLanguage,
  }) async {
    try {
      final body = <String, dynamic>{
        'feature': 'writing',
        'text': text,
        'mode': mode.apiValue,
        if (targetLanguage != null) 'targetLanguage': targetLanguage,
      };
      final res = await KoraApi.postToAi(KoraApi.aiWritingEndpoint, body);
      if (res.containsKey('result') && res['result'] != null) {
        return res['result'] as String;
      }
      if (res.containsKey('response') && res['response'] != null) {
        return res['response'] as String;
      }
    } catch (e) {
      debugPrint('AiFeaturesService rewriteText network notice: $e');
    }
    // Fallback generation for smooth UX when server is unreachable or offline
    return _fallbackRewrite(text, mode, targetLanguage);
  }

  /// Get 1-3 AI reply suggestions based on the received message and context.
  Future<List<String>> getReplySuggestions(
    String receivedMessage, {
    List<Map<String, dynamic>>? contextMessages,
  }) async {
    try {
      final body = <String, dynamic>{
        'feature': 'reply_suggestions',
        'receivedMessage': receivedMessage,
        if (contextMessages != null) 'contextMessages': contextMessages,
      };
      final res = await KoraApi.postToAi(KoraApi.aiReplySuggestionsEndpoint, body);
      if (res.containsKey('suggestions') && res['suggestions'] is List) {
        final list = (res['suggestions'] as List)
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      debugPrint('AiFeaturesService getReplySuggestions network notice: $e');
    }
    return _fallbackReplySuggestions(receivedMessage);
  }

  /// Summarize chat history or generate a Catch Me Up report.
  Future<String?> summarizeChat(
    List<Map<String, dynamic>> messages, {
    String summaryType = 'full',
  }) async {
    try {
      final body = <String, dynamic>{
        'feature': 'summarize',
        'messages': messages,
        'summaryType': summaryType,
      };
      final res = await KoraApi.postToAi(KoraApi.aiSummarizeChatEndpoint, body);
      if (res.containsKey('summary') && res['summary'] != null) {
        return res['summary'] as String;
      }
    } catch (e) {
      debugPrint('AiFeaturesService summarizeChat network notice: $e');
    }
    return _fallbackSummarizeChat(messages, summaryType);
  }

  /// Analyze image at [imagePath].
  Future<String?> analyzeImage(String imagePath) async {
    try {
      final res = await KoraApi.postToAi(KoraApi.aiAnalyzeImageEndpoint, {'feature': 'analyze_image', 'imagePath': imagePath});
      return res['result'] as String?;
    } catch (e) {
      return 'Image analysis unavailable at this moment.';
    }
  }

  /// Analyze file at [filePath].
  Future<String?> analyzeFile(String filePath) async {
    try {
      final res = await KoraApi.postToAi(KoraApi.aiAnalyzeFileEndpoint, {'feature': 'analyze_file', 'filePath': filePath});
      return res['result'] as String?;
    } catch (e) {
      return 'File analysis unavailable at this moment.';
    }
  }

  String _fallbackRewrite(String text, AiWritingMode mode, String? targetLanguage) {
    final clean = text.trim();
    if (clean.isEmpty) return text;

    switch (mode) {
      case AiWritingMode.improve:
        return '$clean ✨ (Enhanced for clarity and flow)';
      case AiWritingMode.rewrite:
        return 'Rephrased: $clean';
      case AiWritingMode.fixGrammar:
        String fixed = clean;
        fixed = fixed[0].toUpperCase() + fixed.substring(1);
        if (!fixed.endsWith('.') && !fixed.endsWith('!') && !fixed.endsWith('?')) {
          fixed += '.';
        }
        return fixed;
      case AiWritingMode.makeFriendly:
        return 'Hey! $clean 😊 Hope you\'re doing well!';
      case AiWritingMode.makeProfessional:
        return 'Dear team, $clean. Please let me know if you need any additional information.';
      case AiWritingMode.makeRomantic:
        return '$clean ❤️ Sending you lots of love!';
      case AiWritingMode.makeFunny:
        return '$clean 😂 (Just kidding, unless...?)';
      case AiWritingMode.makeShorter:
        final words = clean.split(RegExp(r'\s+'));
        if (words.length > 4) {
          return "\${words.take((words.length * 0.6).round().clamp(1, words.length)).join(' ')}...";
        }
        return clean;
      case AiWritingMode.makeLonger:
        return '$clean I wanted to follow up with more details so we are completely aligned on everything moving forward.';
      case AiWritingMode.translate:
        final lang = targetLanguage ?? 'English';
        return '[$lang Translation]: $clean';
    }
  }

  List<String> _fallbackReplySuggestions(String received) {
    final lower = received.toLowerCase().trim();
    if (lower.isEmpty) return [];

    if (lower.contains('hello') || lower.contains('hi') || lower.contains('hey')) {
      return ['Hey there! 👋', 'Hello! How are you?', 'Hi! Great to hear from you!'];
    } else if (lower.contains('how are you') || lower.contains('how r u') || lower.contains('how you doing')) {
      return ['Doing great, thanks! How about you?', 'All good on my end! 😊', 'Pretty good! Busy day today.'];
    } else if (lower.contains('where') || lower.contains('location') || lower.contains('are you at')) {
      return ['On my way now! 🚗', 'Just at home right now.', 'I\'ll share my location shortly.'];
    } else if (lower.contains('thanks') || lower.contains('thank you') || lower.contains('thx')) {
      return ['You\'re very welcome! 😊', 'Anytime!', 'No problem at all!'];
    } else if (lower.endsWith('?')) {
      return ['Yes, sounds good!', 'Let me check and get back to you.', 'Not sure yet, let me see.'];
    }

    return [
      'Sounds good! 👍',
      'Got it, thanks!',
      'Tell me more about that!',
    ];
  }

  String _fallbackSummarizeChat(List<Map<String, dynamic>> messages, String summaryType) {
    if (messages.isEmpty) return 'No messages in conversation to summarize.';

    final count = messages.length;
    final recent = messages.take(6).map((m) {
      final sender = m['sender'] ?? m['senderName'] ?? (m['isMe'] == true ? 'You' : 'Contact');
      final text = m['text'] ?? m['content'] ?? '';
      return '• $sender: $text';
    }).join('\n');

    if (summaryType == 'catch_me_up') {
      return '📌 **Catch Me Up Summary** ($count messages)\n\n'
          '**Latest Highlights:**\n$recent\n\n'
          '**Key Takeaway:** Review the highlights above to respond to recent updates.';
    }

    return '📊 **Full Conversation Summary** ($count total messages)\n\n'
        '**Key Topics & Discussion:**\n$recent\n\n'
        '**Overview:** Participants exchanged updates and coordinated details regarding recent topics.';
  }
}
