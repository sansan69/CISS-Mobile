import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/app_role.dart';
import '../../../core/models/auth_session.dart';
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

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
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
          _error = error.toString().replaceFirst('Exception: ', '');
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      late final AuthSession session;
      if (widget.role == LoginRole.guard) {
        session = await ref
            .read(authControllerProvider)
            .signInAsGuard(loginIdOrPhone: loginId, pin: pin);
      } else {
        session = await ref
            .read(authControllerProvider)
            .signInAsFieldOfficer(email: loginId, password: pin);
      }
      if (mounted) {
        context.go(
          session.role == AppRole.fieldOfficer ? '/field-officer' : '/',
        );
      }
    } catch (error) {
      setState(() {
        final message = error.toString().replaceFirst('Exception: ', '');
        _error = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
              trailing: StatusChip(
                label: isGuard ? 'Guard access' : 'Officer access',
                icon: isGuard
                    ? Icons.shield_outlined
                    : Icons.admin_panel_settings_outlined,
                tone: isGuard ? StatusChipTone.success : StatusChipTone.info,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: tokens.surface,
                    foregroundColor: tokens.primaryStrong,
                    side: BorderSide(color: tokens.border),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.pageTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: tokens.inkMuted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: widget.usernameLabel,
                      hintText: widget.usernameHint,
                      prefixIcon: Icon(
                        isGuard
                            ? Icons.badge_outlined
                            : Icons.alternate_email_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
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
                                final loginId = _usernameController.text.trim();
                                final bool looksLikePhone =
                                    RegExp(r'^\d{8,15}$').hasMatch(
                                      loginId.replaceAll(RegExp(r'\D+'), ''),
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
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: tokens.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
