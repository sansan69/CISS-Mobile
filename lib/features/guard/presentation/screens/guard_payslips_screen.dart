import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/models/payroll_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/region/region_service.dart';
import '../../../../../app/theme/app_tokens.dart';
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
    final tokens = CissThemeTokens.of(context);
    final payslipsAsync = ref.watch(guardPayslipsProvider);
    return payslipsAsync.when(
      loading: () => const GuardLoadingScaffold(label: 'Loading payslips...'),
      error:
          (Object error, StackTrace stackTrace) => GuardErrorScaffold(
            title: 'Could not load payslips',
            error: error,
            onRetry: () => ref.invalidate(guardPayslipsProvider),
          ),
      data: (payslips) {
        return ScreenScaffold(
          title: 'Payslips',
          subtitle: 'Monthly payroll slips',
          onRefresh: () async => ref.invalidate(guardPayslipsProvider),
          actions: <Widget>[
            IconButton(
              onPressed: () => ref.invalidate(guardPayslipsProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          children: <Widget>[
            GuardHeroPanel(
              eyebrow: 'Payroll',
              title:
                  '${payslips.length} payslip${payslips.length == 1 ? '' : 's'}',
              subtitle:
                  payslips.isEmpty
                      ? 'Published monthly payslips will appear here.'
                      : 'Tap any period to download the PDF.',
              icon: Icons.account_balance_wallet_rounded,
              accentColor: tokens.warning,
            ),
            const SizedBox(height: AppSpacing.lg),
            GuardMetricStrip(
              items: <GuardMetricItem>[
                GuardMetricItem(
                  label: 'Records',
                  value: '${payslips.length}',
                  icon: Icons.receipt_long_rounded,
                  color: tokens.primary,
                ),
                GuardMetricItem(
                  label: 'Format',
                  value: 'PDF',
                  icon: Icons.picture_as_pdf_rounded,
                  color: tokens.danger,
                ),
                GuardMetricItem(
                  label: 'Action',
                  value: 'Open',
                  icon: Icons.open_in_new_rounded,
                  color: tokens.accent,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (payslips.isEmpty)
              const StateBlock(
                icon: Icons.receipt_long_rounded,
                title: 'No payslips published',
                message:
                    'Monthly payslips will appear here after payroll is processed.',
              ),
            ...payslips.map(
              (payslip) => GuardRecordCard(
                title: payslip.periodLabel,
                subtitle: payslip.netPayLabel,
                icon: Icons.payments_rounded,
                chip: const StatusChip(label: 'PDF', tone: StatusChipTone.info),
                onTap: () async {
                  final launchUri = Uri.parse(
                    '${RegionService.instance.activeApiUrl.replaceAll(RegExp(r'/$'), '')}/api/guard/payslips/${payslip.id}/payslip',
                  );
                  if (await canLaunchUrl(launchUri)) {
                    await launchUrl(
                      launchUri,
                      mode: LaunchMode.externalApplication,
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not open payslip. Please install a PDF viewer.',
                        ),
                      ),
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
