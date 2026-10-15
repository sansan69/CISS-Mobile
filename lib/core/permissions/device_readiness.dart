import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../i18n/app_strings.dart';
import '../location/background_tracking_service.dart';
import '../location/device_compat_service.dart';
import 'oem_autostart.dart';

/// Preconditions that decide whether a device can report duty tracking
/// reliably. Mirrors the sibling CISS-AMS build's permission surface, which
/// declares background location, boot restart and battery-optimisation
/// handling (REA evidence `ev_ac973383…`).
enum ReadinessItem {
  notifications,
  location,
  backgroundLocation,
  camera,
  activityRecognition,
  batteryExemption,
  autostart,
}

enum ReadinessState {
  granted,
  denied,
  permanentlyDenied,
  notRequested,
  notApplicable,

  /// The platform exposes no readable state (auto-start on most brands).
  unknown,
}

/// Battery optimisation and OEM auto-start cannot be granted by a dialog and
/// only degrade battery life; they are surfaced but never block a punch.
const Set<ReadinessItem> advisoryReadinessItems = <ReadinessItem>{
  ReadinessItem.batteryExemption,
  ReadinessItem.autostart,
};

class ReadinessSnapshot {
  const ReadinessSnapshot(this.items, {this.manufacturer = ''});

  const ReadinessSnapshot.empty()
    : items = const <ReadinessItem, ReadinessState>{},
      manufacturer = '';

  final Map<ReadinessItem, ReadinessState> items;

  /// `Build.MANUFACTURER` at read time, so the OEM recipe is chosen from the
  /// same observation as the permission states.
  final String manufacturer;

  ReadinessState stateOf(ReadinessItem item) =>
      items[item] ?? ReadinessState.unknown;

  /// Required items that still need user action.
  List<ReadinessItem> get blocking => ReadinessItem.values
      .where((item) => !advisoryReadinessItems.contains(item))
      .where(
        (item) => switch (stateOf(item)) {
          ReadinessState.denied ||
          ReadinessState.permanentlyDenied ||
          ReadinessState.notRequested => true,
          _ => false,
        },
      )
      .toList(growable: false);

  /// Advisory items the user can still improve.
  List<ReadinessItem> get advisory => ReadinessItem.values
      .where(advisoryReadinessItems.contains)
      .where(
        (item) => switch (stateOf(item)) {
          ReadinessState.notRequested ||
          ReadinessState.denied ||
          ReadinessState.permanentlyDenied ||
          ReadinessState.unknown => true,
          _ => false,
        },
      )
      .toList(growable: false);

  /// Required items whose state could not be read at all.
  List<ReadinessItem> get unverified => ReadinessItem.values
      .where((item) => !advisoryReadinessItems.contains(item))
      .where((item) => stateOf(item) == ReadinessState.unknown)
      .toList(growable: false);

  /// True only when every required item is granted or does not apply. A probe
  /// that failed (`unknown`) is deliberately *not* blocking a punch — see
  /// [blocking] — but it must never be reported as "everything is in place".
  bool get ready => blocking.isEmpty && unverified.isEmpty;

  Map<String, String> toStorage() => <String, String>{
    for (final entry in items.entries) entry.key.name: entry.value.name,
    manufacturerKey: manufacturer,
  };

  /// Storage slot for [manufacturer]; not a [ReadinessItem] name, so
  /// [fromStorage] ignores it when rebuilding the item map.
  static const String manufacturerKey = '_manufacturer';

  static ReadinessSnapshot fromStorage(Map<dynamic, dynamic> raw) {
    final items = <ReadinessItem, ReadinessState>{};
    for (final item in ReadinessItem.values) {
      final value = raw[item.name];
      if (value is! String) continue;
      final state = ReadinessState.values
          .where((candidate) => candidate.name == value)
          .firstOrNull;
      if (state != null) items[item] = state;
    }
    final manufacturer = raw[manufacturerKey];
    return ReadinessSnapshot(
      items,
      manufacturer: manufacturer is String ? manufacturer : '',
    );
  }
}

/// Reads and requests every precondition. Injectable so widget tests never
/// touch a platform channel.
abstract class ReadinessSource {
  Future<ReadinessSnapshot> read();

  Future<ReadinessState> request(ReadinessItem item);

  /// `Build.MANUFACTURER`, used to pick the OEM survival recipe.
  Future<String> manufacturer();

  /// Each returns false when no settings surface could be resolved, so the
  /// caller can fall back to the app detail screen.
  Future<bool> openSettings();

  Future<bool> openBatteryOptimizationSettings();

  Future<bool> openAutostartSettings();
}

class PlatformReadinessSource implements ReadinessSource {
  PlatformReadinessSource({DeviceCompatService? compat})
    : _compat = compat ?? DeviceCompatService();

  final DeviceCompatService _compat;

  static const Map<ReadinessItem, Permission> _permissions =
      <ReadinessItem, Permission>{
        ReadinessItem.notifications: Permission.notification,
        ReadinessItem.location: Permission.location,
        ReadinessItem.backgroundLocation: Permission.locationAlways,
        ReadinessItem.camera: Permission.camera,
        ReadinessItem.activityRecognition: Permission.activityRecognition,
      };

  @override
  Future<ReadinessSnapshot> read() async {
    final items = <ReadinessItem, ReadinessState>{};
    for (final entry in _permissions.entries) {
      items[entry.key] = await _stateOf(entry.value);
    }
    items[ReadinessItem.batteryExemption] =
        (await _compat.isIgnoringBatteryOptimizations())
        ? ReadinessState.granted
        : ReadinessState.denied;
    final manufacturer = await _compat.getManufacturer();
    // Auto-start has no readable state on any OEM; it matters only on brands
    // known to kill background apps, which is exactly the set the OEM guide
    // table covers.
    items[ReadinessItem.autostart] = oemGuideFor(manufacturer) != null
        ? ReadinessState.notRequested
        : ReadinessState.notApplicable;
    return ReadinessSnapshot(items, manufacturer: manufacturer);
  }

  static Future<ReadinessState> _stateOf(Permission permission) async {
    try {
      return _fromStatus(await permission.status);
    } catch (_) {
      return ReadinessState.unknown;
    }
  }

  static ReadinessState _fromStatus(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return ReadinessState.granted;
    if (status.isPermanentlyDenied) return ReadinessState.permanentlyDenied;
    if (status.isDenied) return ReadinessState.denied;
    if (status.isRestricted) return ReadinessState.permanentlyDenied;
    return ReadinessState.notRequested;
  }

  @override
  Future<ReadinessState> request(ReadinessItem item) async {
    if (item == ReadinessItem.batteryExemption) {
      await openBatteryOptimizationSettings();
      return (await _compat.isIgnoringBatteryOptimizations())
          ? ReadinessState.granted
          : ReadinessState.denied;
    }
    if (item == ReadinessItem.autostart) {
      await openAutostartSettings();
      return ReadinessState.unknown;
    }
    final permission = _permissions[item];
    if (permission == null) return ReadinessState.notApplicable;
    try {
      return _fromStatus(await permission.request());
    } catch (_) {
      return ReadinessState.unknown;
    }
  }

  @override
  Future<String> manufacturer() => _compat.getManufacturer();

  @override
  Future<bool> openSettings() => openAppSettings();

  @override
  Future<bool> openBatteryOptimizationSettings() async {
    final opened = await _compat.openBatteryOptimizationSettings();
    // A vendor build can rename or remove its battery screen, and the native
    // bridge reports that as false; never leave the user on a dead button.
    return opened ? true : openAppSettings();
  }

  @override
  Future<bool> openAutostartSettings() async {
    final opened = await _compat.openBrandAutostartSettings();
    // A vendor build can rename or remove its security component; never leave
    // the user on a dead button.
    return opened ? true : openAppSettings();
  }
}

final readinessSourceProvider = Provider<ReadinessSource>(
  (ref) => PlatformReadinessSource(),
);

/// Live read. Callers must be user-initiated (readiness screen, "Check
/// again"); building a screen must never trigger permission traffic.
final readinessProvider = FutureProvider<ReadinessSnapshot>(
  (ref) => ref.watch(readinessSourceProvider).read(),
);

/// Starts the user-visible foreground tracking service. Called once
/// notifications are granted, exactly as the previous onboarding flow did.
/// Injectable so widget tests never touch the background-service plugin.
final readinessServiceStartProvider = Provider<Future<void> Function()>(
  (ref) => BackgroundTrackingService.initialize,
);

/// Last observed snapshot, persisted so the readiness banner can show
/// outstanding items without querying the platform on every build.
class ReadinessCache extends StateNotifier<ReadinessSnapshot?> {
  ReadinessCache() : super(null) {
    if (Hive.isBoxOpen(boxName)) {
      final raw = Hive.box(boxName).get(snapshotKey);
      if (raw is Map) state = ReadinessSnapshot.fromStorage(raw);
    }
  }

  static const String boxName = 'device_readiness';
  static const String snapshotKey = 'snapshot';
  static const String checkedAtKey = 'checked_at';

  Future<void> init() async {
    await Hive.openBox(boxName);
    final raw = Hive.box(boxName).get(snapshotKey);
    state = raw is Map ? ReadinessSnapshot.fromStorage(raw) : null;
  }

  Future<void> save(ReadinessSnapshot snapshot) async {
    state = snapshot;
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).put(snapshotKey, snapshot.toStorage());
      await Hive.box(boxName).put(
        checkedAtKey,
        DateTime.now().toIso8601String(),
      );
    }
  }
}

final readinessCacheProvider =
    StateNotifierProvider<ReadinessCache, ReadinessSnapshot?>(
      (ref) => ReadinessCache(),
    );

/// One row of the readiness checklist, ready to render.
class ReadinessStep {
  const ReadinessStep({
    required this.item,
    required this.title,
    required this.why,
    required this.state,
    required this.advisory,
  });

  final ReadinessItem item;
  final String title;
  final String why;
  final ReadinessState state;
  final bool advisory;

  bool get needsAction => switch (state) {
    ReadinessState.granted || ReadinessState.notApplicable => false,
    _ => true,
  };

  /// Permanently denied permissions can only be changed in app settings.
  bool get needsSettings => state == ReadinessState.permanentlyDenied;
  bool get needsAutostart => item == ReadinessItem.autostart;
  bool get needsBatterySettings => item == ReadinessItem.batteryExemption;
}

List<ReadinessStep> buildReadinessSteps(
  ReadinessSnapshot snapshot,
  AppStrings strings,
) => <ReadinessStep>[
  _step(
    snapshot,
    strings,
    ReadinessItem.notifications,
    strings.readinessNotifications,
    strings.readinessNotificationsWhy,
  ),
  _step(
    snapshot,
    strings,
    ReadinessItem.location,
    strings.readinessLocationItem,
    strings.readinessLocationWhy,
  ),
  _step(
    snapshot,
    strings,
    ReadinessItem.backgroundLocation,
    strings.readinessBackgroundItem,
    strings.readinessBackgroundLocationWhy,
  ),
  _step(
    snapshot,
    strings,
    ReadinessItem.camera,
    strings.readinessCameraItem,
    strings.readinessCameraWhy,
  ),
  _step(
    snapshot,
    strings,
    ReadinessItem.activityRecognition,
    strings.readinessActivityItem,
    strings.readinessActivityWhy,
  ),
  _step(
    snapshot,
    strings,
    ReadinessItem.batteryExemption,
    strings.batteryUnrestricted,
    strings.readinessBatteryWhy,
  ),
  _step(
    snapshot,
    strings,
    ReadinessItem.autostart,
    strings.readinessAutostart,
    strings.readinessAutostartWhy,
  ),
];

ReadinessStep _step(
  ReadinessSnapshot snapshot,
  AppStrings strings,
  ReadinessItem item,
  String title,
  String why,
) => ReadinessStep(
  item: item,
  title: title,
  why: why,
  state: snapshot.stateOf(item),
  advisory: advisoryReadinessItems.contains(item),
);

String readinessStateLabel(ReadinessState state, AppStrings strings) =>
    switch (state) {
      ReadinessState.granted => strings.readinessStateGranted,
      ReadinessState.denied => strings.readinessStateDenied,
      ReadinessState.permanentlyDenied => strings.readinessStateBlocked,
      ReadinessState.notRequested => strings.readinessStateNotAsked,
      ReadinessState.notApplicable => strings.readinessStateNotNeeded,
      ReadinessState.unknown => strings.readinessStateUnknown,
    };
