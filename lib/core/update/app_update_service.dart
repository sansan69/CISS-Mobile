import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

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

/// Result of an attempted in-app update installation.
sealed class InstallResult {
  const InstallResult();
}

class InstallSuccess extends InstallResult {
  const InstallSuccess();
}

class InstallNeedsPermission extends InstallResult {
  const InstallNeedsPermission();
}

class InstallFailed extends InstallResult {
  const InstallFailed(this.message);
  final String message;
}

/// The downloaded APK failed native package/signer verification.
///
/// This is a security refusal, not a transient failure: the gate must not
/// offer the browser fallback for this result.
class InstallSignatureRejected extends InstallResult {
  const InstallSignatureRejected(this.reason);
  final String reason;
}

/// Result of the native APK package/signer verification.
///
/// [verified] is only true when the archive's package name and every signer
/// digest match the production values baked into [AppUpdateService].
class ApkVerification {
  const ApkVerification({
    required this.verified,
    this.packageName,
    this.signerSha256,
    this.reason,
  });

  const ApkVerification.failed(String this.reason)
    : verified = false,
      packageName = null,
      signerSha256 = null;

  final bool verified;
  final String? packageName;
  final String? signerSha256;
  final String? reason;
}

class AppUpdateService {
  AppUpdateService(this._regionService);

  final RegionService _regionService;
  static const MethodChannel _channel = MethodChannel(
    'co.in.ciss.ciss_mobile/apk_installer',
  );

  /// The production package id; must match `applicationId` in
  /// `android/app/build.gradle.kts`.
  static const String productionPackageName = 'co.in.ciss.ciss_mobile';

  /// SHA-256 of the production signing certificate (DER), lower-case hex.
  ///
  /// This is the pinned identity of a genuine CISS Workforce build. The
  /// manifest SHA-256 only proves the file matches the server's own claim;
  /// this digest proves *who* signed it (F-08 / P-04).
  static const String productionSignerSha256 =
      'e5ee3fd603d258abe3bcf0364589dc13c2e8afcc3c063d33edbb68cf1b5c29aa';

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

  /// Check whether this device can install APKs from unknown sources.
  Future<bool> canInstallApk() async {
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } catch (e) {
      debugPrint('ApkInstaller.canInstall error: $e');
      return false;
    }
  }

  /// Open the system "Install unknown apps" settings page for this app.
  Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod('openInstallSettings');
    } catch (e) {
      debugPrint('ApkInstaller.openInstallSettings error: $e');
    }
  }

  /// Verify the APK at [localPath] natively before it is handed to the
  /// Package Installer.
  ///
  /// The native side uses `PackageManager.getPackageArchiveInfo(path,
  /// GET_SIGNING_CERTIFICATES)` to read the archive's package name and signer
  /// certificate digests, then compares them with [productionPackageName] and
  /// [productionSignerSha256]. Any channel failure or parse failure is
  /// reported as *not verified* so the caller fails closed.
  Future<ApkVerification> verifyApk(String localPath) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const ApkVerification.failed(
        'APK verification is only available on Android.',
      );
    }
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('verifyApk', <String, dynamic>{
            'path': localPath,
            'expectedPackageName': productionPackageName,
            'expectedCertSha256': productionSignerSha256,
          });
      if (result == null) {
        return const ApkVerification.failed(
          'The package installer returned no verification result.',
        );
      }
      return ApkVerification(
        verified: result['verified'] == true,
        packageName: result['packageName'] as String?,
        signerSha256: result['signerSha256'] as String?,
        reason: result['reason'] as String?,
      );
    } on PlatformException catch (e) {
      return ApkVerification.failed(e.message ?? e.code);
    } catch (e) {
      return ApkVerification.failed(e.toString());
    }
  }

  /// Install the APK at [localPath] via the Package Installer.
  ///
  /// The file is verified first ([verifyApk]); a mismatch is refused with
  /// [InstallSignatureRejected] and nothing is handed to the installer.
  ///
  /// Returns [InstallSuccess] if the intent was sent (user still needs to
  /// confirm in the system dialog). Returns [InstallNeedsPermission] if the
  /// user needs to grant "Install unknown apps" first. Returns [InstallFailed]
  /// on any other error — caller should fall back to the browser download.
  Future<InstallResult> installUpdate(String localPath) async {
    final verification = await verifyApk(localPath);
    if (!verification.verified) {
      return InstallSignatureRejected(
        verification.reason ??
            'The downloaded file is not a genuine CISS Workforce build.',
      );
    }
    try {
      await _channel.invokeMethod('installApk', {'path': localPath});
      return const InstallSuccess();
    } on PlatformException catch (e) {
      // MethodChannel errors
      if (e.code == 'INSTALL_FAILED' &&
          (e.message?.contains('Permission') == true ||
              e.message?.contains('Unknown sources') == true)) {
        return const InstallNeedsPermission();
      }
      return InstallFailed(e.message ?? 'Unknown install error');
    } catch (e) {
      return InstallFailed(e.toString());
    }
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService(ref.read(regionServiceProvider));
});
