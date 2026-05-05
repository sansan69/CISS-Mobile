import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/models/payroll_models.dart';
import '../../../../../core/network/api_config.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/section_card.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../widgets/guard_portal_widgets.dart';

final FutureProvider<List<PayslipSummaryModel>> guardPayslipsProvider =
    FutureProvider<List<PayslipSummaryModel>>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchPayslips();
    });

class GuardPayslipsScreen extends ConsumerWidget {
  const GuardPayslipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payslipsAsync = ref.watch(guardPayslipsProvider);
    return payslipsAsync.when(
      loading: () => const GuardLoadingScaffold(label: 'Loading payslips...'),
      error: (Object error, StackTrace stackTrace) => GuardErrorScaffold(
        title: 'Could not load payslips',
        error: error,
        onRetry: () => ref.invalidate(guardPayslipsProvider),
      ),
      data: (payslips) {
        return ScreenScaffold(
          title: 'Payslips',
          subtitle: 'Monthly payroll slips',
          actions: <Widget>[
            IconButton(
              onPressed: () => ref.invalidate(guardPayslipsProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          children: <Widget>[
            SectionCard(
              title: 'Available Payslips',
              subtitle:
                  '${payslips.length} record${payslips.length == 1 ? '' : 's'} found',
              icon: Icons.receipt_long_rounded,
            ),
            if (payslips.isEmpty)
              const StateBlock(
                icon: Icons.receipt_long_outlined,
                title: 'No payslips published',
                message:
                    'Monthly payslips will appear here after payroll is processed.',
              ),
            ...payslips.map(
              (payslip) => GuardRecordCard(
                title: payslip.periodLabel,
                subtitle: payslip.netPayLabel,
                icon: Icons.payments_outlined,
                chip: const StatusChip(label: 'PDF', tone: StatusChipTone.info),
                onTap: () async {
                  final launchUri = Uri.parse(
                    '${ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '')}/api/guard/payslips/${payslip.id}/payslip',
                  );
                  if (await canLaunchUrl(launchUri)) {
                    await launchUrl(
                      launchUri,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
