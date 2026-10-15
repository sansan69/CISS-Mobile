import '../models/auth_session.dart';
import '../models/app_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keys for notification destinations currently on the protected route stack.
/// The event key is scoped to role, owner, and API origin by the service.
final dutyNotificationActiveDestinationsProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);

class DutyNotificationDestination {
  const DutyNotificationDestination(this.role, this.recordId);
  final AppRole role;
  final String recordId;
  static DutyNotificationDestination? resolve(
    Map<String, dynamic> data,
    AuthSession? session,
  ) {
    if (session == null || data['recipientUid'] != session.uid) return null;
    final type = data['type'];
    final route = data['routeKind'];
    final guard =
        ['duty_assigned', 'duty_changed', 'duty_cancelled'].contains(type) ||
        route == 'guard_duties';
    final fo = type == 'duty_willingness' || route == 'work_order_willingness';
    final role = appRoleFromWire(data['recipientRole']);
    if ((!guard && !fo) ||
        role != session.role ||
        (guard && role != AppRole.guard) ||
        (fo && role != AppRole.fieldOfficer)) {
      return null;
    }
    final id =
        guard
            ? data['assignmentId'] ?? data['workOrderId']
            : data['workOrderId'];
    if (id is! String ||
        id.isEmpty ||
        id.contains('/') ||
        id == '..' ||
        id.length > 256) {
      return null;
    }
    return DutyNotificationDestination(role!, id);
  }
}
