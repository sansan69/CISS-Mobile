import 'dart:io';

import 'package:ciss_mobile/core/location/address_cache.dart';
import 'package:hive/hive.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts lookups and answers with a fixed address.
class _FakeGeocoder implements ReverseGeocoder {
  _FakeGeocoder({this.address = 'Main Gate, MG Road, Ernakulam 682011'});

  String? address;
  bool throwOnLookup = false;
  final List<String> calls = <String>[];

  @override
  Future<String?> lookup(double latitude, double longitude) async {
    calls.add(AddressResolver.cacheKey(latitude, longitude));
    if (throwOnLookup) throw StateError('geocoder unavailable');
    return address;
  }
}

void main() {
  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('ciss-address-').path);
  });
  tearDownAll(() async => Hive.close());

  group('address resolver', () {
    test('rounds coordinates to about a metre for the cache key', () {
      expect(
        AddressResolver.cacheKey(9.981234567, 76.287654321),
        '9.98123,76.28765',
      );
      expect(
        AddressResolver.cacheKey(9.981231, 76.287652),
        AddressResolver.cacheKey(9.981234, 76.287651),
      );
    });

    test('resolves without a cache box instead of failing', () async {
      final geocoder = _FakeGeocoder();
      final resolver = AddressResolver(geocoder: geocoder);
      // No box open: the lookup still answers, it just cannot be cached.
      expect(
        await resolver.forCoordinates(9.98, 76.28),
        'Main Gate, MG Road, Ernakulam 682011',
      );
      expect(geocoder.calls, hasLength(1));
    });

    test('rejects missing and non-finite coordinates', () async {
      final resolver = AddressResolver(geocoder: _FakeGeocoder());
      expect(await resolver.forCoordinates(null, null), isNull);
      expect(await resolver.forCoordinates(double.nan, 76.28), isNull);
      expect(await resolver.forCoordinates(9.98, double.infinity), isNull);
    });
  });

  group('address cache', () {
    late Box<dynamic> box;
    late DateTime clock;

    setUp(() async {
      box = await Hive.openBox<dynamic>(AddressResolver.boxName);
      await box.clear();
      clock = DateTime(2026, 10, 15, 10);
    });

    tearDown(() async {
      await box.deleteFromDisk();
    });

    test('resolves once and serves the second read from the cache', () async {
      final geocoder = _FakeGeocoder();
      final resolver = AddressResolver(geocoder: geocoder, now: () => clock);

      const lat = 9.98123;
      const lng = 76.28765;
      expect(
        await resolver.forCoordinates(lat, lng),
        'Main Gate, MG Road, Ernakulam 682011',
      );
      expect(await resolver.forCoordinates(lat, lng), isNotNull);
      expect(geocoder.calls, hasLength(1));

      // A neighbouring fix inside the same metre reads the same entry.
      await resolver.forCoordinates(9.981234, 76.287651);
      expect(geocoder.calls, hasLength(1));
    });

    test('re-resolves after the ttl expires', () async {
      final geocoder = _FakeGeocoder();
      final resolver = AddressResolver(geocoder: geocoder, now: () => clock);
      await resolver.forCoordinates(9.98, 76.28);

      clock = clock.add(const Duration(hours: 7));
      geocoder.address = 'Updated address';
      expect(await resolver.forCoordinates(9.98, 76.28), 'Updated address');
      expect(geocoder.calls, hasLength(2));
    });

    test('an offline lookup returns null and caches nothing', () async {
      final geocoder = _FakeGeocoder(address: null);
      final resolver = AddressResolver(geocoder: geocoder, now: () => clock);
      expect(await resolver.forCoordinates(9.98, 76.28), isNull);
      expect(box.isEmpty, isTrue);
    });

    test('a geocoder failure is answered as unknown, not thrown', () async {
      final geocoder = _FakeGeocoder()..throwOnLookup = true;
      final resolver = AddressResolver(geocoder: geocoder, now: () => clock);
      expect(await resolver.forCoordinates(9.98, 76.28), isNull);
      expect(box.isEmpty, isTrue);
    });
  });
}
