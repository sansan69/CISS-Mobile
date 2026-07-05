import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/network/providers.dart';
import '../../../shared/utils/initials.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/state_block.dart';

class AdminClientsSitesScreen extends ConsumerStatefulWidget {
  const AdminClientsSitesScreen({super.key});

  @override
  ConsumerState<AdminClientsSitesScreen> createState() =>
      _AdminClientsSitesScreenState();
}

class _AdminClientsSitesScreenState extends ConsumerState<AdminClientsSitesScreen> {
  List<ClientModel> _clients = const [];
  Map<String, List<Map<String, dynamic>>> _clientSites = const {};
  Map<String, int> _clientGuardCounts = const {};
  bool _loading = true;
  String? _error;
  String? _expandedClientId;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final clients = await repo.fetchAdminClients();
      final sitesMap = <String, List<Map<String, dynamic>>>{};
      final guardCounts = <String, int>{};

      for (final client in clients) {
        try {
          final sites = await repo.fetchAdminSites(clientId: client.id);
          sitesMap[client.id] = sites;
        } catch (_) {
          sitesMap[client.id] = const [];
        }
        try {
          final employees = await repo.fetchAdminEmployees(
            clientId: client.id,
            status: 'Active',
          );
          guardCounts[client.id] = employees.length;
        } catch (_) {
          guardCounts[client.id] = 0;
        }
      }

      if (!mounted) return;
      setState(() {
        _clients = clients;
        _clientSites = sitesMap;
        _clientGuardCounts = guardCounts;
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

  Future<void> _showCreateClientDialog() async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Client'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Client Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        final repo = ref.read(mobileRepositoryProvider);
        await repo.createClient({'name': nameCtrl.text.trim()});
        nameCtrl.dispose();
        await _fetchAll();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: CissThemeTokens.of(context).danger,
          ),
        );
      }
    }
    nameCtrl.dispose();
  }

  Future<void> _showDeleteClientDialog(ClientModel client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Client'),
        content: Text('Delete ${client.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: CissThemeTokens.of(context).danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final repo = ref.read(mobileRepositoryProvider);
        await repo.deleteClient(client.id);
        await _fetchAll();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: CissThemeTokens.of(context).danger,
          ),
        );
      }
    }
  }

  Future<void> _showCreateSiteDialog(String clientId) async {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Site'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Site Name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: lngCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        final repo = ref.read(mobileRepositoryProvider);
        final payload = <String, dynamic>{
          'clientId': clientId,
          'siteName': nameCtrl.text.trim(),
          if (addressCtrl.text.trim().isNotEmpty)
            'address': addressCtrl.text.trim(),
          if (latCtrl.text.trim().isNotEmpty)
            'lat': double.tryParse(latCtrl.text.trim()),
          if (lngCtrl.text.trim().isNotEmpty)
            'lng': double.tryParse(lngCtrl.text.trim()),
        };
        await repo.createSite(payload);
        await _fetchAll();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: CissThemeTokens.of(context).danger,
          ),
        );
      }
    }
    nameCtrl.dispose();
    addressCtrl.dispose();
    latCtrl.dispose();
    lngCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Clients & Sites'),
        backgroundColor: tokens.canvas,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateClientDialog,
        child: const Icon(Icons.add_rounded),
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
                      onPressed: _fetchAll,
                      child: const Text('Retry'),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchAll,
                  child: _clients.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            StateBlock(
                              icon: Icons.business_rounded,
                              title: 'No clients',
                              message: 'Add a client to get started.',
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _clients.length,
                          itemBuilder: (context, index) {
                            final client = _clients[index];
                            final sites =
                                _clientSites[client.id] ?? const [];
                            final guardCount =
                                _clientGuardCounts[client.id] ?? 0;
                            final isExpanded =
                                _expandedClientId == client.id;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ModernCard(
                                child: Column(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _expandedClientId = isExpanded
                                              ? null
                                              : client.id;
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: tokens.primarySoft,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                initials(client.name,
                                                    fallback: ''),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: tokens.primary,
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
                                                    client.name,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: tokens.ink,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${sites.length} sites · $guardCount guards',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: tokens.inkMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.add_location_alt_rounded,
                                                    size: 20,
                                                    color: tokens.primary,
                                                  ),
                                                  tooltip: 'Add Site',
                                                  onPressed: () =>
                                                      _showCreateSiteDialog(
                                                          client.id),
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.delete_outline_rounded,
                                                    size: 20,
                                                    color: tokens.danger,
                                                  ),
                                                  tooltip: 'Delete Client',
                                                  onPressed: () =>
                                                      _showDeleteClientDialog(
                                                          client),
                                                ),
                                                Icon(
                                                  isExpanded
                                                      ? Icons.expand_less_rounded
                                                      : Icons.expand_more_rounded,
                                                  color: tokens.inkMuted,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (isExpanded) ...[
                                      const Divider(),
                                      if (sites.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          child: Text(
                                            'No sites yet',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: tokens.inkMuted,
                                            ),
                                          ),
                                        )
                                      else
                                        ...sites.map((site) {
                                          final siteName =
                                              site['siteName']?.toString() ??
                                                  site['name']?.toString() ??
                                                  '';
                                          final hasCoords =
                                              site['lat'] != null &&
                                                  site['lng'] != null;
                                          final address =
                                              site['address']?.toString() ?? '';
                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                            leading: Icon(
                                              Icons.location_on_rounded,
                                              color: hasCoords
                                                  ? tokens.success
                                                  : tokens.warning,
                                              size: 18,
                                            ),
                                            title: Text(
                                              siteName,
                                              style: const TextStyle(
                                                  fontSize: 13),
                                            ),
                                            subtitle: address.isNotEmpty
                                                ? Text(
                                                    address,
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            tokens.inkMuted),
                                                  )
                                                : null,
                                            trailing: !hasCoords
                                                ? Tooltip(
                                                    message:
                                                        'Coordinates not verified',
                                                    child: Icon(
                                                      Icons.warning_amber_rounded,
                                                      size: 16,
                                                      color: tokens.warning,
                                                    ),
                                                  )
                                                : null,
                                          );
                                        }),
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
