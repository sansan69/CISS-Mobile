import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/network/ciss_error.dart';
import '../../../../../core/models/leave_models.dart';
import '../../../../../core/sync/providers.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/success_overlay.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';
import '../widgets/guard_portal_widgets.dart';

final FutureProvider<Map<String, dynamic>> guardLeaveProvider =
    FutureProvider<Map<String, dynamic>>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchLeaveOverview();
    });

class GuardLeaveScreen extends ConsumerStatefulWidget {
  const GuardLeaveScreen({super.key});

  @override
  ConsumerState<GuardLeaveScreen> createState() => _GuardLeaveScreenState();
}

class _GuardLeaveScreenState extends ConsumerState<GuardLeaveScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  String _type = 'casual';
  String? _message;
  bool _loading = false;
  XFile? _medicalCertificate;
  final ImagePicker _picker = ImagePicker();

  static final DateFormat _displayFmt = DateFormat('dd/MM/yyyy');
  static final DateFormat _apiFmt = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickMedicalCertificate(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        setState(() => _medicalCertificate = picked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick certificate: $e')),
        );
      }
    }
  }

  Future<void> _submitLeave() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    final fromDateStr =
        _fromDate != null
            ? _apiFmt.format(_fromDate!)
            : _fromController.text.trim();
    final toDateStr =
        _toDate != null ? _apiFmt.format(_toDate!) : _toController.text.trim();

    if (fromDateStr.isEmpty) {
      setState(() {
        _message = 'Please select a start date.';
        _loading = false;
      });
      return;
    }
    if (toDateStr.isEmpty) {
      setState(() {
        _message = 'Please select an end date.';
        _loading = false;
      });
      return;
    }

    String? attachmentUrl;
    if (_type == 'sick' && _medicalCertificate != null) {
      try {
        final bytes = await _medicalCertificate!.readAsBytes();
        final repo = ref.read(mobileRepositoryProvider);
        final dataUrl = await repo.encodeFileToDataUrl(
          bytes,
          _medicalCertificate!.mimeType ?? 'image/jpeg',
        );
        final uploadRes = await repo.uploadReportPhoto(
          path:
              'leaveAttachments/${DateTime.now().millisecondsSinceEpoch}_cert.jpg',
          dataUrl: dataUrl,
        );
        attachmentUrl = uploadRes['url'] as String?;
      } catch (e) {
        debugPrint('Failed to upload medical certificate: $e');
      }
    }

    final payload = <String, dynamic>{
      'type': _type,
      'fromDate': fromDateStr,
      'toDate': toDateStr,
      'startDate': fromDateStr,
      'endDate': toDateStr,
      'reason': _reasonController.text.trim(),
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
    };
    try {
      await ref.read(mobileRepositoryProvider).createLeaveRequest(payload);
      ref.invalidate(guardLeaveProvider);
      _fromController.clear();
      _toController.clear();
      _reasonController.clear();
      setState(() {
        _fromDate = null;
        _toDate = null;
        _medicalCertificate = null;
        _message = null;
      });
      if (mounted) {
        unawaited(
          SuccessOverlay.show(
            context,
            title: 'Leave request sent',
            message: 'Your request is submitted for approval.',
          ),
        );
      }
    } catch (error) {
      if (CissError.isRetryableNetworkError(error)) {
        await ref
            .read(offlineQueueProvider)
            .enqueue(path: '/api/guard/leave', method: 'POST', body: payload);
        setState(
          () =>
              _message =
                  'No internet — your request is saved and will be sent automatically when connected.',
        );
      } else {
        if (mounted) {
          setState(
            () => _message = error.toString().replaceFirst('Exception: ', ''),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _cancelLeave(LeaveRequestModel request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Leave Request?'),
        content: Text(
          'Are you sure you want to cancel your ${request.type} leave request from ${request.fromDate} to ${request.toDate}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: CissThemeTokens.of(context).danger,
            ),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await ref.read(mobileRepositoryProvider).cancelLeaveRequest(request.id);
      ref.invalidate(guardLeaveProvider);
      if (mounted) {
        unawaited(
          SuccessOverlay.show(
            context,
            title: 'Leave request cancelled',
            message: 'Your leave request has been withdrawn.',
          ),
        );
      }
    } catch (error) {
      if (CissError.isRetryableNetworkError(error)) {
        await ref.read(offlineQueueProvider).enqueue(
          path: '/api/guard/leave',
          method: 'PATCH',
          body: <String, dynamic>{'requestId': request.id},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No internet — cancellation queued to sync when online.',
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error.toString().replaceFirst('Exception: ', ''),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(guardLeaveProvider);
    return dataAsync.when(
      loading:
          () => const GuardLoadingScaffold(label: 'Loading leave records...'),
      error:
          (Object error, StackTrace stackTrace) => GuardErrorScaffold(
            title: 'Could not load leave',
            error: error,
            onRetry: () => ref.invalidate(guardLeaveProvider),
          ),
      data: (data) {
        final tokens = CissThemeTokens.of(context);
        final requests =
            (data['requests'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .map(LeaveRequestModel.fromJson)
                .toList();
        final balance =
            data['balance'] as Map<String, dynamic>? ??
            const <String, dynamic>{};
        Map<String, dynamic> balanceFor(String key) {
          final value = balance[key];
          if (value is Map<String, dynamic>) return value;
          return const <String, dynamic>{};
        }

        final casual = balanceFor('casual');
        final sick = balanceFor('sick');
        final earned = balanceFor('earned');
        return ScreenScaffold(
          title: 'Leave',
          subtitle: 'Apply and track leave requests',
          onRefresh: () async => ref.invalidate(guardLeaveProvider),
          actions: <Widget>[
            SyncStatusBadge(
              onTap: () => ref.read(syncServiceProvider).processQueue(),
            ),
            IconButton(
              onPressed: () => ref.invalidate(guardLeaveProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          children: <Widget>[
            GuardHeroPanel(
              eyebrow: 'Leave',
              title: 'Request time off',
              subtitle: 'Apply for casual, sick, or earned leave',
              icon: Icons.event_available_rounded,
              accentColor: tokens.success,
            ),
            const SizedBox(height: AppSpacing.lg),
            GuardMetricStrip(
              items: <GuardMetricItem>[
                GuardMetricItem(
                  label: 'Casual',
                  value: '${casual['balance'] ?? 0}',
                  icon: Icons.beach_access_rounded,
                  color: tokens.primary,
                ),
                GuardMetricItem(
                  label: 'Sick',
                  value: '${sick['balance'] ?? 0}',
                  icon: Icons.local_hospital_rounded,
                  color: tokens.warning,
                ),
                GuardMetricItem(
                  label: 'Earned',
                  value: '${earned['balance'] ?? 0}',
                  icon: Icons.calendar_month_rounded,
                  color: tokens.success,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionLabel(title: 'New request'),
            const SizedBox(height: AppSpacing.sm),
            GuardFormCard(
              children: <Widget>[
                DropdownButtonFormField<String>(
                  value: _type,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'casual',
                      child: Text('Casual'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'sick',
                      child: Text('Sick'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'earned',
                      child: Text('Earned'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'unpaid',
                      child: Text('Unpaid'),
                    ),
                  ],
                  onChanged:
                      (value) => setState(() => _type = value ?? 'casual'),
                  decoration: const InputDecoration(labelText: 'Leave Type'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fromController,
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _fromDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 30),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        _fromDate = picked;
                        _fromController.text = _displayFmt.format(picked);
                      });
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'From Date',
                    hintText: 'Select date',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _toController,
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _toDate ?? _fromDate ?? DateTime.now(),
                      firstDate: _fromDate ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        _toDate = picked;
                        _toController.text = _displayFmt.format(picked);
                      });
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'To Date',
                    hintText: 'Select date',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
                if (_type == 'sick') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: tokens.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: tokens.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.medical_services_outlined,
                              size: 18,
                              color: tokens.warning,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Medical Certificate (Optional)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: tokens.ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_medicalCertificate == null)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed:
                                      () => _pickMedicalCertificate(
                                        ImageSource.camera,
                                      ),
                                  icon: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Camera'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed:
                                      () => _pickMedicalCertificate(
                                        ImageSource.gallery,
                                      ),
                                  icon: const Icon(
                                    Icons.photo_library_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Gallery'),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Icon(
                                Icons.description_rounded,
                                size: 20,
                                color: tokens.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _medicalCertificate!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: tokens.ink,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed:
                                    () => setState(
                                      () => _medicalCertificate = null,
                                    ),
                                tooltip: 'Remove certificate',
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (_message != null)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color:
                          _message!.toLowerCase().contains('submitted')
                              ? tokens.successSoft
                              : tokens.dangerSoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color:
                            _message!.toLowerCase().contains('submitted')
                                ? tokens.success
                                : tokens.danger,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loading ? null : _submitLeave,
                  child:
                      _loading
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                          : const Text('Submit Leave'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const _SectionLabel(title: 'Request history'),
            const SizedBox(height: AppSpacing.sm),
            if (requests.isEmpty)
              const StateBlock(
                icon: Icons.event_busy_rounded,
                title: 'No leave requests',
                message:
                    'Submitted leave requests and approval status will appear here.',
              )
            else
              ...requests.map(
                (request) {
                  final isPending = request.status.toLowerCase() == 'pending';
                  return GuardRecordCard(
                    title: '${request.type.toUpperCase()} • ${request.status}',
                    subtitle:
                        '${request.fromDate} to ${request.toDate} • ${request.days} day(s)\n${request.reason}${request.attachmentUrl != null && request.attachmentUrl!.isNotEmpty ? '\n📎 Certificate attached' : ''}',
                    icon: Icons.event_available_rounded,
                    chip: StatusChip(
                      label: request.status,
                      tone:
                          request.status.toLowerCase() == 'approved'
                              ? StatusChipTone.success
                              : request.status.toLowerCase() == 'rejected'
                              ? StatusChipTone.danger
                              : StatusChipTone.warning,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (request.attachmentUrl != null &&
                            request.attachmentUrl!.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.attachment_rounded, size: 20),
                            color: tokens.primary,
                            tooltip: 'View Certificate',
                            onPressed:
                                () => launchUrl(
                                  Uri.parse(request.attachmentUrl!),
                                  mode: LaunchMode.externalApplication,
                                ),
                          ),
                        if (isPending)
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined, size: 20),
                            color: tokens.danger,
                            tooltip: 'Cancel Request',
                            onPressed:
                                _loading ? null : () => _cancelLeave(request),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: tokens.ink,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
