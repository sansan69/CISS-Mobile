enum AppRole { guard, fieldOfficer }

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
    }
  }
}
