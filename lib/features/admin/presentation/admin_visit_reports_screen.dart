import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/report_models.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

final FutureProvider<List<VisitReportModel>> adminVisitReportsProvider =
    FutureProvider<List<VisitReportModel>>((Ref ref) {
  return ref.read(mobileRepositoryProvider).fetchAdminVisitReports();
});

class AdminVisitReportsScreen extends ConsumerWidget {
  const AdminVisitReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final reportsAsync = ref.watch(adminVisitReportsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(adminVisitReportsProvider),
          child: reportsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load visit reports',
                message: error.toString().replaceFirst('Exception: ', ''),
                action: FilledButton.tonal(
                  onPressed: () => ref.invalidate(adminVisitReportsProvider),
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
                    subtitle: 'Field officer site visits & observations',
                  ),
                ),
                if (reports.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: StateBlock(
                      icon: Icons.fact_check_outlined,
                      title: 'No visit reports',
                      message: 'Submitted visit reports will appear here.',
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final report = reports[index];
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            16, index == 0 ? 12 : 0, 16,
                            index == reports.length - 1 ? 24 : 8,
                          ),
                          child: _VisitReportCard(report: report),
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
  final VisitReportModel report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);

    return ModernCard(
      padding: const EdgeInsets.all(14),
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
                      report.fieldOfficerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tokens.ink,
                      ),
                    ),
                    Text(
                      report.dateLabel.isNotEmpty
                          ? report.dateLabel
                          : 'No date',
                      style: TextStyle(fontSize: 11, color: tokens.inkMuted),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: report.status.toUpperCase(),
                tone: report.status == 'reviewed'
                    ? StatusChipTone.success
                    : report.status == 'submitted'
                        ? StatusChipTone.warning
                        : StatusChipTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(tokens, Icons.business_rounded, report.clientName),
          const SizedBox(height: 4),
          _infoRow(tokens, Icons.place_rounded, report.siteName),
          const SizedBox(height: 4),
          _infoRow(
            tokens,
            Icons.location_city_rounded,
            '${report.guardsPresentCount} present · ${report.guardsAbsentCount} absent',
            iconColor: tokens.success,
          ),
          if (report.summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tokens.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                report.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.ink,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (report.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: report.photoUrls.map((url) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        if (url.isNotEmpty) {
                          launchUrl(Uri.parse(url),
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: tokens.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.image_rounded,
                            color: tokens.primary, size: 24),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(CissThemeTokens tokens, IconData icon, String text,
      {Color? iconColor}) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: iconColor ?? tokens.inkMuted),
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
