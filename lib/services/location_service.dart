import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:my_demo_project/utility/CommonUtil.dart';
import '../global_config.dart';
import '../models/employee_model.dart';
import '../models/location_data_model.dart';
import 'package:intl/intl.dart';
import 'background_location_service.dart';
import 'employee_cached_location_service.dart';

class LocationService {
  static const String baseUrl = GlobalConfig.baseUrl;
  static const String syncEndpoint = '/api/geoportal/geo-location/sync-employee-location';
  static const int syncIntervalMinutes = 1;
  LocationDataModel? currentLocation;
  VoidCallback? onLocationSynced;
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

    currentLocation = LocationDataModel(
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
    BackgroundLocationService.stopTracking();
    if (kDebugMode) {
      print('⏹️ Scheduled location sync stopped');
    }
  }

  /// Start scheduled location sync every 1 minute (keeps running when screen is off)
  void startScheduledSync(EmployeeModel? employee) {
    _scheduledTimer?.cancel();
    _scheduledTimer = null;
    if (employee != null && commonUtil.isOfficeHourFinished(employee)) {
      stopScheduledSync();
      if (kDebugMode) {
        print('⏹️ Office hours (8 hours) are finished. Sync scheduler will not start.');
      }
      return;
    }

    // 1. Periodic scheduler every 1 minute (heart of the app)
    _scheduledTimer = Timer.periodic(
      const Duration(minutes: syncIntervalMinutes),
      (_) async {
        try {
          if (employee != null && commonUtil.isOfficeHourFinished(employee)) {
            if (kDebugMode) {
              print('⏹️ Office duty time (8 hours) completed. Stopping scheduled sync timer.');
            }
            stopScheduledSync();
            return;
          }
          await _recordAndSyncLocation(employee: employee);
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ [LocationService] Scheduled sync tick error caught (scheduler kept alive): $e');
          }
        }
      },
    );

    // 2. Immediate first tick
    _recordAndSyncLocation(employee: employee);

    // 3. Keep CPU & process awake when phone screen is turned off
    BackgroundLocationService.startTracking(employee);
  }

  /// Records the current location into app cache and triggers backend API call
  /// only when the cache size reaches 5 or multiples of 5 (5*n).
  Future<void> _recordAndSyncLocation({EmployeeModel? employee}) async {
    try {
      final location = await getCurrentLocation();
      currentLocation = location;
      if (kDebugMode) {
        print('📍 [LocationService] Coordinates retrieved: Lat=${location.latitude}, Lng=${location.longitude}');
      }

      final String empId = employee?.userId ?? globals.currentEmployee?.userId ?? '';
      final String? token = employee?.token ?? globals.accessToken;

      // Prepare location data point matching backend EmployeeDistanceRequestDTO
      final locationEntry = {
        'employeeId': empId,
        'longitude': location.longitude,
        'latitude': location.latitude,
        'date': (location.timestamp ?? DateTime.now()).toIso8601String(),
        'accessToken': token,
      };

      // Store in persistent app cache
      await employeeCachedLocationService.addLocation(locationEntry);
      final List<Map<String, dynamic>> cachedLocations =
          await employeeCachedLocationService.getCachedLocations();
      final int cacheCount = cachedLocations.length;
      final timeStr = DateFormat('hh:mm:ss a').format(DateTime.now());

      if (kDebugMode) {
        print('📦 [LocationService] Current cached locations count: $cacheCount');
      }

      // Condition: array list size is 5 or product of 5 (5*n, where n=1,2,3...)
      if (cacheCount > 0 && cacheCount % 2 == 0) {
        if (kDebugMode) {
          print('🚀 [LocationService] Cache count ($cacheCount) reached multiple of 5. Syncing to backend...');
        }
        await _syncCachedLocationsToBackend(
          cachedLocations: cachedLocations,
          token: token,
          location: location,
        );
      } else {
        if (kDebugMode) {
          print('⏳ [LocationService] Cache count ($cacheCount) not a multiple of 5. Skipping backend call to keep server relaxed.');
        }
        BackgroundLocationService.updateNotification(
          title: '📍 Location Tracking Active',
          content: 'Last recorded: $timeStr | Cached: $cacheCount pts (next sync at ${((cacheCount ~/ 5) + 1) * 5})',
        );
        onLocationSynced?.call();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LocationService] Location tick error: $e');
      }
    }
  }

  /// Sends the cached locations array to backend /sync-employee-location.
  /// If successful, cache is cleared to 0.
  /// If failed, cache is preserved without data loss.
  Future<void> _syncCachedLocationsToBackend({
    required List<Map<String, dynamic>> cachedLocations,
    String? token,
    required LocationDataModel location,
  }) async {
    try {
      final String jsonBody = jsonEncode(cachedLocations);
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final Uri syncUri = Uri.parse('$baseUrl$syncEndpoint');
      if (kDebugMode) {
        print('🌐 [LocationService] Sending POST $syncUri with ${cachedLocations.length} locations');
        print('🌐 [LocationService] Headers: $headers');
        print('🌐 [LocationService] Body: $jsonBody');
      }
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
          print('✅ [LocationService] Successfully synced ${cachedLocations.length} locations to backend.');
        }

        // On success: clear cache to size=0
        await employeeCachedLocationService.clearCachedLocations();

        final timeStr = DateFormat('hh:mm:ss a').format(DateTime.now());
        BackgroundLocationService.updateNotification(
          title: '📍 Location Tracking Active',
          content: 'Last sync: $timeStr | Synced ${cachedLocations.length} locations | Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}',
        );
        onLocationSynced?.call();
      } else {
        throw Exception('Server error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // On failure: array list in cache is NOT cleared, avoiding any data loss
      if (kDebugMode) {
        print('❌ [LocationService] Batch location sync failed (cache kept intact): $e');
      }
    }
  }

  /// Manual sync - call from UI
  Future<void> syncLocationNow({EmployeeModel? employee}) async {
    await _recordAndSyncLocation(employee: employee ?? globals.currentEmployee);
  }
}
final locationService = LocationService();