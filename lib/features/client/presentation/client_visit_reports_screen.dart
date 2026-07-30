import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';
import 'client_visit_report_detail_screen.dart';

final FutureProvider<List<Map<String, dynamic>>> clientVisitReportsProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) {
  return ref.read(mobileRepositoryProvider).fetchClientVisitReports();
});

class ClientVisitReportsScreen extends ConsumerWidget {
  const ClientVisitReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final reportsAsync = ref.watch(clientVisitReportsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(clientVisitReportsProvider),
          child: reportsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load visit reports',
                message: error.toString().replaceFirst('Exception: ', ''),
                action: FilledButton.tonal(
                  onPressed: () => ref.invalidate(clientVisitReportsProvider),
                  child: const Text('Try again'),
                ),
              ),
            ),
            data: (reports) => CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: ModernHero(
                    eyebrow: 'Reports',
                    title: 'Visit Reports',
                    subtitle: '${reports.length} reports',
                  ),
                ),
                if (reports.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: StateBlock(
                      icon: Icons.fact_check_outlined,
                      title: 'No visit reports',
                      message: 'Submitted reports will appear here.',
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
                          child: _VisitReportCard(report: r),
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

class _VisitReportCard extends ConsumerWidget {
  const _VisitReportCard({required this.report});
  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);

    final fieldOfficer =
        (report['fieldOfficerName'] as String?) ?? (report['officerName'] as String?) ?? 'Officer';
    final siteName = report['siteName'] as String? ?? '';
    final summary = report['summary'] as String? ?? report['issueSummary'] as String? ?? '';
    final status = report['status'] as String? ?? 'submitted';
    final dateLabel = report['visitDate'] as String? ?? report['dateLabel'] as String? ?? '';
    final id = report['id'] as String? ?? '';

    return ModernCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: id.isNotEmpty
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClientVisitReportDetailScreen(report: report),
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
                    color: tokens.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person_pin_rounded,
                      color: tokens.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        fieldOfficer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tokens.ink,
                        ),
                      ),
                      Text(
                        dateLabel.isNotEmpty ? dateLabel : 'No date',
                        style: TextStyle(fontSize: 11, color: tokens.inkMuted),
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  label: status.toUpperCase(),
                  tone: status == 'reviewed'
                      ? StatusChipTone.success
                      : status == 'submitted'
                          ? StatusChipTone.warning
                          : StatusChipTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row(tokens, Icons.place_rounded, siteName),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: tokens.ink, height: 1.4),
                ),
              ),
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
