import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freerasp/freerasp.dart';

abstract interface class AttestationSource {
  Future<Map<String, dynamic>> evidence(String attemptId);
}

/// No integrity verdict is invented before a Play backend verifier exists.
class NoopAttestationSource implements AttestationSource {
  const NoopAttestationSource();
  @override
  Future<Map<String, dynamic>> evidence(String attemptId) async => {
    'attestationStatus': 'not_configured',
  };
}

class AttendanceIntegrity {
  AttendanceIntegrity({AttestationSource? attestation})
    : _attestation = attestation ?? const NoopAttestationSource();
  final AttestationSource _attestation;
  final Set<String> _riskFlags = {};
  String _raspStatus = 'not_configured';
  void recordRisk(String flag) {
    if (const {'root', 'debugger', 'hook'}.contains(flag)) _riskFlags.add(flag);
  }

  Future<Map<String, dynamic>> evidence(String attemptId) async {
    Map<String, dynamic> attestation;
    try {
      attestation = await _attestation
          .evidence(attemptId)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      attestation = {'attestationStatus': 'unavailable'};
    }
    return {
      ...attestation,
      'raspStatus': _raspStatus,
      'riskFlags': _riskFlags.toList()..sort(),
    };
  }

  Future<void> start() async {
    const cert = String.fromEnvironment('RASP_SIGNING_CERT_BASE64');
    const watcher = String.fromEnvironment('RASP_WATCHER_EMAIL');
    if (defaultTargetPlatform != TargetPlatform.android ||
        cert.isEmpty ||
        watcher.isEmpty) {
      return;
    }
    try {
      await Talsec.instance.attachListener(
        ThreatCallback(
          onPrivilegedAccess: () => recordRisk('root'),
          onDebug: () => recordRisk('debugger'),
          onHooks: () => recordRisk('hook'),
        ),
      );
      await Talsec.instance.start(
        TalsecConfig(
          androidConfig: AndroidConfig(
            packageName: 'co.in.ciss.ciss_mobile',
            signingCertHashes: [cert],
          ),
          watcherMail: watcher,
          isProd: kReleaseMode,
          killOnBypass: false,
        ),
      );
      _raspStatus = 'active';
    } catch (_) {
      _raspStatus = 'unavailable';
    }
  }
}

final attendanceIntegrityProvider = Provider((ref) => AttendanceIntegrity());
