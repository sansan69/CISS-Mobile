import 'app_role.dart';

class AuthSession {
  const AuthSession({
    required this.role,
    required this.displayName,
    required this.primaryId,
    required this.uid,
    this.email,
    this.employeeDocId,
    this.assignedDistricts = const <String>[],
    this.clientName,
    this.district,
    this.stateCode,
    this.offline = false,
  });

  final AppRole role;
  final String displayName;
  final String primaryId;
  final String uid;
  final String? email;
  final String? employeeDocId;
  final List<String> assignedDistricts;
  final String? clientName;
  final String? district;
  final String? stateCode;

  /// `true` only when this session was restored from the local snapshot after a
  /// transport failure (no HTTP response). The account is *not* authoritatively
  /// re-validated in that state, so the UI must surface it and every write must
  /// still require a successful server round-trip.
  final bool offline;

  AuthSession copyWith({bool? offline}) {
    return AuthSession(
      role: role,
      displayName: displayName,
      primaryId: primaryId,
      uid: uid,
      email: email,
      employeeDocId: employeeDocId,
      assignedDistricts: assignedDistricts,
      clientName: clientName,
      district: district,
      stateCode: stateCode,
      offline: offline ?? this.offline,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'role': role.name,
      'displayName': displayName,
      'primaryId': primaryId,
      'uid': uid,
      if (email != null) 'email': email,
      if (employeeDocId != null) 'employeeDocId': employeeDocId,
      if (assignedDistricts.isNotEmpty)
        'assignedDistricts': assignedDistricts,
      if (clientName != null) 'clientName': clientName,
      if (district != null) 'district': district,
      if (stateCode != null) 'stateCode': stateCode,
      if (offline) 'offline': true,
    };
  }

  /// Parses a persisted session, returning `null` when the payload cannot
  /// describe a valid account (unknown role, missing uid).
  static AuthSession? fromJson(Map<String, dynamic> json) {
    final role = appRoleFromWire(json['role']);
    final uid = json['uid']?.toString().trim() ?? '';
    if (role == null || uid.isEmpty) return null;
    final districtsRaw = json['assignedDistricts'];
    return AuthSession(
      role: role,
      displayName: json['displayName']?.toString() ?? role.label,
      primaryId: json['primaryId']?.toString() ?? '',
      uid: uid,
      email: json['email']?.toString(),
      employeeDocId: json['employeeDocId']?.toString(),
      assignedDistricts:
          districtsRaw is List
              ? districtsRaw
                  .whereType<String>()
                  .where((value) => value.trim().isNotEmpty)
                  .toList(growable: false)
              : const <String>[],
      clientName: json['clientName']?.toString(),
      district: json['district']?.toString(),
      stateCode: json['stateCode']?.toString(),
      offline: json['offline'] == true,
    );
  }
}
