import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';

class AdminStateManagementScreen extends ConsumerStatefulWidget {
  const AdminStateManagementScreen({super.key});

  @override
  ConsumerState<AdminStateManagementScreen> createState() =>
      _AdminStateManagementScreenState();
}

class _AdminStateManagementScreenState
    extends ConsumerState<AdminStateManagementScreen> {
  Map<String, dynamic>? _stateConfig;
  bool _loading = true;
  String? _error;
  bool _isEditing = false;

  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _timezoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStateConfig();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _timezoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStateConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final data = await repo.getJson('/api/admin/states');
      if (!mounted) return;
      setState(() {
        _stateConfig = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _updateStateConfig() async {
    Haptics.light();
    setState(() => _isEditing = false);
    try {
      final payload = <String, dynamic>{};
      if (_nameCtrl.text.trim().isNotEmpty) {
        payload['name'] = _nameCtrl.text.trim();
      }
      if (_codeCtrl.text.trim().isNotEmpty) {
        payload['code'] = _codeCtrl.text.trim().toUpperCase();
      }
      if (_timezoneCtrl.text.trim().isNotEmpty) {
        payload['timezone'] = _timezoneCtrl.text.trim();
      }
      await ref
          .read(mobileRepositoryProvider)
          .postGeneric('/api/admin/states', payload);
      await _fetchStateConfig();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('State configuration updated')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Update failed: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startEditing() {
    Haptics.light();
    _nameCtrl.text = _stateConfig?['name'] as String? ?? '';
    _codeCtrl.text = _stateConfig?['code'] as String? ?? '';
    _timezoneCtrl.text = _stateConfig?['timezone'] as String? ?? 'Asia/Kolkata';
    setState(() => _isEditing = true);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: StateBlock(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load state config',
                      message: _error!,
                      action: FilledButton.tonal(
                        onPressed: _fetchStateConfig,
                        child: const Text('Try again'),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: <Widget>[
                      ModernHero(
                        eyebrow: 'Settings',
                        title: 'State Management',
                        subtitle: 'Region configuration & status',
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ModernCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'REGION DETAILS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: tokens.inkMuted,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _detailRow(
                                tokens,
                                'State Name',
                                _stateConfig?['name'] as String? ?? '—',
                              ),
                              const SizedBox(height: 10),
                              _detailRow(
                                tokens,
                                'State Code',
                                _stateConfig?['code'] as String? ?? '—',
                              ),
                              const SizedBox(height: 10),
                              _detailRow(
                                tokens,
                                'Timezone',
                                _stateConfig?['timezone'] as String? ?? 'Asia/Kolkata',
                              ),
                              const SizedBox(height: 10),
                              _detailRow(
                                tokens,
                                'Status',
                                _stateConfig?['status'] as String? ?? 'active',
                                valueColor: tokens.success,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _startEditing,
                                  icon: const Icon(Icons.edit_rounded, size: 18),
                                  label: const Text('EDIT CONFIGURATION'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isEditing) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ModernCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'EDIT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: tokens.inkMuted,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _nameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'State Name',
                                    hintText: 'e.g. Kerala',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _codeCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'State Code',
                                    hintText: 'e.g. KL',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _timezoneCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Timezone',
                                    hintText: 'e.g. Asia/Kolkata',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => setState(
                                            () => _isEditing = false),
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: _updateStateConfig,
                                        child: const Text('Save'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _detailRow(
    CissThemeTokens tokens,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(fontSize: 13, color: tokens.inkMuted),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? tokens.ink,
            ),
          ),
        ),
      ],
    );
  }
}
