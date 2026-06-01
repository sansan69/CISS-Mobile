import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/models/leave_models.dart';
import '../../../../../core/sync/providers.dart';
import '../../../../../shared/widgets/section_card.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
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

  static final DateFormat _displayFmt = DateFormat('dd/MM/yyyy');
  static final DateFormat _apiFmt = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitLeave() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    final fromDateStr = _fromDate != null ? _apiFmt.format(_fromDate!) : _fromController.text.trim();
    final toDateStr = _toDate != null ? _apiFmt.format(_toDate!) : _toController.text.trim();

    final payload = <String, dynamic>{
      'type': _type,
      'fromDate': fromDateStr,
      'toDate': toDateStr,
      'reason': _reasonController.text.trim(),
    };
    try {
      await ref.read(mobileRepositoryProvider).createLeaveRequest(payload);
      ref.invalidate(guardLeaveProvider);
      setState(() => _message = 'Leave request submitted.');
    } catch (error) {
      if (error is DioException &&
          (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.sendTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.connectionError)) {
        await ref
            .read(offlineQueueProvider)
            .enqueue(
              path: '/api/guard/leave/requests',
              method: 'POST',
              body: payload,
            );
        setState(() => _message = 'Offline: Leave request queued.');
      } else {
        setState(
          () => _message = error.toString().replaceFirst('Exception: ', ''),
        );
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
      loading: () =>
          const GuardLoadingScaffold(label: 'Loading leave records...'),
      error: (Object error, StackTrace stackTrace) => GuardErrorScaffold(
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
            IconButton(
              onPressed: () => ref.invalidate(guardLeaveProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          children: <Widget>[
            SectionCard(
              title: 'Balance',
              subtitle:
                  'Casual ${casual['balance'] ?? 0} • Sick ${sick['balance'] ?? 0} • Earned ${earned['balance'] ?? 0}',
              icon: Icons.calendar_month_rounded,
            ),
            GuardFormCard(
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: _type,
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
                  onChanged: (value) =>
                      setState(() => _type = value ?? 'casual'),
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
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
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
                const SizedBox(height: 12),
                if (_message != null)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: _message!.toLowerCase().contains('submitted')
                          ? tokens.successSoft
                          : tokens.dangerSoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _message!.toLowerCase().contains('submitted')
                            ? tokens.success
                            : tokens.danger,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _submitLeave,
                  child: _loading
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
            if (requests.isEmpty)
              const StateBlock(
                icon: Icons.event_busy_rounded,
                title: 'No leave requests',
                message:
                    'Submitted leave requests and approval status will appear here.',
              )
            else
              ...requests.map(
                (request) => GuardRecordCard(
                  title: '${request.type.toUpperCase()} • ${request.status}',
                  subtitle:
                      '${request.fromDate} to ${request.toDate} • ${request.days} day(s)\n${request.reason}',
                  icon: Icons.event_available_rounded,
                  chip: StatusChip(
                    label: request.status,
                    tone: request.status.toLowerCase() == 'approved'
                        ? StatusChipTone.success
                        : request.status.toLowerCase() == 'rejected'
                        ? StatusChipTone.danger
                        : StatusChipTone.warning,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
