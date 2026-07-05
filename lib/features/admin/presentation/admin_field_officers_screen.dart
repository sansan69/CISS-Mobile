import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/haptics.dart';
import '../../../core/network/providers.dart';
import '../../../shared/utils/initials.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/state_block.dart';

class AdminFieldOfficersScreen extends ConsumerStatefulWidget {
  const AdminFieldOfficersScreen({super.key});

  @override
  ConsumerState<AdminFieldOfficersScreen> createState() =>
      _AdminFieldOfficersScreenState();
}

class _AdminFieldOfficersScreenState
    extends ConsumerState<AdminFieldOfficersScreen> {
  List<FieldOfficerModel> _officers = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOfficers();
  }

  Future<void> _fetchOfficers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final officers =
          await ref.read(mobileRepositoryProvider).fetchAdminFieldOfficers();
      if (!mounted) return;
      setState(() {
        _officers = officers;
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

  Future<void> _deleteOfficer(FieldOfficerModel officer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Remove Field Officer?'),
            content: Text(
              'Remove ${officer.name} (${officer.email})? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(mobileRepositoryProvider)
          .deleteFieldOfficer(officer.id);
      Haptics.medium();
      _fetchOfficers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final districtsCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Add Field Officer'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v?.trim().isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v?.trim().isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v?.trim().isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: districtsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Districts (comma separated)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(ctx);
                  try {
                    await ref
                        .read(mobileRepositoryProvider)
                        .createFieldOfficer({
                          'name': nameCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'password': passCtrl.text.trim(),
                          'assignedDistricts': districtsCtrl.text
                              .split(',')
                              .map((d) => d.trim())
                              .where((d) => d.isNotEmpty)
                              .toList(),
                        });
                    Haptics.medium();
                    _fetchOfficers();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceFirst('Exception: ', ''),
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Field Officers'),
        backgroundColor: tokens.canvas,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Officer',
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: StateBlock(
                    icon: Icons.cloud_off_rounded,
                    title: 'Error',
                    message: _error!,
                    action: FilledButton.tonal(
                      onPressed: _fetchOfficers,
                      child: const Text('Retry'),
                    ),
                  ),
                )
              : _officers.isEmpty
                  ? Center(
                      child: StateBlock(
                        icon: Icons.engineering_rounded,
                        title: 'No field officers',
                        message:
                            'Add field officers to manage guards and sites.',
                        action: FilledButton.tonal(
                          onPressed: _showCreateDialog,
                          child: const Text('Add Officer'),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchOfficers,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _officers.length,
                        itemBuilder: (context, index) {
                          final officer = _officers[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: tokens.primarySoft,
                                        child: Text(
                                          initials(officer.name, fallback: ''),
                                          style: TextStyle(
                                            color: tokens.primaryStrong,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              officer.name,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: tokens.ink,
                                              ),
                                            ),
                                            Text(
                                              officer.email,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: tokens.inkMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          color: tokens.danger,
                                        ),
                                        onPressed: () =>
                                            _deleteOfficer(officer),
                                      ),
                                    ],
                                  ),
                                  if (officer.assignedDistricts.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: officer.assignedDistricts
                                          .map(
                                            (d) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: tokens.primarySoft,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                d,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: tokens.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
