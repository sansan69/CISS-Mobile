import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../../core/models/duty_models.dart';
import '../../../../../core/models/guard_profile.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/network/ciss_error.dart';
import '../../../../../core/settings/module_gate.dart';
import '../../../../../shared/widgets/adaptive_dropdown.dart';
import '../../../../../shared/widgets/primary_action.dart';

class AssignmentEditorSheet extends ConsumerStatefulWidget {
  const AssignmentEditorSheet({
    super.key,
    this.assignment,
    required this.onSaved,
  });
  final GuardAssignment? assignment;
  final VoidCallback onSaved;
  @override
  ConsumerState<AssignmentEditorSheet> createState() =>
      _AssignmentEditorSheetState();
}

class _AssignmentEditorSheetState extends ConsumerState<AssignmentEditorSheet> {
  final _form = GlobalKey<FormState>();
  final _date = TextEditingController(),
      _label = TextEditingController(),
      _start = TextEditingController(),
      _end = TextEditingController();
  final _selected = <String>{},
      _ids = <String, String>{},
      _results = <String, String>{};
  List<FieldOfficerSiteOption>? _sites;
  List<GuardProfileModel> _guards = [];
  String? _siteId, _shiftCode, _error;
  String _type = 'regular';
  bool _overnight = false, _saving = false;
  @override
  void initState() {
    super.initState();
    final a = widget.assignment?.data;
    _siteId = a?['siteId'] as String?;
    _shiftCode = a?['shiftCode'] as String?;
    _date.text = a?['date'] as String? ?? '';
    _label.text = a?['shiftLabel'] as String? ?? '';
    _type = a?['type'] as String? ?? 'regular';
    String time(Object? value) {
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      if (parsed == null) return '';
      final ist = parsed.toUtc().add(const Duration(hours: 5, minutes: 30));
      return '${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')}';
    }

    _start.text = time(a?['startsAt']);
    _end.text = time(a?['endsAt']);
    _overnight =
        _start.text.isNotEmpty && _end.text.compareTo(_start.text) <= 0;
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final values = await Future.wait<dynamic>([
        repo.fetchFieldOfficerSites(),
        repo.fetchFieldOfficerGuards(),
      ]);
      if (mounted) {
        setState(() {
          _sites = values[0] as List<FieldOfficerSiteOption>;
          _guards = values[1] as List<GuardProfileModel>;
          if (!_sites!.any((s) => s.id == _siteId)) _siteId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = 'Could not load sites and guards: ${CissError.parse(e)}',
        );
      }
    }
  }

  @override
  void dispose() {
    _date.dispose();
    _label.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  FieldOfficerSiteOption? get _site =>
      _sites?.where((s) => s.id == _siteId).firstOrNull;
  String? _time(String? value) =>
      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value ?? '')
          ? null
          : 'Enter a valid time';
  String? _day(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    if (parsed == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value ?? '') ||
        parsed.toIso8601String().substring(0, 10) != value) {
      return 'Enter a valid duty date';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!moduleEnabled(ref, 'workOrders')) return;
    if (widget.assignment == null && _selected.isEmpty) {
      setState(() => _error = 'Select at least one guard');
      return;
    }
    final templates = _site!.shiftTemplates;
    if (templates.isEmpty &&
        ((_overnight && _end.text.compareTo(_start.text) >= 0) ||
            (!_overnight && _end.text.compareTo(_start.text) <= 0))) {
      setState(() => _error = 'Check shift times and whether it ends next day');
      return;
    }
    final body = <String, dynamic>{
      'siteId': _siteId,
      'date': _date.text,
      'type': _type,
      if (templates.isNotEmpty) 'shiftCode': _shiftCode,
      if (templates.isEmpty) ...{
        'shiftLabel': _label.text.trim(),
        'startTime': _start.text,
        'endTime': _end.text,
        'crossesMidnight': _overnight,
      },
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final assignment = widget.assignment;
      if (assignment != null) {
        final payload = {...body, 'expectedVersion': assignment.version};
        final key = jsonEncode(payload);
        await repo.updateGuardAssignment(assignment.id, {
          ...payload,
          'clientRequestId': _ids.putIfAbsent(key, () => const Uuid().v4()),
        });
        widget.onSaved();
        if (mounted) Navigator.pop(context);
      } else {
        for (final id in List.of(_selected)) {
          final guard = _guards.firstWhere((g) => g.id == id);
          final payload = {...body, 'employeeDocId': id};
          final key = jsonEncode(payload);
          try {
            await repo.createGuardAssignment({
              ...payload,
              'clientRequestId': _ids.putIfAbsent(key, () => const Uuid().v4()),
            });
            _results[id] = '${guard.fullName}: saved';
            _selected.remove(id);
          } catch (e) {
            _results[id] =
                '${guard.fullName}: not saved — ${CissError.parse(e)}';
          }
          if (mounted) setState(() {});
        }
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Assignment not saved: ${CissError.parse(e)}');
      }
      widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = _site?.shiftTemplates ?? [];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.assignment == null
                            ? 'Schedule duty'
                            : 'Edit duty',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (_sites == null && _error == null)
                  const CircularProgressIndicator(),
                AdaptiveDropdownFormField<String>(
                  value: _siteId,
                  label: 'Site',
                  validator: (v) => v == null ? 'Select a site' : null,
                  items:
                      (_sites ?? [])
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                '${s.siteName} · ${s.district}',
                                softWrap: true,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged:
                      _saving
                          ? null
                          : (v) => setState(() {
                            _siteId = v;
                            _shiftCode = null;
                          }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _date,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: 'Duty date',
                    helperText: 'Enter date as YYYY-MM-DD',
                    helperMaxLines: 2,
                    suffixIcon: IconButton(
                      tooltip: 'Choose date',
                      onPressed:
                          _saving
                              ? null
                              : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      DateTime.tryParse(_date.text) ??
                                      DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  _date.text = picked
                                      .toIso8601String()
                                      .substring(0, 10);
                                }
                              },
                      icon: const Icon(Icons.calendar_month),
                    ),
                  ),
                  validator: _day,
                ),
                const SizedBox(height: 12),
                AdaptiveDropdownFormField<String>(
                  value: _type,
                  label: 'Assignment type',
                  items: const [
                    DropdownMenuItem(value: 'regular', child: Text('Regular')),
                    DropdownMenuItem(
                      value: 'relieving',
                      child: Text('Relieving'),
                    ),
                  ],
                  onChanged: _saving ? null : (v) => setState(() => _type = v!),
                ),
                const SizedBox(height: 12),
                if (templates.isNotEmpty)
                  AdaptiveDropdownFormField<String>(
                    value:
                        templates.any((s) => s.code == _shiftCode)
                            ? _shiftCode
                            : null,
                    label: 'Shift',
                    validator: (v) => v == null ? 'Select a shift' : null,
                    items:
                        templates
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.code,
                                child: Text(
                                  '${s.label} · ${s.startTime}–${s.endTime}',
                                  softWrap: true,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        _saving ? null : (v) => setState(() => _shiftCode = v),
                  )
                else ...[
                  TextFormField(
                    controller: _label,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Shift label'),
                    validator:
                        (v) =>
                            v?.trim().isNotEmpty == true
                                ? null
                                : 'Enter a shift label',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _start,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Start time (HH:mm)',
                    ),
                    validator: _time,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _end,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'End time (HH:mm)',
                    ),
                    validator: _time,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ends next day'),
                    value: _overnight,
                    onChanged:
                        _saving ? null : (v) => setState(() => _overnight = v!),
                  ),
                ],
                if (widget.assignment == null) ...[
                  const SizedBox(height: 12),
                  const Text('Choose guards'),
                  ..._guards.map(
                    (g) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(g.fullName),
                      subtitle: Text(
                        '${g.employeeId} · ${g.district}${g.categoryLabel == null ? '' : ' · ${g.categoryLabel}'}',
                      ),
                      value: _selected.contains(g.id),
                      onChanged:
                          _saving
                              ? null
                              : (v) => setState(
                                () =>
                                    v == true
                                        ? _selected.add(g.id)
                                        : _selected.remove(g.id),
                              ),
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Guard: ${widget.assignment!.guardName}. To change guard, cancel and create a new assignment.',
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ..._results.values.map(
                  (result) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(result),
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryAction(
                  icon: Icons.check,
                  label:
                      _saving
                          ? 'Saving…'
                          : widget.assignment == null
                          ? 'Create assignments'
                          : 'Save duty',
                  enabled:
                      !_saving &&
                      _sites != null &&
                      moduleEnabled(ref, 'workOrders'),
                  onTap: _save,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Each guard is saved separately. Assignments do not control attendance.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
