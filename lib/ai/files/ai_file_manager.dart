import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../config/kora_api.dart';
import '../model/ai_response.dart';

/// File processing pipeline for AI analysis.
/// Validates files, uploads securely, and processes with AI.
class AIFileManager {
  static const supportedTypes = ['pdf', 'txt', 'doc', 'docx', 'csv', 'json', 'png', 'jpg', 'jpeg'];
  static const maxFileSize = 20 * 1024 * 1024; // 20MB

  final http.Client _client = http.Client();

  /// Validate a file before processing.
  Future<bool> validateFile(String path, [int? maxSize]) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      final stat = await file.stat();
      final sizeLimit = maxSize ?? maxFileSize;
      if (stat.size > sizeLimit) return false;
      final ext = path.split('.').last.toLowerCase();
      return supportedTypes.contains(ext);
    } catch (_) { return false; }
  }

  /// Analyze a file with AI — ask questions about its content.
  Future<AIResponse> analyzeFile({required String filePath, required String query}) async {
    try {
      final valid = await validateFile(filePath);
      if (!valid) return AIResponse(success: false, content: '', error: 'Unsupported file type or size');

      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final ext = filePath.split('.').last.toLowerCase();
      final isImage = ['png', 'jpg', 'jpeg'].contains(ext);

      final body = <String, dynamic>{
        'intent': isImage ? 'image_understanding' : 'file_analysis',
        'message': query,
        'stream': false,
      };

      if (isImage) {
        body['attachments'] = [{'type': 'image', 'base64': base64Encode(bytes), 'mimeType': 'image/$ext'}];
      } else {
        // For text files, extract content
        final textContent = _extractTextContent(bytes, ext);
        body['message'] = '$query\n\nFile content:\n$textContent';
      }

      final response = await _client.post(
        Uri.parse(KoraApi.aiOrchestratorEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) return AIResponse.fromJson(jsonDecode(response.body));
      return AIResponse(success: false, content: '', error: 'Server error: ${response.statusCode}');
    } catch (e) {
      return AIResponse(success: false, content: '', error: e.toString());
    }
  }

  /// Summarize a document.
  Future<AIResponse> summarizeDocument({required String filePath}) async {
    return analyzeFile(filePath: filePath, query: 'Summarize this document concisely.');
  }

  /// Extract text from a file.
  Future<AIResponse> extractText({required String filePath}) async {
    return analyzeFile(filePath: filePath, query: 'Extract all text content from this file.');
  }

  String _extractTextContent(List<int> bytes, String ext) {
    try {
      if (['txt', 'csv', 'json'].contains(ext)) {
        return utf8.decode(bytes, allowMalformed: true);
      }
      // For binary formats (pdf, doc, docx), send as base64
      return '[Binary file — ${bytes.length} bytes, type: $ext]';
    } catch (_) { return '[Could not extract text]'; }
  }

  void dispose() { _client.close(); }
}
