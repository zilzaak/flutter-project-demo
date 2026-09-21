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

  static final TokenCacheService _instance = TokenCacheService._internal();
  factory TokenCacheService() => _instance;
  TokenCacheService._internal();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );


  String _todayKey() {
/*    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$_tokenKeyPrefix$y-$m-$d'; */
    return "todaykey";
  }




  Future<void> saveAndEvictOld(String freshToken) async {
    final todayKey = _todayKey();
    try {
      await _storage.write(key: todayKey, value: freshToken);
    } catch (e) {
    }
  }

  /// Returns the token currently stored for today, or `null` if none exists.
  Future<String?> getToken() async {
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
}

/// Global singleton — import and use anywhere in the app.
final tokenCacheService = TokenCacheService();
