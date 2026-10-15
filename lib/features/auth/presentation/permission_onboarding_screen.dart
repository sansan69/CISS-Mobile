import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../shared/device_readiness_screen.dart';

/// First-run device preparation for a guard.
///
/// Renders the shared readiness checklist, which requests each permission in
/// the order the tracking contract expects and explains why it is needed. The
/// screen deliberately does not gate sign-in: the primary button asks for the
/// outstanding permissions and "Later" continues into the app, so a guard who
/// denies a prompt can still reach the workspace and finish setup from
/// More → Device setup.
class PermissionOnboardingScreen extends StatelessWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    void continueToApp() => context.go('/');

    return ScreenScaffold(
      title: strings.readinessTitle,
      subtitle: strings.readinessSubtitle,
      // Reached by redirect, not by a push; the guard leaves through "Later".
      showBackButton: false,
      children: <Widget>[
        ReadinessChecklist(
          onFinish: continueToApp,
          finishLabel: strings.readinessContinue,
          onLater: continueToApp,
        ),
      ],
    );
  }
}
