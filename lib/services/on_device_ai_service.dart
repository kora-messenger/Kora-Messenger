import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device AI service — smart replies, summarization, rephrasing.
/// All processing happens locally without server calls.
class OnDeviceAiService {
  static final OnDeviceAiService _instance = OnDeviceAiService._internal();
  factory OnDeviceAiService() => _instance;
  OnDeviceAiService._internal();

  bool _enabled = true;
  bool _batterySaver = false;
  int _maxRamMb = 512;

  bool get enabled => _enabled;
  bool get batterySaver => _batterySaver;
  int get maxRamMb => _maxRamMb;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('kora_on_device_ai_enabled') ?? true;
    _batterySaver = prefs.getBool('kora_on_device_ai_battery_saver') ?? false;
    _maxRamMb = prefs.getInt('kora_on_device_ai_ram') ?? 512;
  }

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kora_on_device_ai_enabled', v);
  }

  Future<void> setBatterySaver(bool v) async {
    _batterySaver = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kora_on_device_ai_battery_saver', v);
  }

  Future<void> setMaxRam(int mb) async {
    _maxRamMb = mb;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('kora_on_device_ai_ram', mb);
  }

  /// Generate context-aware smart replies based on incoming message.
  List<String> getSmartReplies(String incomingMessage) {
    if (!_enabled) return [];
    final msg = incomingMessage.toLowerCase();
    final replies = <String>[];

    if (msg.contains('hello') || msg.contains('hi') || msg.contains('hey')) {
      replies.addAll(['Hi there!', 'Hello!', 'Hey, how are you?']);
    }
    if (msg.contains('how are you')) {
      replies.addAll(['I\'m doing great, thanks!', 'Good! How about you?', 'All good here!']);
    }
    if (msg.contains('thank')) {
      replies.addAll(['You\'re welcome!', 'No problem at all!', 'Anytime!']);
    }
    if (msg.contains('?')) {
      replies.addAll(['Let me check...', 'Yes, definitely!', 'I think so.']);
    }
    if (msg.contains('bye') || msg.contains('goodbye')) {
      replies.addAll(['Talk soon!', 'Bye! 👋', 'See you later!']);
    }
    if (msg.contains('congratulations') || msg.contains('congrats')) {
      replies.addAll(['Thank you so much!', 'Thanks! 🎉', 'Appreciate it!']);
    }
    if (msg.contains('sorry')) {
      replies.addAll(['No worries!', 'It\'s okay!', 'Don\'t worry about it.']);
    }
    if (msg.contains('love')) {
      replies.addAll(['Love you too!', '❤️', 'Same here!']);
    }
    if (msg.contains('meet') || msg.contains('meeting')) {
      replies.addAll(['Sure, when?', 'I\'ll be there!', 'Let me check my schedule.']);
    }
    if (replies.isEmpty) {
      replies.addAll(['Got it!', 'Interesting...', 'Tell me more!', 'Sounds good!']);
    }

    return replies.take(3).toList();
  }

  /// Summarize a conversation with bullet points.
  String summarizeConversation(List<String> messages) {
    if (!_enabled || messages.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('Conversation summary:');
    for (final msg in messages.take(5)) {
      if (msg.length > 80) {
        buffer.writeln('• ${msg.substring(0, 80)}...');
      } else {
        buffer.writeln('• $msg');
      }
    }
    if (messages.length > 5) {
      buffer.writeln('• ...and ${messages.length - 5} more messages');
    }
    return buffer.toString();
  }

  /// Rephrase a message in a different tone.
  String rephraseMessage(String message, String tone) {
    if (!_enabled) return message;
    switch (tone.toLowerCase()) {
      case 'professional':
        return message.replaceAll('hi', 'Hello').replaceAll('hey', 'Greetings')
          .replaceAll('thanks', 'Thank you').replaceAll('ok', 'Understood')
          .replaceAll('yeah', 'Yes').replaceAll('nope', 'No');
      case 'casual':
        return message.replaceAll('Hello', 'Hey').replaceAll('Greetings', 'Hi')
          .replaceAll('Thank you', 'Thanks').replaceAll('Understood', 'Got it');
      case 'concise':
        final sentences = message.split('. ');
        return sentences.map((s) => s.length > 50 ? '${s.substring(0, 50)}...' : s).join('. ');
      case 'polite':
        return 'Please ${message.toLowerCase()}';
      default:
        return message;
    }
  }

  /// Analyze sentiment of a message.
  Map<String, dynamic> analyzeSentiment(String message) {
    if (!_enabled) return {'sentiment': 'neutral', 'score': 0.5};
    final msg = message.toLowerCase();
    final positiveWords = ['happy', 'good', 'great', 'excellent', 'love', 'awesome', 'wonderful', 'fantastic', 'amazing', 'perfect'];
    final negativeWords = ['sad', 'bad', 'terrible', 'hate', 'awful', 'horrible', 'angry', 'upset', 'disappointed', 'frustrated'];
    
    int posCount = positiveWords.where((w) => msg.contains(w)).length;
    int negCount = negativeWords.where((w) => msg.contains(w)).length;
    
    if (posCount > negCount) return {'sentiment': 'positive', 'score': 0.6 + (posCount * 0.1)};
    if (negCount > posCount) return {'sentiment': 'negative', 'score': 0.4 - (negCount * 0.1)};
    return {'sentiment': 'neutral', 'score': 0.5};
  }
}
