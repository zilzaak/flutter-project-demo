import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../app_global.dart';
import '../models/location_data_model.dart';

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
      throw Exception('Location services are disabled. Please enable GPS.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are denied.');
      }
    }
    return true;
  }

  /// Get current location
  Future<LocationDataModel> getCurrentLocation() async {
    await handleLocationPermission();

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),//This method will try maximum 15 second to retrieve location if fail than return , don't try after 15 second
      ),
    );

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
      Duration(minutes: syncIntervalMinutes),
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


  /// Sync location to backend API
  Future<void> _syncLocationToBackend() async {
    if (_isSyncing) return;

    // Check globals for token and employee
    final token = globals.accessToken;
    final employee = globals.currentEmployee;

    if (token == null || employee == null) {
      if (kDebugMode) {
        print('❌ No token or employee data available');
      }
      return;
    }

    _isSyncing = true;

    try {
      // Get current location
      final location = await getCurrentLocation();

      // Prepare request body
      final requestBody = {
        'employeeId': employee.userId,
        'longitude': location.longitude,
        'latitude': location.latitude,
        'date': DateTime.now().toIso8601String(),
      };

      // Send to backend
      final response = await http.post(
        Uri.parse('$baseUrl$syncEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (kDebugMode) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          print('✅ Location synced: ${location.latitude}, ${location.longitude}');
        } else {
          print('❌ Sync failed: ${response.statusCode}');
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Location sync error: $e');
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Manual sync - call from UI
  Future<void> syncLocationNow() async {
    await _syncLocationToBackend();
  }

  /// Clean up
  void dispose() {
    stopScheduledSync();
  }
}

