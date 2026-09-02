import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../app_global.dart';
import '../models/location_data_model.dart';
import 'security_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Constants
  static const String baseUrl = AppGlobals.baseUrl;
  static const String syncEndpoint = '/api/ess/portal/employee-duty-monitoring/sync-employee-location';
  static const int syncIntervalMinutes = 1;

  // Controllers
  Timer? _scheduledTimer;
  bool _isSyncing = false;



  /// Check location services and request necessary permissions
  Future<bool> handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please turn on Location in phone settings.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied. Please grant location access.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is permanently denied. Please allow it in App Settings.');
    }
    return true;
  }

  /// Get current location with fast fallback to avoid hanging indoors
  Future<LocationDataModel> getCurrentLocation() async {
    await handleLocationPermission();

    Position? position;

    // 1. Try fast GPS / Network position (8 seconds timeout)
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Fast location timeout/error ($e), trying last known position...');
      }
    }

    // 2. Fallback to last known position if current position timed out
    if (position == null) {
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }

    // 3. Fallback to low accuracy if still null
    if (position == null) {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    }

    return LocationDataModel(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      statusMessage: 'Location fetched successfully',
    );
  }


  /// Start scheduled location sync every 1 minute
  void startScheduledSync() {
    // Check if employee exists in globals
    if (globals.currentEmployee == null) {
      if (kDebugMode) {
        print('❌ No employee data in globals');
      }
      return;
    }
    // Cancel old timer
    stopScheduledSync();
    // Start new/next minutes timer
    _scheduledTimer = Timer.periodic(
      const Duration(minutes: syncIntervalMinutes),
      (_) => _syncLocationToBackend(),
    );
    // Immediate first sync
    _syncLocationToBackend();
    if (kDebugMode) {
      print('📍 Location sync started - every $syncIntervalMinutes minute(s)');
    }
  }

  /// Stop scheduled sync
  void stopScheduledSync() {
    _scheduledTimer?.cancel();
    _scheduledTimer = null;
    if (kDebugMode) {
      print('📍 Location sync stopped');
    }
  }

  /// Sync location to backend API with RSA digital signature on payload
  Future<void> _syncLocationToBackend({bool isManual = false}) async {
    if (_isSyncing && !isManual) {
      if (kDebugMode) {
        print('⏳ Location sync already in progress, skipping periodic tick');
      }
      return;
    }

    // Check globals for token and employee
    final token = globals.accessToken;
    final employee = globals.currentEmployee;

    if (token == null || employee == null || employee.userId.isEmpty) {
      final msg = 'No authentication token or Employee ID found (ID: ${employee?.userId})';
      if (kDebugMode) {
        print('❌ $msg');
      }
      if (isManual) throw Exception(msg);
      return;
    }

    _isSyncing = true;

    try {
      if (kDebugMode) {
        print('📍 [LocationService] Fetching GPS coordinates for employee ${employee.userId}...');
      }
      // Get current location
      final location = await getCurrentLocation();
      if (kDebugMode) {
        print('📍 [LocationService] Coordinates retrieved: Lat=${location.latitude}, Lng=${location.longitude}');
      }

      // Prepare request body
      final requestBody = {
        'employeeId': employee.userId,
        'longitude': location.longitude,
        'latitude': location.latitude,
        'date': DateTime.now().toIso8601String(),
      };

      final String jsonBody = jsonEncode(requestBody);

      // Canonical payload matching backend Option 3 (employeeId|longitude|latitude)
      final String canonicalPayload = '${employee.userId}|${location.longitude}|${location.latitude}';

      // Sign canonical payload with stored RSA private key from Android KeyStore
      if (kDebugMode) {
        print('🔐 [LocationService] Signing canonical payload: "$canonicalPayload"');
      }
      final String? signature = await SecurityService().signPayload(canonicalPayload);

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      if (signature != null && signature.isNotEmpty) {
        headers['X-Signature'] = signature;
        headers['X-Payload-Signature'] = signature;
      }

      final Uri syncUri = Uri.parse('$baseUrl$syncEndpoint');
      if (kDebugMode) {
        print('🌐 [LocationService] Sending POST $syncUri');
        print('🌐 [LocationService] Headers: $headers');
        print('🌐 [LocationService] Body: $jsonBody');
      }

      // Send to backend
      final response = await http.post(
        syncUri,
        headers: headers,
        body: jsonBody,
      ).timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('📡 [LocationService] Status Code: ${response.statusCode}');
        print('📡 [LocationService] Response: ${response.body}');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == false) {
          final String errMsg = jsonResponse['message'] ?? 'Location sync rejected by server';
          throw Exception(errMsg);
        }
        if (kDebugMode) {
          print('✅ Location synced with RSA signature: ${location.latitude}, ${location.longitude}');
        }
      } else {
        throw Exception('Server error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Location sync error: $e');
      }
      if (isManual) {
        rethrow;
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Manual sync - call from UI
  Future<void> syncLocationNow() async {
    await _syncLocationToBackend(isManual: true);
  }

  /// Clean up
  void dispose() {
    stopScheduledSync();
  }
}
