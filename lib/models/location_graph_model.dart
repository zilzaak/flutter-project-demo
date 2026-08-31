import 'package:latlong2/latlong.dart';

class LocationPointModel {
  final double latitude;
  final double longitude;

  const LocationPointModel({
    required this.latitude,
    required this.longitude,
  });



  factory LocationPointModel.fromJson(Map<String, dynamic> json) {
    return LocationPointModel(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
  LatLng toLatLng() => LatLng(latitude, longitude);
}




class LocationGraphData {
  final double? officeLatitude;
  final double? officeLongitude;
  final List<LocationPointModel> locationPoints;

  const LocationGraphData({
    this.officeLatitude,
    this.officeLongitude,
    required this.locationPoints,
  });



  factory LocationGraphData.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['locationPoints'];
    List<LocationPointModel> points = [];

    if (rawPoints is List) {
      points = rawPoints
          .map((item) => LocationPointModel.fromJson(Map<String, dynamic>.from(item)))
          .where((p) => p.latitude != 0.0 || p.longitude != 0.0)
          .toList();
    }

    return LocationGraphData(
      officeLatitude: (json['officeLatitude'] as num?)?.toDouble(),
      officeLongitude: (json['officeLongitude'] as num?)?.toDouble(),
      locationPoints: points,
    );
  }

  bool get hasOfficeLocation =>
      officeLatitude != null &&
      officeLongitude != null &&
      (officeLatitude != 0.0 || officeLongitude != 0.0);

  LatLng? get officeLatLng => hasOfficeLocation ? LatLng(officeLatitude!, officeLongitude!) : null;

  List<LatLng> get polylinePoints => locationPoints.map((p) => p.toLatLng()).toList();

  int get totalPoints => locationPoints.length;

  bool get hasPoints => locationPoints.isNotEmpty;

  LocationPointModel? get startPoint => locationPoints.isNotEmpty ? locationPoints.first : null;

  LocationPointModel? get latestPoint => locationPoints.isNotEmpty ? locationPoints.last : null;

  /// Calculate total path distance in Kilometers
  double get totalDistanceKm {
    if (locationPoints.length < 2) return 0.0;
    const Distance distance = Distance();
    double total = 0.0;
    for (int i = 0; i < locationPoints.length - 1; i++) {
      total += distance.as(
        LengthUnit.Kilometer,
        locationPoints[i].toLatLng(),
        locationPoints[i + 1].toLatLng(),
      );
    }
    return total;
  }

  /// Distance from latest point to office in Kilometers
  double? get distanceFromOfficeKm {
    if (!hasOfficeLocation || latestPoint == null) return null;
    const Distance distance = Distance();
    return distance.as(
      LengthUnit.Kilometer,
      latestPoint!.toLatLng(),
      officeLatLng!,
    );
  }
}
