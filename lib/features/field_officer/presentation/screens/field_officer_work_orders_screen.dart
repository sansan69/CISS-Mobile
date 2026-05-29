import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/guard_profile.dart';
import '../../../../../core/models/report_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/brand_banner.dart';
import '../../../../../shared/widgets/glass_card.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';

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
    final tokens = CissThemeTokens.of(context);

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

        return Scaffold(
          backgroundColor: tokens.canvas,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
            children: [
              BrandBanner(
                title: 'Operations',
                subtitle: 'Manage duty deployments and guard assignments',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SyncStatusBadge(),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () =>
                          ref.invalidate(fieldOfficerWorkOrdersProvider),
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<_WorkOrderFilter>(
                      segments: const <ButtonSegment<_WorkOrderFilter>>[
                        ButtonSegment<_WorkOrderFilter>(
                          value: _WorkOrderFilter.upcoming,
                          label: Text('Upcoming'),
                          icon: Icon(Icons.schedule_rounded),
                        ),
                        ButtonSegment<_WorkOrderFilter>(
                          value: _WorkOrderFilter.all,
                          label: Text('All Orders'),
                          icon: Icon(Icons.list_alt_rounded),
                        ),
                      ],
                      selected: <_WorkOrderFilter>{_activeFilter},
                      onSelectionChanged: (selection) {
                        setState(() => _activeFilter = selection.first);
                      },
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        labelText: 'Search operations',
                        hintText: 'Site, exam, or district',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: tokens.surface,
                      ),
                    ),
                  ],
                ),
              ),

              if (source.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: StateBlock(
                    icon: Icons.assignment_turned_in_outlined,
                    title: _activeFilter == _WorkOrderFilter.upcoming
                        ? 'No upcoming duties'
                        : 'No duties loaded',
                    message: _activeFilter == _WorkOrderFilter.upcoming
                        ? 'All work orders are fully covered.'
                        : 'Work orders will appear here once published.',
                  ),
                )
              else if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: StateBlock(
                    icon: Icons.search_off_rounded,
                    title: 'No matches found',
                    message: 'Try a different search term.',
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: filtered.map((w) => _WorkOrderCard(w)).toList(),
                  ),
                ),
            ],
          ),
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
    final accent = isCovered ? tokens.success : tokens.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: EdgeInsets.zero,
        accentColor: accent,
        child: InkWell(
          onTap: () => _openAssignSheet(context, ref),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workOrder.siteName.isEmpty
                                ? 'Duty Site'
                                : workOrder.siteName,
                            style: GoogleFonts.rajdhani(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: tokens.ink,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${workOrder.examName} · ${workOrder.district}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RadialProgress(
                      progress: progress,
                      label: '${workOrder.assignedCount}/${workOrder.totalManpower}',
                      color: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: tokens.inkMuted),
                    const SizedBox(width: 6),
                    Text(
                      workOrder.dateLabel,
                      style: GoogleFonts.rajdhani(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tokens.inkMuted,
                      ),
                    ),
                    const Spacer(),
                    StatusChip(
                      label: isCovered ? 'COVERED' : 'OPEN',
                      tone: isCovered ? StatusChipTone.success : StatusChipTone.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAssignSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignGuardsSheet(
        workOrder: workOrder,
        onSaved: () => ref.invalidate(fieldOfficerWorkOrdersProvider),
      ),
    );
  }
}

class _RadialProgress extends StatelessWidget {
  const _RadialProgress({
    required this.progress,
    required this.label,
    required this.color,
  });

  final double progress;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 4,
            color: color.withValues(alpha: 0.1),
          ),
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4,
            color: color,
            strokeCap: StrokeCap.round,
          ),
          Text(
            label,
            style: GoogleFonts.rajdhani(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignGuardsSheet extends ConsumerStatefulWidget {
  const _AssignGuardsSheet({
    required this.workOrder,
    required this.onSaved,
  });

  final WorkOrderModel workOrder;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AssignGuardsSheet> createState() => _AssignGuardsSheetState();
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

  bool _isSelected(GuardProfileModel g) => _selected.any((s) => s.id == g.id);

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

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: tokens.surface.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ASSIGN GUARDS',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                wo.siteName,
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TabBar(
                      controller: _tabCtrl,
                      labelStyle: GoogleFonts.rajdhani(fontWeight: FontWeight.w700),
                      tabs: [
                        Tab(text: 'AVAILABLE (${_available?.length ?? 0})'),
                        Tab(text: 'SELECTED (${_selected.length})'),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // Available
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v),
                            decoration: const InputDecoration(
                              hintText: 'Search guards...',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                          ),
                        ),
                        if (_loading)
                          const Expanded(child: Center(child: CircularProgressIndicator()))
                        else
                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) => _GuardTile(
                                guard: _filtered[i],
                                selected: _isSelected(_filtered[i]),
                                onTap: () => _toggle(_filtered[i]),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Selected
                    ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _selected.length,
                      itemBuilder: (_, i) => _GuardTile(
                        guard: _selected[i],
                        selected: true,
                        onTap: () => _toggle(_selected[i]),
                      ),
                    ),
                  ],
                ),
              ),

              // Action Bar
              Container(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  border: Border(top: BorderSide(color: tokens.border)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_selected.length} Selected',
                          style: GoogleFonts.rajdhani(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: tokens.primary,
                          ),
                        ),
                        Text(
                          'Target: ${wo.totalManpower}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: canSave ? _save : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(140, 48),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('COMMIT ASSIGNMENT'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final initials = _initials(guard.fullName, guard.employeeId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? tokens.primarySoft.withValues(alpha: 0.5) : tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: tokens.primarySoft,
                  backgroundImage: (guard.profilePhotoUrl != null && guard.profilePhotoUrl!.isNotEmpty)
                      ? NetworkImage(guard.profilePhotoUrl!)
                      : null,
                  child: (guard.profilePhotoUrl == null || guard.profilePhotoUrl!.isEmpty)
                      ? Text(initials, style: GoogleFonts.rajdhani(fontWeight: FontWeight.w700, color: tokens.primaryStrong))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guard.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.rajdhani(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tokens.ink,
                        ),
                      ),
                      Text(
                        'ID: ${guard.employeeId} · ${guard.gender ?? "N/A"}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                  color: selected ? tokens.primary : tokens.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name, String fallback) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final i = parts.map((p) => p[0]).take(2).join().toUpperCase();
    if (i.isNotEmpty) return i;
    return fallback.trim().isNotEmpty ? fallback.trim().substring(0, 1).toUpperCase() : 'G';
  }
}
