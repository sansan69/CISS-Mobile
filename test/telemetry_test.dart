import 'package:ciss_mobile/core/telemetry/app_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'events carry only safe codes and counts and failure is nonfatal',
    () async {
      final sink = FakeSink();
      final telemetry = AppTelemetry(sink: sink);
      await telemetry.record(
        'attendance_funnel',
        stage: 'outcome',
        reason: 'punch_failed',
        failed: true,
      );
      expect(sink.events.single, {
        'stage': 'outcome',
        'reason': 'punch_failed',
      });
      expect(sink.failures, ['attendance_funnel:punch_failed']);
      await telemetry.record('sync_flush', reason: 'Phone 9999999999');
      expect(sink.events.last['reason'], 'unknown');
      await telemetry.record('employee-name');
      expect(sink.events, hasLength(2));
    },
  );
}

class FakeSink implements TelemetrySink {
  final events = <Map<String, Object>>[];
  final failures = <String>[];
  @override
  Future<void> event(String name, Map<String, Object> parameters) async {
    events.add(parameters);
  }

  @override
  Future<void> failure(String operation, String reason) async {
    failures.add('$operation:$reason');
  }
}
