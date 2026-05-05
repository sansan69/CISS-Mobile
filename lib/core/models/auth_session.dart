import 'app_role.dart';

class AuthSession {
  const AuthSession({
    required this.role,
    required this.displayName,
    required this.primaryId,
    required this.uid,
    this.token,
    this.email,
    this.employeeDocId,
    this.assignedDistricts = const <String>[],
    this.clientId,
    this.clientName,
    this.stateCode,
  });

  final AppRole role;
  final String displayName;
  final String primaryId;
  final String uid;
  final String? token;
  final String? email;
  final String? employeeDocId;
  final List<String> assignedDistricts;
  final String? clientId;
  final String? clientName;
  final String? stateCode;
}
