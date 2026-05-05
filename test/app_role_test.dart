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

    test('rejects unsupported roles', () {
      expect(appRoleFromWire('admin'), isNull);
      expect(appRoleFromWire(null), isNull);
    });
  });
}
