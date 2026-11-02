// test/module_flags_test.dart
import 'package:ciss_mobile/core/settings/module_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses provided flags and falls back for unknown keys', () {
    final f = ModuleFlags.fromJson({'expense': true, 'loan': false});
    expect(f.isOn('expense', fallback: false), isTrue);
    expect(f.isOn('loan', fallback: true), isFalse);
    expect(f.isOn('neverSent', fallback: true), isTrue);
    expect(f.isOn('neverSent', fallback: false), isFalse);
  });

  test('defaults keeps shipped modules on and new modules off', () {
    final f = ModuleFlags.defaults();
    expect(f.isOn('attendance', fallback: false), isTrue);
    expect(f.isOn('break', fallback: false), isTrue);
    expect(f.isOn('documents', fallback: false), isTrue);
    expect(f.isOn('leave', fallback: false), isFalse);
    expect(f.isOn('leave', fallback: true), isFalse);
    // Payslip documents are live again (admin-uploaded PDFs, no payroll).
    expect(f.isOn('payslips', fallback: false), isTrue);
    expect(f.isOn('payslips', fallback: true), isTrue);
  });

  test('ignores the retired leave flag but honours a payslips snapshot', () {
    final f = ModuleFlags.fromJson({'leave': true, 'payslips': true});
    expect(f.isOn('leave', fallback: true), isFalse);
    expect(f.isOn('payslips', fallback: true), isTrue);
    expect(f.toJson(), isNot(contains('leave')));
    expect(f.toJson(), containsPair('payslips', true));
    expect(f.isOn('loan', fallback: true), isFalse);
    expect(f.isOn('ipAttendance', fallback: true), isFalse);
  });

  test('a server snapshot can still turn payslips off without leave returning',
      () {
    final f = ModuleFlags.fromJson({'leave': true, 'payslips': false});
    expect(f.isOn('payslips', fallback: true), isFalse);
    expect(f.isOn('leave', fallback: true), isFalse);
  });
}
