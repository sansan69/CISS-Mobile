// test/module_flags_test.dart
import 'package:ciss_mobile/core/settings/module_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses provided flags and falls back for unknown keys', () {
    final f = ModuleFlags.fromJson({'leave': true, 'loan': false});
    expect(f.isOn('leave', fallback: false), isTrue);
    expect(f.isOn('loan', fallback: true), isFalse);
    expect(f.isOn('neverSent', fallback: true), isTrue);
    expect(f.isOn('neverSent', fallback: false), isFalse);
  });

  test('defaults keeps shipped modules on and new modules off', () {
    final f = ModuleFlags.defaults();
    expect(f.isOn('attendance', fallback: false), isTrue);
    expect(f.isOn('break', fallback: false), isTrue);
    expect(f.isOn('leave', fallback: false), isTrue);
    expect(f.isOn('loan', fallback: true), isFalse);
    expect(f.isOn('ipAttendance', fallback: true), isFalse);
  });
}
