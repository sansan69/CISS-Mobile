import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../models/auth_session.dart';
import '../security/screen_security.dart';
import 'app_lock_lifecycle.dart';
import 'app_lock_preferences.dart';
import 'biometric_service.dart';
import 'saved_accounts_service.dart';

/// Copy shown on the app-lock surface. These are the same credential-recovery
/// messages the previous in-route lock used, so nothing a guard already learned
/// changes.
const String kAppLockReason = 'Verify to access your duty workspace';
const String kAppLockNotAvailableMessage =
    'Biometric app lock is not available right now. '
    'Sign in with your PIN or password to continue.';
const String kAppLockPermanentlyLockedMessage =
    'Biometric app lock was permanently locked on this device. '
    'Sign in with your PIN or password to continue.';
const String kAppLockLockedOutMessage =
    'Biometric app lock is temporarily locked. Unlock your phone '
    'with its PIN or pattern, then retry.';
const String kAppLockFailedMessage =
    'Could not verify with biometrics. Try again.';
const String kAppLockErrorMessage =
    'Could not verify with biometrics. Please try again.';

/// Holder name used by the app lock when it asks for `FLAG_SECURE`.
const String kAppLockSecureHolder = 'app_lock_overlay';

/// App-wide biometric app-lock state.
///
/// The state is bound to a verified [AuthSession]'s uid: the durable
/// `biometricEnabled` flag in [SavedAccountsService] is read once per uid and
/// cached for the lifetime of the process (live enable/disable from the
/// settings sheet is picked up through [appLockPreferencesProvider]). If the
/// durable flag cannot be read, the lock fails closed by signing the session out
/// instead of silently exposing the workspace.
@immutable
class AppLockState {
  const AppLockState({
    this.armed = false,
    this.authenticating = false,
    this.resolving = false,
    this.appLockEnabled = false,
    this.message,
  });

  /// The opaque lock surface must be painted above the navigator.
  final bool armed;

  /// A biometric prompt owned by this controller is on screen. Lifecycle
  /// transitions are ignored while it is set, so the OS prompt itself cannot
  /// arm a second lock (and therefore cannot start a prompt loop).
  final bool authenticating;

  /// The durable uid preference is being read. The workspace stays hidden until
  /// the answer is known, mirroring the old gate's fail-closed loading state.
  final bool resolving;

  /// The active session's durable app-lock preference.
  final bool appLockEnabled;

  /// Credential-recovery copy for the lock surface.
  final String? message;

  /// Whether the overlay must paint an opaque cover over the navigator.
  bool get showsLockSurface => armed || resolving;

  AppLockState copyWith({
    bool? armed,
    bool? authenticating,
    bool? resolving,
    bool? appLockEnabled,
    String? message,
    bool resetMessage = false,
  }) {
    return AppLockState(
      armed: armed ?? this.armed,
      authenticating: authenticating ?? this.authenticating,
      resolving: resolving ?? this.resolving,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      message: resetMessage ? null : (message ?? this.message),
    );
  }
}

/// Session state listened to by [AppLockController].
typedef AppLockSessionValue = AsyncValue<AuthSession?>;

class AppLockController extends StateNotifier<AppLockState> {
  AppLockController(this._ref) : super(const AppLockState()) {
    _security = _ref.read(screenSecurityProvider);
    _sessionSubscription = _ref.listen<AppLockSessionValue>(
      authSessionProvider,
      (previous, next) => _handleSession(next.valueOrNull),
      fireImmediately: true,
    );
    _preferenceSubscription = _ref.listen<Map<String, bool>>(
      appLockPreferencesProvider,
      (previous, next) => _handleLivePreference(next),
    );
    _ref.onDispose(() {
      _sessionSubscription.close();
      _preferenceSubscription.close();
    });
  }

  final Ref _ref;
  late final ScreenSecurity _security;
  late final ProviderSubscription<AppLockSessionValue> _sessionSubscription;
  late final ProviderSubscription<Map<String, bool>> _preferenceSubscription;

  final AppLockLifecycle _lifecycle = AppLockLifecycle();

  /// Durable preference per `role:uid`, read at most once per process.
  final Map<String, bool> _preferenceCache = <String, bool>{};

  String? _sessionKey;
  AuthSession? _session;

  @override
  void dispose() {
    unawaited(_releaseSecureWindow());
    super.dispose();
  }

  // ── Derived from the session ───────────────────────────────────────────────

  void _handleSession(AuthSession? session) {
    if (!mounted) return;
    final key =
        session == null ? null : AppLockPreferencesNotifier.keyFor(session);
    if (key == _sessionKey) {
      _session = session;
      return;
    }

    _sessionKey = key;
    _session = session;
    // A different identity (or a sign-out) must never inherit the previous
    // account's armed/authenticating flags.
    state = const AppLockState();
    _lifecycle.reset();

    if (session == null || key == null) {
      _resetToSignedOut();
      return;
    }

    final cached = _preferenceCache[key];
    if (cached != null) {
      _applyPreference(key, cached);
      return;
    }

    // The settings sheet publishes completed preference changes here, so a
    // value already present in the map is authoritative.
    final live = _ref.read(appLockPreferencesProvider)[key];
    if (live != null) {
      _preferenceCache[key] = live;
      _applyPreference(key, live);
      return;
    }

    // Never reveal the workspace before the durable, uid-scoped flag is known.
    state = const AppLockState(resolving: true);
    unawaited(_resolvePreference(session, key));
  }

  Future<void> _resolvePreference(AuthSession session, String key) async {
    bool? enabled;
    Object? failure;
    try {
      enabled = await _ref
          .read(savedAccountsServiceProvider)
          .isBiometricAppLockEnabledFor(session);
    } catch (error) {
      failure = error;
    }
    if (!mounted || _sessionKey != key) return;

    if (enabled == null) {
      // We cannot decide whether this uid is locked. Fail closed: drop the
      // session so the user recovers through a fresh PIN/password sign-in.
      debugPrint('App lock preference unreadable — signing out: $failure');
      state = const AppLockState();
      unawaited(_releaseSecureWindow());
      unawaited(_ref.read(authControllerProvider).signOut());
      return;
    }

    _preferenceCache[key] = enabled;
    // Keep the in-memory preference map (shared with the settings sheet) in
    // sync so every surface agrees on the resolved value.
    _ref.read(appLockPreferencesProvider.notifier).setFor(session, enabled);
    _applyPreference(key, enabled);
  }

  void _handleLivePreference(Map<String, bool> preferences) {
    if (!mounted) return;
    final key = _sessionKey;
    final session = _session;
    if (key == null || session == null) return;
    final value = preferences[key];
    if (value == null) return;
    _preferenceCache[key] = value;
    _applyPreference(key, value);
  }

  void _applyPreference(String key, bool enabled) {
    if (!mounted || key != _sessionKey) return;
    final resolved = !state.resolving;
    if (resolved && state.appLockEnabled == enabled) return;

    state = state.copyWith(
      resolving: false,
      appLockEnabled: enabled,
      armed: enabled ? state.armed : false,
      authenticating: enabled ? state.authenticating : false,
    );

    if (enabled) {
      // Cold start with a locked session, or the lock was just enabled from
      // settings while the workspace is open.
      _armAndPrompt();
    } else {
      _clearLock();
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Forwarded by [AppLockOverlay], which is mounted above every route.
  ///
  /// Only a real background transition (`paused`/`detached`) arms the lock.
  /// `inactive` is deliberately ignored: transient system UI — the biometric
  /// prompt itself, permission dialogs, the notification shade — reports it
  /// without the app ever leaving the foreground, and arming there would cover
  /// those dialogs and start a second prompt. On Android foregrounding always
  /// reports `resumed`, and backgrounding always reaches `paused`, so the
  /// background→resume requirements are still fully covered.
  void onAppLifecycleChanged(AppLifecycleState lifecycle) {
    if (!mounted) return;
    final promptActive = state.authenticating;
    final enabled = state.appLockEnabled;

    if (lifecycle == AppLifecycleState.resumed) {
      if (_lifecycle.consumeLockOnResume(
        state: lifecycle,
        appLockEnabled: enabled,
        biometricPromptActive: promptActive,
      )) {
        // Exactly one prompt per background→resume cycle; further attempts only
        // happen through the explicit retry button.
        _armAndPrompt();
      }
      return;
    }

    if (lifecycle != AppLifecycleState.paused &&
        lifecycle != AppLifecycleState.detached) {
      return;
    }

    _lifecycle.didChangeAppLifecycleState(
      lifecycle,
      appLockEnabled: enabled,
      biometricPromptActive: promptActive,
    );

    if (enabled && !promptActive) {
      // Cover the workspace (and the recents snapshot) immediately, but never
      // start a prompt until the app is back in the foreground.
      _armSilently();
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// User-requested retry from the lock surface.
  void retry() {
    if (!mounted || !state.armed) return;
    state = state.copyWith(authenticating: false, resetMessage: true);
    unawaited(_runBiometricPrompt());
  }

  /// "Sign in with PIN or password": the credential fallback is a full sign-out
  /// through the existing controller, exactly as the in-route lock did.
  Future<void> signOutForCredentials() async {
    if (!mounted) return;
    state = state.copyWith(authenticating: false, resetMessage: true);
    try {
      await _ref.read(authControllerProvider).signOut();
    } catch (error) {
      debugPrint('App lock sign-out failed: $error');
    }
  }

  void _armSilently() {
    if (!mounted || state.armed) return;
    state = state.copyWith(armed: true, resolving: false, resetMessage: true);
    _acquireSecureWindow();
  }

  void _armAndPrompt() {
    if (!mounted) return;
    _armSilently();
    unawaited(_runBiometricPrompt());
  }

  Future<void> _runBiometricPrompt() async {
    if (!mounted || !state.armed || state.authenticating) return;
    state = state.copyWith(authenticating: true, resetMessage: true);

    BiometricAuthOutcome outcome;
    try {
      outcome = await _ref
          .read(biometricServiceProvider)
          .authenticateFingerprint(localizedReason: kAppLockReason);
    } catch (error) {
      debugPrint('App lock biometric prompt failed: $error');
      outcome = BiometricAuthOutcome.error;
    }
    if (!mounted) return;

    switch (outcome) {
      case BiometricAuthOutcome.success:
        _unlock();
      case BiometricAuthOutcome.notAvailable:
      case BiometricAuthOutcome.notEnrolled:
        // The stored binding no longer matches this device — never brick the
        // user; fall back to a fresh PIN/password sign-in.
        _stayLocked(kAppLockNotAvailableMessage);
      case BiometricAuthOutcome.permanentlyLockedOut:
        _stayLocked(kAppLockPermanentlyLockedMessage);
      case BiometricAuthOutcome.lockedOut:
        _stayLocked(kAppLockLockedOutMessage);
      case BiometricAuthOutcome.failed:
        _stayLocked(kAppLockFailedMessage);
      case BiometricAuthOutcome.error:
        _stayLocked(kAppLockErrorMessage);
    }
  }

  void _unlock() {
    _lifecycle.reset();
    state = state.copyWith(
      armed: false,
      authenticating: false,
      resolving: false,
      resetMessage: true,
    );
    unawaited(_releaseSecureWindow());
  }

  void _stayLocked(String message) {
    // Stay armed and do not auto-retry: a cancelled or failed prompt can never
    // loop.
    state = state.copyWith(
      armed: true,
      authenticating: false,
      resolving: false,
      message: message,
    );
    _acquireSecureWindow();
  }

  void _clearLock() {
    _lifecycle.reset();
    state = state.copyWith(
      armed: false,
      authenticating: false,
      resolving: false,
      resetMessage: true,
    );
    unawaited(_releaseSecureWindow());
  }

  void _resetToSignedOut() {
    _session = null;
    _lifecycle.reset();
    state = const AppLockState();
    unawaited(_releaseSecureWindow());
  }

  // ── FLAG_SECURE ────────────────────────────────────────────────────────────

  void _acquireSecureWindow() {
    unawaited(_security.acquire(kAppLockSecureHolder));
  }

  Future<void> _releaseSecureWindow() {
    return _security.release(kAppLockSecureHolder);
  }
}

final appLockControllerProvider =
    StateNotifierProvider<AppLockController, AppLockState>(
      (ref) => AppLockController(ref),
    );
