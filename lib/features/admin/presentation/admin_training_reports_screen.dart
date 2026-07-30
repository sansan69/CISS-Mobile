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


final FutureProvider<List<TrainingReportModel>> adminTrainingReportsProvider =
    FutureProvider<List<TrainingReportModel>>((Ref ref) {
  return ref.read(mobileRepositoryProvider).fetchAdminTrainingReports();
});

class AdminTrainingReportsScreen extends ConsumerWidget {
  const AdminTrainingReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final reportsAsync = ref.watch(adminTrainingReportsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(adminTrainingReportsProvider),
          child: reportsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load training reports',
                message: error.toString().replaceFirst('Exception: ', ''),
                action: FilledButton.tonal(
                  onPressed: () => ref.invalidate(adminTrainingReportsProvider),
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
                    subtitle: 'Delivered trainings & acknowledgements',
                  ),
                ),
                if (reports.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: StateBlock(
                      icon: Icons.school_outlined,
                      title: 'No training reports',
                      message: 'Submitted training reports will appear here.',
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
                          child: _TrainingReportCard(report: report),
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

class _TrainingReportCard extends StatelessWidget {
  const _TrainingReportCard({required this.report});
  final TrainingReportModel report;

  @override
  Widget build(BuildContext context) {
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
                      report.topic.isNotEmpty ? report.topic : 'Training',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tokens.ink,
                      ),
                    ),
                    Text(
                      report.fieldOfficerName,
                      style: TextStyle(fontSize: 11, color: tokens.inkMuted),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: report.status.toUpperCase(),
                tone: report.status == 'acknowledged'
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
            Icons.people_rounded,
            '${report.attendeeCount} attendees · ${report.durationMinutes} min',
          ),
          if (report.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tokens.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                report.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.ink,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (report.photoUrls.isNotEmpty || report.attachmentUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  ...report.photoUrls.map((url) => _attachmentChip(
                    context, tokens, url, Icons.image_rounded, tokens.primary,
                  )),
                  ...report.attachmentUrls.map((url) => _attachmentChip(
                    context, tokens, url, Icons.attach_file_rounded, tokens.accent,
                  )),
                  if (report.clientReportUrl != null && report.clientReportUrl!.isNotEmpty)
                    _attachmentChip(
                      context, tokens, report.clientReportUrl!, Icons.description_rounded, tokens.success,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _attachmentChip(
    BuildContext ctx, CissThemeTokens tokens, String url, IconData icon, Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                url.split('.').last.length > 4
                    ? url.split('.').last.substring(0, 4).toUpperCase()
                    : url.split('.').last.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(CissThemeTokens tokens, IconData icon, String text) {
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
