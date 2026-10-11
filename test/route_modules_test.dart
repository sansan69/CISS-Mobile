import 'package:ciss_mobile/core/settings/module_flags.dart';
import 'package:ciss_mobile/core/settings/route_modules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unmapped and core paths are allowed', () {
    expect(gatedRedirect(path: '/', flags: ModuleFlags.defaults()), isNull);
    expect(gatedRedirect(path: '/login/guard', flags: ModuleFlags.defaults()), isNull);
    expect(gatedRedirect(path: '/whatever', flags: ModuleFlags.defaults()), isNull);
  });

  test('disabled module redirects; enabled passes', () {
    final off = ModuleFlags.fromJson({'qrAttendance': false});
    expect(gatedRedirect(path: '/qr-attendance', flags: off), '/module-unavailable?m=qrAttendance');
    final on = ModuleFlags.fromJson({'qrAttendance': true});
    expect(gatedRedirect(path: '/qr-attendance', flags: on), isNull);
  });
}
