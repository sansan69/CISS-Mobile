import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../core/auth/saved_accounts_service.dart';
import '../../../core/models/auth_session.dart';
import '../../../core/network/ciss_error.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/brand_banner.dart';
import '../../../shared/widgets/status_chip.dart';

enum LoginRole { guard, fieldOfficer }

class RoleLoginScreen extends ConsumerStatefulWidget {
  const RoleLoginScreen.guard({super.key})
    : role = LoginRole.guard,
      pageTitle = 'Guard duty login',
      heroTitle = 'Guard operations',
      heroSubtitle = 'Secure access for on-site attendance and shift tools.',
      usernameLabel = 'Employee ID or phone',
      usernameHint = 'CISS/2026/001',
      passwordLabel = 'Duty PIN',
      passwordHint = '••••',
      buttonLabel = 'Continue to duty workspace';

  const RoleLoginScreen.fieldOfficer({super.key})
    : role = LoginRole.fieldOfficer,
      pageTitle = 'Field officer command login',
      heroTitle = 'Field command',
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

class _RoleLoginScreenState extends ConsumerState<RoleLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  bool _loading = false;
  String? _error;
  List<SavedAccount> _savedAccounts = <SavedAccount>[];
  bool _accountsLoaded = false;
  bool _biometricAvailable = false;
  bool _enableBiometric = false;


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
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
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
      setState(() {
        _loading = false;
        _error = CissError.parse(error);
      });
      _loadSavedAccounts();
    }
  }

  void _onLoginSuccess(AuthSession session) {
    setState(() => _loading = false);
    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _submit() async {
    final String loginId = _usernameController.text.trim();
    final String pin = _passwordController.text.trim();

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

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final bool isGuard = widget.role == LoginRole.guard;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: <Widget>[
            BrandBanner(
              title: widget.heroTitle,
              subtitle: widget.heroSubtitle,
              showBackButton: true,
              onBack: () => context.go('/login'),
              trailing: StatusChip(
                label: isGuard ? 'Guard access' : 'Officer access',
                icon: isGuard
                    ? Icons.shield_rounded
                    : Icons.admin_panel_settings_rounded,
                tone: isGuard ? StatusChipTone.success : StatusChipTone.info,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                widget.pageTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // ── Saved accounts ─────────────────────────────────────────────
            if (_accountsLoaded && _savedAccounts.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              _SavedAccountsSection(
                accounts: _savedAccounts,
                tokens: tokens,
                biometricAvailable: _biometricAvailable,
                onTap: _fillAccount,
                onBiometricTap: _tryBiometricLogin,
                onRemove: _removeSavedAccount,
              ),
            ],

            // ── Login form ─────────────────────────────────────────────────
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: tokens.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    isGuard
                        ? 'Use the same credentials issued for attendance duty.'
                        : 'Use your operations account to open district tools.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _usernameController,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: isGuard
                        ? TextInputType.text
                        : TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: widget.usernameLabel,
                      hintText: widget.usernameHint,
                      prefixIcon: Icon(
                        isGuard
                            ? Icons.badge_rounded
                            : Icons.alternate_email_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: true,
                    keyboardType: isGuard
                        ? TextInputType.number
                        : TextInputType.visiblePassword,
                    onSubmitted: (_) => _loading ? null : _submit(),
                    decoration: InputDecoration(
                      labelText: widget.passwordLabel,
                      hintText: widget.passwordHint,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (_biometricAvailable) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        Checkbox(
                          value: _enableBiometric,
                          onChanged: _loading
                              ? null
                              : (v) => setState(() => _enableBiometric = v ?? false),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _loading
                                ? null
                                : () => setState(
                                    () => _enableBiometric = !_enableBiometric,
                                  ),
                            child: Text(
                              'Enable biometric login for next time',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: tokens.inkMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(widget.buttonLabel),
                  ),
                  if (isGuard) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                                final loginId =
                                    _usernameController.text.trim();
                                final bool looksLikePhone =
                                    RegExp(r'^\d{8,15}$').hasMatch(
                                      loginId.replaceAll(
                                        RegExp(r'\D+'),
                                        '',
                                      ),
                                    );
                                final params = <String, String>{
                                  if (looksLikePhone && loginId.isNotEmpty)
                                    'phoneNumber': loginId,
                                  if (!looksLikePhone && loginId.isNotEmpty)
                                    'employeeId': loginId,
                                };
                                context.go(
                                  Uri(
                                    path: '/login/guard/setup',
                                    queryParameters: params,
                                  ).toString(),
                                );
                              },
                        child: const Text('Set up PIN for first-time login'),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            Text(
              'System secured by CISS core services',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: tokens.inkMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Saved accounts section
// ─────────────────────────────────────────────────────────────────────────────

class _SavedAccountsSection extends StatelessWidget {
  const _SavedAccountsSection({
    required this.accounts,
    required this.tokens,
    required this.biometricAvailable,
    required this.onTap,
    required this.onBiometricTap,
    required this.onRemove,
  });

  final List<SavedAccount> accounts;
  final CissThemeTokens tokens;
  final bool biometricAvailable;
  final void Function(SavedAccount) onTap;
  final void Function(SavedAccount) onBiometricTap;
  final void Function(SavedAccount) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: <Widget>[
              Icon(Icons.history_rounded, size: 14, color: tokens.inkMuted),
              const SizedBox(width: 6),
              Text(
                'RECENT ACCOUNTS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: tokens.inkMuted,
                ),
              ),
            ],
          ),
        ),
        ...accounts.map(
          (account) => _SavedAccountTile(
            account: account,
            tokens: tokens,
            biometricAvailable: biometricAvailable,
            onTap: () => onTap(account),
            onBiometricTap: () => onBiometricTap(account),
            onRemove: () => onRemove(account),
          ),
        ),
      ],
    );
  }
}

class _SavedAccountTile extends StatelessWidget {
  const _SavedAccountTile({
    required this.account,
    required this.tokens,
    required this.biometricAvailable,
    required this.onTap,
    required this.onBiometricTap,
    required this.onRemove,
  });

  final SavedAccount account;
  final CissThemeTokens tokens;
  final bool biometricAvailable;
  final VoidCallback onTap;
  final VoidCallback onBiometricTap;
  final VoidCallback onRemove;

  static final DateFormat _timeFmt = DateFormat('d MMM, h:mm a');

  @override
  Widget build(BuildContext context) {
    final bool canBiometric = biometricAvailable && account.biometricEnabled;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canBiometric ? onBiometricTap : onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: <Widget>[
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tokens.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    account.initials,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: tokens.primaryStrong,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        account.displayName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: tokens.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: <Widget>[
                          Text(
                            account.maskedLoginId,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.inkMuted),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: tokens.border,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _timeFmt.format(account.lastLoginAt),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: tokens.inkMuted),
                          ),
                          if (canBiometric) ...<Widget>[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.fingerprint_rounded,
                              size: 14,
                              color: tokens.success,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Quick-fill arrow
                Icon(
                  canBiometric
                      ? Icons.fingerprint_rounded
                      : Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: tokens.primary,
                ),
                const SizedBox(width: 4),
                // Remove button
                GestureDetector(
                  onTap: onRemove,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: tokens.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
