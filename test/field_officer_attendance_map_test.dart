import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/models/mobile_dashboard_models.dart';

void main() {
  test('parses field-officer site coordinates from the sites endpoint', () {
    final site = FieldOfficerSiteOption.fromJson(<String, dynamic>{
      'siteId': 'site-1',
      'siteName': 'Samsung HQ',
      'latitude': 10.1234,
      'longitude': 76.5678,
    });

    expect(site.id, 'site-1');
    expect(site.latitude, 10.1234);
    expect(site.longitude, 76.5678);
  });

  test('reads recorded attendance coordinates across legacy key names', () {
    final entry = FieldOfficerAttendanceEntry.fromJson(<String, dynamic>{
      'id': 'attendance-1',
      'guardName': 'Manoj N M',
      'siteName': 'Samsung HQ',
      'locationCoords': <String, dynamic>{
        'latitude': 10.1234,
        'longitude': 76.5678,
      },
    });

    expect(entry.attendanceLatitude, 10.1234);
    expect(entry.attendanceLongitude, 76.5678);
  });
}
