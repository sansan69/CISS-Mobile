import 'package:ciss_mobile/core/security/attendance_integrity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('risk signals are advisory and no-op attestation is explicit', () async {
    final risk = AttendanceIntegrity(
      attestation: const NoopAttestationSource(),
    );
    risk.recordRisk('root');
    risk.recordRisk('debugger');
    risk.recordRisk('root');
    final payload = await risk.evidence('attempt');
    expect(payload['riskFlags'], ['debugger', 'root']);
    expect(payload['attestationStatus'], 'not_configured');
    expect(payload.containsKey('blocked'), isFalse);
  });
  test('platform attestation failure still produces punch evidence', () async {
    final risk = AttendanceIntegrity(attestation: BrokenAttestation());
    final payload = await risk.evidence('attempt');
    expect(payload['attestationStatus'], 'unavailable');
  });
}

class BrokenAttestation implements AttestationSource {
  @override
  Future<Map<String, dynamic>> evidence(String attemptId) async =>
      throw StateError('platform unavailable');
}
