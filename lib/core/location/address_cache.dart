import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// One reverse-geocoding lookup. Injectable so tests never reach the platform
/// geocoder, and so a build without the plugin still compiles.
abstract class ReverseGeocoder {
  Future<String?> lookup(double latitude, double longitude);
}

class PlatformReverseGeocoder implements ReverseGeocoder {
  const PlatformReverseGeocoder();

  @override
  Future<String?> lookup(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;
      final placemark = placemarks.first;
      final parts = <String?>[
        placemark.name,
        placemark.thoroughfare,
        placemark.subLocality,
        placemark.locality,
        placemark.postalCode,
      ];
      final line = <String>[];
      for (final part in parts) {
        final value = part?.trim() ?? '';
        if (value.isEmpty) continue;
        // Long Indian addresses repeat the locality inside the name.
        if (line.any((seen) => seen.toLowerCase() == value.toLowerCase())) {
          continue;
        }
        line.add(value);
      }
      return line.isEmpty ? null : line.join(', ');
    } catch (_) {
      // Offline, no geocoder service, or a platform failure: the caller shows
      // coordinates instead, which is never an error state.
      return null;
    }
  }
}

/// Where resolved addresses are kept between lookups.
///
/// The store is written through and read synchronously: a cache that makes the
/// caller wait on disk before showing an address is slower than not caching it,
/// and a test can substitute an in-memory store instead of opening Hive.
abstract class AddressCacheStore {
  Map<String, dynamic>? read(String key);

  void write(String key, Map<String, dynamic> value);
}

class HiveAddressCacheStore implements AddressCacheStore {
  const HiveAddressCacheStore();

  @override
  Map<String, dynamic>? read(String key) {
    if (!Hive.isBoxOpen(AddressResolver.boxName)) return null;
    final raw = Hive.box<dynamic>(AddressResolver.boxName).get(key);
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  @override
  void write(String key, Map<String, dynamic> value) {
    if (!Hive.isBoxOpen(AddressResolver.boxName)) return;
    // Fire and forget: the address is already in the caller's hand, and a
    // failed cache write must not surface as a failed lookup.
    unawaited(
      Hive.box<dynamic>(AddressResolver.boxName).put(key, value).catchError((
        Object _,
      ) {
        // Deliberately ignored.
      }),
    );
  }
}

/// Store for tests and for a build without a cache box.
class MemoryAddressCacheStore implements AddressCacheStore {
  final Map<String, Map<String, dynamic>> entries =
      <String, Map<String, dynamic>>{};

  @override
  Map<String, dynamic>? read(String key) => entries[key];

  @override
  void write(String key, Map<String, dynamic> value) {
    entries[key] = value;
  }
}

/// Turns coordinates into an address, cached on device.
///
/// Reverse geocoding is a platform call that needs the network, and attendance
/// rows re-render constantly, so results are cached for [ttl] under the
/// coordinates rounded to five decimals (about a metre). A lookup that fails
/// returns null instead of throwing.
class AddressResolver {
  AddressResolver({
    ReverseGeocoder? geocoder,
    DateTime Function()? now,
    AddressCacheStore? store,
    this.ttl = const Duration(hours: 6),
  }) : _geocoder = geocoder ?? const PlatformReverseGeocoder(),
       _now = now ?? DateTime.now,
       _store = store ?? const HiveAddressCacheStore();

  final ReverseGeocoder _geocoder;
  final DateTime Function() _now;
  final AddressCacheStore _store;
  final Duration ttl;

  static const String boxName = 'address_cache';

  /// Cache key for a coordinate pair. Five decimals keeps two guards standing
  /// at the same gate on the same entry without collapsing a whole district.
  static String cacheKey(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';

  Future<void> init() async {
    await Hive.openBox<dynamic>(boxName);
  }

  Future<String?> forCoordinates(double? latitude, double? longitude) async {
    if (latitude == null || longitude == null) return null;
    if (!latitude.isFinite || !longitude.isFinite) return null;

    final key = cacheKey(latitude, longitude);
    final cached = _readCache(key);
    if (cached != null) return cached;

    String? resolved;
    try {
      resolved = await _geocoder.lookup(latitude, longitude);
    } catch (_) {
      // The contract of this resolver is "null when unknown", so a geocoder
      // that throws is answered the same way as one that has nothing to say.
      return null;
    }
    final address = resolved?.trim() ?? '';
    if (address.isEmpty) return null;
    _store.write(key, <String, dynamic>{
      'address': address,
      'at': _now().toIso8601String(),
    });
    return address;
  }

  String? _readCache(String key) {
    final raw = _store.read(key);
    if (raw == null) return null;
    final address = raw['address'];
    final at = DateTime.tryParse(raw['at']?.toString() ?? '');
    if (address is! String || address.trim().isEmpty || at == null) return null;
    if (_now().difference(at) > ttl) return null;
    return address;
  }
}

final reverseGeocoderProvider = Provider<ReverseGeocoder>(
  (ref) => const PlatformReverseGeocoder(),
);

final addressResolverProvider = Provider<AddressResolver>(
  (ref) => AddressResolver(geocoder: ref.watch(reverseGeocoderProvider)),
);
