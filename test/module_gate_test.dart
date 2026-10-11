import 'package:ciss_mobile/core/settings/module_gate.dart';
import 'package:ciss_mobile/core/settings/remote_config.dart';
import 'package:ciss_mobile/core/settings/remote_config_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exposes a fixed [RemoteConfig] through the provider element.
///
/// A `RemoteConfigNotifier(fetch: ...)` keeps an injected local state that
/// bypasses the Riverpod element, so a widget watching the provider would still
/// observe the default config. Overriding `build()` routes the value through the
/// element the widget actually reads.
class _FixedConfigNotifier extends RemoteConfigNotifier {
  _FixedConfigNotifier(this.config);

  final RemoteConfig config;

  @override
  RemoteConfig build() => config;
}

RemoteConfig _cfg(Map<String, bool> modules) =>
    RemoteConfig.fromJson(<String, dynamic>{'modules': modules});

Widget _app() => const MaterialApp(
      home: ModuleGate(module: 'leave', child: Text('LEAVE')),
    );

void main() {
  testWidgets('renders the child when the module is ON', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          remoteConfigProvider
              .overrideWith(() => _FixedConfigNotifier(_cfg({'leave': true}))),
        ],
        child: _app(),
      ),
    );
    await tester.pump();

    expect(find.text('LEAVE'), findsOneWidget);
    expect(find.textContaining("isn't enabled"), findsNothing);
  });

  testWidgets('blocks the child and shows a message when the module is OFF',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          remoteConfigProvider
              .overrideWith(() => _FixedConfigNotifier(_cfg({'leave': false}))),
        ],
        child: _app(),
      ),
    );
    await tester.pump();

    expect(find.text('LEAVE'), findsNothing);
    expect(find.textContaining("isn't enabled"), findsOneWidget);
  });
}
