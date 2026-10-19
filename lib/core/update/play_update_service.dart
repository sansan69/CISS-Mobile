import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

enum PlayUpdateStatus { updateAvailable, upToDate, unavailable }

const isPlayDistribution =
    String.fromEnvironment('CISS_DISTRIBUTION', defaultValue: 'sideload') ==
    'play';

abstract interface class PlayUpdateSource {
  Future<PlayUpdateStatus> check();
  Future<bool> install();
}

class GooglePlayUpdateSource implements PlayUpdateSource {
  @override
  Future<PlayUpdateStatus> check() async {
    final info = await InAppUpdate.checkForUpdate();
    return info.updateAvailability == UpdateAvailability.updateAvailable
        ? PlayUpdateStatus.updateAvailable
        : PlayUpdateStatus.upToDate;
  }

  @override
  Future<bool> install() async =>
      await InAppUpdate.performImmediateUpdate() == AppUpdateResult.success;
}

class PlayUpdateService {
  PlayUpdateService({PlayUpdateSource? source, bool? enabled})
    : _source = source ?? GooglePlayUpdateSource(),
      _enabled =
          enabled ??
          (isPlayDistribution &&
              defaultTargetPlatform == TargetPlatform.android);
  final PlayUpdateSource _source;
  final bool _enabled;
  Future<PlayUpdateStatus> check() async {
    if (!_enabled) return PlayUpdateStatus.unavailable;
    try {
      return await _source.check();
    } catch (_) {
      return PlayUpdateStatus.unavailable;
    }
  }

  Future<bool> available() async =>
      await check() == PlayUpdateStatus.updateAvailable;

  Future<bool> install() async {
    if (!_enabled) return false;
    try {
      return await _source.install();
    } catch (_) {
      return false;
    }
  }
}

bool isBelowMinimumVersion(String installedVersion, String minimumVersion) {
  if (minimumVersion.trim().isEmpty) return false;
  final installed = _numericVersion(installedVersion);
  final minimum = _numericVersion(minimumVersion);
  if (installed == null || minimum == null) return false;
  final length = installed.length > minimum.length
      ? installed.length
      : minimum.length;
  for (var index = 0; index < length; index++) {
    final current = index < installed.length ? installed[index] : 0;
    final required = index < minimum.length ? minimum[index] : 0;
    if (current != required) return current < required;
  }
  return false;
}

bool shouldShowPlayUpdate(
  PlayUpdateStatus status, {
  required bool mandatory,
}) =>
    mandatory || status == PlayUpdateStatus.updateAvailable;

List<int>? _numericVersion(String value) {
  final core = value.split('+').first.split('-').first;
  final parts = core.split('.');
  if (parts.isEmpty || parts.any((part) => int.tryParse(part) == null)) {
    return null;
  }
  return parts.map(int.parse).toList();
}

final playUpdateServiceProvider = Provider((ref) => PlayUpdateService());
