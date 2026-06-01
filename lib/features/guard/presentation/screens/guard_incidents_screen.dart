import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/incident_models.dart';
import '../../../../../core/models/guard_profile.dart';
import '../../../../../core/models/attendance_models.dart';
import '../../../../../core/network/ciss_error.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/sync/providers.dart';
import '../../../../../core/offline/draft_service.dart';
import '../../../../../shared/widgets/section_card.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../widgets/guard_portal_widgets.dart';
import 'guard_attendance_screen.dart';
import 'guard_profile_screen.dart';

final FutureProvider<List<IncidentModel>> guardIncidentsProvider =
    FutureProvider<List<IncidentModel>>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchGuardIncidents();
    });

class GuardIncidentsScreen extends ConsumerStatefulWidget {
  const GuardIncidentsScreen({super.key});

  @override
  ConsumerState<GuardIncidentsScreen> createState() =>
      _GuardIncidentsScreenState();
}

class _GuardIncidentsScreenState extends ConsumerState<GuardIncidentsScreen> {
  String _category = 'Safety';
  String _severity = 'medium';
  SiteOptionModel? _selectedSite;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  XFile? _photo;
  final ImagePicker _picker = ImagePicker();
  
  String? _message;
  bool _loading = false;

  static const String _draftKey = 'guard_incident_draft';

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_saveDraft);
    _locationController.addListener(_saveDraft);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreDraft());
  }

  void _saveDraft() {
    final draftService = ref.read(draftServiceProvider);
    draftService.saveDraft(_draftKey, {
      'description': _descriptionController.text,
      'location': _locationController.text,
    });
  }

  void _restoreDraft() {
    final draftService = ref.read(draftServiceProvider);
    final data = draftService.getDraft(_draftKey);
    if (data != null) {
      setState(() {
        _descriptionController.text = data['description'] ?? '';
        _locationController.text = data['location'] ?? '';
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_saveDraft);
    _locationController.removeListener(_saveDraft);
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (picked != null) {
        setState(() => _photo = picked);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _submitIncident(GuardProfileModel profile) async {
    if (_selectedSite == null) {
      setState(() => _message = 'Please select a site.');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      String? photoDataUrl;
      if (_photo != null) {
        final bytes = await _photo!.readAsBytes();
        photoDataUrl = await ref
            .read(mobileRepositoryProvider)
            .encodeFileToDataUrl(bytes, _photo!.mimeType ?? 'image/jpeg');
      }

      final payload = <String, dynamic>{
        'category': _category,
        'severity': _severity,
        'siteId': _selectedSite!.id,
        'siteName': _selectedSite!.siteName,
        'district': profile.district,
        'description': _descriptionController.text.trim(),
        'locationText': _locationController.text.trim(),
        'reportedAt': DateTime.now().toUtc().toIso8601String(),
      };

      try {
        List<String> photoUrls = [];
        if (photoDataUrl != null) {
          final uploadPath = 'incidents/${profile.id}/ ${DateTime.now().millisecondsSinceEpoch}.jpg';
          final uploadResult = await ref
              .read(mobileRepositoryProvider)
              .uploadAttendancePhoto(path: uploadPath, dataUrl: photoDataUrl);
          photoUrls.add(uploadResult['url']);
        }

        await ref.read(mobileRepositoryProvider).createGuardIncident({
          ...payload,
          'photoUrls': photoUrls,
        });

        await ref.read(draftServiceProvider).clearDraft(_draftKey);

        ref.invalidate(guardIncidentsProvider);
        if (mounted) {
          setState(() {
            _photo = null;
            _descriptionController.clear();
            _locationController.clear();
            _message = 'Incident submitted successfully.';
          });
        }
      } catch (uploadOrSubmitError) {
        if (uploadOrSubmitError is DioException &&
            (uploadOrSubmitError.type == DioExceptionType.connectionTimeout ||
                uploadOrSubmitError.type == DioExceptionType.sendTimeout ||
                uploadOrSubmitError.type == DioExceptionType.receiveTimeout ||
                uploadOrSubmitError.type == DioExceptionType.connectionError)) {
          
          await ref.read(offlineQueueProvider).enqueue(
            path: '/api/guard/incidents',
            method: 'POST',
            body: {
              ...payload,
              if (photoDataUrl != null) 'photoDataUrls': [photoDataUrl],
            },
          );

          await ref.read(draftServiceProvider).clearDraft(_draftKey);
          
          if (mounted) {
            setState(() {
              _photo = null;
              _descriptionController.clear();
              _locationController.clear();
              _message = 'Offline: Incident queued for sync.';
            });
          }
        } else {
          rethrow;
        }
      }
    } catch (error) {
      setState(() {
        _message = CissError.parse(error);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(guardProfileProvider);
    final incidentsAsync = ref.watch(guardIncidentsProvider);
    final sitesAsync = ref.watch(attendanceSitesProvider);

    return profileAsync.when(
      loading: () =>
          const GuardLoadingScaffold(label: 'Loading guard profile...'),
      error: (Object error, StackTrace stackTrace) => GuardErrorScaffold(
        title: 'Could not load profile',
        error: error,
        onRetry: () => ref.invalidate(guardProfileProvider),
      ),
      data: (profile) {
        return incidentsAsync.when(
          loading: () =>
              const GuardLoadingScaffold(label: 'Loading incidents...'),
          error: (Object error, StackTrace stackTrace) => GuardErrorScaffold(
            title: 'Could not load incidents',
            error: error,
            onRetry: () => ref.invalidate(guardIncidentsProvider),
          ),
          data: (incidents) {
            final tokens = CissThemeTokens.of(context);
            return ScreenScaffold(
              title: 'Incidents',
              subtitle: 'Report and track incidents',
              onRefresh: () async => ref.invalidate(guardIncidentsProvider),
          actions: <Widget>[
                IconButton(
                  onPressed: () => ref.invalidate(guardIncidentsProvider),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
              children: <Widget>[
                SectionCard(
                  title: 'Report Incident',
                  subtitle:
                      'Capture category, severity, site, notes, and media.',
                  icon: Icons.warning_amber_rounded,
                ),
                GuardFormCard(
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      items: ['Safety', 'Security', 'Maintenance', 'Medical', 'Other']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v ?? 'Other'),
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _severity,
                      items: ['low', 'medium', 'high', 'critical']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                          .toList(),
                      onChanged: (v) => setState(() => _severity = v ?? 'medium'),
                      decoration: const InputDecoration(labelText: 'Severity'),
                    ),
                    const SizedBox(height: 12),
                    sitesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (err, stack) => const Text('Error loading sites'),
                      data: (sites) => DropdownButtonFormField<SiteOptionModel>(
                        initialValue: _selectedSite,
                        items: sites
                            .map((s) => DropdownMenuItem(value: s, child: Text(s.siteName)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedSite = v),
                        decoration: const InputDecoration(labelText: 'Site'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location / Landmark',
                        hintText: 'e.g. Near Gate 2',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'What happened?',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Photo selection
                    InkWell(
                      onTap: _takePhoto,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: tokens.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: tokens.border),
                        ),
                        child: _photo != null
                            ? Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      child: Image.file(File(_photo!.path), fit: BoxFit.cover),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.black54,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                        onPressed: () => setState(() => _photo = null),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_rounded, color: tokens.primary, size: 32),
                                  const SizedBox(height: 8),
                                  Text('Add incident photo', style: TextStyle(color: tokens.primary, fontWeight: FontWeight.w600)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_message != null)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color:
                              _message!.toLowerCase().contains('submitted') ||
                                  _message!.toLowerCase().contains('queued')
                              ? tokens.successSoft
                              : tokens.dangerSoft,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color:
                                _message!.toLowerCase().contains('submitted') ||
                                    _message!.toLowerCase().contains('queued')
                                ? tokens.success
                                : tokens.danger,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () => _submitIncident(profile),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Submit Incident'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SectionCard(
                  title: 'Incident History',
                  subtitle: incidents.isEmpty
                      ? 'No incidents recorded yet.'
                      : '${incidents.length} incident${incidents.length == 1 ? '' : 's'} found',
                  icon: Icons.assignment_rounded,
                ),
                if (incidents.isEmpty)
                  const StateBlock(
                    icon: Icons.assignment_rounded,
                    title: 'No incident history',
                    message:
                        'Submitted incidents and office review status will appear here.',
                  ),
                ...incidents.map(
                  (incident) => GuardRecordCard(
                    title: '${incident.category} • ${incident.severity}',
                    subtitle:
                        '${incident.siteName} • ${incident.status}\n${incident.reportedAtLabel}\n${incident.summary}',
                    icon: Icons.report_problem_rounded,
                    chip: StatusChip(
                      label: incident.status,
                      tone: incident.status.toLowerCase() == 'closed'
                          ? StatusChipTone.success
                          : StatusChipTone.warning,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
