import 'package:ciss_mobile/core/i18n/app_language.dart';
import 'package:ciss_mobile/core/i18n/app_strings.dart';
import 'package:ciss_mobile/core/permissions/device_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the user asked for and answers from a fixed snapshot.
class _FakeReadiness implements ReadinessSource {
  _FakeReadiness(this.snapshot);

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
    snapshot = ReadinessSnapshot(items);
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

ReadinessSnapshot _snapshot(Map<ReadinessItem, ReadinessState> overrides) {
  final items = <ReadinessItem, ReadinessState>{
    for (final item in ReadinessItem.values) item: ReadinessState.granted,
  };
  items.addAll(overrides);
  return ReadinessSnapshot(items);
}

void main() {
  final english = AppStrings.forLanguage(AppLanguage.english);

  group('readiness snapshot', () {
    test('is ready only when no required item needs action', () {
      expect(_snapshot(const <ReadinessItem, ReadinessState>{}).ready, isTrue);

      final missingCamera = _snapshot(const <ReadinessItem, ReadinessState>{
        ReadinessItem.camera: ReadinessState.denied,
      });
      expect(missingCamera.ready, isFalse);
      expect(missingCamera.blocking, <ReadinessItem>[ReadinessItem.camera]);
    });

    test('an unreadable required item is not blocking but is not ready', () {
      // A probe that throws must not gate a punch, and must not be reported as
      // "everything is in place" either.
      final unreadable = _snapshot(const <ReadinessItem, ReadinessState>{
        ReadinessItem.backgroundLocation: ReadinessState.unknown,
      });
      expect(unreadable.blocking, isEmpty);
      expect(unreadable.unverified, <ReadinessItem>[
        ReadinessItem.backgroundLocation,
      ]);
      expect(unreadable.ready, isFalse);

      // Advisory items never count as unverified either.
      expect(
        _snapshot(const <ReadinessItem, ReadinessState>{
          ReadinessItem.autostart: ReadinessState.unknown,
        }).unverified,
        isEmpty,
      );
    });

    test('advisory items never block a punch', () {
      final advisoryOnly = _snapshot(const <ReadinessItem, ReadinessState>{
        ReadinessItem.batteryExemption: ReadinessState.denied,
        ReadinessItem.autostart: ReadinessState.notRequested,
      });
      expect(advisoryOnly.ready, isTrue);
      expect(advisoryOnly.blocking, isEmpty);
      expect(advisoryOnly.advisory, <ReadinessItem>[
        ReadinessItem.batteryExemption,
        ReadinessItem.autostart,
      ]);
    });

    test('reports blocking items in a stable order', () {
      final snapshot = _snapshot(const <ReadinessItem, ReadinessState>{
        ReadinessItem.backgroundLocation: ReadinessState.notRequested,
        ReadinessItem.notifications: ReadinessState.permanentlyDenied,
      });
      expect(snapshot.blocking, <ReadinessItem>[
        ReadinessItem.notifications,
        ReadinessItem.backgroundLocation,
      ]);
    });

    test('round-trips through storage and ignores unknown codes', () {
      final original = _snapshot(const <ReadinessItem, ReadinessState>{
        ReadinessItem.location: ReadinessState.permanentlyDenied,
        ReadinessItem.activityRecognition: ReadinessState.notApplicable,
      });
      final restored = ReadinessSnapshot.fromStorage(original.toStorage());
      expect(restored.stateOf(ReadinessItem.location),
          ReadinessState.permanentlyDenied);
      expect(restored.stateOf(ReadinessItem.activityRecognition),
          ReadinessState.notApplicable);
      expect(restored.ready, isFalse);
      expect(restored.blocking, <ReadinessItem>[ReadinessItem.location]);

      final corrupt = ReadinessSnapshot.fromStorage(<String, String>{
        'location': 'not_a_state',
      });
      expect(corrupt.stateOf(ReadinessItem.location), ReadinessState.unknown);
    });

    test('keeps the manufacturer next to the permission states', () {
      const snapshot = ReadinessSnapshot(
        <ReadinessItem, ReadinessState>{
          ReadinessItem.location: ReadinessState.granted,
        },
        manufacturer: 'Xiaomi',
      );
      final restored = ReadinessSnapshot.fromStorage(snapshot.toStorage());
      expect(restored.manufacturer, 'Xiaomi');
      expect(restored.stateOf(ReadinessItem.location), ReadinessState.granted);
    });
  });

  group('readiness checklist', () {
    test('lists every precondition in a fixed order', () {
      final steps = buildReadinessSteps(
        _snapshot(const <ReadinessItem, ReadinessState>{}),
        english,
      );
      expect(
        steps.map((step) => step.item).toList(),
        ReadinessItem.values,
      );
      for (final step in steps) {
        expect(step.title.trim(), isNotEmpty);
        expect(step.why.trim(), isNotEmpty);
      }
      expect(steps.first.title, english.readinessNotifications);
      expect(steps.last.title, english.readinessAutostart);
    });

    test('flags which rows need a tap and which need settings', () {
      final steps = buildReadinessSteps(
        _snapshot(const <ReadinessItem, ReadinessState>{
          ReadinessItem.camera: ReadinessState.permanentlyDenied,
          ReadinessItem.location: ReadinessState.notApplicable,
        }),
        english,
      );
      final camera =
          steps.firstWhere((step) => step.item == ReadinessItem.camera);
      expect(camera.needsAction, isTrue);
      expect(camera.needsSettings, isTrue);

      final location =
          steps.firstWhere((step) => step.item == ReadinessItem.location);
      expect(location.needsAction, isFalse);

      final autostart =
          steps.firstWhere((step) => step.item == ReadinessItem.autostart);
      expect(autostart.advisory, isTrue);
      expect(autostart.needsAutostart, isTrue);

      final battery = steps.firstWhere(
        (step) => step.item == ReadinessItem.batteryExemption,
      );
      expect(battery.needsBatterySettings, isTrue);
    });

    test('localises every row', () {
      final englishSteps = buildReadinessSteps(
        _snapshot(const <ReadinessItem, ReadinessState>{}),
        english,
      );
      final hindi = buildReadinessSteps(
        _snapshot(const <ReadinessItem, ReadinessState>{}),
        AppStrings.forLanguage(AppLanguage.hindi),
      );
      final malayalam = buildReadinessSteps(
        _snapshot(const <ReadinessItem, ReadinessState>{}),
        AppStrings.forLanguage(AppLanguage.malayalam),
      );
      expect(hindi.first.title, isNot(englishSteps.first.title));
      expect(malayalam.first.title, isNot(englishSteps.first.title));
      expect(malayalam.first.why.trim(), isNotEmpty);
    });

    test('labels every state distinctly', () {
      final labels = ReadinessState.values
          .map((state) => readinessStateLabel(state, english))
          .toList();
      expect(labels.every((label) => label.trim().isNotEmpty), isTrue);
      expect(labels.toSet().length, ReadinessState.values.length);
    });
  });

  group('readiness cache', () {
    test('serves the last snapshot without touching the platform', () async {
      final cache = ReadinessCache();
      expect(cache.state, isNull);

      final fake = _FakeReadiness(
        _snapshot(const <ReadinessItem, ReadinessState>{
          ReadinessItem.backgroundLocation: ReadinessState.denied,
        }),
      );
      final snapshot = await fake.read();
      await cache.save(snapshot);

      expect(cache.state, isNotNull);
      expect(
        cache.state!.stateOf(ReadinessItem.backgroundLocation),
        ReadinessState.denied,
      );
      expect(fake.requested, isEmpty);
    });
  });

  group('readiness source contract', () {
    test('requests exactly the item the user tapped', () async {
      final fake = _FakeReadiness(
        _snapshot(const <ReadinessItem, ReadinessState>{
          ReadinessItem.activityRecognition: ReadinessState.notRequested,
        }),
      );
      final state = await fake.request(ReadinessItem.activityRecognition);
      expect(fake.requested, <ReadinessItem>[ReadinessItem.activityRecognition]);
      expect(state, ReadinessState.granted);

      await fake.openSettings();
      await fake.openBatteryOptimizationSettings();
      await fake.openAutostartSettings();
      expect(fake.settingsOpened, 1);
      expect(fake.batteryOpened, 1);
      expect(fake.autostartOpened, 1);
    });
  });
}
