import 'package:ciss_mobile/core/permissions/device_readiness.dart';

/// Readiness source driven by a fixed snapshot that records what the UI asked
/// for. Never touches a platform channel.
class FakeReadiness implements ReadinessSource {
  FakeReadiness(this.snapshot);

  ReadinessSnapshot snapshot;
  String manufacturerName = 'Xiaomi';
  ReadinessState nextState = ReadinessState.granted;
  final List<ReadinessItem> requested = <ReadinessItem>[];
  int settingsOpened = 0;
  int batteryOpened = 0;
  int autostartOpened = 0;

  @override
  Future<ReadinessSnapshot> read() async => snapshot;

  @override
  Future<String> manufacturer() async => manufacturerName;

  @override
  Future<ReadinessState> request(ReadinessItem item) async {
    requested.add(item);
    final items = Map<ReadinessItem, ReadinessState>.from(snapshot.items);
    items[item] = nextState;
    snapshot = ReadinessSnapshot(items, manufacturer: snapshot.manufacturer);
    return nextState;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  Future<bool> openBatteryOptimizationSettings() async {
    batteryOpened++;
    return true;
  }

  @override
  Future<bool> openAutostartSettings() async {
    autostartOpened++;
    return true;
  }
}

/// Every precondition granted unless overridden.
ReadinessSnapshot readinessSnapshot([
  Map<ReadinessItem, ReadinessState> overrides =
      const <ReadinessItem, ReadinessState>{},
]) {
  final items = <ReadinessItem, ReadinessState>{
    for (final item in ReadinessItem.values) item: ReadinessState.granted,
  };
  items.addAll(overrides);
  return ReadinessSnapshot(items, manufacturer: 'Xiaomi');
}

/// A device whose vendor ships no auto-start page (Pixel, Nothing, …), so the
/// auto-start row does not apply.
ReadinessSnapshot plainAndroidSnapshot([
  Map<ReadinessItem, ReadinessState> overrides =
      const <ReadinessItem, ReadinessState>{},
]) {
  final snapshot = readinessSnapshot(overrides);
  return ReadinessSnapshot(
    <ReadinessItem, ReadinessState>{
      ...snapshot.items,
      ReadinessItem.autostart: ReadinessState.notApplicable,
    },
    manufacturer: 'Google',
  );
}

/// Cache preset for widget tests: [ReadinessCache] state is protected, so the
/// seeded value has to come from a subclass.
class SeededReadinessCache extends ReadinessCache {
  SeededReadinessCache(ReadinessSnapshot? snapshot) {
    state = snapshot;
  }
}
