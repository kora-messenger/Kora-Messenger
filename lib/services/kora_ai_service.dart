import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/kora_api.dart';

/// Message model for AI conversations.
class KoraAiMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final String? attachmentType; // 'image', 'audio', 'video' — for display
  final String? attachmentPreview; // brief description for history

  KoraAiMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.attachmentType,
    this.attachmentPreview,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        if (attachmentType != null) 'attachmentType': attachmentType,
        if (attachmentPreview != null) 'attachmentPreview': attachmentPreview,
      };

  factory KoraAiMessage.fromJson(Map<String, dynamic> json) => KoraAiMessage(
        role: json['role'] as String,
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        attachmentType: json['attachmentType'] as String?,
        attachmentPreview: json['attachmentPreview'] as String?,
      );

  /// Convert to the format expected by the server
  Map<String, dynamic> toHistoryJson() => {
        'role': role,
        'content': content,
      };
}

/// Attachment for AI messages — supports images, audio, and video frames.
class KoraAiAttachment {
  final String type; // 'image', 'audio', 'video_frame'
  final String? base64; // base64-encoded data (no data: prefix)
  final String? mimeType; // e.g. 'image/jpeg', 'audio/aac'
  final String? transcript; // for audio: on-device STT transcript
  final String? filePath; // local file path (converted to base64 before sending)

  KoraAiAttachment({
    required this.type,
    this.base64,
    this.mimeType,
    this.transcript,
    this.filePath,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type};
    if (base64 != null) map['base64'] = base64;
    if (mimeType != null) map['mimeType'] = mimeType;
    if (transcript != null) map['transcript'] = transcript;
    return map;
  }

  /// Create an image attachment from a file path
  static Future<KoraAiAttachment> fromImageFile(String path, {String mimeType = 'image/jpeg'}) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final base64Data = base64Encode(bytes);
    return KoraAiAttachment(type: 'image', base64: base64Data, mimeType: mimeType);
  }

  /// Create an audio attachment with a transcript
  static KoraAiAttachment fromAudioTranscript(String transcript) {
    return KoraAiAttachment(type: 'audio', transcript: transcript);
  }

  /// Create a video frame attachment from a file path
  static Future<KoraAiAttachment> fromVideoFrameFile(String path, {String mimeType = 'image/jpeg'}) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final base64Data = base64Encode(bytes);
    return KoraAiAttachment(type: 'video_frame', base64: base64Data, mimeType: mimeType);
  }
}

/// Result of an AI request.
class KoraAiResult {
  final bool success;
  final String response;
  final String? error;

  KoraAiResult({
    required this.success,
    required this.response,
    this.error,
  });
}

/// Central AI service for Kora Messenger.
///
/// Handles:
/// - Sending messages to Kora AI and Kora AI Support
/// - Conversation history (persisted locally)
/// - Multimodal support: image, audio (voice note), and video frame attachments
/// - Media analysis via koraAiFeatures backend function
///
/// All API calls go through [KoraApi] — domain-swappable.
/// The OpenRouter key stays server-side; the app never sees it.
class KoraAiService {
  static final KoraAiService instance = KoraAiService._();
  KoraAiService._();

  static const String _kAiHistoryPrefix = 'kora_ai_history_';
  static const String _kSupportHistoryPrefix = 'kora_support_history_';

  /// Send a message to Kora AI (general assistant).
  ///
  /// [conversationId] should be unique per conversation.
  /// [attachments] optional list of images, audio, or video frames.
  ///   - Images: sent as GPT-4o vision content (base64)
  ///   - Audio: transcript is sent (from on-device STT)
  ///   - Video frames: extracted client-side, sent as images
  Future<KoraAiResult> sendAiMessage({
    required String message,
    required String conversationId,
    List<KoraAiAttachment>? attachments,
  }) async {
    try {
      final priorHistory = await getHistory(conversationId: conversationId);
      final historyPayload = priorHistory
          .map((m) => {'isMe': m.role == 'user', 'text': m.content})
          .toList();

      final body = <String, dynamic>{
        'chatType': 'ai',
        'message': message,
        'history': historyPayload,
      };

      // Add attachments if provided
      if (attachments != null && attachments.isNotEmpty) {
        final attachmentPayload = <Map<String, dynamic>>[];
        for (final att in attachments) {
          // If file path is provided but no base64, convert it
          if (att.filePath != null && att.base64 == null) {
            try {
              final file = File(att.filePath!);
              final bytes = await file.readAsBytes();
              final base64Data = base64Encode(bytes);
              attachmentPayload.add({
                'type': att.type,
                'base64': base64Data,
                if (att.mimeType != null) 'mimeType': att.mimeType,
                if (att.transcript != null) 'transcript': att.transcript,
              });
            } catch (e) {
              debugPrint('[KoraAiService] Failed to read attachment file: $e');
            }
          } else {
            attachmentPayload.add(att.toJson());
          }
        }
        if (attachmentPayload.isNotEmpty) {
          body['attachments'] = attachmentPayload;
        }
      }

      final result = await KoraApi.postToAi(KoraApi.aiChatEndpoint, body);

      final response = result['reply'] as String? ?? '';

      if (result['success'] != true) {
        return KoraAiResult(
          success: false,
          response: response,
          error: result['error'] as String? ?? 'Unknown error',
        );
      }

      // Build display message (include attachment preview for history)
      String displayMessage = message;
      String? attachmentType;
      String? attachmentPreview;

      if (attachments != null && attachments.isNotEmpty) {
        for (final att in attachments) {
          if (att.type == 'image') {
            attachmentType = 'image';
            attachmentPreview = '[📷 Image]';
          } else if (att.type == 'audio') {
            attachmentType = 'audio';
            attachmentPreview = '[🎙️ Voice note: ${att.transcript ?? ""}]';
          } else if (att.type == 'video_frame') {
            attachmentType = 'video';
            attachmentPreview = '[🎬 Video frame]';
          }
        }
        if (attachmentPreview != null) {
          displayMessage = '$attachmentPreview $message';
        }
      }

      // Save to local history
      await _saveToHistory(
        prefix: _kAiHistoryPrefix,
        conversationId: conversationId,
        message: KoraAiMessage(
          role: 'user',
          content: displayMessage,
          attachmentType: attachmentType,
          attachmentPreview: attachmentPreview,
        ),
      );
      await _saveToHistory(
        prefix: _kAiHistoryPrefix,
        conversationId: conversationId,
        message: KoraAiMessage(role: 'assistant', content: response),
      );

      return KoraAiResult(success: true, response: response);
    } catch (e) {
      return KoraAiResult(
        success: false,
        response: '',
        error: 'Connection failed: $e',
      );
    }
  }

  /// Send a message to Kora AI Support (product support).
  Future<KoraAiResult> sendSupportMessage({
    required String message,
    required String conversationId,
    List<KoraAiAttachment>? attachments,
  }) async {
    try {
      final priorHistory = await getHistory(
        conversationId: conversationId,
        isSupport: true,
      );
      final historyPayload = priorHistory
          .map((m) => {'isMe': m.role == 'user', 'text': m.content})
          .toList();

      final body = <String, dynamic>{
        'chatType': 'support',
        'message': message,
        'history': historyPayload,
      };

      // Add attachments if provided (support can also receive screenshots)
      if (attachments != null && attachments.isNotEmpty) {
        final attachmentPayload = <Map<String, dynamic>>[];
        for (final att in attachments) {
          if (att.filePath != null && att.base64 == null) {
            try {
              final file = File(att.filePath!);
              final bytes = await file.readAsBytes();
              final base64Data = base64Encode(bytes);
              attachmentPayload.add({
                'type': att.type,
                'base64': base64Data,
                if (att.mimeType != null) 'mimeType': att.mimeType,
                if (att.transcript != null) 'transcript': att.transcript,
              });
            } catch (e) {
              debugPrint('[KoraAiService] Failed to read attachment: $e');
            }
          } else {
            attachmentPayload.add(att.toJson());
          }
        }
        if (attachmentPayload.isNotEmpty) {
          body['attachments'] = attachmentPayload;
        }
      }

      final result = await KoraApi.postToAi(KoraApi.aiSupportEndpoint, body);

      final response = result['reply'] as String? ?? '';

      if (result['success'] != true) {
        return KoraAiResult(
          success: false,
          response: response,
          error: result['error'] as String? ?? 'Unknown error',
        );
      }

      // Save to local history
      String displayMessage = message;
      if (attachments != null && attachments.isNotEmpty) {
        for (final att in attachments) {
          if (att.type == 'image') {
            displayMessage = '[📷 Image] $message';
          } else if (att.type == 'audio') {
            displayMessage = '[🎙️ Voice note] $message';
          }
        }
      }

      await _saveToHistory(
        prefix: _kSupportHistoryPrefix,
        conversationId: conversationId,
        message: KoraAiMessage(role: 'user', content: displayMessage),
      );
      await _saveToHistory(
        prefix: _kSupportHistoryPrefix,
        conversationId: conversationId,
        message: KoraAiMessage(role: 'assistant', content: response),
      );

      return KoraAiResult(success: true, response: response);
    } catch (e) {
      return KoraAiResult(
        success: false,
        response: '',
        error: 'Connection failed: $e',
      );
    }
  }

  /// Analyze an image using the koraAiFeatures backend function.
  ///
  /// [imagePath] — local file path to the image.
  /// [question] — optional question about the image.
  Future<KoraAiResult> analyzeImage({
    required String imagePath,
    String? question,
  }) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);

      final body = <String, dynamic>{
        'feature': 'analyze_media',
        'attachments': [
          {
            'type': 'image',
            'base64': base64Data,
            'mimeType': 'image/jpeg',
          }
        ],
        if (question != null) 'question': question,
      };

      final result = await KoraApi.postToAi(KoraApi.aiFeaturesEndpoint, body);

      if (result['success'] == true) {
        return KoraAiResult(
          success: true,
          response: result['result'] as String? ?? '',
        );
      }
      return KoraAiResult(
        success: false,
        response: '',
        error: result['error'] as String? ?? 'Analysis failed',
      );
    } catch (e) {
      return KoraAiResult(
        success: false,
        response: '',
        error: 'Image analysis failed: $e',
      );
    }
  }

  /// Analyze a voice note transcript.
  ///
  /// [transcript] — on-device STT transcript of the voice note.
  Future<KoraAiResult> enhanceTranscript({
    required String transcript,
  }) async {
    try {
      final body = <String, dynamic>{
        'feature': 'transcribe_audio',
        'transcript': transcript,
      };

      final result = await KoraApi.postToAi(KoraApi.aiFeaturesEndpoint, body);

      if (result['success'] == true) {
        return KoraAiResult(
          success: true,
          response: result['result'] as String? ?? transcript,
        );
      }
      // Fallback: return original transcript
      return KoraAiResult(success: true, response: transcript);
    } catch (e) {
      // Fallback: return original transcript
      return KoraAiResult(success: true, response: transcript);
    }
  }

  /// Analyze video key frames.
  ///
  /// [framePaths] — local file paths to extracted video frames.
  /// [question] — optional question about the video.
  Future<KoraAiResult> analyzeVideo({
    required List<String> framePaths,
    String? question,
  }) async {
    try {
      final attachments = <Map<String, dynamic>>[];
      for (final path in framePaths.take(5)) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          attachments.add({
            'type': 'video_frame',
            'base64': base64Encode(bytes),
            'mimeType': 'image/jpeg',
          });
        }
      }

      if (attachments.isEmpty) {
        return KoraAiResult(
          success: false,
          response: '',
          error: 'No valid video frames found',
        );
      }

      final body = <String, dynamic>{
        'feature': 'analyze_media',
        'attachments': attachments,
        if (question != null) 'question': question,
      };

      final result = await KoraApi.postToAi(KoraApi.aiFeaturesEndpoint, body);

      if (result['success'] == true) {
        return KoraAiResult(
          success: true,
          response: result['result'] as String? ?? '',
        );
      }
      return KoraAiResult(
        success: false,
        response: '',
        error: result['error'] as String? ?? 'Analysis failed',
      );
    } catch (e) {
      return KoraAiResult(
        success: false,
        response: '',
        error: 'Video analysis failed: $e',
      );
    }
  }

  /// Get conversation history for a given conversation.
  Future<List<KoraAiMessage>> getHistory({
    required String conversationId,
    bool isSupport = false,
  }) async {
    final prefix = isSupport ? _kSupportHistoryPrefix : _kAiHistoryPrefix;
    final prefs = await SharedPreferences.getInstance();
    final key = '$prefix$conversationId';
    final json = prefs.getString(key);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => KoraAiMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Clear conversation history.
  Future<void> clearConversation({
    required String conversationId,
    bool isSupport = false,
  }) async {
    final prefix = isSupport ? _kSupportHistoryPrefix : _kAiHistoryPrefix;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$prefix$conversationId');
  }

  /// Save a message to local history.
  Future<void> _saveToHistory({
    required String prefix,
    required String conversationId,
    required KoraAiMessage message,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$prefix$conversationId';
    final json = prefs.getString(key);

    List<KoraAiMessage> history = [];
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        history = list
            .map((e) => KoraAiMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    history.add(message);

    // Keep only last 50 messages locally
    if (history.length > 50) {
      history = history.sublist(history.length - 50);
    }

    await prefs.setString(
      key,
      jsonEncode(history.map((m) => m.toJson()).toList()),
    );
  }

  /// Generate a unique conversation ID.
  String generateConversationId({bool isSupport = false}) {
    final prefix = isSupport ? 'support' : 'ai';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_$timestamp';
  }
}
