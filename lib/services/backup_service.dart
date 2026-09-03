import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'message_service.dart';

/// WhatsApp-style local chat backup & restore service.
///
/// A backup is a single `.korabak` file (plus a `_media` folder when the
/// backup includes media) written under <app-docs>/KoraBackups/.
///
/// File format (encrypted):
///   magic "KORABAK1" (8B) | salt (16B) | nonce (12B) | mac (16B) | ciphertext
/// Key derivation: PBKDF2-HMAC-SHA256(password, salt, 100k iters, 256-bit).
///
/// File format (unencrypted):
///   magic "KORABAK0" (8B) | UTF-8 JSON payload
///
/// The payload contains every `kora_msgs_*` chat history plus the blocked-chat
/// flags, a media manifest and metadata. Restore writes the histories straight
/// back into SharedPreferences and copies media files back to their original
/// paths.
class BackupMetadata {
  final String id;
  final DateTime createdAt;
  final int sizeBytes;
  final int chatCount;
  final int messageCount;
  final bool encrypted;
  final bool includeVideos;
  final bool hasMedia;

  const BackupMetadata({
    required this.id,
    required this.createdAt,
    required this.sizeBytes,
    this.chatCount = 0,
    this.messageCount = 0,
    required this.encrypted,
    required this.includeVideos,
    required this.hasMedia,
  });

  String get formattedSize {
    final kb = sizeBytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024.0).toStringAsFixed(1)} MB';
  }
}

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  static const _dirName = 'KoraBackups';
  static const _magicEncrypted = 'KORABAK1';
  static const _magicPlain = 'KORABAK0';
  static const _msgPrefix = 'kora_msgs_';
  static const _blockedPrefix = 'kora_blocked_';
  static const _pinPref = 'kora_backup_pin';
  static const _lastBackupPref = 'kora_backup_last_date';
  static const _keepCount = 5;

  static const _videoExtensions = ['.mp4', '.mov', '.mkv', '.avi', '.3gp', '.webm'];

  /// Returns the stored backup password (used for auto-backup and
  /// same-device restore), or null when none has been set.
  Future<String?> getStoredPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinPref);
  }

  Future<void> setBackupPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinPref, pin);
  }

  Future<bool> get hasStoredPin async => await getStoredPin() != null;

  Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Create backup ────────────────────────────────────────

  /// Creates a real local backup of every chat history.
  ///
  /// [pin] is required when [encrypt] is true. Media files (images, voice
  /// notes, documents, thumbnails) are always copied; videos only when
  /// [includeVideos] is true.
  Future<BackupMetadata> createBackup({
    String? pin,
    bool includeVideos = false,
    bool encrypt = true,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (encrypt && (pin == null || pin.isEmpty)) {
      throw ArgumentError('A backup password is required for encrypted backups');
    }

    onProgress?.call(0.02, 'Reading chat history…');
    final prefs = await SharedPreferences.getInstance();

    // 1. Collect every chat history + blocked flags.
    final chats = <String, List<dynamic>>{};
    final blocked = <String>[];
    int messageCount = 0;
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_msgPrefix)) {
        final raw = prefs.getString(key);
        if (raw == null || raw.isEmpty) continue;
        final chatId = key.substring(_msgPrefix.length);
        final messages = jsonDecode(raw) as List<dynamic>;
        if (messages.isEmpty) continue;
        chats[chatId] = messages;
        messageCount += messages.length;
      } else if (key.startsWith(_blockedPrefix)) {
        if (prefs.getBool(key) ?? false) {
          blocked.add(key.substring(_blockedPrefix.length));
        }
      }
    }
    if (chats.isEmpty) {
      throw StateError('Nothing to back up — no chat history found');
    }

    onProgress?.call(0.2, 'Reading media files…');
    // 2. Copy media files into the backup folder.
    final stamp = _timestamp();
    final mediaDirName = 'kora_backup_${stamp}_media';
    final media = <Map<String, dynamic>>[];
    final dir = await _backupDir();
    final mediaDir = Directory('${dir.path}/$mediaDirName');
    if (!await mediaDir.exists()) await mediaDir.create(recursive: true);

    final copiedFiles = <String>{}; // original paths already copied
    for (final entry in chats.entries) {
      for (final rawMsg in entry.value) {
        final msg = rawMsg as Map<String, dynamic>;
        final isVideo = _isVideoMessage(msg);
        for (final field in ['mediaPath', 'voiceFilePath', 'mediaThumbnailPath']) {
          final path = msg[field] as String?;
          if (path == null || path.isEmpty || copiedFiles.contains(path)) continue;
          final file = File(path);
          if (!await file.exists()) continue;
          if (isVideo && !includeVideos && field == 'mediaPath') continue;
          final name = await _copyInto(mediaDir, file);
          copiedFiles.add(path);
          media.add({'path': path, 'rel': '$mediaDirName/$name'});
        }
      }
    }
    final hasMedia = media.isNotEmpty;

    onProgress?.call(0.6, hasMedia ? 'Packing ${media.length} media files…' : 'Building backup file…');
    // 3. Build the payload.
    final payload = jsonEncode({
      'format': 'kora-backup',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'chats': chats,
      'blocked': blocked,
      'media': media,
    });

    // 4. Encrypt (optional) and write.
    Uint8List bytes;
    bool encrypted = false;
    if (encrypt) {
      onProgress?.call(0.78, 'Encrypting backup…');
      bytes = await _encryptPayload(payload, pin!);
      encrypted = true;
    } else {
      bytes = Uint8List.fromList(utf8.encode(payload));
    }

    onProgress?.call(0.9, 'Writing backup file…');
    final fileName = 'kora_backup_$stamp.korabak';
    final outFile = File('${dir.path}/$fileName');
    await outFile.writeAsBytes(bytes, flush: true);

    // 5. Prune old backups (keep the newest [_keepCount]).
    await _pruneOldBackups();

    final meta = BackupMetadata(
      id: fileName,
      createdAt: DateTime.now(),
      sizeBytes: bytes.length,
      chatCount: chats.length,
      messageCount: messageCount,
      encrypted: encrypted,
      includeVideos: includeVideos,
      hasMedia: hasMedia,
    );

    // 6. Update the "last backup" info shown in Settings.
    await prefs.setString(_lastBackupPref, meta.createdAt.toIso8601String());
    await prefs.setString('kora_backup_last_size', meta.formattedSize);
    await prefs.setInt('kora_backup_last_messages', meta.messageCount);

    onProgress?.call(1.0, 'Backup complete');
    return meta;
  }

  bool _isVideoMessage(Map<String, dynamic> msg) {
    final type = msg['type'];
    if (type == 'video' || type == 'KoraMessageType.video') return true;
    final mediaPath = msg['mediaPath'] as String? ?? '';
    return _videoExtensions.any((e) => mediaPath.toLowerCase().endsWith(e));
  }

  Future<String> _copyInto(Directory mediaDir, File file) async {
    final ext = file.path.contains('.') ? file.path.substring(file.path.lastIndexOf('.')) : '';
    final name = '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 31)}$ext';
    await file.copy('${mediaDir.path}/$name');
    return name;
  }

  Future<Uint8List> _encryptPayload(String payload, String pin) async {
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);
    final key = await pbkdf2.deriveKey(secretKey: SecretKey(utf8.encode(pin)), nonce: salt);
    final aes = AesGcm.with256bits();
    final clear = utf8.encode(payload);
    final box = await aes.encrypt(clear, secretKey: key);

    final out = BytesBuilder();
    out.add(utf8.encode(_magicEncrypted));
    out.add(salt);
    out.add(box.nonce);
    out.add(box.mac.bytes);
    out.add(box.cipherText);
    return out.toBytes();
  }

  // ── List / delete ────────────────────────────────────────

  Future<List<BackupMetadata>> listBackups() async {
    final dir = await _backupDir();
    final entries = await dir.list().toList();
    final backups = <BackupMetadata>[];
    for (final f in entries) {
      if (f is! File || !f.path.endsWith('.korabak')) continue;
      final name = f.path.split(Platform.pathSeparator).last;
      final stamp = name.replaceAll('kora_backup_', '').replaceAll('.korabak', '');
      final created = DateTime.tryParse(_stampToIso(stamp)) ?? (await f.stat()).changed;
      final bytes = await f.length();
      final first8 = await _readMagic(f);
      backups.add(BackupMetadata(
        id: name,
        createdAt: created,
        sizeBytes: bytes,
        encrypted: first8 == _magicEncrypted,
        includeVideos: false,
        hasMedia: await Directory(f.path.replaceAll('.korabak', '_media')).exists(),
      ));
    }
    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  Future<String> _readMagic(File f) async {
    final raf = await f.open();
    try {
      final bytes = await raf.read(8);
      return String.fromCharCodes(bytes);
    } finally {
      await raf.close();
    }
  }

  Future<void> deleteBackup(BackupMetadata meta) async {
    final dir = await _backupDir();
    final file = File('${dir.path}/${meta.id}');
    if (await file.exists()) await file.delete();
    final mediaDir = Directory(file.path.replaceAll('.korabak', '_media'));
    if (await mediaDir.exists()) await mediaDir.delete(recursive: true);
  }

  Future<void> _pruneOldBackups() async {
    final backups = await listBackups();
    for (final meta in backups.skip(_keepCount)) {
      await deleteBackup(meta);
    }
  }

  // ── Restore ──────────────────────────────────────────────

  /// Restores chat histories from a `.korabak` file.
  ///
  /// When [pin] is null the stored backup password is used; encrypted files
  /// without any available password fail with a [StateError].
  Future<bool> restoreBackup(BackupMetadata meta, {
    String? pin,
    void Function(double progress, String status)? onProgress,
  }) async {
    final dir = await _backupDir();
    return restoreFromFile('${dir.path}/${meta.id}', pin: pin, onProgress: onProgress);
  }

  Future<bool> restoreFromFile(String path, {
    String? pin,
    void Function(double progress, String status)? onProgress,
  }) async {
    final file = File(path);
    if (!await file.exists()) throw StateError('Backup file not found');
    final bytes = await file.readAsBytes();

    onProgress?.call(0.1, 'Opening backup…');
    final magic = String.fromCharCodes(bytes.take(8));
    String payload;
    if (magic == _magicEncrypted) {
      final effectivePin = pin ?? await getStoredPin();
      if (effectivePin == null) {
        throw StateError('This backup is encrypted — enter its password to restore');
      }
      onProgress?.call(0.25, 'Decrypting backup…');
      payload = await _decryptPayload(bytes, effectivePin);
    } else if (magic == _magicPlain) {
      payload = utf8.decode(bytes.sublist(8));
    } else {
      throw StateError('Not a Kora backup file');
    }

    onProgress?.call(0.4, 'Restoring chats…');
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final chats = (data['chats'] as Map<String, dynamic>?) ?? {};
    final blocked = (data['blocked'] as List?) ?? [];
    final media = (data['media'] as List?) ?? [];

    final prefs = await SharedPreferences.getInstance();
    int restored = 0;
    for (final entry in chats.entries) {
      await prefs.setString('$_msgPrefix${entry.key}', jsonEncode(entry.value));
      restored++;
    }
    for (final chatId in blocked) {
      await prefs.setBool('$_blockedPrefix$chatId', true);
    }

    onProgress?.call(0.7, 'Restoring media…');
    final backupParent = file.parent.path;
    int mediaRestored = 0;
    for (final entry in media) {
      final m = entry as Map<String, dynamic>;
      // rel is "<mediaDirName>/<file>" — resolve against the backup's folder
      final src = File('$backupParent/${m['rel']}');
      if (!await src.exists()) continue;
      final originalPath = m['path'] as String;
      final originalDir = File(originalPath).parent;
      if (!await originalDir.exists()) await originalDir.create(recursive: true);
      await src.copy(originalPath);
      mediaRestored++;
    }

    // Drop the in-memory message cache so the restored history is re-read.
    MessageService.instance.invalidateCache();

    onProgress?.call(1.0, 'Restored $restored chats${mediaRestored > 0 ? ', $mediaRestored media files' : ''}');
    return true;
  }

  Future<String> _decryptPayload(Uint8List bytes, String pin) async {
    final salt = bytes.sublist(8, 24);
    final nonce = bytes.sublist(24, 36);
    final mac = bytes.sublist(36, 52);
    final cipherText = bytes.sublist(52);
    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);
    final key = await pbkdf2.deriveKey(secretKey: SecretKey(utf8.encode(pin)), nonce: salt);
    final aes = AesGcm.with256bits();
    try {
      final clear = await aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw StateError('Wrong password — could not decrypt this backup');
    }
  }

  // ── Auto backup ──────────────────────────────────────────

  /// Runs a backup automatically when the configured cadence has elapsed.
  ///
  /// Called at app start; reads the user's frequency + network preferences
  /// and silently creates a backup when due.
  Future<void> maybeRunAutoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final frequency = prefs.getString('kora_backup_frequency') ?? 'Weekly';
      final interval = _frequencyToInterval(frequency);
      if (interval == null) return; // Never / Off

      final lastTs = prefs.getString(_lastBackupPref);
      if (lastTs != null) {
        final last = DateTime.tryParse(lastTs);
        if (last != null && DateTime.now().difference(last) < interval) return;
      }

      final network = prefs.getString('kora_backup_network') ?? 'Wi-Fi only';
      if (network == 'Wi-Fi only') {
        final results = await Connectivity().checkConnectivity();
        if (!results.contains(ConnectivityResult.wifi)) return;
      }

      final includeVideos = prefs.getBool('kora_backup_videos') ?? false;
      final encrypt = prefs.getBool('kora_backup_encrypt') ?? true;
      final pin = await getStoredPin();
      if (encrypt && pin == null) return; // no password set yet — skip
      await createBackup(
        pin: pin,
        includeVideos: includeVideos,
        encrypt: encrypt,
      );
    } catch (_) {
      // Auto backup must never crash the app.
      if (kDebugMode) rethrow;
    }
  }

  Duration? _frequencyToInterval(String frequency) {
    switch (frequency) {
      case 'Daily':
        return const Duration(days: 1);
      case 'Weekly':
        return const Duration(days: 7);
      case 'Monthly':
        return const Duration(days: 30);
      default:
        return null; // Never / Off
    }
  }

  // ── Helpers ──────────────────────────────────────────────

  String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  String _stampToIso(String stamp) {
    // 20260903_055301 -> 2026-09-03T05:53:01
    if (stamp.length < 15) return '';
    final y = stamp.substring(0, 4);
    final mo = stamp.substring(4, 6);
    final d = stamp.substring(6, 8);
    final h = stamp.substring(9, 11);
    final mi = stamp.substring(11, 13);
    final s = stamp.substring(13, 15);
    return '$y-$mo-${d}T$h:$mi:$s';
  }
}
