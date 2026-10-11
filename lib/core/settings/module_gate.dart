// lib/core/settings/module_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'remote_config_provider.dart';

/// Whether the server-driven module [key] is enabled for the active account.
///
/// Defaults to [fallback] when the server has not reported the module, which
/// keeps shipped features visible until a deployment explicitly turns them off.
bool moduleEnabled(WidgetRef ref, String key, {bool fallback = true}) =>
    ref.watch(remoteConfigProvider).modules.isOn(key, fallback: fallback);

/// Shows [child] only when module [module] is enabled; otherwise renders a
/// neutral "not enabled" body.
///
/// The dashboard itself stays visible — gate genuinely optional sections so a
/// module rollout can hide a feature without shipping a new build.
class ModuleGate extends ConsumerWidget {
  const ModuleGate({
    super.key,
    required this.module,
    required this.child,
    this.fallback = true,
  });

  final String module;
  final Widget child;
  final bool fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (moduleEnabled(ref, module, fallback: fallback)) return child;
    return const Scaffold(
      body: Center(child: Text("This feature isn't enabled for your account.")),
    );
  }
}
