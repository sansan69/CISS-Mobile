import 'package:flutter_test/flutter_test.dart';
import 'package:ciss_mobile/core/models/app_role.dart';

void main() {
  group('appRoleFromWire', () {
    test('accepts guard role values', () {
      expect(appRoleFromWire('guard'), AppRole.guard);
      expect(appRoleFromWire(' Guard '), AppRole.guard);
    });

    test('accepts field officer role aliases', () {
      expect(appRoleFromWire('fieldOfficer'), AppRole.fieldOfficer);
      expect(appRoleFromWire('field-officer'), AppRole.fieldOfficer);
      expect(appRoleFromWire('field_officer'), AppRole.fieldOfficer);
      expect(appRoleFromWire('field officer'), AppRole.fieldOfficer);
    });

    test('accepts admin and client role values', () {
      expect(appRoleFromWire('admin'), AppRole.admin);
      expect(appRoleFromWire('super-admin'), AppRole.admin);
      expect(appRoleFromWire('client'), AppRole.client);
    });

    test('rejects unsupported roles', () {
      expect(appRoleFromWire('manager'), isNull);
      expect(appRoleFromWire(null), isNull);
    });
  });
}
