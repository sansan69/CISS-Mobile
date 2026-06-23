import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pre-warms the Riverpod provider cache after login to reduce skeleton
/// screen FOUC on guard/FO dashboards.
class PreloadController {
  /// TODO: Wire these into auth_controller after sign-in so that guard
  /// screens immediately render with data instead of loading spinners.
  void preloadAllGuard() {
    debugPrint('PreloadController: guard preload not yet implemented');
  }

  void preloadAllFieldOfficer() {
    debugPrint('PreloadController: FO preload not yet implemented');
  }
}

final preloadControllerProvider = Provider<PreloadController>((ref) => PreloadController());
