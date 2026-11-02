// lib/core/settings/module_flags.dart
class ModuleFlags {
  ModuleFlags(Map<String, bool> values) : _values = Map<String, bool>.from(values);
  final Map<String, bool> _values;

  factory ModuleFlags.fromJson(Map<String, dynamic> json) => ModuleFlags(
        <String, bool>{
          ..._defaults,
          for (final entry in json.entries)
            if (!_removedModules.contains(entry.key))
              entry.key: entry.value == true,
        },
      );

  /// Modules the client refuses to enable even when a stale server snapshot
  /// still lists them. `leave` is retired with payroll; `payslips` is live
  /// again (admin-uploaded PDFs only, no payroll figures).
  static const Set<String> _removedModules = <String>{'leave'};

  factory ModuleFlags.defaults() => ModuleFlags(_defaults);

  static const Map<String, bool> _defaults = <String, bool>{
        'attendance': true,
        'qrAttendance': true,
        'offlineTracking': true,
        'biometricVerification': true,
        'documents': true,
        'payslips': true,
        'patrol': true,
        'incidents': true,
        'evaluations': true,
        'training': true,
        'workOrders': true,
        'reports': true,
        'break': true,
        'geoFence': true,
        'loan': false,
        'expense': false,
        'documentRequest': false,
        'dynamicForm': false,
        'task': false,
        'product': false,
        'paymentCollection': false,
        'notice': false,
        'clientVisit': false,
        'chat': false,
        'aiChat': false,
        'dynamicQr': false,
        'ipAttendance': false,
        'uidLogin': false,
      };

  bool isOn(String key, {required bool fallback}) =>
      _removedModules.contains(key) ? false : (_values[key] ?? fallback);

  bool get geoFence => isOn('geoFence', fallback: true);
  bool get ipAttendance => isOn('ipAttendance', fallback: false);
  bool get breakEnabled => isOn('break', fallback: true);
  bool get qrAttendance => isOn('qrAttendance', fallback: true);
  bool get offlineTracking => isOn('offlineTracking', fallback: true);

  Map<String, bool> toJson() => Map<String, bool>.from(_values);
}
