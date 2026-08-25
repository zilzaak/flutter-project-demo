import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationDataModel {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final String statusMessage;

  const LocationDataModel({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    required this.statusMessage,
  });
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;

  /// Check location services and request necessary permissions for FLP (Fused Location Provider)
  Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled on device
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled on your device. Please enable GPS.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied. Please allow location permissions in device settings.',
      );
    }

    return true;
  }

  /// Fetches current employee location (Latitude & Longitude) using FLP
  Future<LocationDataModel> getCurrentLocation() async {
    await handleLocationPermission();

    // Acquire current position using Fused Location Provider settings
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    // Call placeholder API sender method
    sendLocationToApi(position.latitude, position.longitude);

    return LocationDataModel(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      statusMessage: 'Location fetched successfully via FLP',
    );
  }

  /// Starts continuous background/foreground location updates via FLP
  Stream<LocationDataModel> getLiveLocationStream() async* {
    await handleLocationPermission();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Updates every 10 meters change
    );

    yield* Geolocator.getPositionStream(locationSettings: locationSettings).map((position) {
      // Trigger backend transmission hook
      sendLocationToApi(position.latitude, position.longitude);

      return LocationDataModel(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
        statusMessage: 'Live FLP Tracking Active',
      );
    });
  }

  Future<void> sendLocationToApi(double latitude, double longitude) async {
    if (kDebugMode) {
      print('[FLP Location API Placeholder] Lat: $latitude, Lng: $longitude');
    }

    // TODO (Long Term API):
    /*
    await http.post(
      Uri.parse('https://your-domain.com/api/v1/employee/location'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
    */
  }

  void stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }
}
