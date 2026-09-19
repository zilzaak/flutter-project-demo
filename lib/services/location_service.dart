import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import '../global_config.dart';
import '../models/employee_model.dart';
import '../models/location_data_model.dart';
import 'background_location_service.dart';

class LocationService {
  static const String baseUrl = GlobalConfig.baseUrl;
  static const String syncEndpoint = '/api/geo/portal/geo-location/sync-employee-location';
  static const int syncIntervalMinutes = 1;

  LocationDataModel? currentLocation;
  VoidCallback? onLocationSynced;
  StreamSubscription? _bgLocationSub;

  /// Check location services and request necessary permissions cleanly
  Future<bool> handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please turn on Location in phone settings.');
    }
    return await BackgroundLocationService.ensurePermissions();
  }

  /// Get current GPS position without launching duplicate permission popups
  Future<LocationDataModel> getCurrentLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please turn on Location in phone settings.');
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ GPS timeout ($e), trying last known position...');
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
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (_) {}
    }

    if (position == null) {
      throw Exception('Unable to acquire GPS coordinates. Please ensure GPS is enabled.');
    }

    final locData = LocationDataModel(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      statusMessage: 'Location fetched successfully',
    );

    currentLocation = locData;
    return locData;
  }

  /// Stop continuous location sync
  void stopScheduledSync() {
    _bgLocationSub?.cancel();
    _bgLocationSub = null;
    BackgroundLocationService.stopTracking();
    if (kDebugMode) {
      print('⏹️ Scheduled location tracking stopped');
    }
  }

  /// Start continuous background location sync.
  /// Runs inside the Android Foreground Service isolate so tracking does not stop
  /// when the screen is off, minimized, or locked.
  void startScheduledSync(EmployeeModel? employee) {
    if (employee == null) return;

    // Listen to real-time location updates emitted by the background service isolate
    _bgLocationSub?.cancel();
    _bgLocationSub = FlutterBackgroundService().on('locationUpdated').listen((data) {
      if (data != null) {
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        final acc = (data['accuracy'] as num?)?.toDouble();
        final tsStr = data['timestamp']?.toString();
        final DateTime ts = tsStr != null ? (DateTime.tryParse(tsStr) ?? DateTime.now()) : DateTime.now();

        if (lat != null && lng != null) {
          currentLocation = LocationDataModel(
            latitude: lat,
            longitude: lng,
            accuracy: acc,
            timestamp: ts,
            statusMessage: 'Location synced successfully',
          );
          onLocationSynced?.call();
        }
      }
    });

    // Start Android Foreground Service tracking
    BackgroundLocationService.startTracking(employee);

    // Also fetch initial location for fast UI population
    getCurrentLocation().then((loc) {
      currentLocation = loc;
      onLocationSynced?.call();
    }).catchError((_) {});
  }

  /// Manual sync - triggers immediate check in the background tracking service
  Future<void> syncLocationNow({EmployeeModel? employee}) async {
    await BackgroundLocationService.syncNow();
    try {
      final loc = await getCurrentLocation();
      currentLocation = loc;
      onLocationSynced?.call();
    } catch (_) {}
  }
}

final locationService = LocationService();