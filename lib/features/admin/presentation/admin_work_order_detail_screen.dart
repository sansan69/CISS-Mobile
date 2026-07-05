import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

// ── Data Models ────────────────────────────────────────────────────────

class WorkOrderDetail {
  const WorkOrderDetail({
    required this.id,
    required this.siteName,
    required this.clientName,
    required this.district,
    this.examName,
    this.examCode,
    this.date,
    this.maleRequired = 0,
    this.femaleRequired = 0,
    this.totalRequired = 0,
    this.assignedGuards = const [],
  });

  final String id;
  final String siteName;
  final String clientName;
  final String district;
  final String? examName;
  final String? examCode;
  final String? date;
  final int maleRequired;
  final int femaleRequired;
  final int totalRequired;
  final List<AssignedGuard> assignedGuards;

  factory WorkOrderDetail.fromJson(Map<String, dynamic> json) {
    final male = json['maleGuardsRequired'];
    final female = json['femaleGuardsRequired'];
    final total = json['totalManpower'];
    final guards = json['assignedGuards'] as List<dynamic>? ?? const <dynamic>[];
    return WorkOrderDetail(
      id: (json['id'] as String?) ?? '',
      siteName: (json['siteName'] as String?) ?? '',
      clientName: (json['clientName'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      examName: json['examName'] as String?,
      examCode: json['examCode'] as String?,
      date: json['date'] as String?,
      maleRequired: male is num ? male.toInt() : 0,
      femaleRequired: female is num ? female.toInt() : 0,
      totalRequired: total is num
          ? total.toInt()
          : ((male is num ? male.toInt() : 0) +
                (female is num ? female.toInt() : 0)),
      assignedGuards: guards
          .whereType<Map<String, dynamic>>()
          .map(AssignedGuard.fromJson)
          .toList(),
    );
  }
}

class AssignedGuard {
  const AssignedGuard({
    required this.uid,
    required this.name,
    required this.employeeId,
    this.gender,
  });

  final String uid;
  final String name;
  final String employeeId;
  final String? gender;

  factory AssignedGuard.fromJson(Map<String, dynamic> json) {
    return AssignedGuard(
      uid: (json['uid'] as String?) ??
          (json['id'] as String?) ??
          (json['employeeId'] as String?) ??
          '',
      name: (json['name'] as String?) ?? '',
      employeeId: (json['employeeId'] as String?) ?? '',
      gender: json['gender'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (uid.isNotEmpty) 'uid': uid,
        'name': name,
        'employeeId': employeeId,
        if (gender != null) 'gender': gender,
      };
}

// ── Screen ─────────────────────────────────────────────────────────────

class AdminWorkOrderDetailScreen extends ConsumerStatefulWidget {
  const AdminWorkOrderDetailScreen({super.key, required this.workOrderId});

  final String workOrderId;

  @override
  ConsumerState<AdminWorkOrderDetailScreen> createState() =>
      _AdminWorkOrderDetailScreenState();
}

class _AdminWorkOrderDetailScreenState
    extends ConsumerState<AdminWorkOrderDetailScreen> {
  WorkOrderDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _saving = false;

  List<EmployeeModel> _allGuards = const <EmployeeModel>[];
  late Set<String> _selectedGuardIds;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedGuardIds = <String>{};
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final results = await Future.wait<Map<String, dynamic>>([
        repo.fetchWorkOrderDetail(widget.workOrderId),
        repo.fetchAdminEmployees().then((list) => <String, dynamic>{'guards': list}),
      ]);
      final detailJson = results[0];
      final guardsData = results[1]['guards'] as List<dynamic>;
      final guards = guardsData.whereType<EmployeeModel>().toList();
      if (!mounted) return;
      final detail = WorkOrderDetail.fromJson(detailJson);
      _selectedGuardIds = detail.assignedGuards
          .map((g) => g.employeeId)
          .where((id) => id.isNotEmpty)
          .toSet();
      setState(() {
        _detail = detail;
        _allGuards = guards;
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

  List<EmployeeModel> get _filteredGuards {
    if (_searchQuery.isEmpty) return _allGuards;
    final q = _searchQuery.toLowerCase();
    return _allGuards.where((g) {
      final name = g.fullName.toLowerCase();
      final eid = g.employeeId.toLowerCase();
      return name.contains(q) || eid.contains(q);
    }).toList();
  }

  void _toggleGuard(String employeeId) {
    setState(() {
      if (_selectedGuardIds.contains(employeeId)) {
        _selectedGuardIds.remove(employeeId);
      } else {
        _selectedGuardIds.add(employeeId);
      }
    });
  }

  Future<void> _saveAssignments() async {
    if (_detail == null) return;
    setState(() => _saving = true);
    try {
      final assigned = _selectedGuardIds.map((eid) {
        final guard = _allGuards.firstWhere(
          (g) => g.employeeId == eid,
          orElse: () => EmployeeModel(
            id: eid,
            name: eid,
            fullName: eid,
            employeeId: eid,
            employeeCode: '',
            phoneNumber: '',
            clientId: '',
            clientName: '',
            district: '',
            siteName: '',
            status: 'Active',
          ),
        );
        return <String, dynamic>{
          'employeeId': eid,
          'name': guard.fullName,
          'uid': guard.id,
        };
      }).toList();
      await ref.read(mobileRepositoryProvider).updateWorkOrderAssignments(
            workOrderId: widget.workOrderId,
            assignedGuards: assigned,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignments saved')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
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

    if (_loading) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        appBar: AppBar(backgroundColor: tokens.canvas),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _detail == null) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        appBar: AppBar(backgroundColor: tokens.canvas),
        body: Center(
          child: StateBlock(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load work order',
            message: _error ?? 'Work order not found',
            action: FilledButton.tonal(
              onPressed: _fetchData,
              child: const Text('Retry'),
            ),
          ),
        ),
      );
    }

    final detail = _detail!;
    final assignedCount = _selectedGuardIds.length;
    final totalRequired = detail.totalRequired;
    final progress = totalRequired > 0
        ? (assignedCount / totalRequired).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final isFullyAssigned =
        totalRequired > 0 && assignedCount >= totalRequired;
    final examLabel = detail.examName?.isNotEmpty == true
        ? detail.examName!
        : detail.examCode?.isNotEmpty == true
            ? detail.examCode!
            : 'Duty';

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Work Order Detail'),
        backgroundColor: tokens.canvas,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ModernHero(
              eyebrow: detail.clientName,
              title: detail.siteName,
              subtitle: detail.district,
              avatarText: _initials(detail.siteName),
            ),
            const SizedBox(height: 24),

            // ── Work order info card ──────────────────────────────────
            _sectionHeader('ORDER DETAILS', tokens),
            const SizedBox(height: 12),
            ModernCard(
              child: Column(
                children: [
                  _detailRow('Exam', examLabel, tokens),
                  _divider(tokens),
                  if (detail.examCode != null && detail.examCode!.isNotEmpty)
                    _detailRow('Exam Code', detail.examCode!, tokens),
                  if (detail.examCode != null && detail.examCode!.isNotEmpty)
                    _divider(tokens),
                  _detailRow(
                    'Duty Date',
                    detail.date != null ? _formatDate(detail.date!) : '—',
                    tokens,
                  ),
                  _divider(tokens),
                  _manpowerGrid(detail, tokens),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Progress bar ──────────────────────────────────────────
            _sectionHeader('ASSIGNMENT PROGRESS', tokens),
            const SizedBox(height: 12),
            ModernCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.groups_rounded,
                          size: 20, color: tokens.inkMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$assignedCount / $totalRequired guards assigned',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: tokens.ink,
                          ),
                        ),
                      ),
                      StatusChip(
                        label: isFullyAssigned ? 'Fully Assigned' : 'Partial',
                        tone: isFullyAssigned
                            ? StatusChipTone.success
                            : StatusChipTone.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: tokens.surfaceMuted,
                      color: isFullyAssigned ? tokens.success : tokens.warning,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Assigned guards ───────────────────────────────────────
            _sectionHeader('ASSIGNED GUARDS (${_selectedGuardIds.length})', tokens),
            const SizedBox(height: 12),
            if (_selectedGuardIds.isEmpty)
              ModernCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: tokens.inkMuted),
                      const SizedBox(width: 8),
                      Text(
                        'No guards assigned yet',
                        style: TextStyle(fontSize: 14, color: tokens.inkMuted),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._selectedGuardIds.map((eid) {
                final guard = _allGuards.firstWhere(
                  (g) => g.employeeId == eid,
                  orElse: () => EmployeeModel(
                    id: eid,
                    name: eid,
                    fullName: eid,
                    employeeId: eid,
                    employeeCode: '',
                    phoneNumber: '',
                    clientId: '',
                    clientName: '',
                    district: '',
                    siteName: '',
                    status: 'Active',
                  ),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ModernCard(
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: tokens.primarySoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _initials(guard.fullName),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: tokens.primaryStrong,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                guard.fullName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.ink,
                                ),
                              ),
                              if (guard.employeeId.isNotEmpty)
                                Text(
                                  guard.employeeId,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tokens.inkMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 20, color: tokens.danger),
                          tooltip: 'Remove guard',
                          onPressed: () => _toggleGuard(eid),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),

            // ── Available guards ──────────────────────────────────────
            _sectionHeader('AVAILABLE GUARDS', tokens),
            const SizedBox(height: 12),
            _buildSearchField(tokens),
            const SizedBox(height: 8),
            ..._filteredGuards.map((guard) {
              final eid = guard.employeeId.isNotEmpty
                  ? guard.employeeId
                  : guard.id;
              final isSelected = _selectedGuardIds.contains(eid);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ModernCard(
                  onTap: eid.isNotEmpty ? () => _toggleGuard(eid) : null,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? tokens.primarySoft
                              : tokens.surfaceMuted,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: isSelected
                            ? Icon(Icons.check_rounded,
                                size: 18, color: tokens.primary)
                            : Text(
                                _initials(guard.fullName),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.inkMuted,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              guard.fullName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: tokens.ink,
                              ),
                            ),
                            if (guard.employeeId.isNotEmpty)
                              Text(
                                guard.employeeId,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.inkMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (guard.siteName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.surfaceMuted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            guard.siteName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: tokens.inkMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 32),

            // ── Save button ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _saveAssignments,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Assignments'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(CissThemeTokens tokens) {
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
          hintText: 'Search guards by name or ID...',
          hintStyle: TextStyle(fontSize: 14, color: tokens.inkMuted),
          prefixIcon:
              Icon(Icons.search_rounded, size: 20, color: tokens.inkMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded,
                      size: 18, color: tokens.inkMuted),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          isDense: true,
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _manpowerGrid(WorkOrderDetail detail, CissThemeTokens tokens) {
    return Row(
      children: [
        Expanded(
          child: _manpowerTile('Male', detail.maleRequired, Icons.male_rounded, tokens),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _manpowerTile('Female', detail.femaleRequired, Icons.female_rounded, tokens),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _manpowerTile('Total', detail.totalRequired, Icons.groups_rounded, tokens),
        ),
      ],
    );
  }

  Widget _manpowerTile(String label, int count, IconData icon, CissThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: tokens.inkMuted),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: tokens.ink,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: tokens.inkMuted),
          ),
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

  Widget _detailRow(String label, String value, CissThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: tokens.inkMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(CissThemeTokens tokens) {
    return Divider(height: 16, color: tokens.border.withValues(alpha: 0.3));
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  String _formatDate(String value) {
    if (value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }
}
