import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/info_line.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';
import 'client_visit_report_detail_screen.dart';

class ClientVisitReportsScreen extends ConsumerStatefulWidget {
  const ClientVisitReportsScreen({super.key});

  @override
  ConsumerState<ClientVisitReportsScreen> createState() =>
      _ClientVisitReportsScreenState();
}

class _ClientVisitReportsScreenState
    extends ConsumerState<ClientVisitReportsScreen> {
  List<Map<String, dynamic>> _reports = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(mobileRepositoryProvider)
          .fetchClientDashboard()
          .timeout(const Duration(seconds: 12));
      final reports = data['recentVisitReports'] as List<dynamic>? ??
          const <dynamic>[];
      if (!mounted) return;
      setState(() {
        _reports = reports.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Visit Reports'),
        backgroundColor: tokens.canvas,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: StateBlock(
                    icon: Icons.cloud_off_rounded,
                    title: 'Error',
                    message: _error!,
                    action: FilledButton.tonal(
                      onPressed: _fetch,
                      child: const Text('Retry'),
                    ),
                  ),
                )
              : _reports.isEmpty
                  ? const Center(
                      child: StateBlock(
                        icon: Icons.rate_review_rounded,
                        title: 'No visit reports',
                        message:
                            'Field officer visit reports will appear here.',
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final r = _reports[index];
                          final siteName =
                              r['siteName']?.toString() ?? 'Site';
                          final officer =
                              r['fieldOfficerName']?.toString() ?? '-';
                          final status =
                              r['status']?.toString() ?? 'submitted';
                          final summary =
                              r['summary']?.toString() ?? '';
                          final district =
                              r['district']?.toString() ?? '';
                          final visitDate =
                              r['visitDate']?.toString() ?? '';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ModernCard(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ClientVisitReportDetailScreen(
                                      report: r,
                                    ),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          siteName,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: tokens.ink,
                                          ),
                                        ),
                                      ),
                                      StatusChip(
                                        label: status,
                                        tone: status == 'submitted'
                                            ? StatusChipTone.info
                                            : StatusChipTone.success,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  InfoLine(Icons.person_rounded, officer),
                                  if (district.isNotEmpty)
                                    InfoLine(Icons.place_rounded, district),
                                  if (visitDate.isNotEmpty)
                                    InfoLine(
                                        Icons.calendar_today_rounded,
                                        _formatDate(visitDate)),
                                  if (summary.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      summary,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: tokens.inkMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  String _formatDate(String value) {
    final p = DateTime.tryParse(value);
    if (p == null) return value;
    final local = p.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}
