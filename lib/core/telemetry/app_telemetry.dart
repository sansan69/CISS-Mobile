import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class TelemetrySink {
  Future<void> event(String name, Map<String, Object> parameters);
  Future<void> failure(String operation, String reason);
}

class FirebaseTelemetrySink implements TelemetrySink {
  @override
  Future<void> event(String name, Map<String, Object> parameters) async {
    await FirebaseAnalytics.instance.logEvent(
      name: name,
      parameters: parameters,
    );
  }

  @override
  Future<void> failure(String operation, String reason) async {
    await FirebaseCrashlytics.instance.recordError(
      StateError('$operation:$reason'),
      StackTrace.current,
      fatal: false,
      reason: reason,
    );
  }
}

class AppTelemetry {
  AppTelemetry({TelemetrySink? sink}) : _sink = sink ?? FirebaseTelemetrySink();
  final TelemetrySink _sink;
  static final instance = AppTelemetry();
  // This API accepts reason codes and counts, never photos, locations, IDs or PII.
  Future<void> record(
    String event, {
    String? stage,
    String? reason,
    int? count,
    bool failed = false,
  }) async {
    if (!const {
      'attendance_funnel',
      'duty_response',
      'sync_flush',
    }.contains(event)) {
      return;
    }
    try {
      final safeReason =
          reason != null && RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(reason)
              ? reason
              : 'unknown';
      await _sink.event(event, {
        if (stage != null && RegExp(r'^[a-z0-9_]{1,32}$').hasMatch(stage))
          'stage': stage,
        if (reason != null) 'reason': safeReason,
        if (count != null) 'count': count,
      });
      if (failed) await _sink.failure(event, safeReason);
    } catch (_) {
      /* Telemetry is never required to record attendance. */
    }
  }
}

final appTelemetryProvider = Provider((ref) => AppTelemetry.instance);
