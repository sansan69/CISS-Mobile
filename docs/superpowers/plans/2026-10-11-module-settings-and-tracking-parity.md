# Module Settings Gating + Attendance/Tracking Parity — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a server-driven module-gating subsystem and bring attendance/tracking payloads to CISS-AMS parity in the `ciss_mobile` Flutter app.

**Architecture:** One `RemoteConfig` value (app config + `ModuleFlags`) fetched from `GET /api/mobile/settings`, cached encrypted in Hive, exposed via `remoteConfigProvider`, and enforced by a GoRouter `redirect` + `ModuleGate` widget (hard-hide + redirect). Tracking parity extends the existing `BackgroundTrackingService` heartbeat with AMS field names, adds a Hive `TrackingBuffer` flushed via a batch endpoint, a break/early-checkout state machine, and server-authoritative geo+IP validation.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), go_router, Hive (`hive_flutter`), Dio, geolocator, new dep `flutter_activity_recognition`.

**Spec:** `docs/superpowers/specs/2026-10-11-module-settings-and-tracking-parity-design.md`

## Global Constraints

- Backend endpoints (ours, `https://cisskerala.site`): `GET /api/mobile/settings`, `POST /api/mobile/attendance/break`, `POST /api/mobile/attendance/validate`, `POST /api/mobile/tracking/batch`. Heartbeat stays `POST /api/guard/tracking/heartbeat`.
- Tracking/attendance fields use **AMS names**: `latitude, longitude, accuracy, locationAccuracy, altitude, bearing, speed, activity, status, isMock, isGPSOn, batteryPercentage, wifiConnected, networkType, time, capturedAt, earlyCheckOutReason`.
- **Never fail-closed**: on fetch error keep cache; with no cache use `ModuleFlags.defaults`. Only `app.forceUpdate` / `app.maintenance` may block.
- **Zero behavior change until enabled**: break/geoFence/ipAttendance paths sit behind module flags (defaults below); nothing new activates until the server enables it.
- `ModuleFlags.defaults` ON = `attendance, qrAttendance, offlineTracking, biometricVerification, leave, documents, payslips, patrol, incidents, evaluations, training, workOrders, reports, break, geoFence`; everything else OFF.
- Names must not collide with the existing theme `AppSettingsController` / Hive box `app_settings` (see spec naming note).
- Gates for every task: `flutter analyze` clean and `flutter test` green (existing `test/` suite must not regress).
- No new HRMS screens in this plan.

---

## File Structure

**Create**
- `lib/core/settings/module_flags.dart` — `ModuleFlags` + defaults.
- `lib/core/settings/remote_config.dart` — `RemoteConfig` + `AppConfig` models + JSON parse.
- `lib/core/settings/remote_config_store.dart` — encrypted Hive cache keyed `region:role`.
- `lib/core/settings/remote_config_provider.dart` — fetch/cache/refresh provider.
- `lib/core/settings/route_modules.dart` — pure path→module map + decision fn.
- `lib/core/settings/module_gate.dart` — `ModuleGate` widget + `moduleEnabled` helper.
- `lib/features/shared/module_unavailable_screen.dart` — `/module-unavailable` screen.
- `lib/core/location/tracking_sample.dart` — `TrackingSample` model + AMS mapping.
- `lib/core/location/tracking_buffer.dart` — capped Hive buffer.
- `lib/core/location/public_ip.dart` — optional public-IP hint lookup.
- `lib/core/attendance/attendance_session.dart` — break state machine + `AttendanceValidator`.

**Modify**
- `lib/core/location/background_tracking_service.dart` — enriched heartbeat + buffer write.
- `lib/core/sync/sync_service.dart` — register `/api/mobile/tracking/batch`.
- `lib/core/network/mobile_repository.dart` — `fetchRemoteConfig`, `startBreak/stopBreak`, `validateAttendance`.
- `lib/app/app.dart` — watch `routerProvider`.
- `lib/app/router/app_router.dart` — provider + `redirect` + `/module-unavailable`.
- `lib/main.dart` — open `remote_config` box (encrypted) and init.
- Guard/FO dashboards, More, FO tools — respect module flags.
- `lib/features/guard/presentation/screens/guard_attendance_screen.dart` + `field_officer_attendance_screen.dart` — break UI + reason sheet + validation.
- `pubspec.yaml` — add `flutter_activity_recognition`.
- `android/app/src/main/AndroidManifest.xml` — add `ACTIVITY_RECOGNITION` permission.

---

## Phase A — Module settings gating

### Task A1: `ModuleFlags` model + defaults

**Files:**
- Create: `lib/core/settings/module_flags.dart`
- Test: `test/module_flags_test.dart`

**Interfaces:**
- Produces: `class ModuleFlags { ModuleFlags(Map<String,bool> values); factory ModuleFlags.fromJson(Map<String,dynamic>); factory ModuleFlags.defaults(); bool isOn(String key, {required bool fallback}); bool get geoFence; bool get ipAttendance; bool get breakEnabled; bool get qrAttendance; bool get offlineTracking; Map<String,bool> toJson(); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/module_flags_test.dart
import 'package:ciss_mobile/core/settings/module_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses provided flags and falls back for unknown keys', () {
    final f = ModuleFlags.fromJson({'leave': true, 'loan': false});
    expect(f.isOn('leave', fallback: false), isTrue);
    expect(f.isOn('loan', fallback: true), isFalse);
    expect(f.isOn('neverSent', fallback: true), isTrue);
    expect(f.isOn('neverSent', fallback: false), isFalse);
  });

  test('defaults keeps shipped modules on and new modules off', () {
    final f = ModuleFlags.defaults();
    expect(f.isOn('attendance', fallback: false), isTrue);
    expect(f.isOn('break', fallback: false), isTrue);
    expect(f.isOn('leave', fallback: false), isTrue);
    expect(f.isOn('loan', fallback: true), isFalse);
    expect(f.isOn('ipAttendance', fallback: true), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/module_flags_test.dart`
Expected: FAIL (target of URI doesn't exist)

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/settings/module_flags.dart
class ModuleFlags {
  ModuleFlags(Map<String, bool> values) : _values = Map<String, bool>.from(values);
  final Map<String, bool> _values;

  factory ModuleFlags.fromJson(Map<String, dynamic> json) => ModuleFlags(
        json.map((k, v) => MapEntry(k, v == true)),
      );

  factory ModuleFlags.defaults() => ModuleFlags(const <String, bool>{
        'attendance': true,
        'qrAttendance': true,
        'offlineTracking': true,
        'biometricVerification': true,
        'leave': true,
        'documents': true,
        'payslips': true,
        'patrol': true,
        'incidents': true,
        'evaluations': true,
        'training': true,
        'workOrders': true,
        'reports': true,
        'break': true,
        'geoFence': true,
      });

  bool isOn(String key, {required bool fallback}) => _values[key] ?? fallback;

  bool get geoFence => isOn('geoFence', fallback: true);
  bool get ipAttendance => isOn('ipAttendance', fallback: false);
  bool get breakEnabled => isOn('break', fallback: true);
  bool get qrAttendance => isOn('qrAttendance', fallback: true);
  bool get offlineTracking => isOn('offlineTracking', fallback: true);

  Map<String, bool> toJson() => Map<String, bool>.from(_values);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/module_flags_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/settings/module_flags.dart test/module_flags_test.dart
git commit -m "feat(settings): add ModuleFlags model with shipped-module defaults"
```

### Task A2: `RemoteConfig` model + parse

**Files:**
- Create: `lib/core/settings/remote_config.dart`
- Test: `test/remote_config_test.dart`

**Interfaces:**
- Consumes: `ModuleFlags` (Task A1).
- Produces: `class AppConfig { String minSupportedVersion; bool forceUpdate; bool maintenance; String? supportEmail; String? supportPhone; String currencySymbol; String distanceUnit; factory AppConfig.fromJson(Map<String,dynamic>); }` and `class RemoteConfig { AppConfig app; ModuleFlags modules; int version; DateTime fetchedAt; factory RemoteConfig.fromJson(Map<String,dynamic>, {DateTime? fetchedAt}); Map<String,dynamic> toJson(); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/remote_config_test.dart
import 'package:ciss_mobile/core/settings/remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses app + modules from the data envelope', () {
    final rc = RemoteConfig.fromJson({
      'version': 7,
      'app': {'minSupportedVersion': '1.0.21', 'forceUpdate': true, 'maintenance': false,
              'currencySymbol': '₹', 'distanceUnit': 'km'},
      'modules': {'leave': true, 'loan': false},
    });
    expect(rc.version, 7);
    expect(rc.app.forceUpdate, isTrue);
    expect(rc.app.currencySymbol, '₹');
    expect(rc.modules.isOn('leave', fallback: false), isTrue);
    expect(rc.modules.isOn('loan', fallback: true), isFalse);
    expect(rc.modules.isOn('patrol', fallback: false), isTrue); // default
  });

  test('survives a minimal/empty payload', () {
    final rc = RemoteConfig.fromJson(const {});
    expect(rc.app.forceUpdate, isFalse);
    expect(rc.modules.isOn('attendance', fallback: false), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/remote_config_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/remote_config_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/settings/remote_config.dart test/remote_config_test.dart
git commit -m "feat(settings): add RemoteConfig/AppConfig models"
```

### Task A3: Encrypted `RemoteConfigStore`

**Files:**
- Create: `lib/core/settings/remote_config_store.dart`
- Test: `test/remote_config_store_test.dart`

**Interfaces:**
- Consumes: `RemoteConfig` (A2).
- Produces: `class RemoteConfigStore { static const boxName = 'remote_config'; Future<void> init(HiveAesCipher? cipher); RemoteConfig? read(String key); Future<void> write(String key, RemoteConfig cfg); static String keyFor(String regionCode, String role); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/remote_config_store_test.dart
import 'package:ciss_mobile/core/settings/remote_config.dart';
import 'package:ciss_mobile/core/settings/remote_config_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:io';

void main() {
  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('rc').path);
  });
  tearDownAll(() async => Hive.close());

  test('round-trips a RemoteConfig per region:role key', () async {
    final store = RemoteConfigStore();
    await store.init(null);
    final key = RemoteConfigStore.keyFor('KL', 'guard');
    await store.write(key, RemoteConfig.fromJson({'version': 3, 'modules': {'loan': true}}));
    final got = store.read(key)!;
    expect(got.version, 3);
    expect(got.modules.isOn('loan', fallback: false), isTrue);
    expect(store.read(RemoteConfigStore.keyFor('KL', 'fieldOfficer')), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/remote_config_store_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/settings/remote_config_store.dart
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'remote_config.dart';

class RemoteConfigStore {
  static const String boxName = 'remote_config';

  Future<void> init(HiveAesCipher? cipher) async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<Map>(boxName, encryptionCipher: cipher);
    }
  }

  static String keyFor(String regionCode, String role) => '$regionCode:$role';

  Box<Map> get _box {
    if (!Hive.isBoxOpen(boxName)) {
      throw StateError('RemoteConfigStore not initialized. Call init() first.');
    }
    return Hive.box(boxName);
  }

  RemoteConfig? read(String key) {
    if (!Hive.isBoxOpen(boxName)) return null;
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(raw);
      final fetchedAt = DateTime.tryParse(map['fetchedAt']?.toString() ?? '');
      return RemoteConfig.fromJson(map, fetchedAt: fetchedAt);
    } catch (e) {
      debugPrint('RemoteConfigStore: corrupt entry for $key — $e');
      return null;
    }
  }

  Future<void> write(String key, RemoteConfig cfg) => _box.put(key, cfg.toJson());
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/remote_config_store_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/settings/remote_config_store.dart test/remote_config_store_test.dart
git commit -m "feat(settings): add encrypted RemoteConfigStore"
```

### Task A4: Repository fetch + `remoteConfigProvider`

**Files:**
- Modify: `lib/core/network/mobile_repository.dart`
- Create: `lib/core/settings/remote_config_provider.dart`
- Test: `test/remote_config_provider_test.dart`

**Interfaces:**
- Consumes: `RemoteConfigStore`, `RemoteConfig`, `MobileRepository`, `apiClientProvider`, `regionServiceProvider`.
- Produces: `Future<Map<String,dynamic>> MobileRepository.fetchRemoteConfig()` returning the `data` object; `final remoteConfigProvider = NotifierProvider<RemoteConfigNotifier, RemoteConfig>;` with `RemoteConfigNotifier.refresh()` and `now` (cached value, sync-readable).

Read `mobile_repository.dart` first to reuse its private `_getJson`/`_postJson` helpers. Add:

```dart
// in MobileRepository
static const String _remoteConfigPath = '/api/mobile/settings';

Future<Map<String, dynamic>> fetchRemoteConfig() async {
  final response = await _apiClient.dio.get<dynamic>(_remoteConfigPath);
  final body = response.data;
  final map = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  final data = map['data'];
  return data is Map ? Map<String, dynamic>.from(data) : map;
}
```

- [ ] **Step 1: Write the failing test** (provider uses a fake repository)

```dart
// test/remote_config_provider_test.dart
import 'package:ciss_mobile/core/settings/remote_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('falls back to defaults and never throws on fetch failure', () async {
    final n = RemoteConfigNotifier(
      fetch: () async => throw Exception('offline'),
      role: 'guard', regionCode: 'KL', store: null,
    );
    await n.refresh();
    expect(n.state.modules.isOn('attendance', fallback: false), isTrue);
  });

  test('applies server flags on success', () async {
    final n = RemoteConfigNotifier(
      fetch: () async => {'version': 9, 'modules': {'loan': true}},
      role: 'guard', regionCode: 'KL', store: null,
    );
    await n.refresh();
    expect(n.state.version, 9);
    expect(n.state.modules.isOn('loan', fallback: false), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/remote_config_provider_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/settings/remote_config_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/providers.dart';
import '../models/app_role.dart';
import 'remote_config.dart';
import 'remote_config_store.dart';

typedef RemoteConfigFetch = Future<Map<String, dynamic>> Function();

class RemoteConfigNotifier extends Notifier<RemoteConfig> {
  RemoteConfigNotifier({RemoteConfigFetch? fetch, String? role, String? regionCode, RemoteConfigStore? store})
      : _injectedFetch = fetch, _injectedRole = role, _injectedRegion = regionCode, _injectedStore = store;

  final RemoteConfigFetch? _injectedFetch;
  final String? _injectedRole;
  final String? _injectedRegion;
  final RemoteConfigStore? _injectedStore;
  bool _inFlight = false;

  static const Duration ttl = Duration(minutes: 15);

  @override
  RemoteConfig build() {
    if (_injectedFetch != null) return RemoteConfig.defaults();
    final store = ref.watch(remoteConfigStoreProvider);
    final key = _cacheKey;
    return store.read(key) ?? RemoteConfig.defaults();
  }

  String get _cacheKey => RemoteConfigStore.keyFor(
        _injectedRegion ?? ref.read(regionServiceProvider).activeRegion?.code ?? 'KL',
        _injectedRole ?? 'unknown',
      );

  RemoteConfigStore get _store => _injectedStore ?? ref.read(remoteConfigStoreProvider);

  Future<void> refresh({bool force = false}) async {
    if (_inFlight) return;
    if (!force) {
      final age = DateTime.now().difference(state.fetchedAt);
      if (state.version != 0 && age < ttl) return;
    }
    _inFlight = true;
    try {
      final fetch = _injectedFetch ?? ref.read(mobileRepositoryProvider).fetchRemoteConfig;
      final json = await fetch();
      final next = RemoteConfig.fromJson(json);
      state = next;
      await _store.write(_cacheKey, next);
    } catch (e) {
      debugPrint('remoteConfig refresh failed (keeping cached/defaults): $e');
    } finally {
      _inFlight = false;
    }
  }
}

final remoteConfigStoreProvider = Provider<RemoteConfigStore>((ref) => RemoteConfigStore());

final remoteConfigProvider =
    NotifierProvider<RemoteConfigNotifier, RemoteConfig>(RemoteConfigNotifier.new);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/remote_config_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/mobile_repository.dart lib/core/settings/remote_config_provider.dart test/remote_config_provider_test.dart
git commit -m "feat(settings): fetch /api/mobile/settings into remoteConfigProvider"
```

### Task A5: Route→module map + redirect decision (pure)

**Files:**
- Create: `lib/core/settings/route_modules.dart`
- Test: `test/route_modules_test.dart`

**Interfaces:**
- Consumes: `RemoteConfig`/`ModuleFlags`.
- Produces: `const Map<String,String?> kRouteModules;` and `String? moduleForPath(String path);` and `String? gatedRedirect({required String path, required ModuleFlags flags});` (returns the redirect location or `null`).

- [ ] **Step 1: Write the failing test**

```dart
// test/route_modules_test.dart
import 'package:ciss_mobile/core/settings/module_flags.dart';
import 'package:ciss_mobile/core/settings/route_modules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unmapped and core paths are allowed', () {
    expect(gatedRedirect(path: '/', flags: ModuleFlags.defaults()), isNull);
    expect(gatedRedirect(path: '/login/guard', flags: ModuleFlags.defaults()), isNull);
    expect(gatedRedirect(path: '/whatever', flags: ModuleFlags.defaults()), isNull);
  });

  test('disabled module redirects; enabled passes', () {
    final off = ModuleFlags.fromJson({'qrAttendance': false});
    expect(gatedRedirect(path: '/qr-attendance', flags: off), '/module-unavailable?m=qrAttendance');
    final on = ModuleFlags.fromJson({'qrAttendance': true});
    expect(gatedRedirect(path: '/qr-attendance', flags: on), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/route_modules_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/settings/route_modules.dart
import 'module_flags.dart';

/// Path prefix → module key. `null`/absent = always allowed.
const Map<String, String> kRouteModules = <String, String>{
  '/qr-attendance': 'qrAttendance',
  '/attendance': 'attendance',
  '/guard/leave': 'leave',
  '/guard/patrol': 'patrol',
  '/guard/documents': 'documents',
  '/guard/payslips': 'payslips',
  '/guard/incidents': 'incidents',
  '/guard/training': 'training',
  '/guard/evaluations': 'evaluations',
};

String? moduleForPath(String path) {
  String? best;
  for (final entry in kRouteModules.entries) {
    if (path == entry.key || path.startsWith('${entry.key}/')) {
      if (best == null || entry.key.length > best!.length) best = entry.key;
    }
  }
  return best == null ? null : kRouteModules[best];
}

String? gatedRedirect({required String path, required ModuleFlags flags}) {
  final module = moduleForPath(path);
  if (module == null) return null;
  if (flags.isOn(module, fallback: true)) return null;
  return '/module-unavailable?m=$module';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/route_modules_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/settings/route_modules.dart test/route_modules_test.dart
git commit -m "feat(settings): pure route→module gate decision"
```

### Task A6: `routerProvider` + `/module-unavailable` + app wiring

**Files:**
- Create: `lib/features/shared/module_unavailable_screen.dart`
- Modify: `lib/app/router/app_router.dart`, `lib/app/app.dart`, `lib/main.dart`
- Test: `test/module_gate_test.dart` (widget, added in A7)

**Interfaces:**
- Consumes: `remoteConfigProvider`, `gatedRedirect`.
- Produces: `final routerProvider = Provider<GoRouter>((ref) => ...)` replacing the global `appRouter`; `/module-unavailable` route.

- [ ] **Step 1: Add the unavailable screen**

```dart
// lib/features/shared/module_unavailable_screen.dart
import 'package:flutter/material.dart';

class ModuleUnavailableScreen extends StatelessWidget {
  const ModuleUnavailableScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Not available')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text("This feature isn't enabled for your account.",
                textAlign: TextAlign.center),
          ),
        ),
      );
}
```

- [ ] **Step 2: Convert `appRouter` to `routerProvider` and add redirect**

In `lib/app/router/app_router.dart`: rename `final GoRouter appRouter = GoRouter(` to a `Provider`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/settings/remote_config_provider.dart';
import '../../core/settings/route_modules.dart';
import '../../features/shared/module_unavailable_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(remoteConfigProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final flags = ref.read(remoteConfigProvider).modules;
      return gatedRedirect(path: state.uri.path, flags: flags);
    },
    routes: <RouteBase>[
      // ...existing routes unchanged...
      GoRoute(
        path: '/module-unavailable',
        pageBuilder: (c, s) => _buildPage(context: c, state: s, child: const ModuleUnavailableScreen()),
      ),
    ],
  );
});
```

- [ ] **Step 3: Update `app.dart` to watch it**

Replace `routerConfig: appRouter,` with a `Consumer` read:

```dart
// inside build, with ref available (ConsumerWidget)
final router = ref.watch(routerProvider);
return MaterialApp.router(routerConfig: router, ...);
```

- [ ] **Step 4: Init the store + refresh in `main.dart`**

After `Hive.initFlutter()`:

```dart
final rcStore = container.read(remoteConfigStoreProvider);
await rcStore.init(cipher);
```

- [ ] **Step 5: Verify it builds + existing tests pass**

Run: `flutter analyze && flutter test test/widget_test.dart`
Expected: analyze clean; PASS

- [ ] **Step 6: Commit**

```bash
git add lib/app/router/app_router.dart lib/app/app.dart lib/main.dart lib/features/shared/module_unavailable_screen.dart
git commit -m "feat(settings): router provider with hard-hide module redirect"
```

### Task A7: `ModuleGate` widget + `moduleEnabled` + dashboard gating

**Files:**
- Create: `lib/core/settings/module_gate.dart`
- Modify: `lib/features/guard/presentation/screens/guard_dashboard_screen.dart`
- Test: `test/module_gate_test.dart`

**Interfaces:**
- Consumes: `remoteConfigProvider`.
- Produces: `bool moduleEnabled(WidgetRef ref, String key, {bool fallback = true});` and `class ModuleGate extends ConsumerWidget { const ModuleGate({required this.module, required this.child, this.fallback = true}); }`.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/module_gate_test.dart
import 'package:ciss_mobile/core/settings/module_gate.dart';
import 'package:ciss_mobile/core/settings/module_flags.dart';
import 'package:ciss_mobile/core/settings/remote_config.dart';
import 'package:ciss_mobile/core/settings/remote_config_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

RemoteConfig _cfg(Map<String, bool> modules) => RemoteConfig.fromJson({'modules': modules});

void main() {
  testWidgets('shows child when module on, blocks when off', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [remoteConfigProvider.overrideWith((ref, notifier) => _cfg({'leave': false}))],
      child: const MaterialApp(home: ModuleGate(module: 'leave', fallback: true, child: Text('LEAVE'))),
    ));
    await tester.pump();
    expect(find.text('LEAVE'), findsNothing);
    expect(find.textContaining("isn't enabled"), findsOneWidget);
  });
}
```

> Note: if `overrideWith` signature differs for `NotifierProvider`, use `remoteConfigProvider.overrideWithBuild((ref, notifier) => _cfg(...))` or add a test-only `remoteConfigOverrideProvider`. Confirm the exact API against the installed `flutter_riverpod` version before writing; adjust the test, not the production code.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/module_gate_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/settings/module_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'remote_config_provider.dart';

bool moduleEnabled(WidgetRef ref, String key, {bool fallback = true}) =>
    ref.watch(remoteConfigProvider).modules.isOn(key, fallback: fallback);

class ModuleGate extends ConsumerWidget {
  const ModuleGate({super.key, required this.module, required this.child, this.fallback = true});
  final String module;
  final Widget child;
  final bool fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (moduleEnabled(ref, module, fallback: fallback)) return child;
    return const Scaffold(
      body: Center(child: Text("This feature isn't enabled for your account.")),
    );
  }
}
```

- [ ] **Step 4: Gate the guard dashboard tiles**

In `guard_dashboard_screen.dart`, wrap each gated quick action/tile's visibility with `if (moduleEnabled(ref, 'patrol'))`, `if (moduleEnabled(ref, 'leave'))`, `if (moduleEnabled(ref, 'payslips'))`, etc. Wrap the dashboard body in `ModuleGate(module: 'attendance', child: ...)` only for genuinely optional sections (dashboard itself stays always visible).

- [ ] **Step 5: Run tests**

Run: `flutter test test/module_gate_test.dart test/widget_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/core/settings/module_gate.dart lib/features/guard/presentation/screens/guard_dashboard_screen.dart test/module_gate_test.dart
git commit -m "feat(settings): ModuleGate widget + guard dashboard gating"
```

### Task A8: Refresh triggers (login, resume, pull-to-refresh, 403)

**Files:**
- Modify: `lib/core/settings/remote_config_provider.dart`, `lib/features/guard/presentation/screens/guard_dashboard_screen.dart` (pull-to-refresh already calls sync — add config refresh), FO More screen
- Test: covered by A4 refresh tests

**Interfaces:**
- Consumes: `remoteConfigProvider.notifier.refresh(force:)`.

- [ ] **Step 1: Hook login/session resolve** — in the auth success path (where `syncServiceProvider` starts / session resolves), call `ref.read(remoteConfigProvider.notifier).refresh(force: true)`.
- [ ] **Step 2: Hook app resume** — in the existing `WidgetsBindingObserver.didChangeAppLifecycleState` (`resumed`) handler, call `refresh()` (TTL-gated).
- [ ] **Step 3: Hook pull-to-refresh** — the dashboard `RefreshIndicator.onRefresh` calls `await ref.read(remoteConfigProvider.notifier).refresh(force: true)` before/with sync.
- [ ] **Step 4: Hook 403** — in `ApiClient.onError`, on `403` with body code `module_disabled`, call a provided callback that forces a refresh (add optional `onModuleDisabled` to `ApiClient` wired from `providers.dart`).
- [ ] **Step 5: Verify** `flutter analyze && flutter test`
- [ ] **Step 6: Commit**

```bash
git add lib/core/settings/remote_config_provider.dart lib/core/network/api_client.dart lib/core/network/providers.dart
git commit -m "feat(settings): refresh remote config on login, resume, pull, 403"
```

---

## Phase B — Attendance/tracking parity

### Task B1: `TrackingSample` model + AMS mapping

**Files:**
- Create: `lib/core/location/tracking_sample.dart`
- Test: `test/tracking_sample_test.dart`

**Interfaces:**
- Produces: `class TrackingSample { String? status; double latitude, longitude, accuracy, locationAccuracy; double? altitude, bearing, speed; String activity; bool isMock, isGPSOn, wifiConnected; int? batteryPercentage; String networkType; DateTime time; Map<String,dynamic> toJson(); }` and `String mapActivity(int? activityType)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/tracking_sample_test.dart
import 'package:ciss_mobile/core/location/tracking_sample.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson uses AMS field names', () {
    final s = TrackingSample(
      status: 'in', latitude: 12.9, longitude: 80.2, accuracy: 8, locationAccuracy: 8,
      altitude: 12, bearing: 90, speed: 1.4, activity: 'walking',
      isMock: false, isGPSOn: true, wifiConnected: true, batteryPercentage: 78,
      networkType: 'wifi', time: DateTime.utc(2026, 1, 1),
    );
    final j = s.toJson();
    expect(j['latitude'], 12.9);
    expect(j['batteryPercentage'], 78);
    expect(j['isMock'], false);
    expect(j['isGPSOn'], true);
    expect(j['activity'], 'walking');
    expect(j.containsKey('time'), isTrue);
  });

  test('activity mapping', () {
    expect(mapActivity(null), 'unknown');
    expect(mapActivity(7), 'walking'); // ActivityType.walking
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/tracking_sample_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/location/tracking_sample.dart
String mapActivity(int? activityType) {
  switch (activityType) {
    case 3: return 'still';       // still
    case 7: return 'walking';     // walking
    case 8: return 'traveling';   // running -> traveling (AMS umbrella)
    case 0: return 'in_vehicle';  // in_vehicle
    case 1: return 'on_bicycle';  // on_bicycle
    default: return 'unknown';
  }
}

class TrackingSample {
  TrackingSample({required this.status, required this.latitude, required this.longitude,
    required this.accuracy, required this.locationAccuracy, required this.activity,
    required this.isMock, required this.isGPSOn, required this.wifiConnected,
    required this.networkType, required this.time,
    this.altitude, this.bearing, this.speed, this.batteryPercentage});

  final String? status;
  final double latitude, longitude, accuracy, locationAccuracy;
  final double? altitude, bearing, speed;
  final String activity;
  final bool isMock, isGPSOn, wifiConnected;
  final int? batteryPercentage;
  final String networkType;
  final DateTime time;

  Map<String, dynamic> toJson() => {
        'status': status, 'latitude': latitude, 'longitude': longitude,
        'accuracy': accuracy, 'locationAccuracy': locationAccuracy,
        'altitude': altitude, 'bearing': bearing, 'speed': speed,
        'activity': activity, 'isMock': isMock, 'isGPSOn': isGPSOn,
        'batteryPercentage': batteryPercentage, 'wifiConnected': wifiConnected,
        'networkType': networkType, 'time': time.millisecondsSinceEpoch,
        'capturedAt': time.toUtc().toIso8601String(),
      };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/tracking_sample_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/location/tracking_sample.dart test/tracking_sample_test.dart
git commit -m "feat(tracking): TrackingSample with AMS field names"
```

### Task B2: Enrich the heartbeat payload + activity recognition

**Files:**
- Modify: `lib/core/location/background_tracking_service.dart`, `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add the dependency + permission**

`pubspec.yaml`:
```yaml
  flutter_activity_recognition: ^4.0.0
```
`AndroidManifest.xml` (with the other `uses-permission` entries):
```xml
    <uses-permission android:name="com.google.android.gms.permission.ACTIVITY_RECOGNITION"/>
    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
```

- [ ] **Step 2: Build the enriched body** — in `background_tracking_service.dart`, where the heartbeat body map is built, replace with:

```dart
final activityType = ActivityRecognition.activityType; // best-effort; guard with try/catch
final activity = mapActivity(activityType);
final isGpsOn = await Geolocator.isLocationServiceEnabled();
final sample = TrackingSample(
  status: siteContext!['status'] as String?,
  latitude: position.latitude, longitude: position.longitude,
  accuracy: accuracy, locationAccuracy: accuracy,
  altitude: position.altitude, bearing: position.heading, speed: speed,
  activity: activity, isMock: position.isMocked, isGPSOn: isGpsOn,
  wifiConnected: telemetry['wifiConnected'] == true,
  batteryPercentage: (telemetry['batteryLevel'] as num?)?.round(),
  networkType: (telemetry['networkType'] ?? 'none').toString(),
  time: DateTime.now().toUtc(),
);
final body = jsonEncode({...sample.toJson(), 'siteId': siteContext!['siteId']});
```

Keep `batteryLevel` in the map too for one release (compatibility), then remove in a follow-up.

- [ ] **Step 3: Verify** `flutter analyze`
- [ ] **Step 4: Manual check** on device/emulator: heartbeat accepted, fields present in server logs.
- [ ] **Step 5: Commit**

```bash
git add lib/core/location/background_tracking_service.dart pubspec.yaml android/app/src/main/AndroidManifest.xml
git commit -m "feat(tracking): AMS-named heartbeat fields + activity recognition"
```

### Task B3: `TrackingBuffer` + batch sync

**Files:**
- Create: `lib/core/location/tracking_buffer.dart`
- Modify: `lib/core/sync/sync_service.dart`, `lib/core/location/background_tracking_service.dart`
- Test: `test/tracking_buffer_test.dart`

**Interfaces:**
- Produces: `class TrackingBuffer { static const boxName = 'tracking_buffer'; static const int maxSamples = 5000; Future<void> init(HiveAesCipher? cipher); Future<void> add(Map<String,dynamic> sample); List<Map<String,dynamic>> pending(); Future<void> clear(Iterable<String> ids); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/tracking_buffer_test.dart
import 'package:ciss_mobile/core/location/tracking_buffer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:io';

void main() {
  setUpAll(() async => Hive.init(Directory.systemTemp.createTempSync('tb').path));
  tearDownAll(() async => Hive.close());

  test('caps at maxSamples and evicts oldest', () async {
    final b = TrackingBuffer();
    await b.init(null);
    for (var i = 0; i < TrackingBuffer.maxSamples + 5; i++) {
      await b.add({'latitude': i.toDouble(), 'capturedAt': DateTime.now().toIso8601String()});
    }
    expect(b.pending().length, TrackingBuffer.maxSamples);
    expect(b.pending().first['latitude'], 5.0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/tracking_buffer_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation** (Hive box keyed by ISO timestamp+uuid; after add, if length > maxSamples delete oldest keys).

```dart
// lib/core/location/tracking_buffer.dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class TrackingBuffer {
  static const String boxName = 'tracking_buffer';
  static const int maxSamples = 5000;
  final _uuid = const Uuid();

  Future<void> init(HiveAesCipher? cipher) async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<Map>(boxName, encryptionCipher: cipher);
    }
  }

  Box<Map> get _box {
    if (!Hive.isBoxOpen(boxName)) throw StateError('TrackingBuffer not initialized.');
    return Hive.box(boxName);
  }

  Future<void> add(Map<String, dynamic> sample) async {
    await _box.put(_uuid.v4(), sample);
    if (_box.length > maxSamples) {
      final keys = _box.keys.cast<String>().toList();
      for (var i = 0; i < keys.length - maxSamples; i++) {
        await _box.delete(keys[i]);
      }
    }
  }

  List<Map<String, dynamic>> pending() =>
      _box.values.map((v) => Map<String, dynamic>.from(v)).toList();

  Future<void> clear(Iterable<String> ids) async {
    for (final id in ids) { await _box.delete(id); }
  }
}
```

- [ ] **Step 4: Flush via batch endpoint** — in `sync_service.dart`, before processing the generic queue, if online and `trackingBuffer.pending()` is non-empty, POST `{'samples': pending}` to `/api/mobile/tracking/batch` and clear on success. In `background_tracking_service.dart`, when the live heartbeat POST fails (offline), call `trackingBuffer.add(sample.toJson())`.

- [ ] **Step 5: Run tests** `flutter test test/tracking_buffer_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/core/location/tracking_buffer.dart lib/core/sync/sync_service.dart lib/core/location/background_tracking_service.dart test/tracking_buffer_test.dart
git commit -m "feat(tracking): offline TrackingBuffer flushed via /api/mobile/tracking/batch"
```

### Task B4: Break state machine + API

**Files:**
- Create: `lib/core/attendance/attendance_session.dart`
- Modify: `lib/core/network/mobile_repository.dart`, `lib/features/guard/presentation/screens/guard_attendance_screen.dart`
- Test: `test/attendance_session_test.dart`

**Interfaces:**
- Produces: `enum BreakAction { start, stop }`; `class AttendanceSession { bool onBreak; DateTime? breakStartedAt; int totalBreakSeconds; bool canCheckOut; void applyBreakResponse(Map<String,dynamic>); }`; `MobileRepository.startBreak()` / `stopBreak()`.

- [ ] **Step 1: Write the failing test**

```dart
// test/attendance_session_test.dart
import 'package:ciss_mobile/core/attendance/attendance_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('break state machine applies server response', () {
    final s = AttendanceSession();
    s.applyBreakResponse({'onBreak': true, 'breakStartedAt': '2026-01-01T10:00:00Z',
                          'breakSeconds': 0, 'canCheckOut': false});
    expect(s.onBreak, isTrue);
    expect(s.canCheckOut, isFalse);
    expect(s.breakStartedAt, DateTime.parse('2026-01-01T10:00:00Z'));
    s.applyBreakResponse({'onBreak': false, 'breakSeconds': 900, 'canCheckOut': true});
    expect(s.onBreak, isFalse);
    expect(s.totalBreakSeconds, 900);
    expect(s.breakStartedAt, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/attendance_session_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/attendance/attendance_session.dart
enum BreakAction { start, stop }

class AttendanceSession {
  bool onBreak = false;
  DateTime? breakStartedAt;
  int totalBreakSeconds = 0;
  bool canCheckOut = true;

  void applyBreakResponse(Map<String, dynamic> r) {
    onBreak = r['onBreak'] == true;
    totalBreakSeconds = (r['breakSeconds'] as num?)?.toInt() ?? totalBreakSeconds;
    canCheckOut = r['canCheckOut'] != false;
    final started = r['breakStartedAt'] as String?;
    breakStartedAt = onBreak && started != null ? DateTime.tryParse(started) : null;
  }
}
```

- [ ] **Step 4: Repository + UI** — add to `MobileRepository`:

```dart
static const String _breakPath = '/api/mobile/attendance/break';
Future<Map<String, dynamic>> attendanceBreak({required String action, double? lat, double? lng, double? accuracy}) async {
  final res = await _apiClient.dio.post<dynamic>(_breakPath, data: {
    'action': action, 'lat': lat, 'lng': lng, 'accuracy': accuracy,
    'capturedAt': DateTime.now().toUtc().toIso8601String(),
  });
  return (res.data is Map) ? Map<String, dynamic>.from(res.data as Map) : {};
}
```

In `guard_attendance_screen.dart`, when `moduleEnabled(ref, 'break')` and checked in: render Start break / End break; call `attendanceBreak(action: ...)` via `OfflineQueue` when offline (enqueue `OfflineRequest(path: _breakPath, ...)`), else direct; feed the response to `AttendanceSession.applyBreakResponse`; show elapsed timer; disable checkout while `canCheckOut == false`.

- [ ] **Step 5: Run tests** `flutter test test/attendance_session_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/core/attendance/attendance_session.dart lib/core/network/mobile_repository.dart lib/features/guard/presentation/screens/guard_attendance_screen.dart test/attendance_session_test.dart
git commit -m "feat(attendance): break start/stop state + endpoint"
```

### Task B5: Early-checkout reason

**Files:**
- Modify: `lib/core/network/mobile_repository.dart` (checkout payload), `lib/features/guard/presentation/screens/guard_attendance_screen.dart`, `lib/features/field_officer/presentation/screens/field_officer_attendance_screen.dart`

- [ ] **Step 1: Reason sheet** — a `showModalBottomSheet` returning a `String` from the constant list `const kEarlyCheckoutReasons = ['Personal emergency', 'Shift relief arrived', 'Supervisor instruction', 'Other'];` with a free-text field when "Other".
- [ ] **Step 2: Checkout flow** — when the checkout response (or pre-check) returns `requiresReason == true`, show the sheet; re-submit checkout with `earlyCheckOutReason: reason` in the payload.
- [ ] **Step 3: Offline** — the reason is part of the queued checkout `OfflineRequest.body` (already generic), so it survives offline.
- [ ] **Step 4: Verify** `flutter analyze && flutter test`
- [ ] **Step 5: Commit**

```bash
git add lib/features/guard/presentation/screens/guard_attendance_screen.dart lib/features/field_officer/presentation/screens/field_officer_attendance_screen.dart
git commit -m "feat(attendance): early-checkout reason capture"
```

### Task B6: Public IP hint + server-authoritative validation

**Files:**
- Create: `lib/core/location/public_ip.dart`
- Modify: `lib/core/network/mobile_repository.dart`, both attendance screens
- Test: `test/attendance_validation_test.dart`

**Interfaces:**
- Produces: `Future<String?> fetchPublicIp([http.Client? client]);` and `AttendanceValidationResult { bool allowed; String? reason; Map<String,dynamic> checks; }`; `MobileRepository.validateAttendance({required String siteId, required double lat, required double lng, required double accuracy, String? publicIp})`.

- [ ] **Step 1: Write the failing test** (validator parses response; blocks when allowed=false)

```dart
// test/attendance_validation_test.dart
import 'package:ciss_mobile/core/attendance/attendance_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses allowed/reason and blocks when not allowed', () {
    final r = AttendanceValidationResult.fromJson({
      'allowed': false, 'reason': 'Outside site geofence (145 m of 100 m)',
      'checks': {'geoFence': {'ok': false}},
    });
    expect(r.allowed, isFalse);
    expect(r.reason, contains('geofence'));
    expect(r.blocksSubmit, isTrue);
  });

  test('allowed result does not block', () {
    final r = AttendanceValidationResult.fromJson({'allowed': true});
    expect(r.blocksSubmit, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** Run: `flutter test test/attendance_validation_test.dart` — Expected: FAIL

- [ ] **Step 3: Implement `public_ip.dart` and `attendance_validation.dart`**

```dart
// lib/core/location/public_ip.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Best-effort public IP hint (server remains authoritative). Returns null on failure.
Future<String?> fetchPublicIp([http.Client? client]) async {
  try {
    final c = client ?? http.Client();
    final res = await c.get(Uri.parse('https://api.ipify.org?format=json'))
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body);
    final ip = body is Map ? body['ip'] : null;
    return ip is String && ip.isNotEmpty ? ip : null;
  } catch (_) { return null; }
}
```

```dart
// lib/core/attendance/attendance_validation.dart
class AttendanceValidationResult {
  AttendanceValidationResult({required this.allowed, this.reason, this.checks = const {}});
  final bool allowed;
  final String? reason;
  final Map<String, dynamic> checks;

  bool get blocksSubmit => !allowed;

  factory AttendanceValidationResult.fromJson(Map<String, dynamic> j) => AttendanceValidationResult(
        allowed: j['allowed'] == true,
        reason: j['reason'] as String?,
        checks: (j['checks'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}
```

- [ ] **Step 4: Repository + wiring** — add `validateAttendance(...)` posting to `/api/mobile/attendance/validate` with `{siteId, lat, lng, accuracy, publicIp, capturedAt}`, returning `AttendanceValidationResult`. In both attendance screens, before submit: if `geoFence || ipAttendance` enabled, call validate; if `blocksSubmit`, show `reason` and abort; warn when `accuracy > 100`.

- [ ] **Step 5: Run tests** `flutter test test/attendance_validation_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/core/location/public_ip.dart lib/core/attendance/attendance_validation.dart lib/core/network/mobile_repository.dart lib/features/guard/presentation/screens/guard_attendance_screen.dart lib/features/field_officer/presentation/screens/field_officer_attendance_screen.dart test/attendance_validation_test.dart
git commit -m "feat(attendance): server-authoritative geo+IP validation pre-check"
```

---

## Final verification

- [ ] `flutter analyze` — clean.
- [ ] `flutter test` — full suite green.
- [ ] Manual: with server flags ON, break/validate calls fire; flip `qrAttendance=false` server-side, confirm nav hides and `/qr-attendance` redirects to `/module-unavailable`.
- [ ] Confirm no behavior change with all-new flags OFF (loan/expense/ipAttendance/etc.).

## Self-review notes

- Spec §1→Task A1–A4; §2→A3/A4/A8; §3→A5/A6/A7; §4→B1–B3; §5→B4/B5; §6→B6; §7→Final verification.
- `ModuleFlags`/`RemoteConfig` names are consistent across A1–A8; AMS field names consistent across B1–B6.
- The `remoteConfigProvider` Riverpod override signature in A7's test must be verified against the installed `flutter_riverpod` version before writing the test.
