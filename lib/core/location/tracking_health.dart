import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../permissions/device_readiness.dart';

/// Presentation state for one row of the tracking-health card.
enum TrackingHealthState { ok, actionNeeded, unknown }

/// Whether the user-visible foreground service is currently running.
///
/// This is the only condition the readiness checklist cannot answer: the
/// service can be stopped by the OS even when every permission is granted.
/// Permission state itself is owned by `lib/core/permissions`, so the app has
/// exactly one permission reader.
enum TrackingServiceState { running, stopped, unknown }

abstract class TrackingServiceProbe {
  Future<TrackingServiceState> read();
}

class PlatformTrackingServiceProbe implements TrackingServiceProbe {
  const PlatformTrackingServiceProbe();

  @override
  Future<TrackingServiceState> read() async {
    try {
      return await FlutterBackgroundService().isRunning()
          ? TrackingServiceState.running
          : TrackingServiceState.stopped;
    } catch (_) {
      return TrackingServiceState.unknown;
    }
  }
}

final trackingServiceProbeProvider = Provider<TrackingServiceProbe>(
  (ref) => const PlatformTrackingServiceProbe(),
);

/// Read only when a screen asks for it — the health card reads this after the
/// guard taps "Check", never while unrelated screens build.
final trackingServiceStateProvider = FutureProvider<TrackingServiceState>(
  (ref) => ref.watch(trackingServiceProbeProvider).read(),
);

/// Maps a readiness state onto the card's row presentation.
TrackingHealthState trackingHealthFor(ReadinessState state) => switch (state) {
  ReadinessState.granted || ReadinessState.notApplicable =>
    TrackingHealthState.ok,
  ReadinessState.denied ||
  ReadinessState.permanentlyDenied ||
  ReadinessState.notRequested => TrackingHealthState.actionNeeded,
  ReadinessState.unknown => TrackingHealthState.unknown,
};

/// Rows the card renders, in the order a guard should repair them.
const List<ReadinessItem> trackingHealthItems = <ReadinessItem>[
  ReadinessItem.location,
  ReadinessItem.backgroundLocation,
  ReadinessItem.notifications,
  ReadinessItem.batteryExemption,
];
