import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../core/auth/saved_accounts_service.dart';
import '../../../core/haptics.dart';
import '../../../core/network/ciss_error.dart';
import '../application/auth_controller.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _secureStorage = const FlutterSecureStorage();
  bool _loading = false;
  bool _obscurePw = true;
  bool _rememberEmail = true;
  bool _enableBiometric = false;
  bool _biometricAvailable = false;
  String? _error;
  List<SavedAccount> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
    _loadSavedAccounts();
    _checkBiometric();
  }

  Future<void> _loadSavedEmail() async {
    final saved = await _secureStorage.read(key: 'admin_remembered_email');
    if (saved != null && saved.isNotEmpty) {
      _emailCtrl.text = saved;
    }
  }

  Future<void> _loadSavedAccounts() async {
    final all = await ref.read(savedAccountsServiceProvider).loadAll();
    final adminOrClient = all.where((a) => a.role == 'admin' || a.role == 'client').toList();
    if (mounted) {
      setState(() {
        _savedAccounts = adminOrClient;
      });
    }
  }

  Future<void> _checkBiometric() async {
    final available = await ref.read(biometricServiceProvider).canAuthenticate();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _fillAccount(SavedAccount account) {
    setState(() {
      _emailCtrl.text = account.loginId;
      _passwordCtrl.clear();
      _error = null;
    });
  }

  Future<void> _tryBiometricLogin(SavedAccount account) async {
    if (!_biometricAvailable) { _fillAccount(account); return; }

    setState(() => _loading = true);
    try {
      final bioService = ref.read(biometricServiceProvider);
      final success = await bioService.authenticate(
        localizedReason: 'Authenticate to sign in as ${account.displayName}',
      );
      if (!success || !mounted) { setState(() => _loading = false); return; }

      final password = await ref
          .read(authControllerProvider)
          .getStoredPassword(role: account.role, loginId: account.loginId);

      if (password == null || password.isEmpty) {
        if (!mounted) return;
        setState(() { _loading = false; _error = 'Stored credentials not found. Enter password manually.'; });
        _fillAccount(account);
        return;
      }

      _emailCtrl.text = account.loginId;
      _passwordCtrl.text = password;
      Haptics.heavy();
      await _doSignIn(account.loginId, password, account.role);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Biometric login failed: $e'; });
    }
  }

  Future<void> _doSignIn(String email, String password, String role) async {
    try {
      await ref
          .read(authControllerProvider)
          .signInAsAdminOrClient(
            email: email,
            password: password,
            saveForBiometric: _enableBiometric,
          );

      if (!mounted) return;

      if (_rememberEmail) {
        await _secureStorage.write(key: 'admin_remembered_email', value: email.trim());
      } else {
        await _secureStorage.delete(key: 'admin_remembered_email');
      }

      Haptics.heavy();
      if (mounted) context.go('/');
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    Haptics.medium();
    setState(() { _loading = true; _error = null; });
    await _doSignIn(_emailCtrl.text.trim(), _passwordCtrl.text, 'admin');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: tokens.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.admin_panel_settings_rounded, color: tokens.primary, size: 32),
                    ),
                    const SizedBox(height: 20),
                    Text('Admin & Client Login',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tokens.ink),
                    ),
                    const SizedBox(height: 6),
                    Text('Sign in with your admin or client credentials.',
                      style: TextStyle(fontSize: 14, color: tokens.inkMuted),
                    ),
                    const SizedBox(height: 20),

                    // Saved accounts
                    if (_savedAccounts.isNotEmpty && !_loading) ...[
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _savedAccounts.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final account = _savedAccounts[index];
                            return _SavedAccountChip(
                              account: account,
                              tokens: tokens,
                              biometricAvailable: _biometricAvailable,
                              onTap: () => _tryBiometricLogin(account),
                              onRemove: () async {
                                await ref.read(savedAccountsServiceProvider).removeAccount(account.role, account.loginId);
                                await ref.read(authControllerProvider).deleteBiometricCredentials(role: account.role, loginId: account.loginId);
                                _loadSavedAccounts();
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [Expanded(child: Divider(color: tokens.border.withValues(alpha: 0.3)))],),
                      const SizedBox(height: 16),
                    ],

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tokens.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: tokens.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          Icon(Icons.error_outline, color: tokens.danger, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_error!, style: TextStyle(color: tokens.danger, fontSize: 13))),
                        ]),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),

                    // Password
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePw,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePw ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscurePw = !_obscurePw),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Remember email
                    Row(children: [
                      SizedBox(
                        height: 24, width: 24,
                        child: Checkbox(
                          value: _rememberEmail,
                          onChanged: (v) => setState(() => _rememberEmail = v ?? true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => setState(() => _rememberEmail = !_rememberEmail),
                        child: Text('Remember email', style: TextStyle(fontSize: 14, color: tokens.inkMuted)),
                      ),
                    ]),

                    // Enable biometric
                    if (_biometricAvailable) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        SizedBox(
                          height: 24, width: 24,
                          child: Checkbox(
                            value: _enableBiometric,
                            onChanged: (v) => setState(() => _enableBiometric = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => setState(() => _enableBiometric = !_enableBiometric),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fingerprint, size: 16, color: tokens.primary),
                              const SizedBox(width: 6),
                              Text('Enable biometric login',
                                style: TextStyle(fontSize: 14, color: tokens.inkMuted)),
                            ],
                          ),
                        ),
                      ]),
                    ],

                    const SizedBox(height: 20),

                    // Submit
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Sign In'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Back
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: Text('Back to role selection', style: TextStyle(color: tokens.inkMuted)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedAccountChip extends StatelessWidget {
  final SavedAccount account;
  final CissThemeTokens tokens;
  final bool biometricAvailable;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedAccountChip({
    required this.account,
    required this.tokens,
    required this.biometricAvailable,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Material(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: tokens.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: biometricAvailable
                      ? const Icon(Icons.fingerprint, size: 18)
                      : Center(child: Text(account.initials, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.primary))),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(account.displayName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(account.maskedLoginId, style: TextStyle(fontSize: 10, color: tokens.inkMuted)),
                  ]),
                ),
                if (biometricAvailable) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onRemove,
                    child: Icon(Icons.close, size: 14, color: tokens.inkMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
