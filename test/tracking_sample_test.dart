import 'package:ciss_mobile/core/location/tracking_sample.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson uses AMS field names', () {
    final s = TrackingSample(
      status: 'in', latitude: 12.9, longitude: 80.2, accuracy: 8, locationAccuracy: 8,
      altitude: 12, bearing: 90, speed: 1.4, activity: 'walking',
      isMock: false, isGPSOn: true, wifiConnected: true, batteryPercentage: 78,
      networkType: 'wifi', time: DateTime.utc(2026, 1, 1),
    );
    final j = s.toJson();
    expect(j['latitude'], 12.9);
    expect(j['batteryPercentage'], 78);
    expect(j['isMock'], false);
    expect(j['isGPSOn'], true);
    expect(j['activity'], 'walking');
    expect(j.containsKey('time'), isTrue);
  });

  test('activity mapping', () {
    expect(mapActivity(null), 'unknown');
    expect(mapActivity(7), 'walking'); // ActivityType.walking
  });
}
