import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/haptics.dart';
import '../../../../../core/models/duty_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/state_block.dart';

final FutureProvider<List<GuardDuty>> guardDutiesProvider =
    FutureProvider<List<GuardDuty>>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchGuardDuties();
    });

/// Upcoming duties for the guard: FO-assigned shifts (future reference) and
/// open adhoc exam duties the guard may express willingness for.
///
/// Assignment is informational — this screen never gates attendance.
class GuardDutiesScreen extends ConsumerWidget {
  const GuardDutiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duties = ref.watch(guardDutiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming duties')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(guardDutiesProvider),
        child: duties.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (Object error, _) => ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  StateBlock(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load duties',
                    message: error.toString().replaceFirst('Exception: ', ''),
                    action: FilledButton.tonal(
                      onPressed: () => ref.invalidate(guardDutiesProvider),
                      child: const Text('Try again'),
                    ),
                  ),
                ],
              ),
          data: (List<GuardDuty> list) {
            if (list.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const <Widget>[
                  SizedBox(height: AppSpacing.xxl),
                  StateBlock(
                    icon: Icons.event_available_outlined,
                    title: 'No upcoming duties',
                    message:
                        'Assigned shifts and open exam duties will appear here. You can mark attendance with or without a duty.',
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: list.length,
              separatorBuilder:
                  (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (BuildContext context, int index) {
                final duty = list[index];
                return duty.isExam
                    ? _ExamDutyCard(duty: duty)
                    : _AssignedDutyCard(duty: duty);
              },
            );
          },
        ),
      ),
    );
  }
}

class _AssignedDutyCard extends StatelessWidget {
  const _AssignedDutyCard({required this.duty});

  final GuardDuty duty;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final detail = <String>[
      duty.date,
      if (duty.shiftLabel != null) duty.shiftLabel!,
      if (duty.siteName.isNotEmpty) duty.siteName,
    ].join(' • ');

    return ModernCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.assignment_turned_in_outlined,
              color: tokens.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  duty.clientName.isEmpty ? 'Duty' : duty.clientName,
                  style: AppTypography.cardTitle(context),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.micro(
                    context,
                  ).copyWith(color: tokens.inkMuted),
                ),
              ],
            ),
          ),
          if (duty.relieving) _RelievingBadge(tokens: tokens),
        ],
      ),
    );
  }
}

class _ExamDutyCard extends ConsumerStatefulWidget {
  const _ExamDutyCard({required this.duty});

  final GuardDuty duty;

  @override
  ConsumerState<_ExamDutyCard> createState() => _ExamDutyCardState();
}

class _ExamDutyCardState extends ConsumerState<_ExamDutyCard> {
  bool _saving = false;

  Future<void> _respond(WillingnessStatus status) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(mobileRepositoryProvider)
          .respondDutyWillingness(widget.duty.id, status);
      if (!mounted) return;
      Haptics.confirm();
      ref.invalidate(guardDutiesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == WillingnessStatus.willing
                ? 'Willingness sent to your field officer'
                : 'Marked unavailable',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      Haptics.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not send response: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final duty = widget.duty;
    final responded = duty.willingness;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.school_outlined,
                  color: tokens.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      duty.examName?.isNotEmpty == true
                          ? duty.examName!
                          : 'Exam duty',
                      style: AppTypography.cardTitle(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        duty.date,
                        if (duty.siteName.isNotEmpty) duty.siteName,
                      ].join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.micro(
                        context,
                      ).copyWith(color: tokens.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonal(
                  onPressed:
                      _saving ? null : () => _respond(WillingnessStatus.willing),
                  child: Text(
                    responded == WillingnessStatus.willing
                        ? 'Available ✓'
                        : "I'm available",
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _saving
                          ? null
                          : () => _respond(WillingnessStatus.unavailable),
                  child: Text(
                    responded == WillingnessStatus.unavailable
                        ? "Can't ✓"
                        : "Can't",
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RelievingBadge extends StatelessWidget {
  const _RelievingBadge({required this.tokens});

  final CissThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'Relieving',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: tokens.warning,
        ),
      ),
    );
  }
}
