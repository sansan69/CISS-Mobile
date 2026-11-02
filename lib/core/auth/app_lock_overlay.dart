import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/app_tokens.dart';
import '../../shared/widgets/auth/login_background.dart';
import 'app_lock_controller.dart';

/// App-level biometric app lock.
///
/// Mounted inside `MaterialApp.router.builder`, i.e. **above** the root
/// navigator, so every route the app pushes (documents, incidents,
/// guard detail, dialogs) is covered by the same opaque surface. Keeping the
/// child mounted preserves the navigation stack and screen state underneath the
/// lock; only the pixels and pointer input are replaced.
///
/// The overlay also owns the two mechanisms the previous in-route lock could not
/// provide:
///  * it observes [AppLifecycleState] for the whole app, and
///  * it blocks Android back — both the classic `popRoute` path (via the
///    binding observer, because this widget has no [ModalRoute] ancestor to
///    host a `PopScope`) and the predictive-back path.
class AppLockOverlay extends ConsumerStatefulWidget {
  const AppLockOverlay({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends ConsumerState<AppLockOverlay>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLockControllerProvider.notifier).onAppLifecycleChanged(state);
  }

  // Classic Android back button. `WidgetsApp` defers to the router when a
  // router delegate is configured, and this overlay registers before the
  // router's back-button dispatcher, so returning true swallows the press.
  @override
  Future<bool> didPopRoute() async =>
      ref.read(appLockControllerProvider).showsLockSurface;

  // Android 13+ predictive back: claim the gesture so it never commits a pop
  // while the lock is up. Default commit/cancel handlers are no-ops.
  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) =>
      ref.read(appLockControllerProvider).showsLockSurface;

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockControllerProvider);

    final controller = ref.read(appLockControllerProvider.notifier);
    // The stack shape must not change between locked and unlocked: swapping
    // between a bare child and a Stack would rebuild (and lose) the navigator
    // state underneath.
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Keep the workspace mounted, but while locked remove it from keyboard
        // focus and accessibility semantics. Pointer input is already consumed
        // by the lock surface; focus/semantics exclusion closes the hardware
        // keyboard and screen-reader paths to the covered route.
        FocusScope(
          canRequestFocus: !lock.showsLockSurface,
          descendantsAreFocusable: !lock.showsLockSurface,
          child: ExcludeSemantics(
            excluding: lock.showsLockSurface,
            child: widget.child,
          ),
        ),
        if (lock.showsLockSurface)
          Positioned.fill(
            child: AppLockScreen(
              isResolving: lock.resolving && !lock.armed,
              isAuthenticating: lock.authenticating,
              message: lock.message,
              onRetry: controller.retry,
              onUseCredentials: () => _signOutForCredentials(controller),
            ),
          ),
      ],
    );
  }

  Future<void> _signOutForCredentials(AppLockController controller) async {
    await controller.signOutForCredentials();
    // Do not leave a sensitive pushed route on top of the signed-out hub.
    rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
  }
}

/// The opaque, non-dismissible lock surface.
///
/// It matches the previous in-route `_BiometricLockScreen` so the recovery flow
/// and copy are unchanged, but it is now painted above every route.
class AppLockScreen extends StatelessWidget {
  const AppLockScreen({
    required this.isAuthenticating,
    required this.onRetry,
    required this.onUseCredentials,
    this.isResolving = false,
    this.message,
    super.key,
  });

  final bool isAuthenticating;

  /// True while the durable uid preference is still being read.
  final bool isResolving;

  /// Credential-recovery message for the current failure, if any.
  final String? message;

  final VoidCallback onRetry;
  final VoidCallback onUseCredentials;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final busy = isAuthenticating || isResolving;

    return PopScope(
      canPop: false,
      child: GestureDetector(
        // `opaque` makes the whole surface consume pointer events, so taps,
        // swipes and back-drags never reach the covered route. Child buttons
        // still win the gesture arena, as usual for nested recognizers.
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Scaffold(
          backgroundColor: tokens.canvas,
          body: SecurityGridBackground(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (isResolving) ...<Widget>[
                        // Neutral cover while the durable uid preference is
                        // still being read: the workspace must not be revealed,
                        // but nothing has failed either.
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: tokens.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Securing your workspace…',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: tokens.inkMuted, height: 1.4),
                        ),
                      ] else ...<Widget>[
                        // Lock icon on solid background
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: tokens.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.fingerprint_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'App Locked',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: tokens.ink,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          message ??
                              'Verify with your device biometrics to '
                                  'continue accessing your workspace',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color:
                                message == null
                                    ? tokens.inkMuted
                                    : tokens.warning,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 40),
                        if (busy)
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: tokens.primary,
                            ),
                          )
                        else ...<Widget>[
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: onRetry,
                              style: FilledButton.styleFrom(
                                backgroundColor: tokens.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              icon: const Icon(
                                Icons.fingerprint_rounded,
                                size: 20,
                              ),
                              label: const Text('Try biometrics again'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: onUseCredentials,
                            child: const Text('Sign in with PIN or password'),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
