import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

    test('default platform is safe when no channel is present', () async {
      Haptics.engine = const HapticsEngine(FlutterHapticPlatform());
      await Haptics.selection();
    });
  });

  group('Haptics facade platform failures', () {
    late HapticsEngine previous;

    setUp(() {
      previous = Haptics.engine;
      Haptics.enabled = true;
      Haptics.engine = const HapticsEngine(FlutterHapticPlatform());
    });

    tearDown(() {
      clearPlatform();
      Haptics.engine = previous;
      Haptics.enabled = true;
    });

    test('a missing platform plugin never throws', () async {
      failPlatformWith(MissingPluginException('no haptics motor'));
      await expectLater(Haptics.light(), completes);
    });

    test('a platform exception never throws', () async {
      failPlatformWith(PlatformException(code: 'unavailable'));
      await expectLater(Haptics.selection(), completes);
    });

    test('a failing engine does not latch', () async {
      Haptics.engine =
          HapticsEngine(_ThrowingPlatform(MissingPluginException('gone')));
      await expectLater(Haptics.heavy(), completes);
      await expectLater(Haptics.vibrate(), completes);
    });

    test('non-platform errors still propagate', () async {
      Haptics.engine = HapticsEngine(_ThrowingPlatform(StateError('boom')));
      await expectLater(Haptics.confirm(), throwsStateError);
    });
  });
}

class _ThrowingPlatform implements HapticPlatform {
  _ThrowingPlatform(this.error);

  final Object error;

  @override
  Future<void> lightImpact() async => throw error;

  @override
  Future<void> mediumImpact() async => throw error;

  @override
  Future<void> heavyImpact() async => throw error;

  @override
  Future<void> selectionClick() async => throw error;

  @override
  Future<void> vibrate() async => throw error;
}

void failPlatformWith(Object error) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (_) async {
    throw error;
  });
}

void clearPlatform() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null);
}
