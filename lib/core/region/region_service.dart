import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import '../../firebase_options.dart';

class RegionInfo {
  const RegionInfo({
    required this.code,
    required this.name,
    required this.apiUrl,
    this.androidConfig,
    this.webConfig,
  });

  final String code;
  final String name;
  final String apiUrl;
  final RegionFirebaseConfig? androidConfig;
  final RegionFirebaseConfig? webConfig;

  factory RegionInfo.fromJson(Map<String, dynamic> json) {
    return RegionInfo(
      code: ((json['code'] ?? json['regionCode']) as String?) ?? '',
      name: ((json['name'] ?? json['regionName']) as String?) ?? '',
      apiUrl: (json['apiUrl'] as String?) ?? '',
      androidConfig:
          json['android'] != null
              ? RegionFirebaseConfig.fromJson(
                json['android'] as Map<String, dynamic>,
              )
              : null,
      webConfig:
          json['web'] != null
              ? RegionFirebaseConfig.fromJson(
                json['web'] as Map<String, dynamic>,
              )
              : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'name': name,
    'apiUrl': apiUrl,
    if (androidConfig != null) 'android': androidConfig!.toJson(),
    if (webConfig != null) 'web': webConfig!.toJson(),
  };
}

class RegionFirebaseConfig {
  const RegionFirebaseConfig({
    required this.apiKey,
    required this.appId,
    required this.projectId,
    required this.messagingSenderId,
    required this.storageBucket,
    this.authDomain,
    this.measurementId,
  });

  final String apiKey;
  final String appId;
  final String projectId;
  final String messagingSenderId;
  final String storageBucket;
  final String? authDomain;
  final String? measurementId;

  factory RegionFirebaseConfig.fromJson(Map<String, dynamic> json) {
    return RegionFirebaseConfig(
      apiKey: (json['apiKey'] as String?) ?? '',
      appId: (json['appId'] as String?) ?? '',
      projectId: (json['projectId'] as String?) ?? '',
      messagingSenderId: (json['messagingSenderId'] as String?) ?? '',
      storageBucket: (json['storageBucket'] as String?) ?? '',
      authDomain: json['authDomain'] as String?,
      measurementId: json['measurementId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'apiKey': apiKey,
    'appId': appId,
    'projectId': projectId,
    'messagingSenderId': messagingSenderId,
    'storageBucket': storageBucket,
    if (authDomain != null) 'authDomain': authDomain,
    if (measurementId != null) 'measurementId': measurementId,
  };

  FirebaseOptions toFirebaseOptions() {
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      projectId: projectId,
      messagingSenderId: messagingSenderId,
      storageBucket: storageBucket,
      authDomain: authDomain ?? '$projectId.firebaseapp.com',
      measurementId: measurementId,
    );
  }

  bool get isComplete =>
      apiKey.trim().isNotEmpty &&
      appId.trim().isNotEmpty &&
      projectId.trim().isNotEmpty &&
      messagingSenderId.trim().isNotEmpty &&
      storageBucket.trim().isNotEmpty;
}

abstract interface class RegionActivationService {
  Future<void> activateRegion(RegionInfo region);
}

abstract interface class RegionConfigurationService {
  Future<RegionInfo?> fetchRegionConfig(String regionCode);
}

class RegionService
    implements RegionActivationService, RegionConfigurationService {
  static const String _savedRegionKey = 'ciss_selected_region';
  static const String _savedRegionConfigKey = 'ciss_selected_region_config';
  static const String _baseUrl = 'https://cisskerala.site';

  final FlutterSecureStorage _secureStorage;
  String? _selectedRegionCode;
  String? _activeRegionCode;
  RegionInfo? _activeRegion;

  static final RegionService instance = RegionService._();
  RegionService._() : _secureStorage = const FlutterSecureStorage();

  /// Fetch the list of available regions from the HQ control plane.
  Future<List<RegionInfo>> fetchAvailableRegions() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/public/regions');
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint(
          'RegionService: failed to fetch regions (HTTP ${response.statusCode})',
        );
        return [await _keralaFallback()];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return [await _keralaFallback()];
      final data = Map<String, dynamic>.from(decoded);
      final list = (data['regions'] as List<dynamic>?) ?? <dynamic>[];
      final regions =
          list
              .map((r) => RegionInfo.fromJson(r as Map<String, dynamic>))
              .where(
                (region) => region.code.isNotEmpty && region.name.isNotEmpty,
              )
              .toList();
      return regions.isNotEmpty ? regions : [await _keralaFallback()];
    } catch (e) {
      debugPrint('RegionService: fetchAvailableRegions error: $e');
      return [await _keralaFallback()];
    }
  }

  /// Save the user's region preference.
  Future<void> saveRegionPreference(
    String regionCode, {
    RegionInfo? region,
  }) async {
    await _secureStorage.write(key: _savedRegionKey, value: regionCode);
    if (region != null) {
      await _secureStorage.write(
        key: _savedRegionConfigKey,
        value: jsonEncode(region.toJson()),
      );
    }
    _selectedRegionCode = regionCode;
    _activeRegionCode = regionCode;
    _activeRegion = region;
  }

  /// Read the previously saved region preference.
  Future<String?> getSavedRegion() async {
    try {
      final saved = await _secureStorage.read(key: _savedRegionKey);
      if (saved != null && saved.isNotEmpty) {
        // A persisted selection is not activation. In particular, never use
        // its cached configuration to route a non-Kerala login to default
        // Firebase before config/init succeeds again.
        _selectedRegionCode = saved;
        return saved;
      }
    } catch (_) {}
    return null;
  }

  /// Clear the saved region preference (e.g. on logout or region change).
  Future<void> clearRegionPreference() async {
    await _secureStorage.delete(key: _savedRegionKey);
    await _secureStorage.delete(key: _savedRegionConfigKey);
    _selectedRegionCode = null;
    _activeRegionCode = null;
    _activeRegion = null;
  }

  /// Get the full region config including Firebase options from HQ.
  @override
  Future<RegionInfo?> fetchRegionConfig(String regionCode) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/public/region-config/$regionCode');
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint(
          'RegionService: config fetch failed (HTTP ${response.statusCode})',
        );
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final data = Map<String, dynamic>.from(decoded);
      return RegionInfo.fromJson(data);
    } catch (e) {
      debugPrint('RegionService: fetchRegionConfig error: $e');
      return null;
    }
  }

  /// Initialize a secondary Firebase app for the given region. This does not
  /// activate it: activation happens only after preference persistence also
  /// succeeds, making config/init/persistence one all-or-nothing operation.
  Future<FirebaseApp?> initRegionalFirebase(RegionInfo region) async {
    final appName = 'region_${region.code}';
    try {
      // Check if already initialized
      try {
        final existing = Firebase.app(appName);
        debugPrint('RegionService: Firebase app "$appName" already exists');
        return existing;
      } catch (_) {
        // Not initialized — proceed
      }

      // Use the config for the current platform. Using Android options on iOS
      // creates a valid-looking Firebase app that cannot authenticate or
      // connect to the intended regional project.
      final platformConfig =
          kIsWeb
              ? region.webConfig
              : defaultTargetPlatform == TargetPlatform.android
              ? region.androidConfig
              : region.webConfig ?? region.androidConfig;
      if (region.code != 'KL' &&
          (platformConfig == null || !platformConfig.isComplete)) {
        throw StateError(
          'Regional Firebase configuration is incomplete for ${region.code}.',
        );
      }
      final options =
          platformConfig?.toFirebaseOptions() ??
          (region.code == 'KL' ? DefaultFirebaseOptions.currentPlatform : null);
      if (options == null) {
        throw StateError(
          'Firebase configuration is unavailable for ${region.code}.',
        );
      }

      final app = await Firebase.initializeApp(name: appName, options: options);
      debugPrint(
        'RegionService: Initialized Firebase app "$appName" for ${region.name}',
      );
      return app;
    } catch (e) {
      debugPrint('RegionService: initRegionalFirebase error: $e');
      return null;
    }
  }

  @override
  Future<void> activateRegion(RegionInfo region) async {
    final code = region.code.trim();
    if (code.isEmpty || region.apiUrl.trim().isEmpty) {
      throw StateError('Region configuration is incomplete.');
    }
    if (code != 'KL') {
      final platformConfig =
          kIsWeb
              ? region.webConfig
              : defaultTargetPlatform == TargetPlatform.android
              ? region.androidConfig
              : region.webConfig ?? region.androidConfig;
      if (platformConfig == null || !platformConfig.isComplete) {
        throw StateError('Region Firebase configuration is incomplete.');
      }
    }

    final app = await initRegionalFirebase(region);
    if (app == null) {
      throw StateError('Region Firebase could not be initialized.');
    }
    await saveRegionPreference(code, region: region);
  }

  /// Get the regional Firebase Auth instance.
  FirebaseAuth? getRegionalAuth(String regionCode) {
    try {
      return FirebaseAuth.instanceFor(app: Firebase.app('region_$regionCode'));
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth get activeAuth {
    final code = _selectedRegionCode ?? _activeRegionCode;
    if (code != null && code != 'KL') {
      final regional = getRegionalAuth(code);
      if (regional != null) return regional;
      throw StateError(
        'Selected regional Firebase authentication is inactive.',
      );
    }
    return FirebaseAuth.instance;
  }

  /// Get the regional Firebase Firestore instance.
  FirebaseFirestore? getRegionalFirestore(String regionCode) {
    try {
      return FirebaseFirestore.instanceFor(
        app: Firebase.app('region_$regionCode'),
      );
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore get activeFirestore {
    final code = _selectedRegionCode ?? _activeRegionCode;
    if (code != null && code != 'KL') {
      final regional = getRegionalFirestore(code);
      if (regional != null) return regional;
      throw StateError('Selected regional Firestore is inactive.');
    }
    return FirebaseFirestore.instance;
  }

  /// Get the regional Firebase Storage instance.
  FirebaseStorage? getRegionalStorage(String regionCode) {
    try {
      return FirebaseStorage.instanceFor(
        app: Firebase.app('region_$regionCode'),
      );
    } catch (_) {
      return null;
    }
  }

  FirebaseStorage get activeStorage {
    final code = _selectedRegionCode ?? _activeRegionCode;
    if (code != null && code != 'KL') {
      final regional = getRegionalStorage(code);
      if (regional != null) return regional;
      throw StateError('Selected regional Firebase Storage is inactive.');
    }
    return FirebaseStorage.instance;
  }

  String get activeApiUrl {
    if (_selectedRegionCode != null && _selectedRegionCode != 'KL') {
      final active = _activeRegion;
      if (active == null || active.apiUrl.trim().isEmpty) {
        throw StateError('Selected regional API is inactive.');
      }
      return active.apiUrl;
    }
    return _activeRegion?.apiUrl.isNotEmpty == true
        ? _activeRegion!.apiUrl
        : _baseUrl;
  }

  RegionInfo? get activeRegion => _activeRegion;

  bool get hasActiveSelectedRegion =>
      _selectedRegionCode == null ||
      _selectedRegionCode == 'KL' ||
      (_activeRegionCode == _selectedRegionCode && _activeRegion != null);

  /// Get the regional API base URL.
  Future<String> getRegionalApiUrl(String regionCode) async {
    if (regionCode == 'KL') return _baseUrl;
    final config = await fetchRegionConfig(regionCode);
    if (config == null || config.apiUrl.trim().isEmpty) {
      throw StateError('Regional API configuration is unavailable.');
    }
    return config.apiUrl;
  }

  /// Fallback: return Kerala as the default region.
  Future<RegionInfo> _keralaFallback() async {
    return RegionInfo(
      code: 'KL',
      name: 'Kerala',
      apiUrl: _baseUrl,
      androidConfig: RegionFirebaseConfig(
        apiKey: DefaultFirebaseOptions.currentPlatform.apiKey,
        appId: DefaultFirebaseOptions.currentPlatform.appId,
        projectId: DefaultFirebaseOptions.currentPlatform.projectId,
        messagingSenderId:
            DefaultFirebaseOptions.currentPlatform.messagingSenderId,
        storageBucket:
            DefaultFirebaseOptions.currentPlatform.storageBucket ?? '',
      ),
    );
  }
}

final regionServiceProvider = Provider<RegionService>((ref) {
  return RegionService.instance;
});

final regionActivationServiceProvider = Provider<RegionActivationService>((
  ref,
) {
  return ref.read(regionServiceProvider);
});

final regionConfigurationServiceProvider = Provider<RegionConfigurationService>(
  (ref) {
    return ref.read(regionServiceProvider);
  },
);

/// Bumps whenever the selected region changes so region-bound Firebase, API,
/// and session providers rebuild from the newly active regional app.
final regionGraphRevisionProvider = StateProvider<int>((ref) => 0);

final availableRegionsProvider = FutureProvider<List<RegionInfo>>((ref) async {
  return ref.read(regionServiceProvider).fetchAvailableRegions();
});

final savedRegionProvider = FutureProvider<String?>((ref) async {
  return ref.read(regionServiceProvider).getSavedRegion();
});

final regionConfigProvider = FutureProvider.autoDispose
    .family<RegionInfo?, String>((ref, regionCode) async {
      return ref.read(regionServiceProvider).fetchRegionConfig(regionCode);
    });
