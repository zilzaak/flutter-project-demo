// lib/services/employee_cached_location_service.dart
//
// EmployeeCachedLocationService
// -----------------------------
// Manages buffering and caching of employee location coordinates inside persistent
// app storage (backed by FlutterSecureStorage).
//
// Features:
//  • Keeps raw location data without additional encryption/decryption overhead.
//  • Retains data across app minimization, screen lock, app restart, or device power off.
//  • Allows appending location points every minute and clearing the cache only
//    after the backend batch sync succeeds.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EmployeeCachedLocationService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final EmployeeCachedLocationService _instance =
      EmployeeCachedLocationService._internal();
  factory EmployeeCachedLocationService() => _instance;
  EmployeeCachedLocationService._internal();

  // ── Storage (backed by Android Keystore / iOS Keychain) ───────────────────
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Storage key for the cached locations list.
  static const String _locationsCacheKey = 'employee_cached_locations_list';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Retrieves the list of currently cached location items.
  /// Returns an empty list if none exist or if deserialization fails.
  Future<List<Map<String, dynamic>>> getCachedLocations() async {
    try {
      final String? rawJson = await _storage.read(key: _locationsCacheKey);
      if (rawJson == null || rawJson.trim().isEmpty) {return [];}
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return decoded.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {debugPrint('❌ [EmployeeCachedLocation] getCachedLocations error: $e');}
      return [];
    }
  }

  /// Appends a new [location] entry to the cached list.
  Future<void> addLocation(Map<String, dynamic> location) async {
    try {
      final List<Map<String, dynamic>> currentList = await getCachedLocations();
      currentList.add(location);
      await _storage.write(
        key: _locationsCacheKey,
        value: jsonEncode(currentList),
      );
      if (kDebugMode) {
        debugPrint('💾 [EmployeeCachedLocation] Added location to cache. '
            'Total count: ${currentList.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [EmployeeCachedLocation] addLocation error: $e');
      }
    }
  }

  /// Overwrites the cached list with [locations].
  Future<void> saveLocations(List<Map<String, dynamic>> locations) async {
    try {
      await _storage.write(
        key: _locationsCacheKey,
        value: jsonEncode(locations),
      );
      if (kDebugMode) {
        debugPrint('💾 [EmployeeCachedLocation] Saved ${locations.length} locations to cache.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [EmployeeCachedLocation] saveLocations error: $e');
      }
    }
  }

  /// Clears the cached locations list (resets size to 0).
  /// Must ONLY be called after a successful backend batch sync.
  Future<void> clearCachedLocations() async {
    try {
      await _storage.delete(key: _locationsCacheKey);
      if (kDebugMode) {
        debugPrint('🗑️  [EmployeeCachedLocation] Cleared all cached locations from storage.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [EmployeeCachedLocation] clearCachedLocations error: $e');
      }
    }
  }

  /// Returns the current count of cached locations.
  Future<int> getCachedLocationsCount() async {
    try {
      final locations = await getCachedLocations();
      return locations.length;
    } catch (e) {
      return 0;
    }
  }
}

/// Global singleton — import and use anywhere in the app.
final employeeCachedLocationService = EmployeeCachedLocationService();
