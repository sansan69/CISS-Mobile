import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/models/guard_profile.dart';
import '../../../../core/network/providers.dart';
import '../../../../shared/widgets/brand_banner.dart';
import '../../../../shared/widgets/modern_card.dart';
import '../../../../shared/widgets/state_block.dart';

class FieldOfficerTrainingAssignmentsScreen extends ConsumerStatefulWidget {
  const FieldOfficerTrainingAssignmentsScreen({super.key});

  @override
  ConsumerState<FieldOfficerTrainingAssignmentsScreen> createState() =>
      _FieldOfficerTrainingAssignmentsScreenState();
}

class _FieldOfficerTrainingAssignmentsScreenState
    extends ConsumerState<FieldOfficerTrainingAssignmentsScreen> {
  List<Map<String, dynamic>> _modules = const [];
  List<Map<String, dynamic>> _assignments = const [];
  List<GuardProfileModel> _guards = const [];
  final Set<String> _selectedGuardIds = <String>{};
  String? _moduleId;
  DateTime? _dueDate;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final results = await Future.wait<dynamic>([
        repo.apiClient.dio.get<dynamic>('/api/admin/training/modules'),
        repo.apiClient.dio.get<dynamic>('/api/admin/training/assignments'),
        repo.fetchFieldOfficerGuards(),
      ]);
      final moduleData = Map<String, dynamic>.from(results[0].data as Map);
      final assignmentData = Map<String, dynamic>.from(results[1].data as Map);
      if (!mounted) return;
      setState(() {
        _modules =
            (moduleData['modules'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .toList();
        _assignments =
            (assignmentData['assignments'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .toList();
        _guards = results[2] as List<GuardProfileModel>;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _openGuardSelector() async {
    final tokens = CissThemeTokens.of(context);
    final tempSelected = Set<String>.from(_selectedGuardIds);
    String filterQuery = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setModalState) {
              final filteredGuards =
                  _guards.where((g) {
                    final query = filterQuery.toLowerCase();
                    return g.fullName.toLowerCase().contains(query) ||
                        g.district.toLowerCase().contains(query) ||
                        g.employeeId.toLowerCase().contains(query);
                  }).toList();

              return DraggableScrollableSheet(
                initialChildSize: 0.85,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder:
                    (ctx, scrollController) => Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: tokens.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Select Guards (${tempSelected.length})',
                                style: Theme.of(
                                  ctx,
                                ).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: tokens.ink,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    if (tempSelected.length == _guards.length) {
                                      tempSelected.clear();
                                    } else {
                                      tempSelected.addAll(
                                        _guards.map((g) => g.id),
                                      );
                                    }
                                  });
                                },
                                child: Text(
                                  tempSelected.length == _guards.length
                                      ? 'Deselect All'
                                      : 'Select All',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: TextField(
                            autofocus: false,
                            style: TextStyle(color: tokens.ink),
                            decoration: InputDecoration(
                              hintText:
                                  'Search guard by name, ID, or district...',
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: tokens.inkMuted,
                              ),
                              filled: true,
                              fillColor: tokens.surfaceMuted,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            onChanged:
                                (val) =>
                                    setModalState(() => filterQuery = val),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: filteredGuards.length,
                            itemBuilder: (ctx, i) {
                              final guard = filteredGuards[i];
                              final isChecked = tempSelected.contains(guard.id);
                              return CheckboxListTile(
                                value: isChecked,
                                activeColor: tokens.primary,
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      tempSelected.add(guard.id);
                                    } else {
                                      tempSelected.remove(guard.id);
                                    }
                                  });
                                },
                                title: Text(
                                  guard.fullName,
                                  style: TextStyle(
                                    fontWeight:
                                        isChecked
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                    color: tokens.ink,
                                  ),
                                ),
                                subtitle: Text(
                                  '${guard.employeeId.isNotEmpty ? '${guard.employeeId} · ' : ''}${guard.district}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tokens.inkMuted,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _selectedGuardIds
                                    ..clear()
                                    ..addAll(tempSelected);
                                });
                                Navigator.pop(ctx);
                              },
                              child: Text(
                                'Done (${tempSelected.length} selected)',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
              );
            },
          ),
    );
  }

  Future<void> _assign() async {
    final selectedGuards =
        _guards.where((item) => _selectedGuardIds.contains(item.id)).toList();
    final module =
        _modules
            .where((item) => item['id']?.toString() == _moduleId)
            .firstOrNull;
    if (selectedGuards.isEmpty || module == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(mobileRepositoryProvider)
          .apiClient
          .dio
          .post<dynamic>(
            '/api/admin/training/assignments',
            data: {
              'employeeIds': selectedGuards.map((g) => g.id).toList(),
              'employeeName':
                  selectedGuards.length == 1
                      ? selectedGuards.first.fullName
                      : 'Batch Assignment (${selectedGuards.length} guards)',
              'clientName': selectedGuards.first.clientName,
              'district': selectedGuards.first.district,
              'moduleId': module['id'],
              'moduleName':
                  module['title'] ?? module['name'] ?? 'Training module',
              'moduleCategory': module['category'] ?? 'skills',
              if (_dueDate != null) 'dueDate': _dueDate!.toIso8601String(),
            },
          );
      await _load();
      if (mounted) {
        setState(() {
          _selectedGuardIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Training assigned to ${selectedGuards.length} guard(s).',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Assignment failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    if (_loading) {
      return Scaffold(
        appBar: const CissAppBar(title: 'Training Assignments'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: const CissAppBar(title: 'Training Assignments'),
        body: StateBlock(
          icon: Icons.school_outlined,
          title: 'Could not load training',
          message: _error!,
          action: FilledButton.tonal(
            onPressed: _load,
            child: const Text('Retry'),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: const CissAppBar(title: 'Training Assignments'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ModernCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign a module',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _openGuardSelector,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color:
                              _selectedGuardIds.isEmpty
                                  ? tokens.border
                                  : tokens.primary,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.people_alt_outlined,
                            size: 20,
                            color:
                                _selectedGuardIds.isEmpty
                                    ? tokens.inkMuted
                                    : tokens.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedGuardIds.isEmpty
                                      ? 'Select Guards'
                                      : '${_selectedGuardIds.length} Guard(s) Selected',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color:
                                        _selectedGuardIds.isEmpty
                                            ? tokens.inkMuted
                                            : tokens.ink,
                                  ),
                                ),
                                if (_selectedGuardIds.isNotEmpty)
                                  Text(
                                    _guards
                                            .where(
                                              (g) => _selectedGuardIds.contains(
                                                g.id,
                                              ),
                                            )
                                            .map((g) => g.fullName)
                                            .take(3)
                                            .join(', ') +
                                        (_selectedGuardIds.length > 3
                                            ? ' +${_selectedGuardIds.length - 3} more'
                                            : ''),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: tokens.inkMuted,
                                    ),
                                  )
                                else
                                  Text(
                                    'Tap to search and select guards',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: tokens.inkMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            color: tokens.inkMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _moduleId,
                    decoration: const InputDecoration(
                      labelText: 'Training module',
                    ),
                    items:
                        _modules
                            .map(
                              (module) => DropdownMenuItem(
                                value: module['id']?.toString(),
                                child: Text(
                                  module['title']?.toString() ??
                                      module['name']?.toString() ??
                                      'Module',
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setState(() => _moduleId = value),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: _dueDate ?? DateTime.now(),
                      );
                      if (date != null) setState(() => _dueDate = date);
                    },
                    icon: const Icon(Icons.event_rounded),
                    label: Text(
                      _dueDate == null
                          ? 'Optional due date'
                          : 'Due ${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          _saving ||
                                  _selectedGuardIds.isEmpty ||
                                  _moduleId == null
                              ? null
                              : _assign,
                      icon: const Icon(Icons.add_task_rounded),
                      label: Text(
                        _saving
                            ? 'Assigning…'
                            : _selectedGuardIds.length > 1
                            ? 'Assign to ${_selectedGuardIds.length} Guards'
                            : 'Assign Training',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Recent assignments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: tokens.ink,
              ),
            ),
            const SizedBox(height: 8),
            if (_assignments.isEmpty)
              const StateBlock(
                icon: Icons.assignment_outlined,
                title: 'No assignments yet',
                message: 'Assigned modules will appear here.',
              ),
            ..._assignments
                .take(50)
                .map(
                  (assignment) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ModernCard(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.school_outlined),
                        ),
                        title: Text(
                          assignment['employeeName']?.toString() ?? 'Guard',
                        ),
                        subtitle: Text(
                          '${assignment['moduleName'] ?? 'Module'} · ${assignment['status'] ?? 'assigned'}',
                        ),
                        trailing: Text(
                          assignment['district']?.toString() ?? '',
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
