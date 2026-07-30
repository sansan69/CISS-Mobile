import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../core/auth/saved_accounts_service.dart';
import '../../../core/haptics.dart';
import '../../../core/models/auth_session.dart';
import '../../../core/network/ciss_error.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/auth/login_background.dart';
import 'guard_forgot_pin_screen.dart';

enum LoginRole { guard, fieldOfficer }

class RoleLoginScreen extends ConsumerStatefulWidget {
  const RoleLoginScreen.guard({super.key})
    : role = LoginRole.guard,
      pageTitle = 'Guard duty login',
      heroTitle = 'Guard Operations',
      heroSubtitle = 'Secure access for on-site attendance and shift tools.',
      usernameLabel = 'Employee ID or phone',
      usernameHint = 'CISS/2026/001',
      passwordLabel = 'Duty PIN',
      passwordHint = '••••',
      buttonLabel = 'Continue to duty workspace';

  const RoleLoginScreen.fieldOfficer({super.key})
    : role = LoginRole.fieldOfficer,
      pageTitle = 'Field officer command login',
      heroTitle = 'Field Command',
      heroSubtitle = 'Secure access for district oversight and reporting.',
      usernameLabel = 'Official email',
      usernameHint = 'officer@cissindia.co.in',
      passwordLabel = 'Account password',
      passwordHint = '••••••••',
      buttonLabel = 'Continue to command workspace';

  final LoginRole role;
  final String pageTitle;
  final String heroTitle;
  final String heroSubtitle;
  final String usernameLabel;
  final String usernameHint;
  final String passwordLabel;
  final String passwordHint;
  final String buttonLabel;

  @override
  ConsumerState<RoleLoginScreen> createState() => _RoleLoginScreenState();
}

class _RoleLoginScreenState extends ConsumerState<RoleLoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  bool _loading = false;
  String? _error;
  List<SavedAccount> _savedAccounts = <SavedAccount>[];
  bool _accountsLoaded = false;
  bool _biometricAvailable = false;
  bool _enableBiometric = false;

  late final AnimationController _animCtrl;

  String get _roleKey =>
      widget.role == LoginRole.guard ? 'guard' : 'fieldOfficer';

  Future<void> _checkBiometricAvailability() async {
    final bioService = ref.read(biometricServiceProvider);
    final available = await bioService.canAuthenticate();
    if (mounted) {
      setState(() => _biometricAvailable = available);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
    _checkBiometricAvailability();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Staggered entrance animation
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _animCtrl.forward();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAccounts() async {
    final accounts = await ref
        .read(savedAccountsServiceProvider)
        .loadForRole(_roleKey);
    if (mounted) {
      setState(() {
        _savedAccounts = accounts;
        _accountsLoaded = true;
      });
    }
  }

  void _fillAccount(SavedAccount account) {
    setState(() {
      _usernameController.text = account.loginId;
      _passwordController.clear();
      _error = null;
    });
    _passwordFocus.requestFocus();
  }

  Future<void> _removeSavedAccount(SavedAccount account) async {
    await ref
        .read(savedAccountsServiceProvider)
        .removeAccount(account.role, account.loginId);
    await _loadSavedAccounts();
  }

  Future<void> _tryBiometricLogin(SavedAccount account) async {
    if (!_biometricAvailable) {
      _fillAccount(account);
      return;
    }

    setState(() => _loading = true);
    try {
      final bioService = ref.read(biometricServiceProvider);
      final success = await bioService.authenticate(
        localizedReason: 'Authenticate to sign in as ${account.displayName}',
      );
      if (!success || !mounted) {
        setState(() => _loading = false);
        return;
      }

      final password = await ref
          .read(authControllerProvider)
          .getStoredPassword(role: account.role, loginId: account.loginId);

      if (password == null || password.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Stored credentials not found. Please enter your password manually.';
        });
        _fillAccount(account);
        return;
      }

      _usernameController.text = account.loginId;
      _passwordController.text = password;

      Haptics.heavy(); // Biometric auth success

      if (widget.role == LoginRole.guard) {
        await _doSignInGuard(account.loginId, password);
      } else {
        await _doSignInFieldOfficer(account.loginId, password);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Biometric login failed: $e';
      });
    }
  }

  Future<void> _doSignInGuard(String loginId, String pin) async {
    try {
      final session = await ref
          .read(authControllerProvider)
          .signInAsGuard(
            loginIdOrPhone: loginId,
            pin: pin,
            saveForBiometric: _enableBiometric,
          );
      if (!mounted) return;
      _onLoginSuccess(session);
    } catch (error) {
      if (!mounted) return;
      Haptics.error();
      setState(() {
        _loading = false;
        _error = CissError.parse(error);
      });
      _loadSavedAccounts();
    }
  }

  Future<void> _doSignInFieldOfficer(String email, String password) async {
    try {
      final session = await ref
          .read(authControllerProvider)
          .signInAsFieldOfficer(
            email: email,
            password: password,
            saveForBiometric: _enableBiometric,
          );
      if (!mounted) return;
      _onLoginSuccess(session);
    } catch (error) {
      if (!mounted) return;
      Haptics.error();
      setState(() {
        _loading = false;
        _error = CissError.parse(error);
      });
      _loadSavedAccounts();
    }
  }

  void _onLoginSuccess(AuthSession session) {
    Haptics.heavy();
    setState(() => _loading = false);
    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _submit() async {
    final String loginId = _usernameController.text.trim();
    final String pin = _passwordController.text.trim();

    Haptics.medium();

    if (widget.role == LoginRole.guard) {
      setState(() {
        _loading = true;
        _error = null;
      });

      try {
        final status = await ref
            .read(authControllerProvider)
            .checkGuardPinStatus(loginIdOrPhone: loginId);

        if (!status.found) {
          setState(() {
            _error = 'No employee was found for those details.';
            _loading = false;
          });
          return;
        }

        if (!status.hasPin) {
          if (!mounted) return;
          final bool looksLikePhone = RegExp(
            r'^\d{8,15}$',
          ).hasMatch(loginId.replaceAll(RegExp(r'\D+'), ''));
          setState(() {
            _loading = false;
          });
          final params = <String, String>{
            if (looksLikePhone) 'phoneNumber': loginId,
            if (!looksLikePhone && loginId.isNotEmpty) 'employeeId': loginId,
          };
          context.go(
            Uri(path: '/login/guard/setup', queryParameters: params).toString(),
          );
          return;
        }
      } catch (error) {
        setState(() {
          _loading = false;
          _error = CissError.parse(error);
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    if (widget.role == LoginRole.guard) {
      await _doSignInGuard(loginId, pin);
    } else {
      await _doSignInFieldOfficer(loginId, pin);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build helpers
  // ──────────────────────────────────────────────────────────────────────────

  Animation<double> _fade(double begin, double end) => Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _animCtrl,
          curve: Interval(begin, end, curve: Curves.easeOutCubic),
        ),
      );

  Animation<Offset> _slide(double begin, double end) => Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animCtrl,
          curve: Interval(begin, end, curve: Curves.easeOutCubic),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final isGuard = widget.role == LoginRole.guard;
    final theme = Theme.of(context);

    // Role-specific accent colors
    final Color heroColor = isGuard ? tokens.primary : tokens.accent;
    final Color heroColorStrong =
        isGuard ? tokens.primaryStrong : tokens.accent.withValues(alpha: 0.8);
    final Color heroSoft = isGuard ? tokens.primarySoft : tokens.accent.withValues(alpha: 0.1);
    final IconData roleIcon = isGuard
        ? Icons.verified_user_rounded
        : Icons.admin_panel_settings_rounded;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SecurityGridBackground(
        gridColor: isGuard
            ? tokens.primary.withValues(alpha: 0.06)
            : tokens.accent.withValues(alpha: 0.06),
        dotColor: isGuard
            ? tokens.primary.withValues(alpha: 0.04)
            : tokens.accent.withValues(alpha: 0.04),
        child: SafeArea(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: <Widget>[
                      // Back button
                      _FadeSlide(
                        fade: _fade(0.0, 0.3),
                        slide: _slide(0.0, 0.3),
                        child: _IconButtonCircle(
                          onTap: () => context.go('/login'),
                          icon: Icons.arrow_back_ios_new_rounded,
                          tokens: tokens,
                        ),
                      ),
                      const Spacer(),
                      // Role badge
                      _FadeSlide(
                        fade: _fade(0.0, 0.3),
                        slide: _slide(0.0, 0.3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: heroSoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: heroColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                roleIcon,
                                size: 14,
                                color: heroColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isGuard ? 'GUARD ACCESS' : 'OFFICER ACCESS',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: heroColor,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Hero section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                  child: Column(
                    children: <Widget>[
                      // Large role icon with gradient
                      _FadeSlide(
                        fade: _fade(0.05, 0.45),
                        slide: _slide(0.05, 0.45),
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                heroColor,
                                heroColorStrong,
                              ],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: heroColor.withValues(alpha: 0.25),
                                blurRadius: 32,
                                spreadRadius: 4,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            roleIcon,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Title
                      _FadeSlide(
                        fade: _fade(0.15, 0.5),
                        slide: _slide(0.15, 0.5),
                        child: Text(
                          widget.heroTitle.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: tokens.ink,
                            letterSpacing: 1.5,
                            height: 1.05,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subtitle
                      _FadeSlide(
                        fade: _fade(0.2, 0.55),
                        slide: _slide(0.2, 0.55),
                        child: Text(
                          widget.heroSubtitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.inkMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Login form
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
                  child: _FadeSlide(
                    fade: _fade(0.3, 0.7),
                    slide: _slide(0.3, 0.7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Username field
                        _LoginTextField(
                          controller: _usernameController,
                          label: widget.usernameLabel,
                          hint: widget.usernameHint,
                          prefixIcon: isGuard
                              ? Icons.badge_rounded
                              : Icons.alternate_email_rounded,
                          keyboardType: isGuard
                              ? TextInputType.text
                              : TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                          accentColor: heroColor,
                          tokens: tokens,
                        ),
                        const SizedBox(height: 16),
                        // Password field
                        _LoginTextField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          label: widget.passwordLabel,
                          hint: widget.passwordHint,
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: true,
                          keyboardType: isGuard
                              ? TextInputType.number
                              : TextInputType.visiblePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _loading ? null : _submit(),
                          accentColor: heroColor,
                          tokens: tokens,
                        ),
                        // Error message
                        if (_error != null) ...<Widget>[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: tokens.dangerSoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: tokens.danger.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: tokens.danger,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: tokens.danger,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: _loading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: heroColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  heroColor.withValues(alpha: 0.4),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(widget.buttonLabel),
                          ),
                        ),
                        if (isGuard) ...<Widget>[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      final loginId =
                                          _usernameController.text.trim();
                                      final bool looksLikePhone = RegExp(
                                        r'^\d{8,15}$',
                                      ).hasMatch(
                                        loginId.replaceAll(
                                          RegExp(r'\D+'),
                                          '',
                                        ),
                                      );
                                      final params = <String, String>{
                                        if (looksLikePhone && loginId.isNotEmpty)
                                          'phoneNumber': loginId,
                                        if (!looksLikePhone &&
                                            loginId.isNotEmpty)
                                          'employeeId': loginId,
                                      };
                                      context.go(
                                        Uri(
                                          path: '/login/guard/setup',
                                          queryParameters: params,
                                        ).toString(),
                                      );
                                    },
                              style: TextButton.styleFrom(
                                foregroundColor: tokens.inkMuted,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Set up PIN for first-time login',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const GuardForgotPinScreen(),
                                        ),
                                      );
                                    },
                              style: TextButton.styleFrom(
                                foregroundColor: tokens.danger.withValues(alpha: 0.8),
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot PIN?',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Saved accounts
              if (_accountsLoaded && _savedAccounts.isNotEmpty) ...<Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                    child: _FadeSlide(
                      fade: _fade(0.45, 0.8),
                      slide: _slide(0.45, 0.8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.history_rounded,
                                size: 14,
                                color: tokens.inkMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'RECENT ACCOUNTS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: tokens.inkMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 64,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _savedAccounts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final account = _savedAccounts[index];
                                return _SavedAccountChip(
                                  account: account,
                                  tokens: tokens,
                                  heroColor: heroColor,
                                  heroSoft: heroSoft,
                                  biometricAvailable: _biometricAvailable,
                                  onTap: () => _fillAccount(account),
                                  onBiometricTap: () =>
                                      _tryBiometricLogin(account),
                                  onRemove: () => _removeSavedAccount(account),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // Biometric toggle
              if (_biometricAvailable) ...<Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _FadeSlide(
                      fade: _fade(0.55, 0.9),
                      slide: _slide(0.55, 0.9),
                      child: GestureDetector(
                        onTap: _loading
                            ? null
                            : () => setState(
                                () => _enableBiometric = !_enableBiometric),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tokens.border),
                          ),
                          child: Row(
                            children: <Widget>[
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: _enableBiometric,
                                  onChanged: _loading
                                      ? null
                                      : (v) => setState(
                                          () => _enableBiometric = v ?? false),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Enable biometric login for next time',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: tokens.inkMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.fingerprint_rounded,
                                size: 18,
                                color: tokens.inkMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // Footer
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                  child: _FadeSlide(
                    fade: _fade(0.6, 1.0),
                    slide: _slide(0.6, 1.0),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Text(
                        'Secured by CISS Core Services',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tokens.inkMuted.withValues(alpha: 0.6),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FadeSlide extends StatelessWidget {
  const _FadeSlide({
    required this.fade,
    required this.slide,
    required this.child,
  });

  final Animation<double> fade;
  final Animation<Offset> slide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: child,
      ),
    );
  }
}

class _IconButtonCircle extends StatelessWidget {
  const _IconButtonCircle({
    required this.onTap,
    required this.icon,
    required this.tokens,
  });

  final VoidCallback onTap;
  final IconData icon;
  final CissThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: tokens.ink,
          ),
        ),
      ),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    required this.accentColor,
    required this.tokens,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;
  final Color accentColor;
  final CissThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autocorrect: false,
      enableSuggestions: false,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: tokens.ink,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: tokens.inkMuted.withValues(alpha: 0.5),
        ),
        prefixIcon: Icon(
          prefixIcon,
          size: 20,
          color: tokens.inkMuted,
        ),
        filled: true,
        fillColor: tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: accentColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tokens.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
    );
  }
}

class _SavedAccountChip extends StatelessWidget {
  const _SavedAccountChip({
    required this.account,
    required this.tokens,
    required this.heroColor,
    required this.heroSoft,
    required this.biometricAvailable,
    required this.onTap,
    required this.onBiometricTap,
    required this.onRemove,
  });

  final SavedAccount account;
  final CissThemeTokens tokens;
  final Color heroColor;
  final Color heroSoft;
  final bool biometricAvailable;
  final VoidCallback onTap;
  final VoidCallback onBiometricTap;
  final VoidCallback onRemove;

  static final DateFormat _timeFmt = DateFormat('d MMM');

  @override
  Widget build(BuildContext context) {
    final canBiometric = biometricAvailable && account.biometricEnabled;

    return GestureDetector(
      onTap: canBiometric ? onBiometricTap : onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: canBiometric
                ? heroColor.withValues(alpha: 0.3)
                : tokens.border,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: tokens.ink.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: heroSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                account.initials,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: heroColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    account.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _timeFmt.format(account.lastLoginAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            // Biometric or arrow indicator
            if (canBiometric)
              Icon(
                Icons.fingerprint_rounded,
                size: 18,
                color: heroColor,
              )
            else
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: tokens.inkMuted,
              ),
            // Remove button
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: tokens.inkMuted.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
