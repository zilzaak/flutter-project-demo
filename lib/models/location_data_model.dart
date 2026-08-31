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