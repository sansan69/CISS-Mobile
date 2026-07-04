import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../region/region_service.dart';

class AndroidUpdateInfo {
  const AndroidUpdateInfo({
    required this.latestVersionName,
    required this.latestVersionCode,
    required this.minimumSupportedVersionCode,
    required this.apkUrl,
    required this.sha256,
    required this.sizeBytes,
    required this.releaseNotes,
    required this.mandatory,
  });

  final String latestVersionName;
  final int latestVersionCode;
  final int minimumSupportedVersionCode;
  final String apkUrl;
  final String sha256;
  final int sizeBytes;
  final List<String> releaseNotes;
  final bool mandatory;

  factory AndroidUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AndroidUpdateInfo(
      latestVersionName: (json['latestVersionName'] as String?) ?? '',
      latestVersionCode: _intValue(json['latestVersionCode']),
      minimumSupportedVersionCode: _intValue(
        json['minimumSupportedVersionCode'],
      ),
      apkUrl: (json['apkUrl'] as String?) ?? (json['apkPath'] as String?) ?? '',
      sha256: (json['sha256'] as String?) ?? '',
      sizeBytes: _intValue(json['sizeBytes']),
      releaseNotes:
          ((json['releaseNotes'] as List<dynamic>?) ?? const <dynamic>[])
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList(),
      mandatory: json['mandatory'] == true,
    );
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.currentVersionName,
    required this.currentVersionCode,
    required this.update,
  });

  final String currentVersionName;
  final int currentVersionCode;
  final AndroidUpdateInfo? update;

  bool get hasUpdate =>
      update != null && update!.latestVersionCode > currentVersionCode;
  bool get isMandatory =>
      hasUpdate && currentVersionCode < update!.minimumSupportedVersionCode;
}

class AppUpdateService {
  AppUpdateService(this._regionService);

  final RegionService _regionService;

  Future<AppUpdateCheckResult?> checkForAndroidUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      final baseUrl = _regionService.activeApiUrl.replaceAll(RegExp(r'/$'), '');
      final uri = Uri.parse('$baseUrl/api/public/app-update');
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint(
          'AppUpdateService: update check failed HTTP ${response.statusCode}',
        );
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final update = AndroidUpdateInfo.fromJson(data);
      return AppUpdateCheckResult(
        currentVersionName: packageInfo.version,
        currentVersionCode: currentBuild,
        update: update.latestVersionCode > currentBuild ? update : null,
      );
    } catch (error) {
      debugPrint('AppUpdateService: update check error: $error');
      return null;
    }
  }

  Future<bool> openUpdate(AndroidUpdateInfo update) async {
    final uri = Uri.tryParse(update.apkUrl);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService(ref.read(regionServiceProvider));
});
