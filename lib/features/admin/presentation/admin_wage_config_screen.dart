import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/state_block.dart';

class AdminWageConfigScreen extends ConsumerStatefulWidget {
  const AdminWageConfigScreen({super.key});

  @override
  ConsumerState<AdminWageConfigScreen> createState() =>
      _AdminWageConfigScreenState();
}

class _AdminWageConfigScreenState extends ConsumerState<AdminWageConfigScreen> {
  List<ClientModel> _clients = const [];
  String? _selectedClientId;
  List<Map<String, dynamic>> _components = const [];
  final Map<String, TextEditingController> _valueCtrls = {};
  bool _loadingClients = true;
  bool _loadingConfig = false;
  bool _saving = false;
  String? _error;

  static const List<String> _defaultComponents = [
    'basic',
    'HRA',
    'DA',
    'conveyance',
    'medical',
    'uniform',
    'field',
    'overtime',
    'bonus',
  ];

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  @override
  void dispose() {
    for (final ctrl in _valueCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchClients() async {
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final clients = await repo.fetchAdminClients();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _loadingClients = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loadingClients = false;
      });
    }
  }

  Future<void> _fetchConfig(String clientId) async {
    for (final ctrl in _valueCtrls.values) {
      ctrl.dispose();
    }
    _valueCtrls.clear();

    setState(() {
      _loadingConfig = true;
      _error = null;
    });

    try {
      final repo = ref.read(mobileRepositoryProvider);
      final config = await repo.fetchWageConfig(clientId);
      if (!mounted) return;

      final List<Map<String, dynamic>> components = [];
      for (final key in _defaultComponents) {
        final value = (config[key] as num?)?.toDouble() ?? 0;
        _valueCtrls[key] = TextEditingController(text: value.toString());
        components.add({'key': key, 'label': key.toUpperCase(), 'value': value});
      }

      setState(() {
        _components = components;
        _loadingConfig = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingConfig = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _save() async {
    if (_selectedClientId == null) return;

    setState(() => _saving = true);

    try {
      final repo = ref.read(mobileRepositoryProvider);
      final payload = <String, dynamic>{};
      for (final entry in _valueCtrls.entries) {
        final val = double.tryParse(entry.value.text.trim()) ?? 0;
        payload[entry.key] = val;
      }
      await repo.updateWageConfig(
        clientId: _selectedClientId!,
        payload: payload,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wage config saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: CissThemeTokens.of(context).danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Wage Config'),
        backgroundColor: tokens.canvas,
      ),
      body: _loadingClients
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _components.isEmpty
              ? Center(
                  child: StateBlock(
                    icon: Icons.cloud_off_rounded,
                    title: 'Error',
                    message: _error!,
                    action: FilledButton.tonal(
                      onPressed: _fetchClients,
                      child: const Text('Retry'),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionHeader('CLIENT', tokens),
                    const SizedBox(height: 12),
                    ModernCard(
                      child: DropdownButtonFormField<String>(
                        value: _selectedClientId,
                        decoration: const InputDecoration(
                          labelText: 'Select Client',
                          border: InputBorder.none,
                        ),
                        items: _clients.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() => _selectedClientId = v);
                          if (v != null) _fetchConfig(v);
                        },
                      ),
                    ),
                    if (_loadingConfig)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (!_loadingConfig &&
                        _selectedClientId != null &&
                        _components.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _sectionHeader('WAGE COMPONENTS', tokens),
                      const SizedBox(height: 12),
                      ModernCard(
                        child: Column(
                          children: [
                            ..._components.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final comp = entry.value;
                              final key = comp['key'] as String;
                              final label = comp['label'] as String;

                              return Column(
                                children: [
                                  if (idx > 0) _divider(tokens),
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 100,
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: tokens.ink,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: _valueCtrls[key],
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                              isDense: true,
                                              prefixText: '₹ ',
                                            ),
                                            keyboardType:
                                                TextInputType.number,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save Configuration'),
                        ),
                      ),
                    ],
                    if (!_loadingConfig &&
                        _selectedClientId == null) ...[
                      const SizedBox(height: 60),
                      const Center(
                        child: StateBlock(
                          icon: Icons.monetization_on_rounded,
                          title: 'Select a Client',
                          message:
                              'Choose a client to configure wage components.',
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _sectionHeader(String text, CissThemeTokens tokens) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: tokens.inkMuted,
        letterSpacing: 2,
      ),
    );
  }

  Widget _divider(CissThemeTokens tokens) {
    return Divider(height: 1, color: tokens.border.withValues(alpha: 0.3));
  }
}
