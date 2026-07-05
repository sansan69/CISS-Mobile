import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/info_line.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';
import 'client_training_report_detail_screen.dart';

class ClientTrainingReportsScreen extends ConsumerStatefulWidget {
  const ClientTrainingReportsScreen({super.key});

  @override
  ConsumerState<ClientTrainingReportsScreen> createState() =>
      _ClientTrainingReportsScreenState();
}

class _ClientTrainingReportsScreenState
    extends ConsumerState<ClientTrainingReportsScreen> {
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
      final reports = data['recentTrainingReports'] as List<dynamic>? ??
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
        title: const Text('Training Reports'),
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
                        icon: Icons.school_rounded,
                        title: 'No training reports',
                        message:
                            'Training session reports will appear here.',
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final r = _reports[index];
                          final topic =
                              r['topic']?.toString() ?? 'Training';
                          final siteName =
                              r['siteName']?.toString() ?? '';
                          final officer =
                              r['fieldOfficerName']?.toString() ?? '-';
                          final attendeeCount =
                              (r['attendeeCount'] as num?)?.toInt() ?? 0;
                          final status =
                              r['status']?.toString() ?? 'submitted';
                          final district =
                              r['district']?.toString() ?? '';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ModernCard(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ClientTrainingReportDetailScreen(
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
                                          topic,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: tokens.ink,
                                          ),
                                        ),
                                      ),
                                      StatusChip(
                                        label: status,
                                        tone: StatusChipTone.info,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (siteName.isNotEmpty)
                                    InfoLine(
                                        Icons.location_on_rounded, siteName),
                                  InfoLine(Icons.person_rounded, officer),
                                  if (district.isNotEmpty)
                                    InfoLine(
                                        Icons.place_rounded, district),
                                  InfoLine(
                                    Icons.groups_rounded,
                                    '$attendeeCount attendee${attendeeCount == 1 ? '' : 's'}',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
