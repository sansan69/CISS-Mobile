import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/report_models.dart';
import '../../../../../core/network/mobile_repository.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/sync/providers.dart';
import '../../../../../core/offline/draft_service.dart';
import '../../../../../shared/widgets/brand_banner.dart';
import '../../../../../shared/widgets/glass_card.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';
import 'field_officer_work_orders_screen.dart';

final FutureProvider<List<VisitReportModel>> fieldOfficerVisitReportsProvider =
    FutureProvider<List<VisitReportModel>>((Ref ref) {
  return ref.read(mobileRepositoryProvider).fetchVisitReports();
});

final FutureProvider<List<TrainingReportModel>>
    fieldOfficerTrainingReportsProvider =
    FutureProvider<List<TrainingReportModel>>(
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
  String _monthFilter = '';
  String _clientFilter = '';
  String _districtFilter = '';
  bool _showFilters = false;

  void _refresh() {
    ref.invalidate(fieldOfficerWorkOrdersProvider);
    ref.invalidate(fieldOfficerVisitReportsProvider);
    ref.invalidate(fieldOfficerTrainingReportsProvider);
  }

  void _openSheet(BuildContext context, List<WorkOrderModel> workOrders) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    var filtered = all;
    if (_visitFilter != 'all') filtered = filtered.where((r) => r.status == _visitFilter).toList();
    if (_clientFilter.isNotEmpty) filtered = filtered.where((r) => r.clientName.toLowerCase().contains(_clientFilter.toLowerCase())).toList();
    if (_districtFilter.isNotEmpty) filtered = filtered.where((r) => r.district.toLowerCase().contains(_districtFilter.toLowerCase())).toList();
    if (_monthFilter.isNotEmpty) {
      filtered = filtered.where((r) => r.dateLabel.startsWith(_monthFilter)).toList();
    }
    return filtered;
  }

  List<TrainingReportModel> _filteredTraining(List<TrainingReportModel> all) {
    var filtered = all;
    if (_trainingFilter != 'all') filtered = filtered.where((r) => r.status == _trainingFilter).toList();
    if (_clientFilter.isNotEmpty) filtered = filtered.where((r) => r.clientName.toLowerCase().contains(_clientFilter.toLowerCase())).toList();
    if (_districtFilter.isNotEmpty) filtered = filtered.where((r) => r.district.toLowerCase().contains(_districtFilter.toLowerCase())).toList();
    if (_monthFilter.isNotEmpty) {
      filtered = filtered.where((r) => r.dateLabel.startsWith(_monthFilter)).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final workOrdersAsync = ref.watch(fieldOfficerWorkOrdersProvider);
    final visitAsync = ref.watch(fieldOfficerVisitReportsProvider);
    final trainingAsync = ref.watch(fieldOfficerTrainingReportsProvider);
    final tokens = CissThemeTokens.of(context);

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

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        children: [
          BrandBanner(
            title: 'Reports',
            subtitle: 'Field visit and training briefing center',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SyncStatusBadge(),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SegmentedButton<_Tab>(
                  segments: const <ButtonSegment<_Tab>>[
                    ButtonSegment<_Tab>(
                      value: _Tab.visit,
                      label: Text('Visit Logs'),
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
                const SizedBox(height: 12),
                if (_tab == _Tab.visit)
                  _StatusFilterRow(
                    options: const <(String, String)>[
                      ('all', 'All'),
                      ('draft', 'Draft'),
                      ('submitted', 'Submitted'),
                      ('reviewed', 'Reviewed'),
                    ],
                    selected: _visitFilter,
                    onChanged: (v) => setState(() => _visitFilter = v),
                  )
                else
                  _StatusFilterRow(
                    options: const <(String, String)>[
                      ('all', 'All'),
                      ('draft', 'Draft'),
                      ('submitted', 'Submitted'),
                      ('acknowledged', 'Acknowledged'),
                    ],
                    selected: _trainingFilter,
                    onChanged: (v) => setState(() => _trainingFilter = v),
                  ),
              ],
            ),
          ),

          // Filter bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _showFilters = !_showFilters),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list, size: 16, color: tokens.inkMuted),
                        const SizedBox(width: 4),
                        Text(
                          _showFilters ? 'Hide Filters' : 'Show Filters',
                          style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.inkMuted),
                        ),
                        if (_monthFilter.isNotEmpty || _clientFilter.isNotEmpty || _districtFilter.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: tokens.primarySoft, borderRadius: BorderRadius.circular(4)),
                            child: Text('Active', style: GoogleFonts.rajdhani(fontSize: 9, fontWeight: FontWeight.w800, color: tokens.primary)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_showFilters) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Month', prefixIcon: Icon(Icons.calendar_month, size: 18),
                            isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          ),
                          controller: TextEditingController(text: _monthFilter),
                          onChanged: (v) => setState(() => _monthFilter = v),
                          keyboardType: TextInputType.datetime,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Client', prefixIcon: Icon(Icons.business, size: 18),
                            isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          ),
                          controller: TextEditingController(text: _clientFilter),
                          onChanged: (v) => setState(() => _clientFilter = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'District', prefixIcon: Icon(Icons.map, size: 18),
                            isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          ),
                          controller: TextEditingController(text: _districtFilter),
                          onChanged: (v) => setState(() => _districtFilter = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),

          if (_tab == _Tab.visit) ...[
            if (filteredVisit.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: StateBlock(
                  icon: Icons.fact_check_outlined,
                  title: 'No visit reports',
                  message: 'Your site visit briefing notes will appear here.',
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: filteredVisit.map((r) => _VisitBriefingCard(r)).toList(),
                ),
              ),
          ] else ...[
            if (filteredTraining.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: StateBlock(
                  icon: Icons.school_outlined,
                  title: 'No training logs',
                  message: 'Logged field training sessions will appear here.',
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: filteredTraining.map((r) => _TrainingBriefingCard(r)).toList(),
                ),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(context, workOrders),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'NEW BRIEFING',
          style: GoogleFonts.rajdhani(fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
      ),
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
    final tokens = CissThemeTokens.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final (value, label) = opt;
          final isSelected = value == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                label.toUpperCase(),
                style: GoogleFonts.rajdhani(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? tokens.primaryStrong : tokens.inkMuted,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(value),
              showCheckmark: false,
              backgroundColor: tokens.surface,
              selectedColor: tokens.primarySoft,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _VisitBriefingCard extends StatelessWidget {
  const _VisitBriefingCard(this.report);
  final VisitReportModel report;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final isSynced = !report.id.startsWith('local-');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        accentColor: isSynced ? tokens.success : tokens.warning,
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
                        report.siteName.toUpperCase(),
                        style: GoogleFonts.rajdhani(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: tokens.ink,
                        ),
                      ),
                      Text(
                        report.clientName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.inkMuted),
                      ),
                    ],
                  ),
                ),
                if (!isSynced)
                  const StatusChip(label: 'SYNCING', tone: StatusChipTone.warning)
                else
                  const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF1F8F63)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 12, color: tokens.inkMuted),
                const SizedBox(width: 4),
                Text(
                  report.dateLabel,
                  style: GoogleFonts.rajdhani(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.inkMuted),
                ),
                const SizedBox(width: 16),
                Icon(Icons.groups_2_outlined, size: 12, color: tokens.inkMuted),
                const SizedBox(width: 4),
                Text(
                  '${report.guardsPresentCount} IN / ${report.guardsAbsentCount} OUT',
                  style: GoogleFonts.rajdhani(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.primary),
                ),
              ],
            ),
            if (report.summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                report.summary,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (report.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              _PhotoThumbnailStrip(photoUrls: report.photoUrls),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrainingBriefingCard extends StatelessWidget {
  const _TrainingBriefingCard(this.report);
  final TrainingReportModel report;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final isSynced = !report.id.startsWith('local-');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        accentColor: tokens.accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.topic.toUpperCase(),
                        style: GoogleFonts.rajdhani(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: tokens.ink,
                        ),
                      ),
                      Text(
                        report.siteName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.inkMuted),
                      ),
                    ],
                  ),
                ),
                if (!isSynced)
                  const StatusChip(label: 'QUEUED', tone: StatusChipTone.info)
                else
                  const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF1F8F63)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 12, color: tokens.inkMuted),
                const SizedBox(width: 4),
                Text(
                  '${report.durationMinutes} MINS',
                  style: GoogleFonts.rajdhani(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.accent),
                ),
                const SizedBox(width: 16),
                Icon(Icons.people_alt_outlined, size: 12, color: tokens.inkMuted),
                const SizedBox(width: 4),
                Text(
                  '${report.attendeeCount} ATTENDED',
                  style: GoogleFonts.rajdhani(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.inkMuted),
                ),
              ],
            ),
            if (report.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              _PhotoThumbnailStrip(photoUrls: report.photoUrls),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoThumbnailStrip extends StatelessWidget {
  const _PhotoThumbnailStrip({required this.photoUrls});
  final List<String> photoUrls;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photoUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, int i) => GestureDetector(
          onTap: () => _openFullScreen(context, photoUrls[i]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.network(
              photoUrls[i],
              width: 60,
              height: 60,
              fit: BoxFit.cover,
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
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: Center(child: InteractiveViewer(child: Image.network(url))),
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
  final List<_PhotoEntry> _clientReportPhotos = <_PhotoEntry>[];
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  String _reportStatus = 'submitted'; // 'draft' | 'submitted'
  Map<String, double>? _visitLocation;
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
    
    _visitSummaryCtrl.addListener(_saveDraft);
    _visitIssuesCtrl.addListener(_saveDraft);
    _visitActionsCtrl.addListener(_saveDraft);
    _visitPresentCtrl.addListener(_saveDraft);
    _visitAbsentCtrl.addListener(_saveDraft);
    
    _trainingTopicCtrl.addListener(_saveDraft);
    _trainingDescCtrl.addListener(_saveDraft);
    _trainingDurationCtrl.addListener(_saveDraft);
    _trainingAttendeeCtrl.addListener(_saveDraft);

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
        await _captureLocation();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not pick photos.');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        final mimeType = picked.mimeType ?? 'image/jpeg';
        setState(() => _photos.add(_PhotoEntry(bytes: bytes, mimeType: mimeType)));
        await _captureLocation();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not capture photo.');
    }
  }

  Future<void> _pickClientReport() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        final mimeType = picked.mimeType ?? 'application/pdf';
        setState(() => _clientReportPhotos.add(_PhotoEntry(bytes: bytes, mimeType: mimeType)));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not pick report file.');
    }
  }

  Future<void> _captureLocation() async {
    if (_visitLocation != null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 5)),
      );
      if (mounted) {
        setState(() => _visitLocation = {'lat': pos.latitude, 'lng': pos.longitude});
      }
    } catch (_) {}
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<List<String>> _uploadPhotos({required String folder}) async {
    final urls = <String>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    for (final entry in _photos) {
      if (entry.uploadedUrl != null) {
        urls.add(entry.uploadedUrl!);
        continue;
      }
      setState(() => entry.uploading = true);
      try {
        final ext = entry.mimeType.split('/').last;
        final safeName = '${timestamp}_photo_${urls.length}.$ext';
        final path = 'foReports/$folder/${FirebaseAuth.instance.currentUser!.uid}/$safeName';
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
        'status': _reportStatus,
      };

      Map<String, dynamic> payload;
      String path;
      String photoFolder;
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
        photoFolder = 'visitReports';
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
        photoFolder = 'trainingReports';
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

      if (_visitLocation != null) {
        payload['visitLocation'] = _visitLocation;
      }

      try {
        final photoUrls = await _uploadPhotos(folder: photoFolder);

        // Upload client report for training reports
        String? clientReportUrl;
        if (_tab == _Tab.training && _clientReportPhotos.isNotEmpty) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          for (final entry in _clientReportPhotos) {
            try {
              final ext = entry.mimeType.split('/').last;
              final safeName = '${timestamp}_client_report.$ext';
              final path = 'foReports/trainingReportFiles/${FirebaseAuth.instance.currentUser!.uid}/$safeName';
              final dataUrl = await ref
                  .read(mobileRepositoryProvider)
                  .encodeFileToDataUrl(entry.bytes.toList(), entry.mimeType);
              final result = await ref
                  .read(mobileRepositoryProvider)
                  .uploadReportPhoto(path: path, dataUrl: dataUrl);
              clientReportUrl = result['url'] as String?;
            } catch (_) {}
          }
        }

        final finalPayload = {
          ...payload,
          'photoUrls': photoUrls,
          if (clientReportUrl != null) 'clientReportUrl': clientReportUrl,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  children: [
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: tokens.border, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'NEW BRIEFING',
                            style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1),
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<_Tab>(
                      segments: const <ButtonSegment<_Tab>>[
                        ButtonSegment<_Tab>(value: _Tab.visit, label: Text('Visit'), icon: Icon(Icons.fact_check_outlined, size: 16)),
                        ButtonSegment<_Tab>(value: _Tab.training, label: Text('Training'), icon: Icon(Icons.school_outlined, size: 16)),
                      ],
                      selected: <_Tab>{_tab},
                      onSelectionChanged: (Set<_Tab> next) => setState(() => _tab = next.first),
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  children: [
                    if (widget.workOrders.isNotEmpty) ...[
                      DropdownButtonFormField<WorkOrderModel>(
                        value: _selectedWorkOrder,
                        decoration: const InputDecoration(
                          labelText: 'Link to Work Order',
                          prefixIcon: Icon(Icons.assignment_turned_in_outlined),
                        ),
                        items: widget.workOrders.map((w) => DropdownMenuItem(
                          value: w,
                          child: Text('${w.siteName} · ${w.examName}', overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedWorkOrder = v),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_tab == _Tab.visit) _buildVisitForm() else _buildTrainingForm(),
                    const SizedBox(height: 24),
                    _buildPhotoSection(tokens),
                    const SizedBox(height: 16),
                    _buildStatusToggle(),
                  ],
                ),
              ),

              // Action Bar
              Container(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(color: tokens.surface, border: Border(top: BorderSide(color: tokens.border))),
                child: Row(
                  children: [
                    if (_error != null)
                      Expanded(child: Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: tokens.danger), maxLines: 2))
                    else
                      const Spacer(),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(140, 48),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_reportStatus == 'draft' ? 'SAVE DRAFT' : 'SUBMIT REPORT'),
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

  Widget _buildVisitForm() {
    return Column(
      children: [
        TextField(
          controller: _visitDateCtrl,
          readOnly: true,
          onTap: () => _pickDate(isVisit: true),
          decoration: const InputDecoration(labelText: 'Visit Date', prefixIcon: Icon(Icons.calendar_today_outlined)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: TextField(controller: _visitPresentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Guards Present'))),
            const SizedBox(width: 16),
            Expanded(child: TextField(controller: _visitAbsentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Guards Absent'))),
          ],
        ),
        const SizedBox(height: 16),
        TextField(controller: _visitSummaryCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Visit Summary', alignLabelWithHint: true)),
        const SizedBox(height: 16),
        TextField(controller: _visitIssuesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Issues Found')),
      ],
    );
  }

  Widget _buildTrainingForm() {
    return Column(
      children: [
        TextField(
          controller: _trainingDateCtrl,
          readOnly: true,
          onTap: () => _pickDate(isVisit: false),
          decoration: const InputDecoration(labelText: 'Training Date', prefixIcon: Icon(Icons.calendar_today_outlined)),
        ),
        const SizedBox(height: 16),
        TextField(controller: _trainingTopicCtrl, decoration: const InputDecoration(labelText: 'Training Topic')),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: TextField(controller: _trainingDurationCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (Min)'))),
            const SizedBox(width: 16),
            Expanded(child: TextField(controller: _trainingAttendeeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Attendee Count'))),
          ],
        ),
        const SizedBox(height: 16),
        TextField(controller: _trainingDescCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes/Outcomes')),
      ],
    );
  }

  Widget _buildPhotoSection(CissThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ATTACHMENTS (${_photos.length})', style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.w800, color: tokens.inkMuted, letterSpacing: 1)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12, runSpacing: 12,
          children: [
            ..._photos.asMap().entries.map((entry) => _PhotoPreview(index: entry.key, photo: entry.value, onRemove: _removePhoto)),
            _AddPhotoButton(onGallery: _pickPhotos, onCamera: _takePhoto),
          ],
        ),
        if (_tab == _Tab.training) ...[
          const SizedBox(height: 24),
          Text('CLIENT REPORT', style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.w800, color: tokens.inkMuted, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text('Upload client-signed training report or certificate (PDF/JPG)', style: TextStyle(fontSize: 11, color: tokens.inkMuted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: [
              ..._clientReportPhotos.asMap().entries.map((entry) => _PhotoPreview(index: entry.key, photo: entry.value, onRemove: (i) => setState(() => _clientReportPhotos.removeAt(i)))),
              if (_clientReportPhotos.isEmpty)
                _AddReportButton(onTap: _pickClientReport),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatusToggle() {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'submitted', label: Text('Submit'), icon: Icon(Icons.send_rounded, size: 16)),
              ButtonSegment(value: 'draft', label: Text('Save Draft'), icon: Icon(Icons.save_outlined, size: 16)),
            ],
            selected: {_reportStatus},
            onSelectionChanged: (v) => setState(() => _reportStatus = v.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.index, required this.photo, required this.onRemove});
  final int index;
  final _PhotoEntry photo;
  final Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(photo.bytes, width: 80, height: 80, fit: BoxFit.cover)),
        Positioned(
          top: 4, right: 4,
          child: GestureDetector(
            onTap: () => onRemove(index),
            child: Container(
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
            ),
          ),
        ),
        if (photo.uploading) const Positioned.fill(child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
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
    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(color: tokens.surfaceStrong, borderRadius: BorderRadius.circular(8), border: Border.all(color: tokens.border)),
        child: Icon(Icons.add_a_photo_outlined, color: tokens.inkMuted),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.camera_alt_rounded), title: const Text('Take Photo'), onTap: () { Navigator.pop(context); onCamera(); }),
            ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('Gallery'), onTap: () { Navigator.pop(context); onGallery(); }),
          ],
        ),
      ),
    );
  }
}

class _AddReportButton extends StatelessWidget {
  const _AddReportButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(color: tokens.surfaceStrong, borderRadius: BorderRadius.circular(8), border: Border.all(color: tokens.accent)),
        child: Icon(Icons.description_outlined, color: tokens.accent),
      ),
    );
  }
}
