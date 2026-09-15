// lib/services/security_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import '../models/rsa_key_pair_result.dart';


class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  static const String _privateKeyStorageKey = 'device_rsa_private_key';
  static const String _publicKeyStorageKey = 'device_rsa_public_key';

  // ─── FIXED: use encryptedSharedPreferences: true so keys survive app
  //     restarts on all Android versions (matches TokenCacheService options).
  //     Without this flag, the old AndroidOptions() backend may silently fail
  //     to persist keys across cold starts, causing a new key pair to be
  //     generated on every launch → new public key → server treats it as a
  //     new device user every time.
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true, // AES-256 backed by Android Keystore
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // In-memory cache of the parsed private key object (lives only for this
  // process lifetime; repopulated from secure storage on next cold start).
  RSAPrivateKey? _cachedPrivateKey;

  /// Generate a new 2048-bit RSA Key Pair
  Future<RsaKeyPairResult> generateRsaKeyPair({int bitStrength = 2048}) async {
    final secureRandom = _getSecureRandom();
    final rsaPars = RSAKeyGeneratorParameters(
      BigInt.parse('65537'), // Public exponent e
      bitStrength,
      64,
    );

    final params = ParametersWithRandom(rsaPars, secureRandom);
    final keyGenerator = RSAKeyGenerator()..init(params);
    final AsymmetricKeyPair<PublicKey, PrivateKey> pair = keyGenerator.generateKeyPair();

    final RSAPublicKey publicKey = pair.publicKey as RSAPublicKey;
    final RSAPrivateKey privateKey = pair.privateKey as RSAPrivateKey;

    final String publicKeyBase64 = _encodePublicKeyToX509Base64(publicKey);
    final String privateKeyPem = _encodePrivateKeyToPem(privateKey);

    return RsaKeyPairResult(
      publicKey: publicKey,
      privateKey: privateKey,
      publicKeyBase64: publicKeyBase64,
      privateKeyPem: privateKeyPem,
    );
  }

  /// Store private key in secure storage (AES-256 / Android Keystore).
  Future<void> storePrivateKey(String privateKeyPem) async {
    try {
      await _storage.write(key: _privateKeyStorageKey, value: privateKeyPem);
      // Also cache in-memory to avoid re-parsing on the same run.
      _cachedPrivateKey = _parsePrivateKeyFromPem(privateKeyPem);
      if (kDebugMode) {
        print('🔐 [SecurityService] RSA Private Key stored (${privateKeyPem.length} chars)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SecurityService] Error storing private key: $e');
      }
      rethrow;
    }
  }

  /// Store public key in secure storage.
  Future<void> storePublicKey(String publicKeyBase64) async {
    try {
      await _storage.write(key: _publicKeyStorageKey, value: publicKeyBase64);
      if (kDebugMode) {
        print('🔐 [SecurityService] RSA Public Key stored (${publicKeyBase64.length} chars)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SecurityService] Error storing public key: $e');
      }
    }
  }

  /// Returns true only when BOTH the public and private keys are present and
  /// non-empty in secure storage.
  Future<bool> hasStoredPrivateKey() async {
    try {
      final key = await _storage.read(key: _privateKeyStorageKey);
      final exists = key != null && key.isNotEmpty;
      if (kDebugMode) {
        print('🔍 [SecurityService] hasStoredPrivateKey → $exists');
      }
      return exists;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SecurityService] hasStoredPrivateKey error: $e');
      }
      return false;
    }
  }

  /// Get stored private key PEM string from secure storage.
  Future<String?> getStoredPrivateKeyPem() async {
    try {
      final pem = await _storage.read(key: _privateKeyStorageKey);
      if (kDebugMode) {
        print('🔍 [SecurityService] getStoredPrivateKeyPem → '
            '${pem != null ? "found (${pem.length} chars)" : "NOT FOUND"}');
      }
      return pem;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SecurityService] getStoredPrivateKeyPem error: $e');
      }
      return null;
    }
  }

  /// Get stored public key Base64 string from secure storage.
  Future<String?> getStoredPublicKeyBase64() async {
    try {
      final pub = await _storage.read(key: _publicKeyStorageKey);
      if (kDebugMode) {
        print('🔍 [SecurityService] getStoredPublicKeyBase64 → '
            '${pub != null ? "found (${pub.length} chars)" : "NOT FOUND"}');
      }
      return pub;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SecurityService] getStoredPublicKeyBase64 error: $e');
      }
      return null;
    }
  }

  /// Returns the stored device public key (Base64/X.509) if one already
  /// exists in secure storage, or generates + stores a fresh 2048-bit RSA
  /// key pair and returns the new public key.
  ///
  /// This is the primary guard that prevents generating a new key on every
  /// login: it will only generate when BOTH keys are missing.
  Future<String> getOrCreateDevicePublicKey() async {
    final existingPublic = await getStoredPublicKeyBase64();
    final hasPrivate = await hasStoredPrivateKey();

    if (kDebugMode) {
      print('🔑 [SecurityService] getOrCreateDevicePublicKey: '
          'existingPublic=${existingPublic != null}, hasPrivate=$hasPrivate');
    }

    if (existingPublic != null && existingPublic.isNotEmpty && hasPrivate) {
      if (kDebugMode) {
        print('✅ [SecurityService] Reusing existing RSA KeyPair from secure storage.');
      }
      return existingPublic;
    }

    // One or both keys are missing — generate a fresh pair and persist both.
    if (kDebugMode) {
      print('⚠️  [SecurityService] No stored key pair found — generating new RSA key pair...');
    }
    final keyPair = await generateRsaKeyPair();
    await storePrivateKey(keyPair.privateKeyPem);
    await storePublicKey(keyPair.publicKeyBase64);
    if (kDebugMode) {
      print('✨ [SecurityService] Generated and stored NEW device RSA KeyPair.');
    }
    return keyPair.publicKeyBase64;
  }

  /// Get active RSAPrivateKey for signing
  Future<RSAPrivateKey?> getActivePrivateKey() async {
    if (_cachedPrivateKey != null) {
      return _cachedPrivateKey;
    }

    final pem = await getStoredPrivateKeyPem();
    if (pem != null && pem.isNotEmpty) {
      _cachedPrivateKey = _parsePrivateKeyFromPem(pem);
      return _cachedPrivateKey;
    }
    return null;
  }

  /// Sign payload (string request body or data) with stored RSA private key using SHA256withRSA (PKCS#1 v1.5)
  Future<String?> signPayload(String payload) async {
    try {
      final privateKey = await getActivePrivateKey();
      if (privateKey == null) {
        if (kDebugMode) {
          print('⚠️ No private key found in KeyStore for signing payload');
        }
        return null;
      }
      final Uint8List dataToSign = Uint8List.fromList(utf8.encode(payload));
      final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
      signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
      final RSASignature signature = signer.generateSignature(dataToSign);
      final String base64Signature = base64Encode(signature.bytes);

      if (kDebugMode) {
        print('🔏 Payload signed successfully (Length: ${base64Signature.length})');
      }

      return base64Signature;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error signing payload: $e');
      }
      return null;
    }
  }

  /// Clear all stored keys (e.g., on full reset)
  Future<void> clearKeys() async {
    _cachedPrivateKey = null;
    await _storage.delete(key: _privateKeyStorageKey);
    await _storage.delete(key: _publicKeyStorageKey);
  }

  // ==========================================
  // ASN.1 / X.509 / PKCS#1 DER & PEM ENCODERS
  // ==========================================

  /// Encodes RSAPublicKey into standard X.509 SubjectPublicKeyInfo DER Base64 (Readable by Spring Boot / Java X509EncodedKeySpec)
  String _encodePublicKeyToX509Base64(RSAPublicKey publicKey) {
    // 1. Encode RSA Public Key inside PKCS#1 sequence: SEQUENCE { INTEGER (modulus), INTEGER (exponent) }
    final Uint8List pkcs1Der = _encodePkcs1PublicKey(publicKey);

    // 2. AlgorithmIdentifier: SEQUENCE { OBJECT IDENTIFIER (1.2.840.113549.1.1.1), NULL }
    final Uint8List algorithmIdentifier = Uint8List.fromList([
      0x30, 0x0D, // SEQUENCE (13 bytes)
      0x06, 0x09, // OID (9 bytes)
      0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01, // 1.2.840.113549.1.1.1 (rsaEncryption)
      0x05, 0x00, // NULL
    ]);

    // 3. SubjectPublicKey BIT STRING: 0x03, Length, 0x00 (unused bits), pkcs1Der
    final Uint8List bitString = _encodeBitString(pkcs1Der);

    // 4. Wrap everything in SubjectPublicKeyInfo SEQUENCE
    final List<int> spkiBody = [...algorithmIdentifier, ...bitString];
    final Uint8List spkiDer = _encodeSequence(Uint8List.fromList(spkiBody));

    return base64Encode(spkiDer);
  }

  Uint8List _encodePkcs1PublicKey(RSAPublicKey key) {
    final modDer = _encodeInteger(key.modulus!);
    final expDer = _encodeInteger(key.exponent!);
    return _encodeSequence(Uint8List.fromList([...modDer, ...expDer]));
  }

  /// Encodes RSAPrivateKey into PKCS#1 PEM
  String _encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    final mod = _encodeInteger(privateKey.modulus!);
    final pubExp = _encodeInteger(privateKey.publicExponent ?? BigInt.from(65537));
    final privExp = _encodeInteger(privateKey.privateExponent!);
    final p = _encodeInteger(privateKey.p!);
    final q = _encodeInteger(privateKey.q!);
    final expP = _encodeInteger(privateKey.privateExponent! % (privateKey.p! - BigInt.one));
    final expQ = _encodeInteger(privateKey.privateExponent! % (privateKey.q! - BigInt.one));
    final qInv = _encodeInteger(privateKey.q!.modInverse(privateKey.p!));
    final version = _encodeInteger(BigInt.zero);

    final Uint8List body = Uint8List.fromList([
      ...version,
      ...mod,
      ...pubExp,
      ...privExp,
      ...p,
      ...q,
      ...expP,
      ...expQ,
      ...qInv,
    ]);

    final Uint8List der = _encodeSequence(body);
    final base64Str = base64Encode(der);

    // Split in 64 char lines
    final buffer = StringBuffer();
    buffer.writeln('-----BEGIN RSA PRIVATE KEY-----');
    for (int i = 0; i < base64Str.length; i += 64) {
      buffer.writeln(
        base64Str.substring(i, min(i + 64, base64Str.length)),
      );
    }
    buffer.writeln('-----END RSA PRIVATE KEY-----');
    return buffer.toString();
  }

  /// Parse RSAPrivateKey from PKCS#1 PEM format
  RSAPrivateKey _parsePrivateKeyFromPem(String pem) {
    final lines = pem
        .replaceAll('-----BEGIN RSA PRIVATE KEY-----', '')
        .replaceAll('-----END RSA PRIVATE KEY-----', '')
        .replaceAll('-----BEGIN PRIVATE KEY-----', '')
        .replaceAll('-----END PRIVATE KEY-----', '')
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .trim();

    final Uint8List bytes = base64Decode(lines);
    return _decodePkcs1PrivateKey(bytes);
  }

  RSAPrivateKey _decodePkcs1PrivateKey(Uint8List bytes) {
    int offset = 0;

    // Check SEQUENCE tag
    if (bytes[offset++] != 0x30) {
      throw const FormatException('Expected SEQUENCE in private key');
    }

    // Read sequence length
    offset = _readLength(bytes, offset).newOffset;

    // Version
    final vRes = _readInteger(bytes, offset);
    offset = vRes.newOffset;

    // Modulus
    final modRes = _readInteger(bytes, offset);
    offset = modRes.newOffset;

    // Public Exponent
    final pubExpRes = _readInteger(bytes, offset);
    offset = pubExpRes.newOffset;

    // Private Exponent
    final privExpRes = _readInteger(bytes, offset);
    offset = privExpRes.newOffset;

    // Prime 1 (p)
    final pRes = _readInteger(bytes, offset);
    offset = pRes.newOffset;

    // Prime 2 (q)
    final qRes = _readInteger(bytes, offset);
    offset = qRes.newOffset;

    return RSAPrivateKey(
      modRes.value,
      privExpRes.value,
      pRes.value,
      qRes.value,
    );
  }

  // --- ASN.1 Low-level Helpers ---

  Uint8List _encodeSequence(Uint8List content) {
    final lengthBytes = _encodeLength(content.length);
    return Uint8List.fromList([0x30, ...lengthBytes, ...content]);
  }

  Uint8List _encodeBitString(Uint8List content) {
    final lengthBytes = _encodeLength(content.length + 1);
    return Uint8List.fromList([0x03, ...lengthBytes, 0x00, ...content]);
  }

  Uint8List _encodeInteger(BigInt value) {
    List<int> bytes = [];
    BigInt v = value;
    if (v == BigInt.zero) {
      bytes = [0];
    } else {
      while (v > BigInt.zero) {
        bytes.add((v & BigInt.from(0xFF)).toInt());
        v = v >> 8;
      }
      bytes = bytes.reversed.toList();
      // Leading zero for positive integer if high bit is set
      if ((bytes.first & 0x80) != 0) {
        bytes.insert(0, 0x00);
      }
    }
    final lengthBytes = _encodeLength(bytes.length);
    return Uint8List.fromList([0x02, ...lengthBytes, ...bytes]);
  }

  List<int> _encodeLength(int length) {
    if (length < 128) {
      return [length];
    }
    final List<int> bytes = [];
    int l = length;
    while (l > 0) {
      bytes.add(l & 0xFF);
      l = l >> 8;
    }
    return [0x80 | bytes.length, ...bytes.reversed];
  }

  _LengthResult _readLength(Uint8List bytes, int offset) {
    final int first = bytes[offset++];
    if ((first & 0x80) == 0) {
      return _LengthResult(first, offset);
    }
    final int numBytes = first & 0x7F;
    int length = 0;
    for (int i = 0; i < numBytes; i++) {
      length = (length << 8) | bytes[offset++];
    }
    return _LengthResult(length, offset);
  }

  _IntegerResult _readInteger(Uint8List bytes, int offset) {
    if (bytes[offset++] != 0x02) {
      throw const FormatException('Expected INTEGER tag');
    }
    final lenRes = _readLength(bytes, offset);
    offset = lenRes.newOffset;
    final int length = lenRes.length;

    BigInt value = BigInt.zero;
    for (int i = 0; i < length; i++) {
      value = (value << 8) | BigInt.from(bytes[offset++]);
    }
    return _IntegerResult(value, offset);
  }

  SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }
}

class _LengthResult {
  final int length;
  final int newOffset;
  _LengthResult(this.length, this.newOffset);
}

class _IntegerResult {
  final BigInt value;
  final int newOffset;
  _IntegerResult(this.value, this.newOffset);
}
