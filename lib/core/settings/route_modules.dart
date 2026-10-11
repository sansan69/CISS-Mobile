// lib/core/settings/route_modules.dart
import 'module_flags.dart';

/// Path prefix → module key. `null`/absent = always allowed.
const Map<String, String> kRouteModules = <String, String>{
  '/qr-attendance': 'qrAttendance',
  '/attendance': 'attendance',
  '/guard/leave': 'leave',
  '/guard/patrol': 'patrol',
  '/guard/documents': 'documents',
  '/guard/payslips': 'payslips',
  '/guard/incidents': 'incidents',
  '/guard/training': 'training',
  '/guard/evaluations': 'evaluations',
};

String? moduleForPath(String path) {
  String? best;
  for (final entry in kRouteModules.entries) {
    if (path == entry.key || path.startsWith('${entry.key}/')) {
      if (best == null || entry.key.length > best.length) best = entry.key;
    }
  }
  return best == null ? null : kRouteModules[best];
}

String? gatedRedirect({required String path, required ModuleFlags flags}) {
  final module = moduleForPath(path);
  if (module == null) return null;
  if (flags.isOn(module, fallback: true)) return null;
  return '/module-unavailable?m=$module';
}
