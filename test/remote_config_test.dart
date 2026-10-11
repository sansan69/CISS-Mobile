// test/remote_config_test.dart
import 'package:ciss_mobile/core/settings/remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses app + modules from the data envelope', () {
    final rc = RemoteConfig.fromJson({
      'version': 7,
      'app': {'minSupportedVersion': '1.0.21', 'forceUpdate': true, 'maintenance': false,
              'currencySymbol': '₹', 'distanceUnit': 'km'},
      'modules': {'leave': true, 'loan': false},
    });
    expect(rc.version, 7);
    expect(rc.app.forceUpdate, isTrue);
    expect(rc.app.currencySymbol, '₹');
    expect(rc.modules.isOn('leave', fallback: false), isTrue);
    expect(rc.modules.isOn('loan', fallback: true), isFalse);
    expect(rc.modules.isOn('patrol', fallback: false), isTrue); // default
  });

  test('survives a minimal/empty payload', () {
    final rc = RemoteConfig.fromJson(const {});
    expect(rc.app.forceUpdate, isFalse);
    expect(rc.modules.isOn('attendance', fallback: false), isTrue);
  });
}
