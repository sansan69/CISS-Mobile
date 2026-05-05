import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/guard_profile.dart';
import '../../../../../core/models/report_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/metric_tile.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';

final FutureProvider<List<WorkOrderModel>> fieldOfficerWorkOrdersProvider =
    FutureProvider<List<WorkOrderModel>>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchFieldOfficerWorkOrders();
    });

class FieldOfficerWorkOrdersScreen extends ConsumerStatefulWidget {
  const FieldOfficerWorkOrdersScreen({super.key});

  @override
  ConsumerState<FieldOfficerWorkOrdersScreen> createState() =>
      _FieldOfficerWorkOrdersScreenState();
}

enum _WorkOrderFilter { upcoming, all }

class _FieldOfficerWorkOrdersScreenState
    extends ConsumerState<FieldOfficerWorkOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _WorkOrderFilter _activeFilter = _WorkOrderFilter.upcoming;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workOrdersAsync = ref.watch(fieldOfficerWorkOrdersProvider);
    return workOrdersAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: StateBlock(
              icon: Icons.assignment_late_outlined,
              title: 'Could not load work orders',
              message: '$error',
              action: FilledButton.tonal(
                onPressed: () => ref.invalidate(fieldOfficerWorkOrdersProvider),
                child: const Text('Try again'),
              ),
            ),
          ),
        ),
      ),
      data: (workOrders) {
        final source = _activeFilter == _WorkOrderFilter.upcoming
            ? workOrders
                .where((w) => w.assignedCount < w.totalManpower)
                .toList()
            : workOrders;
        final filtered = _filter(source);
        final totalCenters = source
            .map((w) => w.siteId.isNotEmpty ? w.siteId : w.siteName)
            .where((id) => id.isNotEmpty)
            .toSet()
            .length;
        final assigned = source.fold<int>(
          0,
          (sum, row) => sum + row.assignedCount,
        );
        final manpower = source.fold<int>(
          0,
          (sum, row) => sum + row.totalManpower,
        );
        final openSlots = (manpower - assigned).clamp(0, manpower);

        return ScreenScaffold(
          title: 'Work orders',
          subtitle: _activeFilter == _WorkOrderFilter.upcoming
              ? 'Assign guards to upcoming duties'
              : 'District duty coverage and assignment progress',
          actions: <Widget>[
            IconButton(
              onPressed: () => ref.invalidate(fieldOfficerWorkOrdersProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: MetricTile(
                    label: 'Centers',
                    value: totalCenters.toString(),
                    helper: 'Visible duty sites',
                    icon: Icons.apartment_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MetricTile(
                    label: 'Open slots',
                    value: openSlots.toString(),
                    helper: '$assigned assigned of $manpower',
                    icon: Icons.group_add_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<_WorkOrderFilter>(
              segments: const <ButtonSegment<_WorkOrderFilter>>[
                ButtonSegment<_WorkOrderFilter>(
                  value: _WorkOrderFilter.upcoming,
                  label: Text('Upcoming'),
                  icon: Icon(Icons.schedule_rounded),
                ),
                ButtonSegment<_WorkOrderFilter>(
                  value: _WorkOrderFilter.all,
                  label: Text('All'),
                  icon: Icon(Icons.list_alt_rounded),
                ),
              ],
              selected: <_WorkOrderFilter>{_activeFilter},
              onSelectionChanged: (Set<_WorkOrderFilter> selection) {
                setState(() => _activeFilter = selection.first);
              },
              showSelectedIcon: false,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                labelText: 'Search duties',
                hintText: 'Site, exam, district, or client',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            if (source.isEmpty)
              StateBlock(
                icon: Icons.assignment_turned_in_outlined,
                title: _activeFilter == _WorkOrderFilter.upcoming
                    ? 'No upcoming duties'
                    : 'No duties loaded',
                message: _activeFilter == _WorkOrderFilter.upcoming
                    ? 'All work orders are fully covered. Switch to All to see them.'
                    : 'Published district work orders will appear here once available.',
              )
            else if (filtered.isEmpty)
              const StateBlock(
                icon: Icons.search_off_rounded,
                title: 'No matching duties',
                message:
                    'Try a different site, exam, district, or client name.',
              )
            else
              ...filtered.map(_WorkOrderCard.new),
          ],
        );
      },
    );
  }

  List<WorkOrderModel> _filter(List<WorkOrderModel> workOrders) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return workOrders;
    return workOrders.where((workOrder) {
      final haystack = [
        workOrder.siteName,
        workOrder.examName,
        workOrder.examCode,
        workOrder.district,
        workOrder.clientName,
        workOrder.dateLabel,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }
}

class _WorkOrderCard extends ConsumerWidget {
  const _WorkOrderCard(this.workOrder);

  final WorkOrderModel workOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final progress = workOrder.totalManpower <= 0
        ? 0.0
        : (workOrder.assignedCount / workOrder.totalManpower)
              .clamp(0, 1)
              .toDouble();
    final isCovered =
        workOrder.totalManpower > 0 &&
        workOrder.assignedCount >= workOrder.totalManpower;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      workOrder.siteName.isEmpty
                          ? 'Duty site'
                          : workOrder.siteName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${workOrder.examName} • ${workOrder.district}',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(
                label: isCovered ? 'Covered' : 'Open',
                icon: isCovered
                    ? Icons.check_circle_outline
                    : Icons.pending_actions,
                tone: isCovered
                    ? StatusChipTone.success
                    : StatusChipTone.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Icon(
                Icons.calendar_month_outlined,
                size: 16,
                color: tokens.inkMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  workOrder.dateLabel.isEmpty
                      ? 'Date not set'
                      : workOrder.dateLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: tokens.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${workOrder.assignedCount}/${workOrder.totalManpowerLabel}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.xs),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              backgroundColor: tokens.warningSoft,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCovered ? tokens.success : tokens.warning,
              ),
            ),
          ),
          if (workOrder.clientName.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              workOrder.clientName,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.inkMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          // ── Assign guards button ──────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isCovered
                  ? null
                  : () => _openAssignSheet(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: isCovered
                    ? tokens.successSoft
                    : tokens.primarySoft,
                foregroundColor: isCovered
                    ? tokens.success
                    : tokens.primaryStrong,
                elevation: 0,
                minimumSize: const Size.fromHeight(44),
              ),
              icon: Icon(
                isCovered
                    ? Icons.check_circle_outline_rounded
                    : Icons.person_add_alt_1_rounded,
                size: 18,
              ),
              label: Text(
                isCovered
                    ? 'Fully covered'
                    : 'Assign guards (${workOrder.assignedCount}/${workOrder.totalManpowerLabel})',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAssignSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AssignGuardsSheet(
        workOrder: workOrder,
        onSaved: () => ref.invalidate(fieldOfficerWorkOrdersProvider),
      ),
    );
  }
}

// ── Assign guards bottom sheet ────────────────────────────────────────────────

class _AssignGuardsSheet extends ConsumerStatefulWidget {
  const _AssignGuardsSheet({
    required this.workOrder,
    required this.onSaved,
  });

  final WorkOrderModel workOrder;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AssignGuardsSheet> createState() =>
      _AssignGuardsSheetState();
}

class _AssignGuardsSheetState extends ConsumerState<_AssignGuardsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  List<GuardProfileModel>? _available;
  List<GuardProfileModel> _selected = <GuardProfileModel>[];
  String _query = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadGuards();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGuards() async {
    try {
      final guards = await ref
          .read(mobileRepositoryProvider)
          .fetchFieldOfficerGuards(district: widget.workOrder.district);
      if (mounted) {
        setState(() {
          _available = guards;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(mobileRepositoryProvider).assignGuardsToWorkOrder(
        workOrderId: widget.workOrder.id,
        assignedGuards: _selected
            .map(
              (g) => <String, dynamic>{
                'uid': g.id,
                'name': g.fullName,
                'employeeId': g.employeeId,
                'gender': g.gender ?? '',
              },
            )
            .toList(),
      );
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  List<GuardProfileModel> get _filtered {
    final all = _available ?? <GuardProfileModel>[];
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((g) {
      return g.fullName.toLowerCase().contains(q) ||
          g.employeeId.toLowerCase().contains(q);
    }).toList();
  }

  bool _isSelected(GuardProfileModel g) =>
      _selected.any((s) => s.id == g.id);

  void _toggle(GuardProfileModel g) {
    setState(() {
      if (_isSelected(g)) {
        _selected = _selected.where((s) => s.id != g.id).toList();
      } else {
        _selected = <GuardProfileModel>[..._selected, g];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);
    final wo = widget.workOrder;
    final bool canSave = _selected.isNotEmpty && !_saving;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // ── Header ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: tokens.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Assign guards',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontSize: 20),
                        ),
                        Text(
                          '${wo.siteName} · ${wo.dateLabel}',
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: tokens.surfaceStrong,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Manpower summary
              Row(
                children: <Widget>[
                  _ManpowerStat(
                    label: 'Required',
                    value: wo.totalManpowerLabel,
                    color: tokens.ink,
                  ),
                  _ManpowerStat(
                    label: 'Assigned',
                    value: '${wo.assignedCount}',
                    color: wo.assignedCount >= wo.totalManpower
                        ? tokens.success
                        : tokens.warning,
                  ),
                  _ManpowerStat(
                    label: 'Selected',
                    value: '${_selected.length}',
                    color: tokens.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tab bar
              TabBar(
                controller: _tabCtrl,
                tabs: <Tab>[
                  Tab(
                    text:
                        'Available (${(_available ?? <GuardProfileModel>[]).length})',
                  ),
                  Tab(text: 'Selected (${_selected.length})'),
                ],
              ),
            ],
          ),
        ),

        // ── Tab views ─────────────────────────────────────────────────────
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.48,
          child: TabBarView(
            controller: _tabCtrl,
            children: <Widget>[
              // Available guards tab
              Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        labelText: 'Search by name or ID',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  if (_loading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Expanded(
                      child: Center(
                        child: StateBlock(
                          icon: Icons.error_outline_rounded,
                          title: 'Could not load guards',
                          message: _error!,
                          action: FilledButton.tonal(
                            onPressed: () {
                              setState(() {
                                _loading = true;
                                _error = null;
                              });
                              _loadGuards();
                            },
                            child: const Text('Retry'),
                          ),
                        ),
                      ),
                    )
                  else if (_filtered.isEmpty)
                    Expanded(
                      child: Center(
                        child: StateBlock(
                          icon: Icons.person_off_outlined,
                          title: _query.isEmpty
                              ? 'No guards in this district'
                              : 'No matching guards',
                          message: _query.isEmpty
                              ? 'No active guards found for ${wo.district}.'
                              : 'Try a different name or employee ID.',
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (_, int i) =>
                            _GuardTile(
                          guard: _filtered[i],
                          selected: _isSelected(_filtered[i]),
                          onTap: () => _toggle(_filtered[i]),
                        ),
                      ),
                    ),
                ],
              ),

              // Selected guards tab
              _selected.isEmpty
                  ? const Center(
                      child: StateBlock(
                        icon: Icons.person_add_alt_1_outlined,
                        title: 'No guards selected',
                        message:
                            'Switch to the Available tab and tap guards to add them.',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _selected.length,
                      itemBuilder: (_, int i) => _GuardTile(
                        guard: _selected[i],
                        selected: true,
                        onTap: () => _toggle(_selected[i]),
                      ),
                    ),
            ],
          ),
        ),

        // ── Error banner ───────────────────────────────────────────────────
        if (_error != null && !_loading) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: tokens.dangerSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.error_outline_rounded,
                      color: tokens.danger, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: tokens.danger),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // ── Save button ────────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: FilledButton.icon(
            onPressed: canSave ? _save : null,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(
              _saving
                  ? 'Saving…'
                  : 'Save ${_selected.length} guard${_selected.length == 1 ? '' : 's'}',
            ),
          ),
        ),
      ],
    );
  }
}

// ── Manpower stat chip ────────────────────────────────────────────────────────

class _ManpowerStat extends StatelessWidget {
  const _ManpowerStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: tokens.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Guard list tile ───────────────────────────────────────────────────────────

class _GuardTile extends StatelessWidget {
  const _GuardTile({
    required this.guard,
    required this.selected,
    required this.onTap,
  });

  final GuardProfileModel guard;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final imageUrl = guard.profilePhotoUrl;
    final initials = _initials(guard.fullName, guard.employeeId);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: selected ? tokens.primarySoft : tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 20,
                  backgroundColor: tokens.primarySoft,
                  backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                      ? NetworkImage(imageUrl)
                      : null,
                  child: (imageUrl == null || imageUrl.isEmpty)
                      ? Text(
                          initials,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: tokens.primaryStrong,
                                fontWeight: FontWeight.w800,
                              ),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        guard.fullName.isEmpty ? 'Guard' : guard.fullName,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: selected
                                  ? tokens.primaryStrong
                                  : tokens.ink,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        <String>[
                          if (guard.employeeId.isNotEmpty) guard.employeeId,
                          if (guard.gender != null &&
                              guard.gender!.isNotEmpty)
                            guard.gender!,
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? tokens.primaryStrong : tokens.border,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name, String fallback) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final i = parts.map((p) => p[0]).take(2).join().toUpperCase();
    if (i.isNotEmpty) return i;
    return fallback.trim().isNotEmpty
        ? fallback.trim().substring(0, fallback.length.clamp(0, 2)).toUpperCase()
        : 'GU';
  }
}
