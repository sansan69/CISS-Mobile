String mapActivity(int? activityType) {
  switch (activityType) {
    case 3:
      return 'still'; // still
    case 7:
      return 'walking'; // walking
    case 8:
      return 'traveling'; // running -> traveling (AMS umbrella)
    case 0:
      return 'in_vehicle'; // in_vehicle
    case 1:
      return 'on_bicycle'; // on_bicycle
    default:
      return 'unknown';
  }
}

class TrackingSample {
  TrackingSample({
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.locationAccuracy,
    required this.activity,
    required this.isMock,
    required this.isGPSOn,
    required this.wifiConnected,
    required this.networkType,
    required this.time,
    this.altitude,
    this.bearing,
    this.speed,
    this.batteryPercentage,
  });

  final String? status;
  final double latitude, longitude, accuracy, locationAccuracy;
  final double? altitude, bearing, speed;
  final String activity;
  final bool isMock, isGPSOn, wifiConnected;
  final int? batteryPercentage;
  final String networkType;
  final DateTime time;

  Map<String, dynamic> toJson() => {
        'status': status,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'locationAccuracy': locationAccuracy,
        'altitude': altitude,
        'bearing': bearing,
        'speed': speed,
        'activity': activity,
        'isMock': isMock,
        'isGPSOn': isGPSOn,
        'batteryPercentage': batteryPercentage,
        'wifiConnected': wifiConnected,
        'networkType': networkType,
        'time': time.millisecondsSinceEpoch,
        'capturedAt': time.toUtc().toIso8601String(),
      };
}
