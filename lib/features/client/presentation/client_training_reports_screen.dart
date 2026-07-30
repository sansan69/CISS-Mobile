import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';
import 'client_training_report_detail_screen.dart';

final FutureProvider<List<Map<String, dynamic>>> clientTrainingReportsProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) {
  return ref.read(mobileRepositoryProvider).fetchClientTrainingReports();
});

class ClientTrainingReportsScreen extends ConsumerWidget {
  const ClientTrainingReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final reportsAsync = ref.watch(clientTrainingReportsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(clientTrainingReportsProvider),
          child: reportsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load training reports',
                message: error.toString().replaceFirst('Exception: ', ''),
                action: FilledButton.tonal(
                  onPressed: () =>
                      ref.invalidate(clientTrainingReportsProvider),
                  child: const Text('Try again'),
                ),
              ),
            ),
            data: (reports) => CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: ModernHero(
                    eyebrow: 'Reports',
                    title: 'Training Reports',
                    subtitle: '${reports.length} sessions',
                  ),
                ),
                if (reports.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: StateBlock(
                      icon: Icons.school_outlined,
                      title: 'No training reports',
                      message: 'Submitted training sessions will appear here.',
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final r = reports[index];
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            16, index == 0 ? 12 : 0, 16,
                            index == reports.length - 1 ? 24 : 8,
                          ),
                          child: _TrainingReportCard(report: r),
                        );
                      },
                      childCount: reports.length,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainingReportCard extends ConsumerWidget {
  const _TrainingReportCard({required this.report});
  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);

    final topic = report['topic'] as String? ?? 'Training Session';
    final fieldOfficer =
        (report['fieldOfficerName'] as String?) ?? (report['officerName'] as String?) ?? 'Officer';
    final siteName = report['siteName'] as String? ?? '';
    final status = report['status'] as String? ?? 'submitted';
    final dateLabel =
        report['trainingDate'] as String? ?? report['dateLabel'] as String? ?? '';
    final attendeeCount = (report['attendeeCount'] as num?)?.toInt() ?? 0;
    final duration = (report['durationMinutes'] as num?)?.toInt() ?? 0;
    final id = report['id'] as String? ?? '';

    return ModernCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: id.isNotEmpty
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ClientTrainingReportDetailScreen(report: report),
                  ),
                )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tokens.successSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.school_rounded,
                      color: tokens.success, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        topic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tokens.ink,
                        ),
                      ),
                      Text(
                        fieldOfficer,
                        style: TextStyle(fontSize: 11, color: tokens.inkMuted),
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  label: status.toUpperCase(),
                  tone: status == 'acknowledged'
                      ? StatusChipTone.success
                      : status == 'submitted'
                          ? StatusChipTone.warning
                          : StatusChipTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row(tokens, Icons.place_rounded, siteName),
            const SizedBox(height: 4),
            _row(tokens, Icons.people_rounded, '$attendeeCount attendees · ${duration}min'),
            if (dateLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              _row(tokens, Icons.calendar_today_rounded, dateLabel),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(CissThemeTokens tokens, IconData icon, String text) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: tokens.inkMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text.isNotEmpty ? text : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: tokens.inkMuted),
          ),
        ),
      ],
    );
  }
}
