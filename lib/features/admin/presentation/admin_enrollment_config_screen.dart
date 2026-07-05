import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/state_block.dart';

class AdminEnrollmentConfigScreen extends ConsumerStatefulWidget {
  const AdminEnrollmentConfigScreen({super.key});

  @override
  ConsumerState<AdminEnrollmentConfigScreen> createState() =>
      _AdminEnrollmentConfigScreenState();
}

class _AdminEnrollmentConfigScreenState
    extends ConsumerState<AdminEnrollmentConfigScreen> {
  List<Map<String, dynamic>> _fields = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchConfig();
  }

  Future<void> _fetchConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final config = await repo.fetchEnrollmentConfig();
      if (!mounted) return;

      final fields = (config['fields'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          _defaultFields();
      setState(() {
        _fields = fields;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fields = _defaultFields();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _defaultFields() {
    return [
      {'key': 'firstName', 'label': 'First Name', 'enabled': true, 'required': true},
      {'key': 'lastName', 'label': 'Last Name', 'enabled': true, 'required': false},
      {'key': 'phoneNumber', 'label': 'Phone Number', 'enabled': true, 'required': true},
      {'key': 'address', 'label': 'Address', 'enabled': true, 'required': false},
      {'key': 'dateOfBirth', 'label': 'Date of Birth', 'enabled': true, 'required': false},
      {'key': 'clientId', 'label': 'Client', 'enabled': true, 'required': true},
      {'key': 'siteId', 'label': 'Site', 'enabled': true, 'required': false},
      {'key': 'district', 'label': 'District', 'enabled': true, 'required': false},
      {'key': 'photo', 'label': 'Photo Upload', 'enabled': true, 'required': false},
    ];
  }

  void _toggleField(int index) {
    setState(() {
      final field = _fields[index];
      _fields[index] = {
        ...field,
        'enabled': !(field['enabled'] == true),
      };
    });
  }

  void _moveField(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _fields.removeAt(oldIndex);
    setState(() {
      _fields.insert(newIndex, item);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(mobileRepositoryProvider);
      await repo.updateEnrollmentConfig({
        'fields': _fields,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enrollment config saved')),
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
        title: const Text('Enrollment Config'),
        backgroundColor: tokens.canvas,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: StateBlock(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load config',
                    message: _error!,
                    action: FilledButton.tonal(
                      onPressed: _fetchConfig,
                      child: const Text('Retry'),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionHeader('ENROLLMENT FORM FIELDS', tokens),
                    const SizedBox(height: 12),
                    ModernCard(
                      child: Column(
                        children: [
                          Text(
                            'Toggle and reorder fields for the enrollment form',
                            style: TextStyle(
                                fontSize: 12, color: tokens.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _fields.length,
                      onReorder: _moveField,
                      itemBuilder: (context, index) {
                        final field = _fields[index];
                        final label = field['label']?.toString() ?? '';
                        final enabled = field['enabled'] == true;
                        final required = field['required'] == true;

                        return Padding(
                          key: ValueKey(field['key']),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ModernCard(
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: enabled ? tokens.ink : tokens.inkMuted,
                                ),
                              ),
                              subtitle: Text(
                                required ? 'Required' : 'Optional',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: enabled ? tokens.inkMuted : tokens.inkMuted.withValues(alpha: 0.5),
                                ),
                              ),
                              value: enabled,
                              onChanged: (_) => _toggleField(index),
                              activeColor: tokens.primary,
                              secondary:
                                  Icon(Icons.drag_handle_rounded, color: tokens.inkMuted),
                            ),
                          ),
                        );
                      },
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
                    const SizedBox(height: 32),
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
}
