import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/payslip_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/modern_card.dart';
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

  Future<void> _handlePdfAction({
    required BuildContext context,
    required WidgetRef ref,
    required PayslipSummaryModel payslip,
    bool forceShare = false,
  }) async {
    try {
      final bytes = await ref
          .read(mobileRepositoryProvider)
          .downloadPayslipPdf(payslip.id);
      if (bytes.isEmpty) {
        throw Exception('Empty payslip response');
      }
      final dir = await getTemporaryDirectory();
      final sanitizedPeriod = payslip.periodLabel.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );
      final file = File('${dir.path}/payslip-$sanitizedPeriod.pdf');
      await file.writeAsBytes(bytes, flush: true);

      if (forceShare) {
        await Share.shareXFiles(
          [
            XFile(
              file.path,
              mimeType: 'application/pdf',
              name: 'payslip-$sanitizedPeriod.pdf',
            ),
          ],
          text: 'CISS Payslip - ${payslip.periodLabel}',
        );
        return;
      }

      final launchUri = Uri.file(file.path);
      bool launched = false;
      try {
        launched = await launchUrl(
          launchUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }

      if (!launched) {
        // Graceful fallback to share sheet if no PDF viewer handles the intent
        await Share.shareXFiles(
          [
            XFile(
              file.path,
              mimeType: 'application/pdf',
              name: 'payslip-$sanitizedPeriod.pdf',
            ),
          ],
          text: 'CISS Payslip - ${payslip.periodLabel}',
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open payslip: $error')),
      );
    }
  }

  void _showDetailSheet(
    BuildContext context,
    WidgetRef ref,
    PayslipSummaryModel payslip,
  ) {
    final tokens = CissThemeTokens.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (sheetCtx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.borderStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payslip.periodLabel,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: tokens.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Monthly Salary Statement',
                            style: TextStyle(
                              fontSize: 13,
                              color: tokens.inkMuted,
                            ),
                          ),
                        ],
                      ),
                      StatusChip(
                        label: 'Verified',
                        tone: StatusChipTone.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ModernCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Net Payable',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: tokens.inkMuted,
                          ),
                        ),
                        Text(
                          payslip.netPayLabel,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: tokens.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetCtx).pop();
                            _handlePdfAction(
                              context: context,
                              ref: ref,
                              payslip: payslip,
                              forceShare: true,
                            );
                          },
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Share PDF'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(sheetCtx).pop();
                            _handlePdfAction(
                              context: context,
                              ref: ref,
                              payslip: payslip,
                              forceShare: false,
                            );
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Open PDF'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

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
              eyebrow: 'Payslips',
              title:
                  '${payslips.length} payslip${payslips.length == 1 ? '' : 's'}',
              subtitle:
                  payslips.isEmpty
                      ? 'Published monthly payslips will appear here.'
                      : 'Tap any period to view details or download PDF.',
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
                onTap: () => _showDetailSheet(context, ref, payslip),
              ),
            ),
          ],
        );
      },
    );
  }
}
