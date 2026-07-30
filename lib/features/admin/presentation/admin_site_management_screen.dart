import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/modern_input.dart';

class AdminSiteManagementScreen extends ConsumerStatefulWidget {
  const AdminSiteManagementScreen({super.key});

  @override
  ConsumerState<AdminSiteManagementScreen> createState() =>
      _AdminSiteManagementScreenState();
}

class _AdminSiteManagementScreenState
    extends ConsumerState<AdminSiteManagementScreen> {
  List<Map<String, dynamic>> _sites = const [];
  List<Map<String, dynamic>> _filteredSites = const [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  // Add/Edit dialog
  bool _dialogLoading = false;
  final _nameCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  String? _editingSiteId;

  @override
  void initState() {
    super.initState();
    _fetchSites();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _clientCtrl.dispose();
    _districtCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSites() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sites =
          await ref.read(mobileRepositoryProvider).fetchAdminSites();
      if (!mounted) return;
      setState(() {
        _sites = sites;
        _applyFilter();
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

  void _applyFilter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredSites = query.isEmpty
          ? _sites
          : _sites.where((s) {
              final name = (s['siteName'] as String? ?? s['name'] as String? ?? '').toLowerCase();
              final client = (s['clientName'] as String? ?? '').toLowerCase();
              final district = (s['district'] as String? ?? '').toLowerCase();
              return name.contains(query) ||
                  client.contains(query) ||
                  district.contains(query);
            }).toList();
    });
  }

  Future<void> _addSite() async {
    Haptics.light();
    _nameCtrl.clear();
    _clientCtrl.clear();
    _districtCtrl.clear();
    _latCtrl.clear();
    _lngCtrl.clear();
    setState(() => _editingSiteId = null);

    final result = await _showSiteDialog(context: context, title: 'Add Site');
    if (result == true && mounted) {
      await _fetchSites();
    }
  }

  Future<void> _editSite(Map<String, dynamic> site) async {
    Haptics.light();
    _nameCtrl.text = site['siteName'] as String? ?? site['name'] as String? ?? '';
    _clientCtrl.text = site['clientName'] as String? ?? '';
    _districtCtrl.text = site['district'] as String? ?? '';
    _latCtrl.text = (site['lat'] as num?)?.toString() ?? '';
    _lngCtrl.text = (site['lng'] as num?)?.toString() ?? '';
    setState(() => _editingSiteId = site['id'] as String?);

    final result = await _showSiteDialog(
      context: context,
      title: 'Edit Site',
      isEditing: true,
    );
    if (result == true && mounted) {
      await _fetchSites();
    }
  }

  Future<bool?> _showSiteDialog({
    required BuildContext context,
    required String title,
    bool isEditing = false,
  }) {
    final tokens = CissThemeTokens.of(context);
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ModernInput(
                controller: _nameCtrl,
                labelText: 'Site Name',
                hintText: 'Enter site name',
              ),
              const SizedBox(height: 12),
              ModernInput(
                controller: _clientCtrl,
                labelText: 'Client Name',
                hintText: 'Enter client name',
              ),
              const SizedBox(height: 12),
              ModernInput(
                controller: _districtCtrl,
                labelText: 'District',
                hintText: 'Enter district',
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
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _dialogLoading
                ? null
                : () async {
                    setState(() => _dialogLoading = true);
                    try {
                      final payload = <String, dynamic>{
                        'siteName': _nameCtrl.text.trim(),
                        'clientName': _clientCtrl.text.trim(),
                        'district': _districtCtrl.text.trim(),
                      };
                      if (_latCtrl.text.trim().isNotEmpty) {
                        payload['lat'] = double.tryParse(_latCtrl.text.trim());
                      }
                      if (_lngCtrl.text.trim().isNotEmpty) {
                        payload['lng'] = double.tryParse(_lngCtrl.text.trim());
                      }

                      final repo = ref.read(mobileRepositoryProvider);
                      if (_editingSiteId != null) {
                        await repo.updateSite(
                            siteId: _editingSiteId!, payload: payload);
                      } else {
                        await repo.createSite(payload);
                      }
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}'),
                            backgroundColor: tokens.danger,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _dialogLoading = false);
                    }
                  },
            child: _dialogLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(isEditing ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSite(String siteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Site?'),
        content: const Text('This action cannot be undone.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await ref.read(mobileRepositoryProvider).deleteSite(siteId);
        await _fetchSites();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                      title: 'Could not load sites',
                      message: _error!,
                      action: FilledButton.tonal(
                        onPressed: _fetchSites,
                        child: const Text('Try again'),
                      ),
                    ),
                  )
                : CustomScrollView(
                    slivers: <Widget>[
                      SliverToBoxAdapter(
                        child: ModernHero(
                          eyebrow: 'Settings',
                          title: 'Site Management',
                          subtitle: '${_sites.length} sites configured',
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: ModernInput(
                            controller: _searchCtrl,
                            hintText: 'Search sites...',
                            prefixIcon: Icons.search_rounded,
                            onChanged: (_) => _applyFilter(),
                          ),
                        ),
                      ),
                      if (_filteredSites.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: StateBlock(
                            icon: Icons.place_outlined,
                            title: 'No sites found',
                            message: 'Add a site or adjust your search.',
                            action: FilledButton.icon(
                              onPressed: _addSite,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add Site'),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final site = _filteredSites[index];
                              final siteName = site['siteName'] as String? ??
                                  site['name'] as String? ??
                                  '';
                              final clientName =
                                  site['clientName'] as String? ?? '';
                              final district =
                                  site['district'] as String? ?? '';
                              final lat = site['lat'];
                              final lng = site['lng'];
                              final hasCoords =
                                  lat != null && lng != null;

                              return Padding(
                                padding: EdgeInsets.fromLTRB(
                                  16, index == 0 ? 0 : 0, 16,
                                  index == _filteredSites.length - 1 ? 24 : 8,
                                ),
                                child: ModernCard(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: <Widget>[
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: hasCoords
                                              ? tokens.successSoft
                                              : tokens.warningSoft,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          hasCoords
                                              ? Icons.check_circle_rounded
                                              : Icons.location_off_rounded,
                                          color: hasCoords
                                              ? tokens.success
                                              : tokens.warning,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              siteName.isNotEmpty
                                                  ? siteName
                                                  : 'Unnamed Site',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: tokens.ink,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: <Widget>[
                                                if (clientName.isNotEmpty)
                                                  Text(
                                                    clientName,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: tokens.inkMuted,
                                                    ),
                                                  ),
                                                if (clientName.isNotEmpty &&
                                                    district.isNotEmpty)
                                                  Text(
                                                    ' · ',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: tokens.inkMuted,
                                                    ),
                                                  ),
                                                if (district.isNotEmpty)
                                                  Text(
                                                    district,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: tokens.inkMuted,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert_rounded,
                                            color: tokens.inkMuted, size: 20),
                                        onSelected: (v) {
                                          if (v == 'edit') {
                                            _editSite(site);
                                          } else if (v == 'delete') {
                                            _deleteSite(
                                                site['id'] as String? ?? '');
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: <Widget>[
                                                Icon(Icons.edit_rounded,
                                                    size: 18),
                                                SizedBox(width: 8),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: <Widget>[
                                                Icon(Icons.delete_rounded,
                                                    size: 18, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Delete',
                                                    style: TextStyle(
                                                        color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: _filteredSites.length,
                          ),
                        ),
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSite,
        backgroundColor: tokens.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
