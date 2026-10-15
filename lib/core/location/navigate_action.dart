import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands a destination to whatever map application the device has.
///
/// Three tiers, in the order that keeps a field officer inside the app the
/// shortest time: the installed maps app through `maps_launcher`, then a `geo:`
/// intent, then a plain Google Maps directions link. Injectable so the tier
/// selection can be tested without a device.
abstract class NavigationLauncher {
  /// Returns true when some map surface accepted the destination.
  Future<bool> open(double latitude, double longitude, {String? label});
}

class PlatformNavigationLauncher implements NavigationLauncher {
  const PlatformNavigationLauncher();

  @override
  Future<bool> open(double latitude, double longitude, {String? label}) async {
    if (!latitude.isFinite || !longitude.isFinite) return false;

    // Tier 1: the installed maps application.
    try {
      if (await MapsLauncher.launchCoordinates(latitude, longitude, label)) {
        return true;
      }
    } catch (error) {
      debugPrint('Maps app launch failed: $error');
    }

    // Tier 2: a geo: intent, which some OEM builds accept when the map app is
    // installed but not registered for the launcher helper above.
    try {
      final geo = Uri.parse(
        'geo:$latitude,$longitude?q=$latitude,$longitude'
        '${label == null || label.trim().isEmpty ? '' : '(${Uri.encodeComponent(label.trim())})'}',
      );
      if (await launchUrl(geo, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (error) {
      debugPrint('geo: launch failed: $error');
    }

    // Tier 3: the browser, which needs no app at all.
    try {
      final web = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
      );
      return await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Maps web launch failed: $error');
      return false;
    }
  }
}

final navigationLauncherProvider = Provider<NavigationLauncher>(
  (ref) => const PlatformNavigationLauncher(),
);
