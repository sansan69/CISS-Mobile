import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/report_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/network/ciss_error.dart';
import '../../../../../core/sync/providers.dart';
import '../../../../../core/offline/draft_service.dart';
import '../../../../../core/offline/local_report_store.dart';
import '../../../../../shared/widgets/brand_banner.dart';
import '../../../../../shared/widgets/glass_card.dart';
import '../../../../../shared/widgets/portal_primitives.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';
import '../../../../../shared/utils/report_media_utils.dart';
import '../../../auth/application/auth_controller.dart';
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

final FutureProvider<List<FieldOfficerSiteOption>> fieldOfficerSitesProvider =
    FutureProvider<List<FieldOfficerSiteOption>>((Ref ref) {
      final session = ref.read(authSessionProvider).value;
      final district = session?.assignedDistricts.isNotEmpty == true
          ? session!.assignedDistricts.first
          : null;
      return ref
          .read(mobileRepositoryProvider)
          .fetchFieldOfficerSites(district: district);
    });

enum _Tab { visit, training }

class _PhotoEntry {
  _PhotoEntry({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
    required this.capturedAt,
  });
  final Uint8List bytes;
  final String mimeType;
  final String fileName;
  final DateTime capturedAt;
  String? uploadedUrl;
  bool uploading = false;
}

class _AttachmentEntry {
  _AttachmentEntry({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });
  final Uint8List bytes;
  final String mimeType;
  final String fileName;
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
    ref.invalidate(fieldOfficerSitesProvider);
    ref.invalidate(fieldOfficerVisitReportsProvider);
    ref.invalidate(fieldOfficerTrainingReportsProvider);
  }

  void _openSheet(
    BuildContext context,
    List<WorkOrderModel> workOrders,
    List<FieldOfficerSiteOption> sites,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewReportSheet(
        initialTab: _tab,
        workOrders: workOrders,
        sites: sites,
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
    final sitesAsync = ref.watch(fieldOfficerSitesProvider);
    final visitAsync = ref.watch(fieldOfficerVisitReportsProvider);
    final trainingAsync = ref.watch(fieldOfficerTrainingReportsProvider);
    final tokens = CissThemeTokens.of(context);

    if (sitesAsync.isLoading ||
        visitAsync.isLoading ||
        trainingAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final err = sitesAsync.error ?? visitAsync.error ?? trainingAsync.error;
    if (err != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: StateBlock(
              icon: Icons.assignment_late_outlined,
              title: 'Could not load reports',
              message: CissError.parse(err),
              action: FilledButton.tonal(
                onPressed: _refresh,
                child: const Text('Try again'),
              ),
            ),
          ),
        ),
      );
    }

    final workOrders = workOrdersAsync.value ?? const <WorkOrderModel>[];
    final sites = sitesAsync.value ?? const <FieldOfficerSiteOption>[];
    final visitReports = visitAsync.value ?? const <VisitReportModel>[];
    final trainingReports =
        trainingAsync.value ?? const <TrainingReportModel>[];

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
                      ('submitted', 'Submitted'),
                      ('acknowledged', 'Acknowledged'),
                    ],
                    selected: _trainingFilter,
                    onChanged: (v) => setState(() => _trainingFilter = v),
                  ),
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
                  children: filteredVisit
                      .map((r) => _VisitBriefingCard(r))
                      .toList(),
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
                  children: filteredTraining
                      .map((r) => _TrainingBriefingCard(r))
                      .toList(),
                ),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (sites.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'No sites available. Check your district assignment or try refreshing.',
                ),
                action: SnackBarAction(label: 'Refresh', onPressed: _refresh),
              ),
            );
            return;
          }
          _openSheet(context, workOrders, sites);
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'NEW BRIEFING',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
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
                style: GoogleFonts.roboto(
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
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
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: tokens.ink,
                        ),
                      ),
                      Text(
                        report.clientName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tokens.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isSynced)
                  const StatusChip(
                    label: 'SYNCING',
                    tone: StatusChipTone.warning,
                  )
                else
                  Icon(Icons.verified_rounded, size: 18, color: tokens.success),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: tokens.inkMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  report.dateLabel,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.inkMuted,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.groups_2_outlined, size: 12, color: tokens.inkMuted),
                const SizedBox(width: 4),
                Text(
                  '${report.guardsPresentCount} IN / ${report.guardsAbsentCount} OUT',
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.primary,
                  ),
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
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: tokens.ink,
                        ),
                      ),
                      Text(
                        report.siteName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tokens.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isSynced)
                  const StatusChip(label: 'QUEUED', tone: StatusChipTone.info)
                else
                  Icon(Icons.verified_rounded, size: 18, color: tokens.success),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 12, color: tokens.inkMuted),
                const SizedBox(width: 4),
                Text(
                  '${report.durationMinutes} MINS',
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.accent,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.people_alt_outlined,
                  size: 12,
                  color: tokens.inkMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${report.attendeeCount} ATTENDED',
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.inkMuted,
                  ),
                ),
              ],
            ),
            if (report.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              _PhotoThumbnailStrip(photoUrls: report.photoUrls),
            ],
            if (report.attachmentUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              _AttachmentUrlStrip(urls: report.attachmentUrls),
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
        separatorBuilder: (_, index) => const SizedBox(width: 8),
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
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(child: InteractiveViewer(child: Image.network(url))),
        ),
      ),
    );
  }
}

class _AttachmentUrlStrip extends StatelessWidget {
  const _AttachmentUrlStrip({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...urls.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final url = entry.value;
          return ActionChip(
            avatar: Icon(
              Icons.attachment_rounded,
              size: 16,
              color: tokens.primary,
            ),
            label: Text('Attachment $index'),
            onPressed: () => _openUrl(url),
          );
        }),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _NewReportSheet extends ConsumerStatefulWidget {
  const _NewReportSheet({
    required this.initialTab,
    required this.workOrders,
    required this.sites,
    required this.onSubmitted,
  });

  final _Tab initialTab;
  final List<WorkOrderModel> workOrders;
  final List<FieldOfficerSiteOption> sites;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<_NewReportSheet> createState() => _NewReportSheetState();
}

class _NewReportSheetState extends ConsumerState<_NewReportSheet> {
  late _Tab _tab;
  FieldOfficerSiteOption? _selectedSite;
  bool _siteSelectionPrepared = false;

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

  final List<_PhotoEntry> _visitPhotos = <_PhotoEntry>[];
  final List<_PhotoEntry> _trainingPhotos = <_PhotoEntry>[];
  final List<_AttachmentEntry> _trainingAttachments = <_AttachmentEntry>[];
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  bool _loading = false;
  String? _error;

  static final DateFormat _displayFmt = DateFormat('dd/MM/yyyy');
  static final DateFormat _apiFmt = DateFormat('yyyy-MM-dd');

  String get _draftKey => 'field_officer_report_${_tab.name}';

  List<FieldOfficerSiteOption> get _siteOptions => widget.sites;

  String? _linkedDutyLabelFor(FieldOfficerSiteOption site) {
    for (final workOrder in widget.workOrders) {
      if (workOrder.siteId == site.siteId && workOrder.examName.isNotEmpty) {
        return workOrder.examName;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    final options = _siteOptions;
    _selectedSite = options.isNotEmpty ? options.first : null;

    _visitSummaryCtrl.addListener(_saveDraft);
    _visitIssuesCtrl.addListener(_saveDraft);
    _visitActionsCtrl.addListener(_saveDraft);
    _visitPresentCtrl.addListener(_saveDraft);
    _visitAbsentCtrl.addListener(_saveDraft);

    _trainingTopicCtrl.addListener(_saveDraft);
    _trainingDescCtrl.addListener(_saveDraft);
    _trainingDurationCtrl.addListener(_saveDraft);
    _trainingAttendeeCtrl.addListener(_saveDraft);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreDraft();
      _prepareDefaultSiteSelection();
    });
  }

  Future<void> _prepareDefaultSiteSelection() async {
    if (_siteSelectionPrepared) return;
    _siteSelectionPrepared = true;
    final options = _siteOptions;
    if (options.isEmpty) return;

    FieldOfficerSiteOption selected = options.first;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() => _selectedSite = selected);
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _selectedSite = selected);
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      double bestDistance = double.infinity;
      for (final option in options) {
        final lat = option.latitude;
        final lng = option.longitude;
        if (lat == null || lng == null) continue;
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lat,
          lng,
        );
        if (distance < bestDistance) {
          bestDistance = distance;
          selected = option;
        }
      }
    } catch (_) {
      // If GPS isn't available we keep the earliest district site selected.
    }

    if (mounted) {
      setState(() => _selectedSite = selected);
    }
  }

  Future<void> _openSitePicker() async {
    final FieldOfficerSiteOption? picked =
        await showModalBottomSheet<FieldOfficerSiteOption>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return _SitePickerSheet(
              sites: _siteOptions,
              selected: _selectedSite,
              linkedDutyLabelFor: _linkedDutyLabelFor,
            );
          },
        );

    if (picked != null && mounted) {
      setState(() => _selectedSite = picked);
    }
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
        'date': _visitDate?.toIso8601String(),
        'siteId': _selectedSite?.siteId,
      };
    } else {
      data = {
        'topic': _trainingTopicCtrl.text,
        'description': _trainingDescCtrl.text,
        'duration': _trainingDurationCtrl.text,
        'attendees': _trainingAttendeeCtrl.text,
        'date': _trainingDate?.toIso8601String(),
        'siteId': _selectedSite?.siteId,
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
        final dateStr = data['date'] as String?;
        if (dateStr != null) {
          _visitDate = DateTime.tryParse(dateStr);
          if (_visitDate != null) {
            _visitDateCtrl.text = _displayFmt.format(_visitDate!);
          }
        }
      } else {
        _trainingTopicCtrl.text = data['topic'] ?? '';
        _trainingDescCtrl.text = data['description'] ?? '';
        _trainingDurationCtrl.text = data['duration'] ?? '60';
        _trainingAttendeeCtrl.text = data['attendees'] ?? '0';
        final dateStr = data['date'] as String?;
        if (dateStr != null) {
          _trainingDate = DateTime.tryParse(dateStr);
          if (_trainingDate != null) {
            _trainingDateCtrl.text = _displayFmt.format(_trainingDate!);
          }
        }
      }
      // Restore selected site if available
      final siteId = data['siteId'] as String?;
      if (siteId != null) {
        _selectedSite = _siteOptions.cast<FieldOfficerSiteOption?>().firstWhere(
          (s) => s?.siteId == siteId,
          orElse: () => null,
        );
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
    final initial = isVisit
        ? (_visitDate ?? DateTime.now())
        : (_trainingDate ?? DateTime.now());
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

  Future<void> _addTimestampedPhoto({
    required bool isVisit,
    required ImageSource source,
  }) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null || !mounted) return;

      final rawBytes = await picked.readAsBytes();
      final capturedAt = DateTime.now();
      final stampedBytes = await stampReportPhotoBytes(
        rawBytes,
        timestamp: capturedAt,
        title: isVisit ? 'Visit photo' : 'Training photo',
      );

      final fileName = '${_uuid.v4()}.png';
      final entry = _PhotoEntry(
        bytes: stampedBytes,
        mimeType: 'image/png',
        fileName: fileName,
        capturedAt: capturedAt,
      );

      setState(() {
        (isVisit ? _visitPhotos : _trainingPhotos).add(entry);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not capture photo.');
      }
    }
  }

  Future<void> _pickTimestampedPhotos({required bool isVisit}) async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 85, limit: 10);
      if (picked.isEmpty || !mounted) return;

      final entries = <_PhotoEntry>[];
      for (final xfile in picked) {
        final rawBytes = await xfile.readAsBytes();
        final capturedAt = DateTime.now();
        final stampedBytes = await stampReportPhotoBytes(
          rawBytes,
          timestamp: capturedAt,
          title: isVisit ? 'Visit photo' : 'Training photo',
        );
        entries.add(
          _PhotoEntry(
            bytes: stampedBytes,
            mimeType: 'image/png',
            fileName: '${_uuid.v4()}.png',
            capturedAt: capturedAt,
          ),
        );
      }

      if (entries.isNotEmpty && mounted) {
        setState(() {
          (isVisit ? _visitPhotos : _trainingPhotos).addAll(entries);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not pick photos.');
    }
  }

  Future<void> _pickTrainingAttachments() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const <String>[
          'jpg',
          'jpeg',
          'png',
          'webp',
          'heic',
          'heif',
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt',
        ],
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      final entries = <_AttachmentEntry>[];
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        entries.add(
          _AttachmentEntry(
            bytes: bytes,
            mimeType: mimeTypeFromFileName(
              file.name,
              fallback: file.extension != null
                  ? mimeTypeFromFileName(file.extension!)
                  : null,
            ),
            fileName: file.name,
          ),
        );
      }

      if (entries.isNotEmpty && mounted) {
        setState(() => _trainingAttachments.addAll(entries));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not pick report files.');
      }
    }
  }

  void _removeVisitPhoto(int index) {
    setState(() => _visitPhotos.removeAt(index));
  }

  void _removeTrainingPhoto(int index) {
    setState(() => _trainingPhotos.removeAt(index));
  }

  void _removeTrainingAttachment(int index) {
    setState(() => _trainingAttachments.removeAt(index));
  }

  Future<List<String>> _uploadPhotoEntries(
    List<_PhotoEntry> entries, {
    required String folder,
  }) async {
    final session = ref.read(authSessionProvider).value;
    final officerId = session?.primaryId ?? session?.uid ?? 'unknown';
    final urls = <String>[];
    for (final entry in entries) {
      if (entry.uploadedUrl != null) {
        urls.add(entry.uploadedUrl!);
        continue;
      }
      setState(() => entry.uploading = true);
      try {
        final path =
            'foReports/$officerId/$folder/${_uuid.v4()}_${sanitizeReportFileName(entry.fileName)}';
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

  Future<List<String>> _uploadAttachmentEntries(
    List<_AttachmentEntry> entries,
  ) async {
    final session = ref.read(authSessionProvider).value;
    final officerId = session?.primaryId ?? session?.uid ?? 'unknown';
    final urls = <String>[];
    for (final entry in entries) {
      if (entry.uploadedUrl != null) {
        urls.add(entry.uploadedUrl!);
        continue;
      }
      setState(() => entry.uploading = true);
      try {
        final path =
            'foReports/$officerId/trainingReportFiles/${_uuid.v4()}_${sanitizeReportFileName(entry.fileName)}';
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
    final selected = _selectedSite;
    if (selected == null) {
      setState(() => _error = 'Select a site before submitting.');
      return;
    }

    final date = _tab == _Tab.visit ? _visitDate : _trainingDate;
    if (date == null) {
      setState(() => _error = 'Select a date before submitting.');
      return;
    }

    if (_tab == _Tab.visit && _visitPhotos.isEmpty) {
      setState(
        () => _error = 'Add at least one visit photo before submitting.',
      );
      return;
    }
    if (_tab == _Tab.training && _trainingPhotos.isEmpty) {
      setState(
        () => _error = 'Add at least one training photo before submitting.',
      );
      return;
    }
    if (_tab == _Tab.training && _trainingAttachments.isEmpty) {
      setState(
        () => _error = 'Upload the training report file before submitting.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = ref.read(authSessionProvider).value;
      if (session == null) {
        setState(() {
          _loading = false;
          _error = 'Session expired. Please login again.';
        });
        return;
      }

      Position? position;
      try {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (enabled) {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        debugPrint('Location capture failed for report: $e');
      }

      final photoEntries = _tab == _Tab.visit ? _visitPhotos : _trainingPhotos;
      final attachmentEntries = _tab == _Tab.training
          ? _trainingAttachments
          : const <_AttachmentEntry>[];

      final common = <String, dynamic>{
        'clientId': selected.clientId,
        'clientName': selected.clientName,
        'siteId': selected.siteId,
        'siteName': selected.siteName,
        'district': selected.district,
        'status': 'submitted',
        'officerId': session.primaryId,
        'officerName': session.displayName,
        'officerEmail': session.email,
        if (position != null) ...{
          'locationCoords': {
            'lat': position.latitude,
            'lon': position.longitude,
            'accuracyMeters': position.accuracy,
          },
          'locationText':
              'GPS ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
        },
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
          'guardsPresentCount':
              int.tryParse(_visitPresentCtrl.text.trim()) ?? 0,
          'guardsAbsentCount': int.tryParse(_visitAbsentCtrl.text.trim()) ?? 0,
        };
      } else {
        final topic = _trainingTopicCtrl.text.trim();
        if (topic.isEmpty) {
          setState(() {
            _loading = false;
            _error = 'Please enter the training topic.';
          });
          return;
        }
        path = '/api/field-officer/training-reports';
        payload = {
          ...common,
          'trainingDate': _apiFmt.format(date),
          'durationMinutes':
              int.tryParse(_trainingDurationCtrl.text.trim()) ?? 60,
          'topic': topic,
          'description': _trainingDescCtrl.text.trim(),
          'attendeeIds': <String>[],
          'attendeeCount': int.tryParse(_trainingAttendeeCtrl.text.trim()) ?? 0,
        };
      }

      try {
        final photoUrls = await _uploadPhotoEntries(
          photoEntries,
          folder: _tab == _Tab.visit ? 'visitPhotos' : 'trainingPhotos',
        );
        final attachmentUrls = _tab == _Tab.training
            ? await _uploadAttachmentEntries(attachmentEntries)
            : <String>[];
        final finalPayload = <String, dynamic>{
          ...payload,
          'photoUrls': photoUrls,
          if (_tab == _Tab.training) 'attachmentUrls': attachmentUrls,
        };

        if (_tab == _Tab.visit) {
          await ref
              .read(mobileRepositoryProvider)
              .submitVisitReport(finalPayload);
        } else {
          await ref
              .read(mobileRepositoryProvider)
              .submitTrainingReport(finalPayload);
        }

        // Save local copy on-device so the FO can review past submissions offline.
        final reportSummary = _tab == _Tab.visit
            ? _visitSummaryCtrl.text.trim()
            : _trainingTopicCtrl.text.trim();
        final dateLabel = _apiFmt.format(date);
        unawaited(
          ref
              .read(localReportStoreProvider)
              .saveCopy(
                type: _tab == _Tab.visit ? 'visit' : 'training',
                clientName: selected.clientName,
                siteName: selected.siteName,
                district: selected.district,
                dateLabel: dateLabel,
                summary: reportSummary,
                photoUrls: photoUrls,
                attachmentUrls: attachmentUrls,
                syncedToServer: true,
              ),
        );

        await ref.read(draftServiceProvider).clearDraft(_draftKey);
        widget.onSubmitted();
        if (mounted) Navigator.of(context).pop();
      } catch (uploadOrSubmitError) {
        final isOffline = ref
            .read(mobileRepositoryProvider)
            .shouldQueueOffline(uploadOrSubmitError);
        if (isOffline) {
          final uploadedPhotoUrls = photoEntries
              .where((photo) => photo.uploadedUrl?.isNotEmpty == true)
              .map((photo) => photo.uploadedUrl!)
              .toList();
          final pendingPhotoDataUrls = await Future.wait(
            photoEntries.where((photo) => photo.uploadedUrl == null).map((
              photo,
            ) {
              return ref
                  .read(mobileRepositoryProvider)
                  .encodeFileToDataUrl(photo.bytes.toList(), photo.mimeType);
            }),
          );
          final uploadedAttachmentUrls = attachmentEntries
              .where((attachment) => attachment.uploadedUrl?.isNotEmpty == true)
              .map((attachment) => attachment.uploadedUrl!)
              .toList();
          final pendingAttachmentDataUrls = await Future.wait(
            attachmentEntries
                .where((attachment) => attachment.uploadedUrl == null)
                .map((attachment) {
                  return ref
                      .read(mobileRepositoryProvider)
                      .encodeFileToDataUrl(
                        attachment.bytes.toList(),
                        attachment.mimeType,
                      );
                }),
          );
          final requestId = await ref
              .read(offlineQueueProvider)
              .enqueue(
                path: path,
                method: 'POST',
                body: {
                  ...payload,
                  if (uploadedPhotoUrls.isNotEmpty)
                    'photoUrls': uploadedPhotoUrls,
                  if (pendingPhotoDataUrls.isNotEmpty)
                    'photoDataUrls': pendingPhotoDataUrls,
                  if (_tab == _Tab.training &&
                      uploadedAttachmentUrls.isNotEmpty)
                    'attachmentUrls': uploadedAttachmentUrls,
                  if (_tab == _Tab.training &&
                      pendingAttachmentDataUrls.isNotEmpty)
                    'attachmentDataUrls': pendingAttachmentDataUrls,
                },
              );
          // Save local copy for offline-queued report too.
          final reportSummary = _tab == _Tab.visit
              ? _visitSummaryCtrl.text.trim()
              : _trainingTopicCtrl.text.trim();
          final dateLabel = _apiFmt.format(date);
          unawaited(
            ref
                .read(localReportStoreProvider)
                .saveCopy(
                  type: _tab == _Tab.visit ? 'visit' : 'training',
                  clientName: selected.clientName,
                  siteName: selected.siteName,
                  district: selected.district,
                  dateLabel: dateLabel,
                  summary: reportSummary,
                  photoUrls: uploadedPhotoUrls,
                  attachmentUrls: uploadedAttachmentUrls,
                  syncedToServer: false,
                  id: requestId,
                ),
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
          _error = CissError.parse(error);
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
                          child: Text(
                            'NEW BRIEFING',
                            style: GoogleFonts.roboto(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  children: [
                    if (_siteOptions.isNotEmpty) ...[
                      const PortalFieldLabel('Site'),
                      InkWell(
                        onTap: _openSitePicker,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            hintText: 'Search and select a site',
                            prefixIcon: Icon(Icons.place_outlined),
                            suffixIcon: Icon(Icons.search_rounded),
                          ),
                          child: Text(
                            _selectedSite == null
                                ? 'Search and select a site'
                                : '${_selectedSite!.siteName} · ${_selectedSite!.district}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: _selectedSite == null
                                  ? tokens.inkMuted
                                  : tokens.ink,
                            ),
                          ),
                        ),
                      ),
                      if (_selectedSite != null) ...<Widget>[
                        const SizedBox(height: 12),
                        PortalSurfaceCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _selectedSite!.clientName.isNotEmpty
                                    ? _selectedSite!.clientName
                                    : 'Client pending',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: tokens.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _linkedDutyLabelFor(_selectedSite!) != null
                                    ? 'Linked duty: ${_linkedDutyLabelFor(_selectedSite!)!}'
                                    : 'Selected site in your district',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: tokens.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                    if (_tab == _Tab.visit)
                      _buildVisitForm()
                    else
                      _buildTrainingForm(),
                    const SizedBox(height: 24),
                    _buildPhotoSection(),
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
                    if (_error != null)
                      Expanded(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.danger,
                          ),
                          maxLines: 2,
                        ),
                      )
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
                            : const Text('SUBMIT REPORT'),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PortalFieldLabel('Visit Date'),
        TextField(
          controller: _visitDateCtrl,
          readOnly: true,
          onTap: () => _pickDate(isVisit: true),
          decoration: const InputDecoration(
            hintText: 'Choose visit date',
            prefixIcon: Icon(Icons.calendar_today_outlined),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const PortalFieldLabel('Guards Present'),
                  TextField(
                    controller: _visitPresentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const PortalFieldLabel('Guards Absent'),
                  TextField(
                    controller: _visitAbsentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const PortalFieldLabel('Visit Summary'),
        TextField(
          controller: _visitSummaryCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write the site visit summary',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        const PortalFieldLabel('Issues Found'),
        TextField(
          controller: _visitIssuesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Note any issue, shortage, or escalation',
          ),
        ),
      ],
    );
  }

  Widget _buildTrainingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PortalFieldLabel('Training Date'),
        TextField(
          controller: _trainingDateCtrl,
          readOnly: true,
          onTap: () => _pickDate(isVisit: false),
          decoration: const InputDecoration(
            hintText: 'Choose training date',
            prefixIcon: Icon(Icons.calendar_today_outlined),
          ),
        ),
        const SizedBox(height: 16),
        const PortalFieldLabel('Training Topic'),
        TextField(
          controller: _trainingTopicCtrl,
          decoration: const InputDecoration(
            hintText: 'Enter the training topic',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const PortalFieldLabel('Duration (Min)'),
                  TextField(
                    controller: _trainingDurationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '60'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const PortalFieldLabel('Attendee Count'),
                  TextField(
                    controller: _trainingAttendeeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const PortalFieldLabel('Notes / Outcomes'),
        TextField(
          controller: _trainingDescCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Summarize what was covered and the outcome',
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    final isVisit = _tab == _Tab.visit;
    final photoEntries = isVisit ? _visitPhotos : _trainingPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalSectionHeading(
          title: isVisit
              ? 'Visit Photos (${photoEntries.length})'
              : 'Training Photos (${photoEntries.length})',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ...photoEntries.asMap().entries.map(
              (entry) => _PhotoPreview(
                index: entry.key,
                photo: entry.value,
                onRemove: isVisit ? _removeVisitPhoto : _removeTrainingPhoto,
              ),
            ),
            _AddPhotoButton(
              onGallery: () => _pickTimestampedPhotos(isVisit: isVisit),
              onCamera: () => _addTimestampedPhoto(
                isVisit: isVisit,
                source: ImageSource.camera,
              ),
            ),
          ],
        ),
        if (!isVisit) ...[
          const SizedBox(height: 24),
          PortalSectionHeading(
            title: 'Training Report Uploads (${_trainingAttachments.length})',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ..._trainingAttachments.asMap().entries.map(
                (entry) => _AttachmentPreview(
                  index: entry.key,
                  attachment: entry.value,
                  onRemove: _removeTrainingAttachment,
                ),
              ),
              _UploadOnlyButton(onUpload: _pickTrainingAttachments),
            ],
          ),
        ],
      ],
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.index,
    required this.photo,
    required this.onRemove,
  });
  final int index;
  final _PhotoEntry photo;
  final Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            photo.bytes,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              DateFormat('hh:mm a').format(photo.capturedAt),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => onRemove(index),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (photo.uploading)
          const Positioned.fill(
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.index,
    required this.attachment,
    required this.onRemove,
  });

  final int index;
  final _AttachmentEntry attachment;
  final Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    final isImage = attachment.mimeType.startsWith('image/');

    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          child: isImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(attachment.bytes, fit: BoxFit.cover),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      attachment.mimeType == 'application/pdf'
                          ? Icons.picture_as_pdf_rounded
                          : Icons.insert_drive_file_outlined,
                      color: Colors.black54,
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        attachment.fileName,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => onRemove(index),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (attachment.uploading)
          const Positioned.fill(
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
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
    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: tokens.surfaceStrong,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.border),
        ),
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
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                onCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                onGallery();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadOnlyButton extends StatelessWidget {
  const _UploadOnlyButton({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return InkWell(
      onTap: onUpload,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: tokens.surfaceStrong,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.border),
        ),
        child: Icon(Icons.upload_file_rounded, color: tokens.inkMuted),
      ),
    );
  }
}

class _SitePickerSheet extends StatefulWidget {
  const _SitePickerSheet({
    required this.sites,
    required this.selected,
    required this.linkedDutyLabelFor,
  });

  final List<FieldOfficerSiteOption> sites;
  final FieldOfficerSiteOption? selected;
  final String? Function(FieldOfficerSiteOption site) linkedDutyLabelFor;

  @override
  State<_SitePickerSheet> createState() => _SitePickerSheetState();
}

class _SitePickerSheetState extends State<_SitePickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  List<FieldOfficerSiteOption> get _filteredSites {
    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.sites;
    return widget.sites.where((FieldOfficerSiteOption site) {
      return site.siteName.toLowerCase().contains(query) ||
          site.district.toLowerCase().contains(query) ||
          site.clientName.toLowerCase().contains(query) ||
          (widget.linkedDutyLabelFor(site)?.toLowerCase().contains(query) ??
              false);
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Select Site',
                          style: GoogleFonts.roboto(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (String value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search site, district, client...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _filteredSites.length,
                separatorBuilder: (_, int index) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) {
                  final FieldOfficerSiteOption site = _filteredSites[index];
                  final bool isSelected =
                      widget.selected?.siteId == site.siteId;
                  final String? linkedDuty = widget.linkedDutyLabelFor(site);
                  return Material(
                    color: isSelected
                        ? tokens.primarySoft
                        : tokens.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: () => Navigator.of(context).pop(site),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.place_outlined,
                              color: isSelected
                                  ? tokens.primary
                                  : tokens.inkMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    site.siteName,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${site.district} · ${site.clientName}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: tokens.inkMuted,
                                    ),
                                  ),
                                  if (linkedDuty != null &&
                                      linkedDuty.isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Linked duty: $linkedDuty',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: tokens.primary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_filteredSites.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Text(
                  'No sites match this search.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.inkMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
