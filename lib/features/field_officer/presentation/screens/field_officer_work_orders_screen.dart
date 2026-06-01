import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/guard_profile.dart';
import '../../../../../core/models/report_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/network/ciss_error.dart';
import '../../../../../shared/widgets/brand_banner.dart';
import '../../../../../shared/widgets/glass_card.dart';
import '../../../../../shared/widgets/portal_primitives.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../core/cache/skeleton_widgets.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';

final FutureProvider<List<WorkOrderModel>> fieldOfficerWorkOrdersProvider =
    FutureProvider<List<WorkOrderModel>>((Ref ref) {
      return ref.watch(mobileRepositoryProvider).fetchFieldOfficerWorkOrders();
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
  static final DateFormat _headerDateFormat = DateFormat('EEE, d MMM');
  static final DateFormat _fullDateFormat = DateFormat('d MMM yyyy');
  final Set<String> _collapsedSectionKeys = <String>{};
  bool _initializedCollapsedSections = false;
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
      loading: () => const SkeletonPage(cardCount: 4),
      error: (Object error, StackTrace stackTrace) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: StateBlock(
              icon: Icons.assignment_late_outlined,
              title: 'Could not load work orders',
              message: CissError.parse(error),
              action: FilledButton.tonal(
                onPressed: () => ref.invalidate(fieldOfficerWorkOrdersProvider),
                child: const Text('Try again'),
              ),
            ),
          ),
        ),
      ),
      data: (workOrders) {
        final source = workOrders;
        final filtered = _filter(source);
        final grouped = _groupByDateAndSite(filtered);
        _syncCollapsedSections(grouped);

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
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white70,
                      ),
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
                    const PortalFieldLabel('Search Operations'),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
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
                    children: grouped
                        .map(
                          (_DateGroupedOrders group) => _DateOrderSection(
                            groupKey: group.key,
                            title: _dateHeaderLabel(group),
                            count: group.totalCenters,
                            totalRequired: group.totalRequired,
                            assignedCount: group.assignedCount,
                            examLabels: group.examLabels,
                            expanded: !_collapsedSectionKeys.contains(group.key),
                            onToggle: () => _toggleSection(group.key),
                            rows: group.rows,
                          ),
                        )
                        .toList(),
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

    // Apply "Upcoming" filter: only show orders with unmet manpower.
    List<WorkOrderModel> filtered;
    if (_activeFilter == _WorkOrderFilter.upcoming) {
      filtered = workOrders
          .where((wo) => wo.assignedCount < wo.totalManpower)
          .toList();
    } else {
      filtered = workOrders;
    }

    if (query.isEmpty) return filtered;
    return filtered.where((workOrder) {
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

  List<_DateGroupedOrders> _groupByDateAndSite(List<WorkOrderModel> workOrders) {
    final Map<String, List<WorkOrderModel>> grouped =
        <String, List<WorkOrderModel>>{};
    for (final WorkOrderModel workOrder in workOrders) {
      final DateTime? parsed = _parseWorkOrderDate(workOrder.dateLabel);
      final String key = parsed?.toIso8601String() ?? 'undated';
      grouped.putIfAbsent(key, () => <WorkOrderModel>[]).add(workOrder);
    }

    final List<_DateGroupedOrders> sections = grouped.entries
        .map((_mapDateGroup)
        )
        .toList();

    sections.sort((_DateGroupedOrders left, _DateGroupedOrders right) {
      if (left.date == null && right.date == null) return 0;
      if (left.date == null) return 1;
      if (right.date == null) return -1;
      return left.date!.compareTo(right.date!);
    });

    return sections;
  }

  _DateGroupedOrders _mapDateGroup(MapEntry<String, List<WorkOrderModel>> entry) {
    final Map<String, List<WorkOrderModel>> siteBuckets =
        <String, List<WorkOrderModel>>{};
    for (final WorkOrderModel order in entry.value) {
      final String siteKey = '${order.siteId}::${order.siteName}';
      siteBuckets.putIfAbsent(siteKey, () => <WorkOrderModel>[]).add(order);
    }

    final List<_SiteGroupedOrders> rows = siteBuckets.values
        .map((_buildSiteRow)
        )
        .toList()
      ..sort((_SiteGroupedOrders left, _SiteGroupedOrders right) {
        final int districtCompare = left.district.compareTo(right.district);
        if (districtCompare != 0) return districtCompare;
        return left.siteName.compareTo(right.siteName);
      });

    final Set<String> examLabels = <String>{};
    int totalRequired = 0;
    int assignedCount = 0;
    for (final _SiteGroupedOrders row in rows) {
      examLabels.addAll(row.examLabels);
      totalRequired += row.totalManpower;
      assignedCount += row.assignedCount;
    }

    return _DateGroupedOrders(
      key: entry.key,
      date: entry.key == 'undated' ? null : DateTime.tryParse(entry.key),
      dateLabel: rows.isNotEmpty ? _formatRowDate(rows.first.dateLabel) : '',
      rows: rows,
      totalRequired: totalRequired,
      assignedCount: assignedCount,
      totalCenters: rows.length,
      examLabels: examLabels.toList()..sort(),
    );
  }

  _SiteGroupedOrders _buildSiteRow(List<WorkOrderModel> orders) {
    final WorkOrderModel base = orders.first;
    final int totalManpower = orders.fold<int>(
      0,
      (int sum, WorkOrderModel order) => sum + order.totalManpower,
    );
    final int assignedCount = orders.fold<int>(
      0,
      (int sum, WorkOrderModel order) => sum + order.assignedCount,
    );
    final List<String> examLabels = orders
        .map((WorkOrderModel order) => order.examName.trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return _SiteGroupedOrders(
      siteId: base.siteId,
      siteName: base.siteName,
      district: base.district,
      clientName: base.clientName,
      dateLabel: base.dateLabel,
      examLabels: examLabels,
      orders: orders,
      totalManpower: totalManpower,
      assignedCount: assignedCount,
    );
  }

  DateTime? _parseWorkOrderDate(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) return null;

    final DateTime? isoParsed = DateTime.tryParse(value);
    if (isoParsed != null) {
      return DateTime(isoParsed.year, isoParsed.month, isoParsed.day);
    }

    final List<String> patterns = <String>[
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'd/M/yyyy',
      'dd-MM-yyyy',
      'd-MM-yyyy',
      'd MMM yyyy',
      'dd MMM yyyy',
      'EEE, d MMM',
      'EEE, dd MMM',
    ];

    for (final String pattern in patterns) {
      try {
        final DateTime parsed = DateFormat(pattern).parseStrict(value);
        if (pattern == 'EEE, d MMM' || pattern == 'EEE, dd MMM') {
          final DateTime now = DateTime.now();
          return DateTime(now.year, parsed.month, parsed.day);
        }
        return DateTime(parsed.year, parsed.month, parsed.day);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  String _dateHeaderLabel(_DateGroupedOrders group) {
    final DateTime? date = group.date;
    if (date == null) {
      final String fallbackLabel = group.dateLabel.trim();
      return fallbackLabel.isEmpty ? 'Date Pending' : fallbackLabel;
    }

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int difference = date.difference(today).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference == -1) return 'Yesterday';
    if (date.year == today.year) return _headerDateFormat.format(date);
    return _fullDateFormat.format(date);
  }

  String _formatRowDate(String raw) {
    final DateTime? parsed = _parseWorkOrderDate(raw);
    if (parsed == null) {
      final String fallback = raw.trim();
      return fallback.isEmpty ? 'Date unavailable' : fallback;
    }
    return _fullDateFormat.format(parsed);
  }

  void _syncCollapsedSections(List<_DateGroupedOrders> groups) {
    final Set<String> visibleKeys =
        groups.map((_DateGroupedOrders group) => group.key).toSet();
    _collapsedSectionKeys.removeWhere((String key) => !visibleKeys.contains(key));

    if (!_initializedCollapsedSections) {
      _collapsedSectionKeys
        ..clear()
        ..addAll(visibleKeys);
      _initializedCollapsedSections = true;
      return;
    }

    // No-op: new sections start expanded by default (not in collapsed set).
  }

  void _toggleSection(String key) {
    setState(() {
      if (_collapsedSectionKeys.contains(key)) {
        _collapsedSectionKeys.remove(key);
      } else {
        _collapsedSectionKeys.add(key);
      }
    });
  }
}

class _DateGroupedOrders {
  const _DateGroupedOrders({
    required this.key,
    required this.date,
    required this.dateLabel,
    required this.rows,
    required this.totalRequired,
    required this.assignedCount,
    required this.totalCenters,
    required this.examLabels,
  });

  final String key;
  final DateTime? date;
  final String dateLabel;
  final List<_SiteGroupedOrders> rows;
  final int totalRequired;
  final int assignedCount;
  final int totalCenters;
  final List<String> examLabels;
}

class _SiteGroupedOrders {
  const _SiteGroupedOrders({
    required this.siteId,
    required this.siteName,
    required this.district,
    required this.clientName,
    required this.dateLabel,
    required this.examLabels,
    required this.orders,
    required this.totalManpower,
    required this.assignedCount,
  });

  final String siteId;
  final String siteName;
  final String district;
  final String clientName;
  final String dateLabel;
  final List<String> examLabels;
  final List<WorkOrderModel> orders;
  final int totalManpower;
  final int assignedCount;
}

class _DateOrderSection extends StatelessWidget {
  const _DateOrderSection({
    required this.groupKey,
    required this.title,
    required this.count,
    required this.totalRequired,
    required this.assignedCount,
    required this.examLabels,
    required this.expanded,
    required this.onToggle,
    required this.rows,
  });

  final String groupKey;
  final String title;
  final int count;
  final int totalRequired;
  final int assignedCount;
  final List<String> examLabels;
  final bool expanded;
  final VoidCallback onToggle;
  final List<_SiteGroupedOrders> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PortalSurfaceCard(
            padding: EdgeInsets.zero,
            accentColor: expanded ? tokens.primary : tokens.borderStrong,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: GoogleFonts.roboto(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: tokens.ink,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          PortalSectionHeading(
                            title: '$count ${count == 1 ? 'Order' : 'Orders'}',
                            compact: true,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$assignedCount / $totalRequired guards assigned',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: tokens.inkMuted,
                            ),
                          ),
                          if (examLabels.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 6),
                            Text(
                              examLabels.take(2).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: tokens.primaryStrong,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: tokens.primaryStrong,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                children: rows
                    .map((_SiteGroupedOrders row) => _WorkOrderCard.grouped(row))
                    .toList(),
              ),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _WorkOrderCard extends ConsumerWidget {
  const _WorkOrderCard(this.workOrder)
    : groupedRow = null;

  const _WorkOrderCard.grouped(this.groupedRow)
    : workOrder = null;

  final WorkOrderModel? workOrder;
  final _SiteGroupedOrders? groupedRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _SiteGroupedOrders resolvedGroup = groupedRow ??
        _SiteGroupedOrders(
          siteId: workOrder!.siteId,
          siteName: workOrder!.siteName,
          district: workOrder!.district,
          clientName: workOrder!.clientName,
          dateLabel: workOrder!.dateLabel,
          examLabels: <String>[workOrder!.examName],
          orders: <WorkOrderModel>[workOrder!],
          totalManpower: workOrder!.totalManpower,
          assignedCount: workOrder!.assignedCount,
        );
    final tokens = CissThemeTokens.of(context);
    final progress = resolvedGroup.totalManpower <= 0
        ? 0.0
        : (resolvedGroup.assignedCount / resolvedGroup.totalManpower)
              .clamp(0, 1)
              .toDouble();
    final isCovered =
        resolvedGroup.totalManpower > 0 &&
        resolvedGroup.assignedCount >= resolvedGroup.totalManpower;
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
                            resolvedGroup.siteName.isEmpty
                                ? 'Duty Site'
                                : resolvedGroup.siteName,
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: tokens.ink,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${resolvedGroup.examLabels.join(' · ')} · ${resolvedGroup.district}',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RadialProgress(
                      progress: progress,
                      label:
                          '${resolvedGroup.assignedCount}/${resolvedGroup.totalManpower}',
                      color: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: tokens.inkMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDisplayDate(resolvedGroup.dateLabel),
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tokens.inkMuted,
                      ),
                    ),
                    const Spacer(),
                    StatusChip(
                      label: isCovered ? 'COVERED' : 'OPEN',
                      tone: isCovered
                          ? StatusChipTone.success
                          : StatusChipTone.warning,
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
    final WorkOrderModel target =
        groupedRow != null ? groupedRow!.orders.first : workOrder!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignGuardsSheet(
        workOrder: target,
        onSaved: () => ref.invalidate(fieldOfficerWorkOrdersProvider),
      ),
    );
  }

  String _formatDisplayDate(String raw) {
    final String value = raw.trim();
    final DateTime? isoParsed = DateTime.tryParse(value);
    if (isoParsed != null) {
      return DateFormat('d MMM yyyy').format(isoParsed);
    }
    return value.isEmpty ? 'Date unavailable' : value;
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
            style: GoogleFonts.roboto(
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
  const _AssignGuardsSheet({required this.workOrder, required this.onSaved});

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
          _error = CissError.parse(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(mobileRepositoryProvider)
          .assignGuardsToWorkOrder(
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
          _error = CissError.parse(e);
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
                                style: GoogleFonts.roboto(
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
                      labelStyle: GoogleFonts.roboto(
                        fontWeight: FontWeight.w700,
                      ),
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
                          const Expanded(
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
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
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  16 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  border: Border(top: BorderSide(color: tokens.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_selected.length} Selected',
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: tokens.primary,
                            ),
                          ),
                          Text(
                            _error ?? 'Target: ${wo.totalManpower}',
                            style:
                                (_error == null
                                        ? theme.textTheme.labelSmall
                                        : theme.textTheme.bodySmall)
                                    ?.copyWith(
                                      color: _error == null
                                          ? null
                                          : tokens.danger,
                                    ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
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
        color: selected
            ? tokens.primarySoft.withValues(alpha: 0.5)
            : tokens.surface,
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
                  backgroundImage:
                      (guard.profilePhotoUrl != null &&
                          guard.profilePhotoUrl!.isNotEmpty)
                      ? NetworkImage(guard.profilePhotoUrl!)
                      : null,
                  child:
                      (guard.profilePhotoUrl == null ||
                          guard.profilePhotoUrl!.isEmpty)
                      ? Text(
                          initials,
                          style: GoogleFonts.roboto(
                            fontWeight: FontWeight.w700,
                            color: tokens.primaryStrong,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guard.fullName,
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tokens.ink,
                        ),
                      ),
                      Text(
                        'ID: ${guard.employeeId} · ${guard.gender ?? "N/A"}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
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
    return fallback.trim().isNotEmpty
        ? fallback.trim().substring(0, 1).toUpperCase()
        : 'G';
  }
}
