// lib/services/token_cache_service.dart
//
// TokenCacheService
// -----------------
// Manages the JWT access-token lifecycle inside the app's secure key store
// (FlutterSecureStorage backed by Android Keystore / iOS Keychain).
//
// Caching Strategy
// ----------------
//  • One token slot per calendar day, stored under key "access_token_YYYY-MM-DD".
//  • A meta-key "access_token_current_date_key" tracks the most recently written
//    date key so that the stale previous-day entry can be deleted cheaply.
//
//  On every successful Keycloak login:
//    1. The FRESH token is ALWAYS written to today's key (overwrite if exists).
//       → This covers "re-login on the same day" — the new token always wins.
//    2. If the stored meta-key belongs to a DIFFERENT date, that old entry is
//       deleted before writing the new one.
//
//  Usage in auth_service.dart:
//    await tokenCacheService.saveAndEvictOld(freshToken);
//    // globals.accessToken and employee.token are then set to freshToken.

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenCacheService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final TokenCacheService _instance = TokenCacheService._internal();
  factory TokenCacheService() => _instance;
  TokenCacheService._internal();

  // ── Secure storage (Android Keystore / iOS Keychain) ──────────────────────
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true, // Uses AES-256 backed by Android Keystore
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // ── Storage key constants ──────────────────────────────────────────────────

  /// Prefix for every date-keyed token entry.
  static const String _tokenKeyPrefix = 'access_token_';

  /// Meta-key that always holds the date-key of the most recently saved token.
  /// Used to locate and delete the stale entry on the next login.
  static const String _lastDateKeyMeta = 'access_token_current_date_key';

  // ── Internal helpers ───────────────────────────────────────────────────────

  /// Returns today's storage key: "access_token_YYYY-MM-DD".
  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$_tokenKeyPrefix$y-$m-$d';
  }

  /// Deletes the entry stored under [_lastDateKeyMeta] if it is a DIFFERENT key
  /// from [todayKey], then updates the meta-key to point to [todayKey].
  Future<void> _evictPreviousDateAndUpdateMeta(String todayKey) async {
    try {
      final lastKey = await _storage.read(key: _lastDateKeyMeta);
      if (lastKey != null && lastKey.isNotEmpty && lastKey != todayKey) {
        await _storage.delete(key: lastKey);
        if (kDebugMode) {
          debugPrint('🗑️  [TokenCache] Evicted stale token (key: $lastKey).');
        }
      }
      // Always update meta to point at today's key.
      await _storage.write(key: _lastDateKeyMeta, value: todayKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [TokenCache] _evictPreviousDateAndUpdateMeta error: $e');
      }
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Saves [freshToken] into the key store under today's date key.
  ///
  /// Behaviour:
  ///  • ALWAYS overwrites today's entry — "re-login on the same day" stores
  ///    the brand-new token so the freshest credential is always authoritative.
  ///  • Deletes any entry whose date key differs from today (stale previous day).
  ///
  /// Call this immediately after obtaining a fresh access token from Keycloak.
  Future<void> saveAndEvictOld(String freshToken) async {
    final todayKey = _todayKey();
    try {
      // Evict old date entry and update meta BEFORE writing,
      // so a crash mid-write does not leave two live date entries.
      await _evictPreviousDateAndUpdateMeta(todayKey);

      // Always write (create or overwrite) the fresh token.
      await _storage.write(key: todayKey, value: freshToken);

      if (kDebugMode) {
        final preview = freshToken.length > 30
            ? '${freshToken.substring(0, 30)}...'
            : freshToken;
        debugPrint('💾 [TokenCache] Token saved/updated in key store '
            '(key: $todayKey, preview: $preview).');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [TokenCache] saveAndEvictOld error: $e');
      }
    }
  }

  /// Returns the token currently stored for today, or `null` if none exists.
  Future<String?> getTodayToken() async {
    try {
      final token = await _storage.read(key: _todayKey());
      if (kDebugMode) {
        if (token != null) {
          debugPrint('🗝️  [TokenCache] getTodayToken → found cached token.');
        } else {
          debugPrint('🗝️  [TokenCache] getTodayToken → no token for today.');
        }
      }
      return token;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [TokenCache] getTodayToken error: $e');
      }
      return null;
    }
  }

  /// Completely wipes all token cache entries from the secure key store.
  /// Call ONLY on a deliberate full data-reset; NOT on normal logout flow
  /// (session must remain alive for 8 h continuous service).
  Future<void> clearAllTokens() async {
    try {
      final lastKey = await _storage.read(key: _lastDateKeyMeta);
      if (lastKey != null && lastKey.isNotEmpty) {
        await _storage.delete(key: lastKey);
      }
      await _storage.delete(key: _lastDateKeyMeta);
      if (kDebugMode) {
        debugPrint('🗑️  [TokenCache] All cached tokens cleared from key store.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [TokenCache] clearAllTokens error: $e');
      }
    }
  }
}

/// Global singleton — import and use anywhere in the app.
final tokenCacheService = TokenCacheService();
