// lib/core/settings/module_flags.dart
class ModuleFlags {
  ModuleFlags(Map<String, bool> values) : _values = Map<String, bool>.from(values);
  final Map<String, bool> _values;

  factory ModuleFlags.fromJson(Map<String, dynamic> json) => ModuleFlags(
        json.map((k, v) => MapEntry(k, v == true)),
      );

  factory ModuleFlags.defaults() => ModuleFlags(const <String, bool>{
        'attendance': true,
        'qrAttendance': true,
        'offlineTracking': true,
        'biometricVerification': true,
        'leave': true,
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
      });

  bool isOn(String key, {required bool fallback}) => _values[key] ?? fallback;

  bool get geoFence => isOn('geoFence', fallback: true);
  bool get ipAttendance => isOn('ipAttendance', fallback: false);
  bool get breakEnabled => isOn('break', fallback: true);
  bool get qrAttendance => isOn('qrAttendance', fallback: true);
  bool get offlineTracking => isOn('offlineTracking', fallback: true);

  Map<String, bool> toJson() => Map<String, bool>.from(_values);
}
