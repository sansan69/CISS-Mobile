import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:ciss_mobile/core/haptics.dart';
import 'package:ciss_mobile/core/haptics/haptic_event.dart';
import 'package:ciss_mobile/core/haptics/haptic_platform.dart';
import 'package:ciss_mobile/core/haptics/haptics_engine.dart';

class _RecordingPlatform implements HapticPlatform {
  final List<String> calls = [];

  @override
  Future<void> lightImpact() async => calls.add('light');

  @override
  Future<void> mediumImpact() async => calls.add('medium');

  @override
  Future<void> heavyImpact() async => calls.add('heavy');

  @override
  Future<void> selectionClick() async => calls.add('selection');

  @override
  Future<void> vibrate() async => calls.add('vibrate');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HapticsEngine mapping', () {
    late _RecordingPlatform p;
    late HapticsEngine e;

    setUp(() {
      p = _RecordingPlatform();
      e = HapticsEngine(p);
    });

    test('selection, tick and toggle are selection clicks', () async {
      await e.emit(HapticEvent.selection);
      await e.emit(HapticEvent.tick);
      await e.emit(HapticEvent.toggle);
      expect(p.calls, ['selection', 'selection', 'selection']);
    });

    test('impact events map to their strength', () async {
      await e.emit(HapticEvent.light);
      await e.emit(HapticEvent.medium);
      await e.emit(HapticEvent.heavy);
      expect(p.calls, ['light', 'medium', 'heavy']);
    });

    test('confirm is medium and reject/warning are heavy', () async {
      await e.emit(HapticEvent.confirm);
      await e.emit(HapticEvent.reject);
      await e.emit(HapticEvent.warning);
      expect(p.calls, ['medium', 'heavy', 'heavy']);
    });

    test('vibrate is reserved for attention events', () async {
      await e.emit(HapticEvent.vibrate);
      expect(p.calls, ['vibrate']);
    });
  });

  group('Haptics facade', () {
    late _RecordingPlatform p;
    late HapticsEngine previous;

    setUp(() {
      previous = Haptics.engine;
      p = _RecordingPlatform();
      Haptics.engine = HapticsEngine(p);
      Haptics.enabled = true;
    });

    tearDown(() {
      Haptics.engine = previous;
      Haptics.enabled = true;
    });

    test('legacy methods delegate to the engine', () async {
      await Haptics.success();
      await Haptics.error();
      await Haptics.light();
      expect(p.calls, ['medium', 'heavy', 'light']);
    });

    test('disabled haptics never reach the platform', () async {
      Haptics.enabled = false;
      await Haptics.medium();
      expect(p.calls, isEmpty);
    });

    for (final failure in <Exception>[
      MissingPluginException('Haptics unavailable'),
      PlatformException(code: 'unavailable', message: 'Motor unavailable'),
    ]) {
      test(
        'platform ${failure.runtimeType} is harmless for UI feedback',
        () async {
          Haptics.engine = const HapticsEngine(FlutterHapticPlatform());
          final calls = <MethodCall>[];
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(SystemChannels.platform, (
            call,
          ) async {
            calls.add(call);
            throw failure;
          });
          addTearDown(
            () => messenger.setMockMethodCallHandler(
              SystemChannels.platform,
              null,
            ),
          );

          await expectLater(Haptics.selection(), completes);
          await expectLater(Haptics.medium(), completes);
          expect(calls.map((call) => call.method), [
            'HapticFeedback.vibrate',
            'HapticFeedback.vibrate',
          ]);
          expect(calls.map((call) => call.arguments), [
            'HapticFeedbackType.selectionClick',
            'HapticFeedbackType.mediumImpact',
          ]);
        },
      );
    }

    test('default platform is safe when no channel is present', () async {
      Haptics.engine = const HapticsEngine(FlutterHapticPlatform());
      await Haptics.selection();
    });
  });
}
