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
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      apiUrl: (json['apiUrl'] as String?) ?? '',
      androidConfig: json['android'] != null
          ? RegionFirebaseConfig.fromJson(json['android'] as Map<String, dynamic>)
          : null,
      webConfig: json['web'] != null
          ? RegionFirebaseConfig.fromJson(json['web'] as Map<String, dynamic>)
          : null,
    );
  }
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
}

class RegionService {
  RegionService() : _secureStorage = const FlutterSecureStorage();

  static const String _savedRegionKey = 'ciss_selected_region';
  static const String _baseUrl = 'https://cisskerala.site';

  final FlutterSecureStorage _secureStorage;
  String? _activeRegionCode;

  static final RegionService instance = RegionService._();
  RegionService._();

  /// Fetch the list of available regions from the HQ control plane.
  Future<List<RegionInfo>> fetchAvailableRegions() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/public/regions');
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
      });
      if (response.statusCode != 200) {
        debugPrint('RegionService: failed to fetch regions (HTTP ${response.statusCode})');
        return [await _keralaFallback()];
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['regions'] as List<dynamic>?) ?? <dynamic>[];
      return list.map((r) => RegionInfo.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('RegionService: fetchAvailableRegions error: $e');
      return [await _keralaFallback()];
    }
  }

  /// Save the user's region preference.
  Future<void> saveRegionPreference(String regionCode) async {
    try {
      await _secureStorage.write(key: _savedRegionKey, value: regionCode);
      _activeRegionCode = regionCode;
    } catch (e) {
      debugPrint('RegionService: saveRegionPreference error: $e');
    }
  }

  /// Read the previously saved region preference.
  Future<String?> getSavedRegion() async {
    try {
      final saved = await _secureStorage.read(key: _savedRegionKey);
      if (saved != null && saved.isNotEmpty) {
        _activeRegionCode = saved;
        return saved;
      }
    } catch (_) {}
    return null;
  }

  /// Clear the saved region preference (e.g. on logout or region change).
  Future<void> clearRegionPreference() async {
    try {
      await _secureStorage.delete(key: _savedRegionKey);
      _activeRegionCode = null;
    } catch (_) {}
  }

  /// Get the full region config including Firebase options from HQ.
  Future<RegionInfo?> fetchRegionConfig(String regionCode) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/public/region-config/$regionCode');
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
      });
      if (response.statusCode != 200) {
        debugPrint('RegionService: config fetch failed (HTTP ${response.statusCode})');
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return RegionInfo.fromJson(data);
    } catch (e) {
      debugPrint('RegionService: fetchRegionConfig error: $e');
      return null;
    }
  }

  /// Initialize a secondary Firebase app for the given region.
  /// Returns the named Firebase app, or null if it already exists.
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

      // Use Android config if available, otherwise fall back to web config
      final options = region.androidConfig?.toFirebaseOptions() ??
          region.webConfig?.toFirebaseOptions() ??
          DefaultFirebaseOptions.currentPlatform;

      final app = await Firebase.initializeApp(
        name: appName,
        options: options,
      );

      _activeRegionCode = region.code;
      debugPrint('RegionService: Initialized Firebase app "$appName" for ${region.name}');
      return app;
    } catch (e) {
      debugPrint('RegionService: initRegionalFirebase error: $e');
      return null;
    }
  }

  /// Get the regional Firebase Auth instance.
  FirebaseAuth? getRegionalAuth(String regionCode) {
    try {
      return FirebaseAuth.instanceFor(app: Firebase.app('region_$regionCode'));
    } catch (_) {
      return null;
    }
  }

  /// Get the regional Firebase Firestore instance.
  FirebaseFirestore? getRegionalFirestore(String regionCode) {
    try {
      return FirebaseFirestore.instanceFor(app: Firebase.app('region_$regionCode'));
    } catch (_) {
      return null;
    }
  }

  /// Get the regional Firebase Storage instance.
  FirebaseStorage? getRegionalStorage(String regionCode) {
    try {
      return FirebaseStorage.instanceFor(app: Firebase.app('region_$regionCode'));
    } catch (_) {
      return null;
    }
  }

  /// Get the regional API base URL.
  Future<String> getRegionalApiUrl(String regionCode) async {
    if (regionCode == 'KL') return _baseUrl;
    final config = await fetchRegionConfig(regionCode);
    return config?.apiUrl ?? _baseUrl;
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
        messagingSenderId: DefaultFirebaseOptions.currentPlatform.messagingSenderId,
        storageBucket: DefaultFirebaseOptions.currentPlatform.storageBucket,
      ),
    );
  }
}

final regionServiceProvider = Provider<RegionService>((ref) {
  return RegionService.instance;
});

final availableRegionsProvider = FutureProvider<List<RegionInfo>>((ref) async {
  return ref.read(regionServiceProvider).fetchAvailableRegions();
});

final savedRegionProvider = FutureProvider<String?>((ref) async {
  return ref.read(regionServiceProvider).getSavedRegion();
});

final regionConfigProvider = FutureProvider.family<RegionInfo?, String>((ref, regionCode) async {
  return ref.read(regionServiceProvider).fetchRegionConfig(regionCode);
});
