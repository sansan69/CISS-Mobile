import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/haptics.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/modern_input.dart';

class AdminClientDetailScreen extends ConsumerStatefulWidget {
  const AdminClientDetailScreen({
    super.key,
    required this.client,
  });

  final ClientModel client;

  @override
  ConsumerState<AdminClientDetailScreen> createState() =>
      _AdminClientDetailScreenState();
}

class _AdminClientDetailScreenState
    extends ConsumerState<AdminClientDetailScreen> {
  List<Map<String, dynamic>> _sites = const [];
  bool _loadingSites = true;
  bool _isEditing = false;

  // Edit fields
  final _nameCtrl = TextEditingController();
  final _stateCodeCtrl = TextEditingController();
  final _uniformCtrl = TextEditingController();
  final _fieldAllowCtrl = TextEditingController();
  final _holidaysCtrl = TextEditingController();

  // Geocode coordinates
  bool _geocodeLoading = false;
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  String? _selectedSiteId;
  String? _selectedSiteName;

  @override
  void initState() {
    super.initState();
    _fetchSites();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _stateCodeCtrl.dispose();
    _uniformCtrl.dispose();
    _fieldAllowCtrl.dispose();
    _holidaysCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSites() async {
    setState(() => _loadingSites = true);
    try {
      final sites = await ref
          .read(mobileRepositoryProvider)
          .fetchAdminSites(clientId: widget.client.id);
      if (!mounted) return;
      setState(() {
        _sites = sites;
        _loadingSites = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSites = false);
    }
  }

  void _startEditing() {
    Haptics.light();
    _nameCtrl.text = widget.client.name;
    _stateCodeCtrl.text = widget.client.stateCode ?? '';
    _uniformCtrl.text = widget.client.uniformAllowanceMonthly.toStringAsFixed(0);
    _fieldAllowCtrl.text = widget.client.fieldAllowanceMonthly.toStringAsFixed(0);
    _holidaysCtrl.text = widget.client.nationalHolidayList.join(', ');
    setState(() => _isEditing = true);
  }

  Future<void> _saveClient() async {
    Haptics.light();
    try {
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
      };
      if (_stateCodeCtrl.text.trim().isNotEmpty) {
        payload['stateCode'] = _stateCodeCtrl.text.trim().toUpperCase();
      }
      final uniform = double.tryParse(_uniformCtrl.text.trim());
      if (uniform != null) payload['uniformAllowanceMonthly'] = uniform;
      final fieldAllow = double.tryParse(_fieldAllowCtrl.text.trim());
      if (fieldAllow != null) payload['fieldAllowanceMonthly'] = fieldAllow;
      if (_holidaysCtrl.text.trim().isNotEmpty) {
        payload['nationalHolidayList'] = _holidaysCtrl.text
            .trim()
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      final repo = ref.read(mobileRepositoryProvider);
      await repo.updateClient(
          clientId: widget.client.id, payload: payload);
      if (!mounted) return;
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveGeocode() async {
    if (_selectedSiteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a site first')),
      );
      return;
    }
    Haptics.light();
    setState(() => _geocodeLoading = true);
    try {
      final lat = double.tryParse(_latCtrl.text.trim());
      final lng = double.tryParse(_lngCtrl.text.trim());
      if (lat == null || lng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid coordinates')),
        );
        setState(() => _geocodeLoading = false);
        return;
      }
      final repo = ref.read(mobileRepositoryProvider);
      await repo.updateSite(
        siteId: _selectedSiteId!,
        payload: <String, dynamic>{'lat': lat, 'lng': lng},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Coordinates saved for $_selectedSiteName'),
          backgroundColor: Colors.green,
        ),
      );
      await _fetchSites();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _geocodeLoading = false);
    }
  }

  void _openGeocodeDialog() {
    _latCtrl.clear();
    _lngCtrl.clear();
    _selectedSiteId = null;
    _selectedSiteName = null;

    final localTokens = CissThemeTokens.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: localTokens.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Set Coordinates',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: localTokens.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select a site and enter lat/lng coordinates',
                style: TextStyle(fontSize: 13, color: localTokens.inkMuted),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedSiteId,
                items: _sites.map((site) {
                  final name = site['siteName'] as String? ??
                      site['name'] as String? ?? '';
                  final id = site['id'] as String? ?? '';
                  return DropdownMenuItem(
                    value: id,
                    child: Text(name, maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (v) {
                  setSheetState(() {
                    _selectedSiteId = v;
                    _selectedSiteName = _sites
                        .where((s) => s['id'] == v)
                        .map((s) => s['siteName'] as String? ??
                            s['name'] as String? ?? '')
                        .firstOrNull;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Select Site',
                  filled: true,
                  fillColor: localTokens.surfaceStrong,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ModernInput(
                      controller: _latCtrl,
                      labelText: 'Latitude',
                      hintText: '10.0123',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ModernInput(
                      controller: _lngCtrl,
                      labelText: 'Longitude',
                      hintText: '76.3456',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _geocodeLoading
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          _saveGeocode();
                        },
                  icon: _geocodeLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(Icons.pin_drop_rounded, size: 18),
                  label: const Text('SAVE COORDINATES'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final c = widget.client;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: <Widget>[
            ModernHero(
              eyebrow: 'Client',
              title: c.name,
              subtitle:
                  '${c.stateCode ?? "No state"} · ${c.portalEnabled ? "Portal: ${c.portalUrl ?? 'N/A'}" : "Portal disabled"}',
              avatarText: c.name.isNotEmpty
                  ? c.name.substring(0, 1).toUpperCase()
                  : 'C',
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ModernCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'CLIENT DETAILS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: tokens.inkMuted,
                            letterSpacing: 2,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _startEditing,
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text('Edit'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _detailRow(tokens, 'State Code', c.stateCode ?? '—'),
                    _detailRow(tokens, 'Uniform Allowance',
                        '₹${c.uniformAllowanceMonthly.toStringAsFixed(0)}/mo'),
                    _detailRow(tokens, 'Field Allowance',
                        '₹${c.fieldAllowanceMonthly.toStringAsFixed(0)}/mo'),
                    _detailRow(
                      tokens,
                      'Portal',
                      c.portalEnabled
                          ? 'Enabled (${c.portalUrl ?? "No URL"})'
                          : 'Disabled',
                    ),
                    if (c.nationalHolidayList.isNotEmpty)
                      _detailRow(
                        tokens,
                        'Holidays',
                        c.nationalHolidayList.join(', '),
                      ),
                    if (c.createdAt != null && c.createdAt!.isNotEmpty)
                      _detailRow(
                        tokens,
                        'Created',
                        c.createdAt!.split('T').first,
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
                        'EDIT CLIENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: tokens.inkMuted,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Client Name'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _stateCodeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'State Code',
                          hintText: 'e.g. KL',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _uniformCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Uniform Allowance (₹/mo)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _fieldAllowCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Field Allowance (₹/mo)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _holidaysCtrl,
                        decoration: const InputDecoration(
                          labelText: 'National Holidays (comma-separated)',
                          hintText: 'Republic Day, Independence Day, ...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setState(() => _isEditing = false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _saveClient,
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
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ModernCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.place_rounded,
                            size: 18, color: tokens.primary),
                        const SizedBox(width: 8),
                        Text(
                          'SITES (${_sites.length})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: tokens.inkMuted,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingSites)
                      const LinearProgressIndicator()
                    else if (_sites.isEmpty)
                      Text('No sites for this client',
                          style: TextStyle(
                              fontSize: 13, color: tokens.inkMuted))
                    else
                      ..._sites.map((site) {
                        final name = site['siteName'] as String? ??
                            site['name'] as String? ?? '';
                        final district =
                            site['district'] as String? ?? '';
                        final lat = site['lat'];
                        final lng = site['lng'];
                        final hasCoords = lat != null && lng != null;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                hasCoords
                                    ? Icons.check_circle_rounded
                                    : Icons.location_off_rounded,
                                size: 16,
                                color: hasCoords
                                    ? tokens.success
                                    : tokens.warning,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: tokens.ink)),
                                    if (district.isNotEmpty)
                                      Text(district,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: tokens.inkMuted)),
                                  ],
                                ),
                              ),
                              if (hasCoords)
                                Text(
                                  '${(lat as num).toStringAsFixed(4)}, ${(lng as num).toStringAsFixed(4)}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: tokens.inkMuted),
                                ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openGeocodeDialog,
                        icon: const Icon(Icons.pin_drop_rounded, size: 16),
                        label: const Text('SET COORDINATES'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
      CissThemeTokens tokens, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: tokens.inkMuted)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                )),
          ),
        ],
      ),
    );
  }
}
