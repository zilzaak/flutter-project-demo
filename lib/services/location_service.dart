import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:my_demo_project/utility/CommonUtil.dart';
import '../global_config.dart';
import '../models/employee_model.dart';
import '../models/location_data_model.dart';
import 'security_service.dart';

class LocationService {
  static const String baseUrl = GlobalConfig.baseUrl;
  static const String syncEndpoint = '/api/geoportal/geo-location/sync-employee-location';
  static const int syncIntervalMinutes = 1;
  LocationDataModel? currentLocation;
  // Controllers
  Timer? _scheduledTimer;


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




  Future<LocationDataModel> getCurrentLocation() async {
    await handleLocationPermission();
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Fast GPS timeout/error ($e), trying last known position...');
      }
    }

    if (position == null) {
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }

    if (position == null) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Low accuracy GPS timeout ($e), trying last known position again...');
        }
      }
    }

    // 4. Final attempt: last known position
    if (position == null) {
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }
    if (position == null) {
      throw Exception('Unable to acquire GPS coordinates. Please ensure GPS is enabled and device has satellite/network connectivity.');
    }

    this.currentLocation=LocationDataModel(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      statusMessage: 'Location fetched successfully',
    );

    return LocationDataModel(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      statusMessage: 'Location fetched successfully',
    );
  }

  /// Stop scheduled location sync
  void stopScheduledSync() {
    _scheduledTimer?.cancel();
    _scheduledTimer = null;
    if (kDebugMode) {
      print('⏹️ Scheduled location sync stopped');
    }
  }

  /// Start scheduled location sync every 1 minute
  void startScheduledSync(EmployeeModel? employee) {
    // 1. Cancel previous timer so starting a new timer never leaves duplicates
    _scheduledTimer?.cancel();
    _scheduledTimer = null;
    if (employee != null && commonUtil.isOfficeHourFinished(employee)) {
      stopScheduledSync();
      if (kDebugMode) {print('⏹️ Office hours (8 hours) are finished. Sync scheduler will not start.');}
      return;
    }

    _scheduledTimer = Timer.periodic(
      const Duration(minutes: syncIntervalMinutes),
      (_) async {
        try {
          if(employee != null && commonUtil.isOfficeHourFinished(employee)) {
            if (kDebugMode) {print('⏹️ Office duty time (8 hours) completed. Stopping scheduled sync timer.');}
            stopScheduledSync();
            return;
          }
          await _syncLocationToBackend(employee:employee);
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ [LocationService] Scheduled sync tick error caught (scheduler kept alive): $e');
          }
        }
      },
    );
    // 4. Immediate first sync
    _syncLocationToBackend(employee:employee);
  }

  /// Sync location to backend API with RSA digital signature on payload
  Future<void> _syncLocationToBackend({EmployeeModel? employee}) async {
    try {
      final location = await getCurrentLocation();
      if (kDebugMode) {
        print('📍 [LocationService] Coordinates retrieved: Lat=${location.latitude}, Lng=${location.longitude}');
      }
      // Prepare request body
      final requestBody = {
        'employeeId': employee?.userId,
        'longitude': location.longitude,
        'latitude': location.latitude,
        'date': DateTime.now().toIso8601String(),
        'accessToken': employee?.token,
      };

      final String? token = employee?.token;
      final String jsonBody = jsonEncode(requestBody);
      final String canonicalPayload = '${employee?.userId}|${location.longitude}|${location.latitude}';

      final String? signature = await SecurityService().signPayload(canonicalPayload);
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
        headers['X-Signature'] = signature.toString();
        headers['X-Payload-Signature'] = signature.toString();
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
    } finally {
    }
  }
  /// Manual sync - call from UI
  Future<void> syncLocationNow() async {
  }
}
final locationService = LocationService();