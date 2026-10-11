// test/remote_config_provider_test.dart
import 'package:ciss_mobile/core/settings/remote_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('falls back to defaults and never throws on fetch failure', () async {
    final n = RemoteConfigNotifier(
      fetch: () async => throw Exception('offline'),
      role: 'guard', regionCode: 'KL', store: null,
    );
    await n.refresh();
    expect(n.state.modules.isOn('attendance', fallback: false), isTrue);
  });

  test('applies server flags on success', () async {
    final n = RemoteConfigNotifier(
      fetch: () async => {'version': 9, 'modules': {'loan': true}},
      role: 'guard', regionCode: 'KL', store: null,
    );
    await n.refresh();
    expect(n.state.version, 9);
    expect(n.state.modules.isOn('loan', fallback: false), isTrue);
  });
}
