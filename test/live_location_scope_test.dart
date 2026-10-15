import 'package:ciss_mobile/core/location/live_location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('live location scope', () {
    test('an officer with one district reads that district', () {
      final scope = liveLocationScope(districts: <String>['Ernakulam']);
      expect(scope.kind, LiveLocationScopeKind.single);
      expect(scope.values, <String>['Ernakulam']);
    });

    test('an explicit district wins and is not duplicated', () {
      final scope = liveLocationScope(
        districts: <String>['Ernakulam', 'Kollam'],
        district: 'Kollam',
      );
      expect(scope.kind, LiveLocationScopeKind.single);
      expect(scope.values, <String>['Kollam']);
    });

    test('several districts become one in-filter', () {
      final scope = liveLocationScope(
        districts: <String>['Ernakulam', ' Kollam ', ''],
      );
      expect(scope.kind, LiveLocationScopeKind.many);
      expect(scope.values, <String>['Ernakulam', 'Kollam']);
    });

    test('no districts reads every district, which only staff may do', () {
      expect(
        liveLocationScope().kind,
        LiveLocationScopeKind.everyDistrict,
      );
      expect(
        liveLocationScope(districts: <String>['', '  ']).values,
        isEmpty,
      );
    });

    test('a long district list stays inside the Firestore in-filter limit', () {
      final scope = liveLocationScope(
        districts: <String>[
          for (var index = 0; index < 45; index++) 'District $index',
        ],
      );
      expect(scope.kind, LiveLocationScopeKind.many);
      expect(scope.values, hasLength(LiveLocationService.maxScopeValues));
    });
  });
}
