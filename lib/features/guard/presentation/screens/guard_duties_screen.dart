import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/duty_models.dart';
import '../../../../../core/offline/willingness_queue.dart';
import '../../../../../core/utils/date_format.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../application/duty_willingness_controller.dart';
import 'guard_profile_screen.dart';
import '../widgets/duty_detail_sheet.dart';

/// Server-owned feed. All duty and response state remains informational;
/// the existing attendance tab and its authorization are independent.
class GuardDutiesScreen extends ConsumerStatefulWidget {
  const GuardDutiesScreen({super.key, this.initialDutyId});
  final String? initialDutyId;
  @override
  ConsumerState<GuardDutiesScreen> createState() => _GuardDutiesScreenState();
}

class _GuardDutiesScreenState extends ConsumerState<GuardDutiesScreen> {
  bool _opened = false;
  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    final duties = ref.watch(guardDutiesProvider);
    final responseHistory = ref.watch(dutyResponseHistoryProvider);
    final target =
        duties.valueOrNull
            ?.where(
              (d) =>
                  d.id == widget.initialDutyId ||
                  d.workOrderId == widget.initialDutyId,
            )
            .firstOrNull;
    if (!_opened && widget.initialDutyId != null && target != null) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder:
                (_) => DutyDetailSheet(
                  duty: target,
                  onAccessRevoked: () => router?.go('/'),
                ),
          );
        }
      });
    }
    final profile = ref.watch(guardProfileProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming duties')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(guardDutiesProvider);
          try {
            await ref.read(guardDutiesProvider.future);
          } catch (_) {}
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (profile?.categoryLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  profile!.categoryLabel!,
                  style: AppTypography.cardTitle(context),
                ),
              ),
            if (profile?.isTcs == true && profile?.tcsCategory == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Your category must be set by an administrator before you can respond to exam duties.',
                ),
              ),
            if (widget.initialDutyId != null &&
                duties.hasValue &&
                target == null)
              const StateBlock(
                icon: Icons.event_busy,
                title: 'Duty no longer available',
                message: 'Refresh to check your current duties.',
              ),
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Attendance is available independently of assignments and responses.',
              ),
            ),
            ...responseHistory
                .where(
                  (operation) =>
                      duties.hasError ||
                      duties.valueOrNull?.any(
                            (duty) => duty.workOrderId == operation.workOrderId,
                          ) !=
                          true,
                )
                .map(
                  (operation) => _DutyResponseResultCard(operation: operation),
                ),
            duties.when(
              loading:
                  () => const StateBlock(
                    icon: Icons.event_note_outlined,
                    title: 'Loading duty details',
                    message:
                        'Your assignments and eligible exam duties will appear here.',
                  ),
              error:
                  (_, __) => StateBlock(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load duties',
                    message:
                        'Attendance is still available. Try again to load your duties.',
                    action: FilledButton.tonal(
                      onPressed: () => ref.invalidate(guardDutiesProvider),
                      child: const Text('Try again'),
                    ),
                  ),
              data: (rows) {
                if (rows.isEmpty) {
                  return const StateBlock(
                    icon: Icons.event_available_outlined,
                    title: 'No upcoming assignment',
                    message:
                        'No eligible exam duties are available. You can mark attendance without an assigned duty.',
                  );
                }
                final sorted = List<GuardDuty>.of(rows)..sort(
                  (a, b) =>
                      a.id == widget.initialDutyId ||
                              a.workOrderId == widget.initialDutyId
                          ? -1
                          : b.id == widget.initialDutyId ||
                              b.workOrderId == widget.initialDutyId
                          ? 1
                          : a.date.compareTo(b.date),
                );
                return Column(
                  children:
                      sorted.map((duty) {
                        final response = ref.watch(
                          dutyResponseProvider(duty.workOrderId ?? duty.id),
                        );
                        final label =
                            duty.status == 'cancelled'
                                ? 'Cancelled'
                                : duty.isExam
                                ? (duty.canRespond
                                    ? 'Exam duty'
                                    : 'Responses closed')
                                : (duty.relieving
                                    ? 'Relieving assignment'
                                    : 'Assigned');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ModernCard(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                duty.isExam
                                    ? Icons.event_available_outlined
                                    : Icons.assignment_outlined,
                              ),
                              title: Text(duty.siteName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(formatDutyDate(duty.date)),
                                  Text(label),
                                  if (duty.shiftLabel?.trim().isNotEmpty ==
                                      true)
                                    Text(duty.shiftLabel!),
                                  if (duty.examName != null)
                                    Text(duty.examName!),
                                  if (response?.state == 'pending')
                                    Text(
                                      'Pending — ${response?.reason ?? 'not yet saved'}',
                                    ),
                                  if (response?.state == 'rejected') ...[
                                    const Text('Response not sent:'),
                                    if (response?.reason?.isNotEmpty == true)
                                      Text(response!.reason!),
                                  ],
                                ],
                              ),
                              onTap:
                                  () => showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder:
                                        (_) => DutyDetailSheet(
                                          duty: duty,
                                          onAccessRevoked:
                                              () => router?.go('/'),
                                        ),
                                  ),
                            ),
                          ),
                        );
                      }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DutyResponseResultCard extends ConsumerWidget {
  const _DutyResponseResultCard({required this.operation});
  final WillingnessOperation operation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = operation.state == 'pending';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ModernCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    pending ? Icons.sync_rounded : Icons.error_outline_rounded,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pending ? 'Response pending' : 'Response not sent',
                          style: AppTypography.cardTitle(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          operation.reason ??
                              (pending
                                  ? 'Your response has not been saved yet.'
                                  : 'Refresh duties to review the server response.'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (pending)
                    FilledButton.tonal(
                      onPressed: () async {
                        await ref
                            .read(dutyWillingnessControllerProvider)
                            .sync();
                      },
                      child: const Text('Sync pending response'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(guardDutiesProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh duties'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
