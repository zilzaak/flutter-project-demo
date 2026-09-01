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

  // Secure storage instance using Android KeyStore
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // In-memory cache of private key
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

  /// Store private key in Android KeyStore / Secure Storage
  Future<void> storePrivateKey(String privateKeyPem) async {
    try {
      await _storage.write(key: _privateKeyStorageKey, value: privateKeyPem);
      _cachedPrivateKey = _parsePrivateKeyFromPem(privateKeyPem);
      if (kDebugMode) {
        print('🔐 RSA Private Key securely stored in Android KeyStore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error storing private key in KeyStore: $e');
      }
      rethrow;
    }
  }

  /// Store public key in Secure Storage
  Future<void> storePublicKey(String publicKeyBase64) async {
    try {
      await _storage.write(key: _publicKeyStorageKey, value: publicKeyBase64);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error storing public key: $e');
      }
    }
  }

  /// Check if private key exists in Android KeyStore
  Future<bool> hasStoredPrivateKey() async {
    try {
      final key = await _storage.read(key: _privateKeyStorageKey);
      return key != null && key.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get stored private key PEM string
  Future<String?> getStoredPrivateKeyPem() async {
    try {
      return await _storage.read(key: _privateKeyStorageKey);
    } catch (e) {
      return null;
    }
  }

  /// Get stored public key Base64 string
  Future<String?> getStoredPublicKeyBase64() async {
    try {
      return await _storage.read(key: _publicKeyStorageKey);
    } catch (e) {
      return null;
    }
  }

  /// Get or create the device RSA KeyPair.
  /// If a key pair already exists in KeyStore, returns the existing public key.
  /// If not, generates a new 2048-bit RSA key pair, securely stores it in KeyStore, and returns the public key.
  Future<String> getOrCreateDevicePublicKey() async {
    final existingPublic = await getStoredPublicKeyBase64();
    final hasPrivate = await hasStoredPrivateKey();
    if (existingPublic != null && existingPublic.isNotEmpty && hasPrivate) {
      if (kDebugMode) {
        print('🔑 Reusing existing RSA KeyPair from KeyStore: ${existingPublic.substring(0, 30)}...');
      }
      return existingPublic;
    }

    // Generate and permanently store new key pair on this device
    final keyPair = await generateRsaKeyPair();
    await storePrivateKey(keyPair.privateKeyPem);
    await storePublicKey(keyPair.publicKeyBase64);
    if (kDebugMode) {
      print('✨ Generated and stored NEW device RSA KeyPair in KeyStore');
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
