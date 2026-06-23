enum AppRole { guard, fieldOfficer, admin, client }

AppRole? appRoleFromWire(Object? value) {
  final normalized = value?.toString().trim().toLowerCase().replaceAll(
    RegExp(r'[\s_-]+'),
    '',
  );

  switch (normalized) {
    case 'guard':
      return AppRole.guard;
    case 'fieldofficer':
      return AppRole.fieldOfficer;
    case 'admin':
    case 'superadmin':
      return AppRole.admin;
    case 'client':
      return AppRole.client;
    default:
      return null;
  }
}

extension AppRoleLabel on AppRole {
  String get label {
    switch (this) {
      case AppRole.guard:
        return 'Guard';
      case AppRole.fieldOfficer:
        return 'Field Officer';
      case AppRole.admin:
        return 'Admin';
      case AppRole.client:
        return 'Client';
    }
  }
}
