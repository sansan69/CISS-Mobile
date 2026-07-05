import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/network/providers.dart';
import '../../../shared/utils/initials.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';
import 'admin_guard_detail_screen.dart';

class AdminGuardsScreen extends ConsumerStatefulWidget {
  const AdminGuardsScreen({super.key});

  @override
  ConsumerState<AdminGuardsScreen> createState() => _AdminGuardsScreenState();
}

class _AdminGuardsScreenState extends ConsumerState<AdminGuardsScreen> {
  List<EmployeeModel> _guards = const <EmployeeModel>[];
  List<EmployeeModel> _filtered = const <EmployeeModel>[];
  List<String> _clientNames = const <String>[];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = '';
  String _clientFilter = '';

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchGuards();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchGuards() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final employees = await repo.fetchAdminEmployees(
        status: _statusFilter.isNotEmpty ? _statusFilter : null,
        clientId: _clientFilter.isNotEmpty ? _clientFilter : null,
      );
      if (!mounted) return;
      final clientNames = employees
          .map((e) => e.clientName)
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      setState(() {
        _guards = employees;
        _clientNames = clientNames;
        _loading = false;
      });
      _applySearch();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _applySearch() {
    final query = _searchQuery.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = _guards;
      } else {
        _filtered = _guards
            .where(
              (g) =>
                  g.name.toLowerCase().contains(query) ||
                  g.employeeId.toLowerCase().contains(query) ||
                  g.phoneNumber.contains(query) ||
                  g.clientName.toLowerCase().contains(query) ||
                  g.district.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StateBlock(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load guards',
              message: _error!,
              action: FilledButton.tonal(
                onPressed: _fetchGuards,
                child: const Text('Try again'),
              ),
            ),
          ),
        ),
      );
    }

    final activeCount =
        _guards.where((g) => g.status.toLowerCase() == 'active').length;
    final inactiveCount = _guards.length - activeCount;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Workforce',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_guards.length} profiles, $activeCount active',
                    style: TextStyle(fontSize: 13, color: tokens.inkMuted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: MetricCard(
                          label: 'Active',
                          value: '$activeCount',
                          color: tokens.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MetricCard(
                          label: 'Inactive',
                          value: '$inactiveCount',
                          color: tokens.inkMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MetricCard(
                          label: 'Clients',
                          value: '${_clientNames.length}',
                          color: tokens.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSearchBar(tokens),
                  const SizedBox(height: 12),
                  _buildFilterChips(tokens),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchGuards,
                child: _filtered.isEmpty
                    ? ListView(
                        children: const <Widget>[
                          SizedBox(height: 60),
                          StateBlock(
                            icon: Icons.person_off_rounded,
                            title: 'No guards found',
                            message: 'Try adjusting your search or filters.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final guard = _filtered[index];
                          final isActive =
                              guard.status.toLowerCase() == 'active';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ModernCard(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminGuardDetailScreen(
                                      employeeId: guard.employeeId.isNotEmpty
                                          ? guard.employeeId
                                          : guard.id,
                                    ),
                                  ),
                                ).then((_) => _fetchGuards());
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: tokens.primarySoft,
                                    child: Text(
                                      initials(guard.name, fallback: 'G'),
                                      style: TextStyle(
                                        color: tokens.primaryStrong,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          guard.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: tokens.ink,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (guard.employeeId.isNotEmpty)
                                          _metaLine(
                                            tokens,
                                            Icons.badge_rounded,
                                            guard.employeeId,
                                            guard.employeeId,
                                            guard.id,
                                          ),
                                        if (guard.clientName.isNotEmpty)
                                          _metaLine(
                                            tokens,
                                            Icons.business_rounded,
                                            guard.clientName,
                                            guard.employeeId,
                                            guard.id,
                                          ),
                                        if (guard.district.isNotEmpty)
                                          _metaLine(
                                            tokens,
                                            Icons.place_rounded,
                                            guard.district,
                                            guard.employeeId,
                                            guard.id,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusChip(
                                    label: isActive ? 'Active' : guard.status,
                                    tone: isActive
                                        ? StatusChipTone.success
                                        : StatusChipTone.neutral,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(CissThemeTokens tokens) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: tokens.border),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: TextStyle(fontSize: 14, color: tokens.ink),
        decoration: InputDecoration(
          hintText: 'Search by name, ID, phone...',
          hintStyle: TextStyle(fontSize: 14, color: tokens.inkMuted),
          prefixIcon: Icon(Icons.search_rounded,
              size: 20, color: tokens.inkMuted),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          isDense: true,
        ),
        onChanged: (v) {
          _searchQuery = v;
          _applySearch();
        },
      ),
    );
  }

  Widget _buildFilterChips(CissThemeTokens tokens) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          ActionChip(
            onPressed: () {
              _statusFilter = ''; _clientFilter = '';
              _fetchGuards();
            },
            avatar: Icon(Icons.clear_all_rounded,
                size: 14,
                color: _statusFilter.isEmpty && _clientFilter.isEmpty
                    ? tokens.primary
                    : tokens.inkMuted),
            label: Text(
              'All',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _statusFilter.isEmpty && _clientFilter.isEmpty
                    ? tokens.primary
                    : tokens.inkMuted,
              ),
            ),
            backgroundColor: tokens.surface,
            side: BorderSide(
              color: _statusFilter.isEmpty && _clientFilter.isEmpty
                  ? tokens.primary
                  : tokens.border,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          ...<String>['Active', 'Inactive', 'Exited', 'OnLeave'].map((s) {
            final active = _statusFilter == s;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ActionChip(
                onPressed: () {
                  _statusFilter = active ? '' : s;
                  _clientFilter = '';
                  _fetchGuards();
                },
                label: Text(
                  s,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? tokens.primary : tokens.inkMuted,
                  ),
                ),
                backgroundColor:
                    active ? tokens.primarySoft : tokens.surface,
                side: BorderSide(
                    color: active ? tokens.primary : tokens.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill)),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            );
          }),
          ..._clientNames.take(10).map((c) {
            final active = _clientFilter == c;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ActionChip(
                onPressed: () {
                  _clientFilter = active ? '' : c;
                  _statusFilter = '';
                  _fetchGuards();
                },
                label: Text(
                  c,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? tokens.primary : tokens.inkMuted,
                  ),
                ),
                backgroundColor:
                    active ? tokens.primarySoft : tokens.surface,
                side: BorderSide(
                    color: active ? tokens.primary : tokens.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill)),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _metaLine(CissThemeTokens tokens, IconData icon, String text,
      String? guardEmployeeId, String? guardId) {
    final empId = (guardEmployeeId != null && guardEmployeeId.isNotEmpty)
        ? guardEmployeeId
        : guardId ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminGuardDetailScreen(employeeId: empId),
              ),
            ).then((_) => _fetchGuards());
          },
          child: Row(
            children: <Widget>[
              Icon(icon, size: 14, color: tokens.inkMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: tokens.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
