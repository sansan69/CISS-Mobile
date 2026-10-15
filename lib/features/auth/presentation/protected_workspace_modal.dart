import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_role.dart';
import '../application/auth_controller.dart';

/// Keeps protected data sheets bound to the same admitted workspace as their
/// route. A modal can outlive the page below it, so it must enforce this gate
/// on its own and clear the protected route stack when admission is revoked.
class ProtectedWorkspaceModal extends ConsumerWidget {
  const ProtectedWorkspaceModal({
    required this.role,
    required this.child,
    this.onAccessRevoked,
    super.key,
  });

  final AppRole role;
  final Widget child;
  final VoidCallback? onAccessRevoked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(authSessionProvider);
    final session = sessionState.valueOrNull;
    final accessKey = ref.watch(workspaceAccessSessionKeyProvider);
    // A protected modal can be created in the same frame as a local fixture
    // session (or a normal session refresh). Keep it blank until identity is
    // resolved instead of dismissing it before its admission can be checked.
    if (sessionState.isLoading && accessKey != null) {
      return const SizedBox.shrink();
    }
    final expectedKey =
        session == null ? null : '${session.role.name}:${session.uid}';
    final allowed = session?.role == role && accessKey == expectedKey;
    if (allowed) return child;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        Navigator.of(context).pop();
      }
      onAccessRevoked?.call();
    });
    return const SizedBox.shrink();
  }
}
