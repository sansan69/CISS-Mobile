import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/report_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/sync/providers.dart';
import '../../../../../core/offline/draft_service.dart';
import '../../../../../shared/widgets/metric_tile.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import 'field_officer_work_orders_screen.dart';

final FutureProvider<List<VisitReportModel>> fieldOfficerVisitReportsProvider =
    FutureProvider<List<VisitReportModel>>((Ref ref) {
  return ref.read(mobileRepositoryProvider).fetchVisitReports();
});

final FutureProvider<List<TrainingReportModel>>
fieldOfficerTrainingReportsProvider = FutureProvider<List<TrainingReportModel>>(
  (Ref ref) {
    return ref.read(mobileRepositoryProvider).fetchTrainingReports();
  },
);

enum _Tab { visit, training }

class _PhotoEntry {
  _PhotoEntry({required this.bytes, required this.mimeType});
  final Uint8List bytes;
  final String mimeType;
  String? uploadedUrl;
  bool uploading = false;
}

class FieldOfficerReportsScreen extends ConsumerStatefulWidget {
  const FieldOfficerReportsScreen({super.key});

  @override
  ConsumerState<FieldOfficerReportsScreen> createState() =>
      _FieldOfficerReportsScreenState();
}

class _FieldOfficerReportsScreenState
    extends ConsumerState<FieldOfficerReportsScreen> {
  _Tab _tab = _Tab.visit;
  String _visitFilter = 'all';
  String _trainingFilter = 'all';

  void _refresh() {
    ref.invalidate(fieldOfficerWorkOrdersProvider);
    ref.invalidate(fieldOfficerVisitReportsProvider);
    ref.invalidate(fieldOfficerTrainingReportsProvider);
  }

  void _openSheet(BuildContext context, List<WorkOrderModel> workOrders) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _NewReportSheet(
        initialTab: _tab,
        workOrders: workOrders,
        onSubmitted: () {
          ref.invalidate(fieldOfficerVisitReportsProvider);
          ref.invalidate(fieldOfficerTrainingReportsProvider);
        },
      ),
    );
  }

  List<VisitReportModel> _filteredVisit(List<VisitReportModel> all) {
    if (_visitFilter == 'all') return all;
    return all.where((r) => r.status == _visitFilter).toList();
  }

  List<TrainingReportModel> _filteredTraining(List<TrainingReportModel> all) {
    if (_trainingFilter == 'all') return all;
    return all.where((r) => r.status == _trainingFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final workOrdersAsync = ref.watch(fieldOfficerWorkOrdersProvider);
    final visitAsync = ref.watch(fieldOfficerVisitReportsProvider);
    final trainingAsync = ref.watch(fieldOfficerTrainingReportsProvider);

    if (workOrdersAsync.isLoading ||
        visitAsync.isLoading ||
        trainingAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final err =
        workOrdersAsync.error ?? visitAsync.error ?? trainingAsync.error;
    if (err != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: StateBlock(
              icon: Icons.assignment_late_outlined,
              title: 'Could not load reports',
              message: err.toString().replaceFirst('Exception: ', ''),
              action: FilledButton.tonal(
                onPressed: _refresh,
                child: const Text('Try again'),
              ),
            ),
          ),
        ),
      );
    }

    final workOrders = workOrdersAsync.value!;
    final visitReports = visitAsync.value!;
    final trainingReports = trainingAsync.value!;

    final filteredVisit = _filteredVisit(visitReports);
    final filteredTraining = _filteredTraining(trainingReports);

    return ScreenScaffold(
      title: 'Reports',
      subtitle: 'Visit and training submissions',
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => _openSheet(context, workOrders),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New'),
        ),
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: MetricTile(
                label: 'Visit reports',
                value: visitReports.length.toString(),
                helper: 'Total submissions',
                icon: Icons.fact_check_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricTile(
                label: 'Training',
                value: trainingReports.length.toString(),
                helper: 'Total sessions',
                icon: Icons.school_outlined,
              ),
            ),
          ],
        ),
        SegmentedButton<_Tab>(
          segments: const <ButtonSegment<_Tab>>[
            ButtonSegment<_Tab>(
              value: _Tab.visit,
              label: Text('Visit'),
              icon: Icon(Icons.fact_check_outlined, size: 16),
            ),
            ButtonSegment<_Tab>(
              value: _Tab.training,
              label: Text('Training'),
              icon: Icon(Icons.school_outlined, size: 16),
            ),
          ],
          selected: <_Tab>{_tab},
          onSelectionChanged: (Set<_Tab> next) =>
              setState(() => _tab = next.first),
          showSelectedIcon: false,
        ),
        if (_tab == _Tab.visit)
          _StatusFilterRow(
            options: const <(String, String)>[
              ('all', 'All'),
              ('submitted', 'Submitted'),
              ('reviewed', 'Reviewed'),
              ('draft', 'Draft'),
            ],
            selected: _visitFilter,
            onChanged: (v) => setState(() => _visitFilter = v),
          )
        else
          _StatusFilterRow(
            options: const <(String, String)>[
              ('all', 'All'),
              ('submitted', 'Submitted'),
              ('acknowledged', 'Acknowledged'),
            ],
            selected: _trainingFilter,
            onChanged: (v) => setState(() => _trainingFilter = v),
          ),
        if (_tab == _Tab.visit) ...<Widget>[
          if (filteredVisit.isEmpty)
            StateBlock(
              icon: Icons.fact_check_outlined,
              title: visitReports.isEmpty
                  ? 'No visit reports yet'
                  : 'No ${_visitFilter == 'all' ? '' : _visitFilter} reports',
              message: visitReports.isEmpty
                  ? 'Tap "New" to submit your first site visit report.'
                  : 'Change the status filter to see other reports.',
            )
          else
            ...filteredVisit.map(_VisitReportCard.new),
        ] else ...<Widget>[
          if (filteredTraining.isEmpty)
            StateBlock(
              icon: Icons.school_outlined,
              title: trainingReports.isEmpty
                  ? 'No training reports yet'
                  : 'No ${_trainingFilter == 'all' ? '' : _trainingFilter} reports',
              message: trainingReports.isEmpty
                  ? 'Tap "New" to log your first training session.'
                  : 'Change the status filter to see other reports.',
            )
          else
            ...filteredTraining.map(_TrainingReportCard.new),
        ],
      ],
    );
  }
}

class _StatusFilterRow extends StatelessWidget {
  const _StatusFilterRow({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final (value, label) = opt;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: FilterChip(
              label: Text(label),
              selected: value == selected,
              onSelected: (_) => onChanged(value),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _VisitReportCard extends StatelessWidget {
  const _VisitReportCard(this.report);

  final VisitReportModel report;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);

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
                child: Text(
                  report.siteName.isEmpty ? 'Visit report' : report.siteName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _visitStatusChip(report.status),
            ],
          ),
          if (report.clientName.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              report.clientName,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Icon(Icons.calendar_today_outlined, size: 13, color: tokens.inkMuted),
              const SizedBox(width: 4),
              Text(
                report.dateLabel.isEmpty ? 'Date unknown' : report.dateLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tokens.inkMuted,
                ),
              ),
              if (report.district.isNotEmpty) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.place_outlined, size: 13, color: tokens.inkMuted),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    report.district,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: tokens.inkMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (report.guardsPresentCount > 0 || report.guardsAbsentCount > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                Icon(Icons.groups_2_outlined, size: 13, color: tokens.inkMuted),
                const SizedBox(width: 4),
                Text(
                  '${report.guardsPresentCount} present · ${report.guardsAbsentCount} absent',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tokens.inkMuted,
                  ),
                ),
              ],
            ),
          ],
          if (report.summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              report.summary,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (report.issuesFound.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.warning_amber_rounded, size: 13, color: tokens.warning),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    report.issuesFound,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.warning,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (report.photoUrls.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _PhotoThumbnailStrip(photoUrls: report.photoUrls),
          ],
        ],
      ),
    );
  }

  Widget _visitStatusChip(String status) {
    return switch (status) {
      'reviewed' => const StatusChip(
        label: 'Reviewed',
        icon: Icons.verified_outlined,
        tone: StatusChipTone.success,
      ),
      'draft' => const StatusChip(
        label: 'Draft',
        icon: Icons.edit_note_outlined,
        tone: StatusChipTone.neutral,
      ),
      _ => const StatusChip(
        label: 'Submitted',
        icon: Icons.upload_file_outlined,
        tone: StatusChipTone.info,
      ),
    };
  }
}

class _TrainingReportCard extends StatelessWidget {
  const _TrainingReportCard(this.report);

  final TrainingReportModel report;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);

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
                child: Text(
                  report.topic.isEmpty ? 'Training session' : report.topic,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _trainingStatusChip(report.status),
            ],
          ),
          if (report.siteName.isNotEmpty || report.clientName.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              [if (report.siteName.isNotEmpty) report.siteName, if (report.clientName.isNotEmpty) report.clientName].join(' · '),
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Icon(Icons.calendar_today_outlined, size: 13, color: tokens.inkMuted),
              const SizedBox(width: 4),
              Text(
                report.dateLabel.isEmpty ? 'Date unknown' : report.dateLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tokens.inkMuted,
                ),
              ),
              if (report.durationMinutes > 0) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.timer_outlined, size: 13, color: tokens.inkMuted),
                const SizedBox(width: 3),
                Text(
                  '${report.durationMinutes} min',
                  style: theme.textTheme.labelSmall?.copyWith(color: tokens.inkMuted),
                ),
              ],
              if (report.attendeeCount > 0) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.people_outline_rounded, size: 13, color: tokens.inkMuted),
                const SizedBox(width: 3),
                Text(
                  '${report.attendeeCount} attended',
                  style: theme.textTheme.labelSmall?.copyWith(color: tokens.inkMuted),
                ),
              ],
            ],
          ),
          if (report.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              report.description,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (report.photoUrls.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _PhotoThumbnailStrip(photoUrls: report.photoUrls),
          ],
        ],
      ),
    );
  }

  Widget _trainingStatusChip(String status) {
    return switch (status) {
      'acknowledged' => const StatusChip(
        label: 'Acknowledged',
        icon: Icons.check_circle_outline_rounded,
        tone: StatusChipTone.success,
      ),
      _ => const StatusChip(
        label: 'Submitted',
        icon: Icons.upload_file_outlined,
        tone: StatusChipTone.info,
      ),
    };
  }
}

class _PhotoThumbnailStrip extends StatelessWidget {
  const _PhotoThumbnailStrip({required this.photoUrls});
  final List<String> photoUrls;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photoUrls.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, int i) => GestureDetector(
          onTap: () => _openFullScreen(context, photoUrls[i]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.network(
              photoUrls[i],
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: tokens.surfaceStrong,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.broken_image_outlined, color: tokens.inkMuted),
              ),
              loadingBuilder: (_, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: tokens.surfaceStrong,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewReportSheet extends ConsumerStatefulWidget {
  const _NewReportSheet({
    required this.initialTab,
    required this.workOrders,
    required this.onSubmitted,
  });

  final _Tab initialTab;
  final List<WorkOrderModel> workOrders;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<_NewReportSheet> createState() => _NewReportSheetState();
}

class _NewReportSheetState extends ConsumerState<_NewReportSheet> {
  late _Tab _tab;
  WorkOrderModel? _selectedWorkOrder;

  DateTime? _visitDate;
  final _visitDateCtrl = TextEditingController();
  final _visitSummaryCtrl = TextEditingController();
  final _visitIssuesCtrl = TextEditingController();
  final _visitActionsCtrl = TextEditingController();
  final _visitPresentCtrl = TextEditingController(text: '0');
  final _visitAbsentCtrl = TextEditingController(text: '0');

  DateTime? _trainingDate;
  final _trainingDateCtrl = TextEditingController();
  final _trainingTopicCtrl = TextEditingController();
  final _trainingDescCtrl = TextEditingController();
  final _trainingDurationCtrl = TextEditingController(text: '60');
  final _trainingAttendeeCtrl = TextEditingController(text: '0');

  final List<_PhotoEntry> _photos = <_PhotoEntry>[];
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  bool _loading = false;
  String? _error;

  static final DateFormat _displayFmt = DateFormat('dd/MM/yyyy');
  static final DateFormat _apiFmt = DateFormat('yyyy-MM-dd');

  String get _draftKey => 'field_officer_report_${_tab.name}';

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _selectedWorkOrder = widget.workOrders.isNotEmpty ? widget.workOrders.first : null;

    // Add listeners for auto-save
    _visitSummaryCtrl.addListener(_saveDraft);
    _visitIssuesCtrl.addListener(_saveDraft);
    _visitActionsCtrl.addListener(_saveDraft);
    _visitPresentCtrl.addListener(_saveDraft);
    _visitAbsentCtrl.addListener(_saveDraft);
    
    _trainingTopicCtrl.addListener(_saveDraft);
    _trainingDescCtrl.addListener(_saveDraft);
    _trainingDurationCtrl.addListener(_saveDraft);
    _trainingAttendeeCtrl.addListener(_saveDraft);

    // Restore draft
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreDraft());
  }

  void _saveDraft() {
    final draftService = ref.read(draftServiceProvider);
    Map<String, dynamic> data;
    if (_tab == _Tab.visit) {
      data = {
        'summary': _visitSummaryCtrl.text,
        'issues': _visitIssuesCtrl.text,
        'actions': _visitActionsCtrl.text,
        'present': _visitPresentCtrl.text,
        'absent': _visitAbsentCtrl.text,
      };
    } else {
      data = {
        'topic': _trainingTopicCtrl.text,
        'description': _trainingDescCtrl.text,
        'duration': _trainingDurationCtrl.text,
        'attendees': _trainingAttendeeCtrl.text,
      };
    }
    draftService.saveDraft(_draftKey, data);
  }

  void _restoreDraft() {
    final draftService = ref.read(draftServiceProvider);
    final data = draftService.getDraft(_draftKey);
    if (data == null) return;

    setState(() {
      if (_tab == _Tab.visit) {
        _visitSummaryCtrl.text = data['summary'] ?? '';
        _visitIssuesCtrl.text = data['issues'] ?? '';
        _visitActionsCtrl.text = data['actions'] ?? '';
        _visitPresentCtrl.text = data['present'] ?? '0';
        _visitAbsentCtrl.text = data['absent'] ?? '0';
      } else {
        _trainingTopicCtrl.text = data['topic'] ?? '';
        _trainingDescCtrl.text = data['description'] ?? '';
        _trainingDurationCtrl.text = data['duration'] ?? '60';
        _trainingAttendeeCtrl.text = data['attendees'] ?? '0';
      }
    });
  }

  @override
  void dispose() {
    _visitSummaryCtrl.removeListener(_saveDraft);
    _visitIssuesCtrl.removeListener(_saveDraft);
    _visitActionsCtrl.removeListener(_saveDraft);
    _visitPresentCtrl.removeListener(_saveDraft);
    _visitAbsentCtrl.removeListener(_saveDraft);
    
    _trainingTopicCtrl.removeListener(_saveDraft);
    _trainingDescCtrl.removeListener(_saveDraft);
    _trainingDurationCtrl.removeListener(_saveDraft);
    _trainingAttendeeCtrl.removeListener(_saveDraft);

    _visitDateCtrl.dispose();
    _visitSummaryCtrl.dispose();
    _visitIssuesCtrl.dispose();
    _visitActionsCtrl.dispose();
    _visitPresentCtrl.dispose();
    _visitAbsentCtrl.dispose();
    _trainingDateCtrl.dispose();
    _trainingTopicCtrl.dispose();
    _trainingDescCtrl.dispose();
    _trainingDurationCtrl.dispose();
    _trainingAttendeeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isVisit}) async {
    final initial = isVisit ? (_visitDate ?? DateTime.now()) : (_trainingDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isVisit) {
          _visitDate = picked;
          _visitDateCtrl.text = _displayFmt.format(picked);
        } else {
          _trainingDate = picked;
          _trainingDateCtrl.text = _displayFmt.format(picked);
        }
      });
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 80, limit: 10);
      if (picked.isNotEmpty && mounted) {
        for (final xfile in picked) {
          final bytes = await xfile.readAsBytes();
          final mimeType = xfile.mimeType ?? 'image/jpeg';
          setState(() => _photos.add(_PhotoEntry(bytes: bytes, mimeType: mimeType)));
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not pick photos. Please try again.');
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        final mimeType = picked.mimeType ?? 'image/jpeg';
        setState(() => _photos.add(_PhotoEntry(bytes: bytes, mimeType: mimeType)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not capture photo. Please try again.');
      }
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<List<String>> _uploadPhotos() async {
    final urls = <String>[];
    for (final entry in _photos) {
      if (entry.uploadedUrl != null) {
        urls.add(entry.uploadedUrl!);
        continue;
      }
      setState(() => entry.uploading = true);
      try {
        final ext = entry.mimeType.split('/').last;
        final path = 'reports/${_uuid.v4()}.$ext';
        final dataUrl = await ref
            .read(mobileRepositoryProvider)
            .encodeFileToDataUrl(entry.bytes.toList(), entry.mimeType);
        final result = await ref
            .read(mobileRepositoryProvider)
            .uploadReportPhoto(path: path, dataUrl: dataUrl);
        entry.uploadedUrl = result['url'] as String? ?? '';
        if (mounted) setState(() => entry.uploading = false);
        if (entry.uploadedUrl!.isNotEmpty) urls.add(entry.uploadedUrl!);
      } catch (e) {
        if (mounted) setState(() => entry.uploading = false);
        rethrow;
      }
    }
    return urls;
  }

  Future<void> _submit() async {
    final selected = _selectedWorkOrder;
    if (selected == null) {
      setState(() => _error = 'Select a work order to link the report.');
      return;
    }

    final date = _tab == _Tab.visit ? _visitDate : _trainingDate;
    if (date == null) {
      setState(() => _error = 'Select a date before submitting.');
      return;
    }

    if (selected.clientId.isEmpty) {
      setState(() => _error = 'The selected work order is missing client information. Pick a different one.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final photoDataUrls = <String>[];
      for (final photo in _photos) {
        final dataUrl = await ref
            .read(mobileRepositoryProvider)
            .encodeFileToDataUrl(photo.bytes.toList(), photo.mimeType);
        photoDataUrls.add(dataUrl);
      }

      final common = <String, dynamic>{
        'clientId': selected.clientId,
        'clientName': selected.clientName,
        'siteId': selected.siteId,
        'siteName': selected.siteName,
        'district': selected.district,
        'status': 'submitted',
      };

      Map<String, dynamic> payload;
      String path;
      if (_tab == _Tab.visit) {
        final summary = _visitSummaryCtrl.text.trim();
        if (summary.isEmpty) {
          setState(() {
            _loading = false;
            _error = 'Please write a visit summary.';
          });
          return;
        }
        path = '/api/field-officer/visit-reports';
        payload = {
          ...common,
          'visitDate': _apiFmt.format(date),
          'summary': summary,
          'issuesFound': _visitIssuesCtrl.text.trim(),
          'actionsRequired': _visitActionsCtrl.text.trim(),
          'guardsPresentCount': int.tryParse(_visitPresentCtrl.text.trim()) ?? 0,
          'guardsAbsentCount': int.tryParse(_visitAbsentCtrl.text.trim()) ?? 0,
        };
      } else {
        path = '/api/field-officer/training-reports';
        payload = {
          ...common,
          'trainingDate': _apiFmt.format(date),
          'durationMinutes': int.tryParse(_trainingDurationCtrl.text.trim()) ?? 60,
          'topic': _trainingTopicCtrl.text.trim(),
          'description': _trainingDescCtrl.text.trim(),
          'attendeeIds': <String>[],
          'attendeeCount': int.tryParse(_trainingAttendeeCtrl.text.trim()) ?? 0,
        };
      }

      try {
        final photoUrls = await _uploadPhotos();
        final finalPayload = {
          ...payload,
          'photoUrls': photoUrls,
        };
        
        if (_tab == _Tab.visit) {
          await ref.read(mobileRepositoryProvider).submitVisitReport(finalPayload);
        } else {
          await ref.read(mobileRepositoryProvider).submitTrainingReport(finalPayload);
        }
        
        await ref.read(draftServiceProvider).clearDraft(_draftKey);
        
        widget.onSubmitted();
        if (mounted) Navigator.of(context).pop();
      } catch (uploadOrSubmitError) {
        if (uploadOrSubmitError is DioException &&
            (uploadOrSubmitError.type == DioExceptionType.connectionTimeout ||
                uploadOrSubmitError.type == DioExceptionType.sendTimeout ||
                uploadOrSubmitError.type == DioExceptionType.receiveTimeout ||
                uploadOrSubmitError.type == DioExceptionType.connectionError)) {
          await ref.read(offlineQueueProvider).enqueue(
            path: path,
            method: 'POST',
            body: {
              ...payload,
              'photoDataUrls': photoDataUrls,
            },
          );

          await ref.read(draftServiceProvider).clearDraft(_draftKey);

          widget.onSubmitted();
          if (mounted) Navigator.of(context).pop();
        } else {
          rethrow;
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: tokens.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'New report',
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
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
            const SizedBox(height: 16),
            SegmentedButton<_Tab>(
              segments: const <ButtonSegment<_Tab>>[
                ButtonSegment<_Tab>(
                  value: _Tab.visit,
                  label: Text('Visit report'),
                  icon: Icon(Icons.fact_check_outlined, size: 16),
                ),
                ButtonSegment<_Tab>(
                  value: _Tab.training,
                  label: Text('Training'),
                  icon: Icon(Icons.school_outlined, size: 16),
                ),
              ],
              selected: <_Tab>{_tab},
              onSelectionChanged: (Set<_Tab> next) => setState(() => _tab = next.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 16),
            if (widget.workOrders.isNotEmpty) ...<Widget>[
              DropdownButtonFormField<WorkOrderModel>(
                initialValue: _selectedWorkOrder,
                decoration: const InputDecoration(
                  labelText: 'Linked work order',
                  prefixIcon: Icon(Icons.assignment_turned_in_outlined),
                ),
                items: widget.workOrders
                    .map(
                      (w) => DropdownMenuItem<WorkOrderModel>(
                        value: w,
                        child: Text(
                          '${w.siteName.isEmpty ? 'Site' : w.siteName} · ${w.examName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedWorkOrder = v),
              ),
              const SizedBox(height: 14),
            ],
            if (_tab == _Tab.visit) _buildVisitForm() else _buildTrainingForm(),
            const SizedBox(height: 16),
            _buildPhotoSection(tokens),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: tokens.dangerSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.error_outline_rounded, color: tokens.danger, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(color: tokens.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _tab == _Tab.visit
                      ? 'Submit visit report'
                      : 'Submit training report',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _visitDateCtrl,
          readOnly: true,
          onTap: () => _pickDate(isVisit: true),
          decoration: const InputDecoration(
            labelText: 'Visit date',
            hintText: 'Tap to select',
            prefixIcon: Icon(Icons.calendar_month_outlined),
            suffixIcon: Icon(Icons.arrow_drop_down_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _visitPresentCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Guards present',
                  prefixIcon: Icon(Icons.check_circle_outline_rounded),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _visitAbsentCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Guards absent',
                  prefixIcon: Icon(Icons.cancel_outlined),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _visitSummaryCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Visit summary',
            hintText: 'Describe what you observed during this visit',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _visitIssuesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Issues found',
            hintText: 'Any compliance, safety, or operational issues',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _visitActionsCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Actions required',
            hintText: 'Follow-up steps or escalations needed',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildTrainingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _trainingDateCtrl,
          readOnly: true,
          onTap: () => _pickDate(isVisit: false),
          decoration: const InputDecoration(
            labelText: 'Training date',
            hintText: 'Tap to select',
            prefixIcon: Icon(Icons.calendar_month_outlined),
            suffixIcon: Icon(Icons.arrow_drop_down_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _trainingTopicCtrl,
          decoration: const InputDecoration(
            labelText: 'Topic',
            hintText: 'e.g. Emergency procedures, Equipment handling',
            prefixIcon: Icon(Icons.subject_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _trainingDurationCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (min)',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _trainingAttendeeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Attendees',
                  prefixIcon: Icon(Icons.people_outline_rounded),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _trainingDescCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Key points covered, observations, outcomes',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection(CissThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.camera_alt_outlined, size: 18, color: tokens.inkMuted),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Photos (${_photos.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: tokens.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            ..._photos.asMap().entries.map((entry) {
              final index = entry.key;
              final photo = entry.value;
              return Stack(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.memory(
                      photo.bytes,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => _removePhoto(index),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  if (photo.uploading)
                    const Positioned.fill(
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                  if (photo.uploadedUrl != null)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1F8F63),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                ],
              );
            }),
            _AddPhotoButton(onGallery: _pickPhotos, onCamera: _takePhoto),
          ],
        ),
      ],
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({required this.onGallery, required this.onCamera});

  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'gallery') onGallery();
        if (value == 'camera') onCamera();
      },
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'camera',
          child: Row(
            children: <Widget>[
              Icon(Icons.camera_alt_rounded, size: 20, color: tokens.primary),
              const SizedBox(width: AppSpacing.sm),
              const Text('Take photo'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'gallery',
          child: Row(
            children: <Widget>[
              Icon(Icons.photo_library_rounded, size: 20, color: tokens.primary),
              const SizedBox(width: AppSpacing.sm),
              const Text('Choose from gallery'),
            ],
          ),
        ),
      ],
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: tokens.surfaceStrong,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: tokens.border,
            style: BorderStyle.solid,
          ),
        ),
        child: Icon(Icons.add_rounded, color: tokens.inkMuted, size: 28),
      ),
    );
  }
}
