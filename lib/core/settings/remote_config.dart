// lib/core/settings/remote_config.dart
import 'module_flags.dart';

class AppConfig {
  const AppConfig({
    required this.minSupportedVersion, required this.forceUpdate,
    required this.maintenance, required this.currencySymbol,
    required this.distanceUnit, this.supportEmail, this.supportPhone,
  });

  final String minSupportedVersion;
  final bool forceUpdate;
  final bool maintenance;
  final String currencySymbol;
  final String distanceUnit;
  final String? supportEmail;
  final String? supportPhone;

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        minSupportedVersion: (j['minSupportedVersion'] as String?) ?? '',
        forceUpdate: j['forceUpdate'] == true,
        maintenance: j['maintenance'] == true,
        currencySymbol: (j['currencySymbol'] as String?) ?? '₹',
        distanceUnit: (j['distanceUnit'] as String?) ?? 'km',
        supportEmail: j['supportEmail'] as String?,
        supportPhone: j['supportPhone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'minSupportedVersion': minSupportedVersion, 'forceUpdate': forceUpdate,
        'maintenance': maintenance, 'currencySymbol': currencySymbol,
        'distanceUnit': distanceUnit, 'supportEmail': supportEmail,
        'supportPhone': supportPhone,
      };
}

class RemoteConfig {
  RemoteConfig({required this.app, required this.modules, required this.version, required this.fetchedAt});

  final AppConfig app;
  final ModuleFlags modules;
  final int version;
  final DateTime fetchedAt;

  factory RemoteConfig.fromJson(Map<String, dynamic> j, {DateTime? fetchedAt}) {
    final app = (j['app'] as Map?)?.cast<String, dynamic>() ?? const {};
    final modules = (j['modules'] as Map?)?.cast<String, dynamic>() ?? const {};
    final version = (j['version'] as num?)?.toInt() ?? 0;
    return RemoteConfig(
      app: AppConfig.fromJson(app),
      modules: ModuleFlags.fromJson(modules),
      version: version,
      fetchedAt: fetchedAt ?? DateTime.now(),
    );
  }

  factory RemoteConfig.defaults() => RemoteConfig(
        app: const AppConfig(minSupportedVersion: '', forceUpdate: false, maintenance: false,
                             currencySymbol: '₹', distanceUnit: 'km'),
        modules: ModuleFlags.defaults(), version: 0, fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, dynamic> toJson() => {
        'version': version, 'app': app.toJson(), 'modules': modules.toJson(),
        'fetchedAt': fetchedAt.toIso8601String(),
      };
}
