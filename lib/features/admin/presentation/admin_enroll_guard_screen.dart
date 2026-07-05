import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/state_block.dart';

class AdminEnrollGuardScreen extends ConsumerStatefulWidget {
  const AdminEnrollGuardScreen({super.key});

  @override
  ConsumerState<AdminEnrollGuardScreen> createState() =>
      _AdminEnrollGuardScreenState();
}

class _AdminEnrollGuardScreenState extends ConsumerState<AdminEnrollGuardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  List<ClientModel> _clients = const [];
  List<Map<String, dynamic>> _sites = const [];
  List<Map<String, dynamic>> _districts = const [];
  String? _selectedClientId;
  String? _selectedSiteId;
  String? _selectedDistrict;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final clients = await repo.fetchAdminClients();
      if (!mounted) return;
      setState(() {
        _clients = clients;
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

  Future<void> _fetchSitesAndDistricts(String clientId) async {
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final sites = await repo.fetchAdminSites(clientId: clientId);
      final districts = sites
          .map((s) => s['district']?.toString() ?? '')
          .where((d) => d.isNotEmpty)
          .toSet()
          .map((d) => <String, dynamic>{'value': d, 'label': d})
          .toList();
      if (!mounted) return;
      setState(() {
        _sites = sites;
        _districts = districts;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sites = const [];
        _districts = const [];
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final repo = ref.read(mobileRepositoryProvider);
      await repo.enrollGuard({
        'firstName': _nameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        if (_selectedClientId != null) 'clientId': _selectedClientId,
        if (_selectedSiteId != null) 'siteId': _selectedSiteId,
        if (_selectedDistrict != null) 'district': _selectedDistrict,
        if (_addressCtrl.text.trim().isNotEmpty)
          'address': _addressCtrl.text.trim(),
        if (_dobCtrl.text.trim().isNotEmpty) 'dateOfBirth': _dobCtrl.text.trim(),
      });
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guard enrolled successfully')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: CissThemeTokens.of(context).danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Enroll Guard'),
        backgroundColor: tokens.canvas,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: StateBlock(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load data',
                    message: _error!,
                    action: FilledButton.tonal(
                      onPressed: _fetchInitialData,
                      child: const Text('Retry'),
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _sectionHeader('PERSONAL INFO', tokens),
                      const SizedBox(height: 12),
                      ModernCard(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icon(Icons.person_rounded),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Name is required'
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: Icon(Icons.call_rounded),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Phone is required'
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _addressCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Address (optional)',
                                prefixIcon: Icon(Icons.home_rounded),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _dobCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Date of Birth (optional)',
                                prefixIcon: Icon(Icons.cake_rounded),
                                border: OutlineInputBorder(),
                                hintText: 'YYYY-MM-DD',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _sectionHeader('ASSIGNMENT', tokens),
                      const SizedBox(height: 12),
                      ModernCard(
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedClientId,
                              decoration: const InputDecoration(
                                labelText: 'Client',
                                prefixIcon: Icon(Icons.business_rounded),
                                border: OutlineInputBorder(),
                              ),
                              items: _clients.map((c) {
                                return DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                );
                              }).toList(),
                              onChanged: (v) {
                                setState(() {
                                  _selectedClientId = v;
                                  _selectedSiteId = null;
                                  _selectedDistrict = null;
                                  _sites = const [];
                                  _districts = const [];
                                });
                                if (v != null) _fetchSitesAndDistricts(v);
                              },
                              validator: (v) =>
                                  v == null ? 'Client is required' : null,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedSiteId,
                              decoration: const InputDecoration(
                                labelText: 'Site',
                                prefixIcon: Icon(Icons.location_on_rounded),
                                border: OutlineInputBorder(),
                              ),
                              items: _sites.map((s) {
                                final name =
                                    s['siteName']?.toString() ?? s['name']?.toString() ?? '';
                                return DropdownMenuItem(
                                  value: s['id']?.toString() ?? '',
                                  child: Text(name),
                                );
                              }).toList(),
                              onChanged: (v) => setState(() => _selectedSiteId = v),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedDistrict,
                              decoration: const InputDecoration(
                                labelText: 'District',
                                prefixIcon: Icon(Icons.place_rounded),
                                border: OutlineInputBorder(),
                              ),
                              items: _districts.map((d) {
                                return DropdownMenuItem(
                                  value: d['value'] as String,
                                  child: Text(d['label'] as String),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedDistrict = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _sectionHeader('DOCUMENTS', tokens),
                      const SizedBox(height: 12),
                      ModernCard(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.camera_alt_rounded,
                                    color: tokens.inkMuted),
                                const SizedBox(width: 12),
                                Text(
                                  'Photo upload will be available after enrollment',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: tokens.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Enroll Guard'),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
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
