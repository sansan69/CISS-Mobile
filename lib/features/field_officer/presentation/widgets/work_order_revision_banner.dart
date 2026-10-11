import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/models/report_models.dart';
import '../../../../core/network/providers.dart';

final FutureProvider<List<WorkOrderRevisionEventModel>>
fieldOfficerWorkOrderRevisionsProvider =
    FutureProvider<List<WorkOrderRevisionEventModel>>((ref) {
      return ref.read(mobileRepositoryProvider).fetchWorkOrderRevisions();
    });

class WorkOrderRevisionBanner extends ConsumerWidget {
  const WorkOrderRevisionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revisions = ref.watch(fieldOfficerWorkOrderRevisionsProvider);
    return revisions.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (events) {
        final pending = events.where((event) => !event.acknowledged).toList();
        if (pending.isEmpty) return const SizedBox.shrink();
        final tokens = CissThemeTokens.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Card(
            color: tokens.warningSoft,
            child: ExpansionTile(
              leading: Icon(
                Icons.notification_important_rounded,
                color: tokens.warning,
              ),
              title: Text(
                '${pending.length} duty revision${pending.length == 1 ? '' : 's'} need attention',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: tokens.ink,
                ),
              ),
              subtitle: Text(
                'Review changed staffing before dispatching guards.',
                style: TextStyle(color: tokens.inkMuted),
              ),
              children:
                  pending.take(12).map((event) {
                    final date = DateTime.tryParse(event.date);
                    final dateLabel =
                        date == null
                            ? event.date
                            : DateFormat('dd MMM yyyy').format(date);
                    return ListTile(
                      title: Text(
                        event.siteName.isEmpty ? 'Duty site' : event.siteName,
                      ),
                      subtitle: Text(
                        '$dateLabel · ${event.district}\nMale ${event.previousMaleGuardsRequired} → ${event.maleGuardsRequired} · Female ${event.previousFemaleGuardsRequired} → ${event.femaleGuardsRequired}',
                      ),
                      isThreeLine: true,
                      trailing: TextButton(
                        onPressed: () async {
                          await ref
                              .read(mobileRepositoryProvider)
                              .acknowledgeWorkOrderRevision(event.id);
                          ref.invalidate(
                            fieldOfficerWorkOrderRevisionsProvider,
                          );
                        },
                        child: const Text('Reviewed'),
                      ),
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );
  }
}
