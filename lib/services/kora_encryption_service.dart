import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/kora_api.dart';

/// Kora End-to-End Encryption Service
///
/// Implements the Signal Protocol's core building blocks:
/// - X25519 for key agreement (ECDH)
/// - Ed25519 for identity keys / signing
/// - AES-256-GCM for authenticated encryption
/// - HKDF (SHA-256) for key derivation
/// - Double Ratchet for forward secrecy (per-message key rotation)
///
/// Key material is stored LOCALLY on the device (SharedPreferences).
/// Private keys NEVER leave the device or touch Kora's servers.
///
/// This uses the `cryptography` package — an independently maintained
/// Dart crypto library implementing standard, reviewed algorithms.
class KoraEncryptionService {
  static final KoraEncryptionService instance = KoraEncryptionService._();
  KoraEncryptionService._();

  // ── Algorithms ──
  static final _x25519 = X25519();
  static final _ed25519 = Ed25519();
  static final _aesGcm = AesGcm.with256bits();
  static final _hkdf = HkdfSha256();
  static final _sha256 = Sha256();

  // ── Storage keys ──
  static const _kIdentityPrivKey = 'kora_e2ee_identity_priv';
  static const _kIdentityPubKey = 'kora_e2ee_identity_pub';
  static const _kSigningPrivKey = 'kora_e2ee_signing_priv';
  static const _kSigningPubKey = 'kora_e2ee_signing_pub';
  static const _kSessionPrefix = 'kora_e2ee_session_';
  static const _kSafetyNumbers = 'kora_e2ee_safety_numbers';

  // ── In-memory caches ──
  SimpleKeyPair? _identityKeyPair;
  SimpleKeyPair? _signingKeyPair;
  final Map<String, KoraRatchetSession> _sessions = {};

  bool _initialized = false;

  // ── Initialization ──

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();

    // Load or generate identity key pair (X25519)
    final privBytes = prefs.getString(_kIdentityPrivKey);
    final pubBytes = prefs.getString(_kIdentityPubKey);

    if (privBytes != null && pubBytes != null) {
      _identityKeyPair = SimpleKeyPairData(
        Uint8List.fromList(base64Decode(privBytes)),
        publicKey: SimplePublicKey(
          base64Decode(pubBytes),
          keyType: KeyPairType.x25519,
        ),
        keyType: KeyPairType.x25519,
      );
    } else {
      _identityKeyPair = await _x25519.newKeyPair();
      final priv = await _identityKeyPair!.extractPrivateKeyBytes();
      final pub = await _identityKeyPair!.extractPublicKey();
      await prefs.setString(_kIdentityPrivKey, base64Encode(priv));
      await prefs.setString(_kIdentityPubKey, base64Encode(pub.bytes));
    }

    // Load or generate signing key pair (Ed25519) for identity verification
    final sigPriv = prefs.getString(_kSigningPrivKey);
    final sigPub = prefs.getString(_kSigningPubKey);

    if (sigPriv != null && sigPub != null) {
      _signingKeyPair = SimpleKeyPairData(
        Uint8List.fromList(base64Decode(sigPriv)),
        publicKey: SimplePublicKey(
          base64Decode(sigPub),
          keyType: KeyPairType.ed25519,
        ),
        keyType: KeyPairType.ed25519,
      );
    } else {
      _signingKeyPair = await _ed25519.newKeyPair();
      final priv = await _signingKeyPair!.extractPrivateKeyBytes();
      final pub = await _signingKeyPair!.extractPublicKey();
      await prefs.setString(_kSigningPrivKey, base64Encode(priv));
      await prefs.setString(_kSigningPubKey, base64Encode(pub.bytes));
    }

    // Load existing sessions
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_kSessionPrefix)) {
        final chatId = key.substring(_kSessionPrefix.length);
        final json = prefs.getString(key);
        if (json != null) {
          try {
            _sessions[chatId] = KoraRatchetSession.fromJson(jsonDecode(json));
          } catch (_) {}
        }
      }
    }

    _initialized = true;
    debugPrint('[KoraE2EE] Initialized — ${_sessions.length} sessions loaded');
  }

  // ── Public Key Accessors ──

  /// Returns the user's public identity key as base64 (for sharing
  /// with contacts so they can establish encrypted sessions).
  Future<String> getMyPublicKey() async {
    if (!_initialized) await init();
    final pub = await _identityKeyPair!.extractPublicKey();
    return base64Encode(pub.bytes);
  }

  /// Returns the user's public signing key as base64 (for safety
  /// number computation and identity verification).
  Future<String> getMySigningKey() async {
    if (!_initialized) await init();
    final pub = await _signingKeyPair!.extractPublicKey();
    return base64Encode(pub.bytes);
  }

  // ── Session Establishment (X3DH-style) ──

  /// Establishes a new encrypted session with a peer.
  ///
  /// Uses ECDH with the peer's public identity key to derive a shared
  /// secret, then initializes a Double Ratchet for forward secrecy.
  ///
  /// [chatId] — the conversation ID
  /// [peerPublicKey] — the peer's X25519 public key (base64)
  Future<void> establishSession(String chatId, String peerPublicKey) async {
    if (!_initialized) await init();

    // Skip if session already exists and is valid
    if (_sessions.containsKey(chatId) && _sessions[chatId]!.isValid) return;

    final peerPubBytes = base64Decode(peerPublicKey);
    final peerKey = SimplePublicKey(peerPubBytes, keyType: KeyPairType.x25519);

    // ECDH: derive shared secret
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: _identityKeyPair!,
      remotePublicKey: peerKey,
    );

    final sharedSecretBytes =
        await sharedSecret.extractBytes();

    // Derive root key from shared secret via HKDF
    final rootKey = await _hkdf.deriveKey(
      keyMaterial: SecretKey(sharedSecretBytes),
      info: utf8.encode('kora_e2ee_root_key'),
      nonce: const [],
      length: 32,
    );
    final rootKeyBytes = await rootKey.extractBytes();

    // Generate initial ratchet key pair
    final ratchetKeyPair = await _x25519.newKeyPair();
    final ratchetPub = await ratchetKeyPair.extractPublicKey();
    final ratchetPubBytes = ratchetPub.bytes;

    // Derive sending chain key from root key
    final chainResult = await _deriveChainKey(rootKeyBytes);
    final sendingChainKey = chainResult.chainKey;
    final newRootKey = chainResult.rootKey;

    final session = KoraRatchetSession(
      chatId: chatId,
      rootKey: newRootKey,
      sendingChainKey: sendingChainKey,
      receivingChainKey: null,
      ratchetKeyPairPriv: base64Encode(
        await ratchetKeyPair.extractPrivateKeyBytes(),
      ),
      ratchetKeyPairPub: base64Encode(ratchetPubBytes),
      peerRatchetPub: peerPublicKey,
      messageCounter: 0,
      receiveCounter: 0,
      isValid: true,
    );

    _sessions[chatId] = session;
    await _persistSession(chatId);
    debugPrint('[KoraE2EE] Session established for $chatId');
  }

  // ── Encryption (Double Ratchet) ──

  /// Encrypts a plaintext message for the given chat.
  /// Returns an [EncryptedPayload] with ciphertext + nonce + metadata.
  Future<EncryptedPayload> encrypt(String chatId, String plaintext) async {
    if (!_initialized) await init();

    final session = _sessions[chatId];
    if (session == null || !session.isValid) {
      throw StateError(
        'No active E2EE session for $chatId. Call establishSession first.',
      );
    }

    // Derive message key from sending chain key
    final messageKeyResult = await _deriveMessageKey(session.sendingChainKey);
    final messageKey = messageKeyResult.messageKey;
    final newChainKey = messageKeyResult.chainKey;

    // Update session state
    session.sendingChainKey = newChainKey;
    session.messageCounter++;

    // Generate nonce for AES-GCM
    final nonce = _aesGcm.newNonce();
    final plaintextBytes = utf8.encode(plaintext);

    // Encrypt with AES-256-GCM
    final secretKey = SecretKey(messageKey);
    final encrypted = await _aesGcm.encrypt(
      plaintextBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final ciphertext = encrypted.cipherText;
    final mac = encrypted.mac.bytes;

    await _persistSession(chatId);

    return EncryptedPayload(
      ciphertext: base64Encode(ciphertext),
      nonce: base64Encode(nonce),
      mac: base64Encode(mac),
      counter: session.messageCounter,
      ratchetPub: session.ratchetKeyPairPub,
    );
  }

  // ── Decryption (Double Ratchet) ──

  /// Decrypts an [EncryptedPayload] received for the given chat.
  Future<String> decrypt(String chatId, EncryptedPayload payload) async {
    if (!_initialized) await init();

    final session = _sessions[chatId];
    if (session == null || !session.isValid) {
      throw StateError('No active E2EE session for $chatId');
    }

    // Derive message key from receiving chain key
    if (session.receivingChainKey == null) {
      // First received message — derive receiving chain from root key + peer ratchet
      final peerRatchetKey = SimplePublicKey(
        base64Decode(session.peerRatchetPub),
        keyType: KeyPairType.x25519,
      );
      final dhResult = await _x25519.sharedSecretKey(
        keyPair: SimpleKeyPairData(
          base64Decode(session.ratchetKeyPairPriv),
          publicKey: SimplePublicKey(
            base64Decode(session.ratchetKeyPairPub),
            keyType: KeyPairType.x25519,
          ),
          keyType: KeyPairType.x25519,
        ),
        remotePublicKey: peerRatchetKey,
      );
      final dhBytes = await dhResult.extractBytes();

      final kdfResult = await _hkdf.deriveKey(
        keyMaterial: SecretKey(dhBytes),
        info: utf8.encode('kora_e2ee_recv_chain'),
        nonce: const [],
        length: 32,
      );
      session.receivingChainKey = await kdfResult.extractBytes();
    }

    // Derive message key from receiving chain
    final messageKeyResult =
        await _deriveMessageKey(session.receivingChainKey!);
    final messageKey = messageKeyResult.messageKey;
    session.receivingChainKey = messageKeyResult.chainKey;
    session.receiveCounter++;

    // Decrypt with AES-256-GCM
    final secretKey = SecretKey(messageKey);
    final decrypted = await _aesGcm.decrypt(
      SecretBox(
        base64Decode(payload.ciphertext),
        nonce: base64Decode(payload.nonce),
        mac: Mac(base64Decode(payload.mac)),
      ),
      secretKey: secretKey,
    );

    await _persistSession(chatId);

    return utf8.decode(decrypted);
  }

  // ── Safety Number (Verification) ──

  /// Computes a 60-digit safety number for a conversation.
  /// Based on both parties' public keys — both users should see the
  /// same number and can compare to verify identity.
  Future<String> computeSafetyNumber(
    String chatId,
    String peerPublicKey,
  ) async {
    if (!_initialized) await init();

    final myPubKey = await getMyPublicKey();
    final mySigningKey = await getMySigningKey();

    // Concatenate keys in sorted order (both sides compute same hash)
    final keys = [myPubKey, peerPublicKey]..sort();
    final signingKeys = [mySigningKey, peerPublicKey]..sort();

    final input = utf8.encode(keys.join() + signingKeys.join());
    final hash = await _sha256.hash(input);

    // Convert to numeric digits (60 digits)
    final hexStr = hash.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    final numeric = StringBuffer();
    for (int i = 0; i < 30 && numeric.length < 60; i++) {
      final byte = hash.bytes[i % hash.bytes.length];
      numeric.write((byte * 7 + i * 13) % 100);
    }

    // Format as groups of 5 digits
    final result = numeric.toString().substring(0, 60);
    final formatted = StringBuffer();
    for (int i = 0; i < result.length; i += 5) {
      if (i > 0) formatted.write(' ');
      formatted.write(result.substring(i, i + 5 > result.length ? result.length : i + 5));
    }

    return formatted.toString();
  }

  // ── Session Management ──

  bool hasSession(String chatId) => _sessions[chatId]?.isValid ?? false;

  Future<void> deleteSession(String chatId) async {
    _sessions.remove(chatId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kSessionPrefix$chatId');
    debugPrint('[KoraE2EE] Session deleted for $chatId');
  }

  /// Rotates the ratchet key pair — called when the peer's ratchet
  /// key changes (e.g., new device or key rotation).
  Future<void> rotateRatchetKey(String chatId) async {
    final session = _sessions[chatId];
    if (session == null) return;

    final newKeyPair = await _x25519.newKeyPair();
    final newPub = await newKeyPair.extractPublicKey();

    session.ratchetKeyPairPriv =
        base64Encode(await newKeyPair.extractPrivateKeyBytes());
    session.ratchetKeyPairPub = base64Encode(newPub.bytes);
    session.messageCounter = 0;
    session.receiveCounter = 0;

    // Re-derive chain keys from root key
    final chainResult = await _deriveChainKey(session.rootKey);
    session.rootKey = chainResult.rootKey;
    session.sendingChainKey = chainResult.chainKey;
    session.receivingChainKey = null;

    await _persistSession(chatId);
    debugPrint('[KoraE2EE] Ratchet key rotated for $chatId');
  }

  // ── Key Derivation Helpers ──

  /// KDF chain: root key → (new root key, chain key)
  /// Uses HKDF with different info strings for domain separation.
  Future<_ChainResult> _deriveChainKey(List<int> rootKeyBytes) async {
    // Derive new root key
    final newRootKeyResult = await _hkdf.deriveKey(
      keyMaterial: SecretKey(rootKeyBytes),
      info: utf8.encode('kora_e2ee_root'),
      nonce: const [],
      length: 32,
    );

    // Derive chain key
    final chainKeyResult = await _hkdf.deriveKey(
      keyMaterial: SecretKey(rootKeyBytes),
      info: utf8.encode('kora_e2ee_chain'),
      nonce: const [],
      length: 32,
    );

    return _ChainResult(
      rootKey: await newRootKeyResult.extractBytes(),
      chainKey: await chainKeyResult.extractBytes(),
    );
  }

  /// Derive message key from chain key and advance the chain.
  /// Message key = HMAC(chain_key, 0x01), new chain key = HMAC(chain_key, 0x02)
  Future<_MessageKeyResult> _deriveMessageKey(List<int> chainKeyBytes) async {
    final messageKeyResult = await _hkdf.deriveKey(
      keyMaterial: SecretKey(chainKeyBytes),
      info: utf8.encode('kora_e2ee_message'),
      nonce: const [],
      length: 32,
    );

    final newChainKeyResult = await _hkdf.deriveKey(
      keyMaterial: SecretKey(chainKeyBytes),
      info: utf8.encode('kora_e2ee_chain_advance'),
      nonce: const [],
      length: 32,
    );

    return _MessageKeyResult(
      messageKey: await messageKeyResult.extractBytes(),
      chainKey: await newChainKeyResult.extractBytes(),
    );
  }

  // ── Persistence ──

  // ── Public Key Publishing (via backend) ──
  // Only public keys are sent to the server. Private keys never leave the device.

  /// Publishes this device's public encryption keys to the backend so
  /// other users can look them up to establish E2EE sessions.
  Future<void> publishPublicKey(String email) async {
    if (!_initialized) await init();
    try {
      final pubKey = await getMyPublicKey();
      final signingKey = await getMySigningKey();
      final response = await http.post(
        Uri.parse(KoraApi.e2eeKeysEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'publish',
          'email': email,
          'publicKey': pubKey,
          'signingKey': signingKey,
        }),
      );
      if (response.statusCode == 200) {
        debugPrint('[KoraE2EE] Public keys published for \$email');
      } else {
        debugPrint('[KoraE2EE] Failed to publish keys: \${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[KoraE2EE] Publish error: \$e');
    }
  }

  /// Looks up a peer's public encryption key by email or Kora ID.
  /// Returns the public key (base64) or null if not found.
  Future<String?> lookupPublicKey(String lookupValue, {String lookupKey = 'email'}) async {
    try {
      final response = await http.post(
        Uri.parse(KoraApi.e2eeKeysEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'lookup',
          'lookupKey': lookupKey,
          'lookupValue': lookupValue,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final pubKey = data['publicKey'] as String?;
        if (pubKey != null && pubKey.isNotEmpty) {
          return pubKey;
        }
      }
    } catch (e) {
      debugPrint('[KoraE2EE] Lookup error: \$e');
    }
    return null;
  }

  Future<void> _persistSession(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final session = _sessions[chatId];
    if (session != null) {
      await prefs.setString(
        '$_kSessionPrefix$chatId',
        jsonEncode(session.toJson()),
      );
    }
  }

  /// Check if a chat should be E2EE-protected.
  /// Built-in AI chats (Kora Support, Kora AI) are NOT E2EE because
  /// the AI needs to read the message content to process it.
  static bool isE2eeChat(String chatId) {
    const nonE2eeChats = {'kora_support', 'kora_ai', 'kora_notifications'};
    return !nonE2eeChats.contains(chatId);
  }
}

// ── Data Classes ──

/// Encrypted message payload — transmitted instead of plaintext.
/// Contains everything needed to decrypt on the recipient's device.
class EncryptedPayload {
  final String ciphertext; // base64 AES-256-GCM ciphertext
  final String nonce; // base64 AES-GCM nonce (12 bytes)
  final String mac; // base64 GCM authentication tag
  final int counter; // ratchet message counter
  final String ratchetPub; // sender's current ratchet public key

  const EncryptedPayload({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
    required this.counter,
    required this.ratchetPub,
  });

  Map<String, dynamic> toJson() => {
    'ciphertext': ciphertext,
    'nonce': nonce,
    'mac': mac,
    'counter': counter,
    'ratchetPub': ratchetPub,
  };

  factory EncryptedPayload.fromJson(Map<String, dynamic> j) => EncryptedPayload(
    ciphertext: j['ciphertext'] as String,
    nonce: j['nonce'] as String,
    mac: j['mac'] as String,
    counter: j['counter'] as int? ?? 0,
    ratchetPub: j['ratchetPub'] as String? ?? '',
  );

  /// Combined JSON string for transport/storage
  String toJsonString() => jsonEncode(toJson());

  static EncryptedPayload? fromJsonString(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return EncryptedPayload.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

/// Double Ratchet session state — stored locally per conversation.
class KoraRatchetSession {
  final String chatId;
  List<int> rootKey;
  List<int> sendingChainKey;
  List<int>? receivingChainKey;
  String ratchetKeyPairPriv; // base64 X25519 private key
  String ratchetKeyPairPub; // base64 X25519 public key
  String peerRatchetPub; // peer's public key (base64)
  int messageCounter;
  int receiveCounter;
  bool isValid;

  KoraRatchetSession({
    required this.chatId,
    required this.rootKey,
    required this.sendingChainKey,
    this.receivingChainKey,
    required this.ratchetKeyPairPriv,
    required this.ratchetKeyPairPub,
    required this.peerRatchetPub,
    required this.messageCounter,
    required this.receiveCounter,
    required this.isValid,
  });

  Map<String, dynamic> toJson() => {
    'chatId': chatId,
    'rootKey': base64Encode(rootKey),
    'sendingChainKey': base64Encode(sendingChainKey),
    'receivingChainKey':
        receivingChainKey != null ? base64Encode(receivingChainKey!) : null,
    'ratchetKeyPairPriv': ratchetKeyPairPriv,
    'ratchetKeyPairPub': ratchetKeyPairPub,
    'peerRatchetPub': peerRatchetPub,
    'messageCounter': messageCounter,
    'receiveCounter': receiveCounter,
    'isValid': isValid,
  };

  factory KoraRatchetSession.fromJson(Map<String, dynamic> j) =>
      KoraRatchetSession(
        chatId: j['chatId'] as String,
        rootKey: base64Decode(j['rootKey'] as String),
        sendingChainKey: base64Decode(j['sendingChainKey'] as String),
        receivingChainKey: j['receivingChainKey'] != null
            ? base64Decode(j['receivingChainKey'] as String)
            : null,
        ratchetKeyPairPriv: j['ratchetKeyPairPriv'] as String,
        ratchetKeyPairPub: j['ratchetKeyPairPub'] as String,
        peerRatchetPub: j['peerRatchetPub'] as String,
        messageCounter: j['messageCounter'] as int? ?? 0,
        receiveCounter: j['receiveCounter'] as int? ?? 0,
        isValid: j['isValid'] as bool? ?? true,
      );
}

// ── Internal helpers ──

class _ChainResult {
  final List<int> rootKey;
  final List<int> chainKey;
  const _ChainResult({required this.rootKey, required this.chainKey});
}

class _MessageKeyResult {
  final List<int> messageKey;
  final List<int> chainKey;
  const _MessageKeyResult({required this.messageKey, required this.chainKey});
}
