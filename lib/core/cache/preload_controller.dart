import 'package:flutter_riverpod/flutter_riverpod.dart';

class PreloadController {
  void preloadAllGuard() {}
  void preloadAllFieldOfficer() {}
}

final preloadControllerProvider = Provider<PreloadController>((ref) => PreloadController());
