import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/haptics.dart';
import '../../../../../core/media/browser_download.dart';
import '../../../../../core/models/payslip_document.dart';
import '../../../../../core/network/ciss_error.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../widgets/guard_portal_widgets.dart';

/// Published salary slips for the signed-in guard.
///
/// Account-scoped: registered in `accountScopedProviders`, so sign-out and an
/// A -> B account change drop the cached list instead of showing the previous
/// guard's documents.
final FutureProvider<List<PayslipDocumentModel>> guardPayslipsProvider =
    FutureProvider<List<PayslipDocumentModel>>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchPayslips();
    });

/// Writes the downloaded PDF into the app's temporary directory.
typedef PayslipFileWriter =
    Future<File> Function(PayslipDocumentModel payslip, Uint8List bytes);

/// Hands a saved PDF to an external viewer. `false` means no app handled it.
typedef PayslipFileOpener = Future<bool> Function(File file);

/// Last-resort delivery through the platform share sheet.
typedef PayslipFileSharer =
    Future<void> Function(File file, PayslipDocumentModel payslip);

/// Platform seams for slip delivery. Overridable in tests so the screen never
/// touches a real plugin, and a stalled plugin channel cannot pin the spinner
/// forever (each step is awaited with a timeout).
final Provider<PayslipFileWriter> payslipFileWriterProvider =
    Provider<PayslipFileWriter>((Ref ref) {
      return (PayslipDocumentModel payslip, Uint8List bytes) async {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/${payslip.safeFileName}');
        await file.writeAsBytes(bytes, flush: true);
        return file;
      };
    });

final Provider<PayslipFileOpener> payslipFileOpenerProvider =
    Provider<PayslipFileOpener>((Ref ref) {
      return (File file) async {
        try {
          return await launchUrl(
            Uri.file(file.path),
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {
          return false;
        }
      };
    });

final Provider<PayslipFileSharer> payslipFileSharerProvider =
    Provider<PayslipFileSharer>((Ref ref) {
      return (File file, PayslipDocumentModel payslip) async {
        await Share.shareXFiles(
          <XFile>[
            XFile(
              file.path,
              mimeType: 'application/pdf',
              name: payslip.safeFileName,
            ),
          ],
          subject: 'Salary slip ${payslip.title}',
        );
      };
    });

class GuardPayslipsScreen extends ConsumerStatefulWidget {
  const GuardPayslipsScreen({super.key});

  @override
  ConsumerState<GuardPayslipsScreen> createState() =>
      _GuardPayslipsScreenState();
}

class _GuardPayslipsScreenState extends ConsumerState<GuardPayslipsScreen> {
  /// Id of the slip currently downloading, so only that row shows progress.
  String? _busyId;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final payslipsAsync = ref.watch(guardPayslipsProvider);

    return payslipsAsync.when(
      loading:
          () => const GuardLoadingScaffold(label: 'Loading salary slips...'),
      error:
          (Object error, StackTrace stackTrace) => GuardErrorScaffold(
            title: 'Could not load salary slips',
            error: error,
            onRetry: () => ref.invalidate(guardPayslipsProvider),
          ),
      data: (List<PayslipDocumentModel> payslips) {
        return ScreenScaffold(
          title: 'Salary Slips',
          subtitle: 'PDF payslips published by your employer',
          onRefresh: () async => ref.invalidate(guardPayslipsProvider),
          actions: <Widget>[
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(guardPayslipsProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          children: <Widget>[
            GuardHeroPanel(
              eyebrow: 'Salary',
              title: '${payslips.length} slip${payslips.length == 1 ? '' : 's'}',
              subtitle:
                  payslips.isEmpty
                      ? 'Your payslips will appear here once payroll publishes them.'
                      : 'Tap a slip to download and open the PDF.',
              icon: Icons.receipt_long_rounded,
              accentColor: tokens.primary,
            ),
            if (payslips.isEmpty)
              const StateBlock(
                icon: Icons.receipt_long_rounded,
                title: 'No salary slips yet',
                message:
                    'Payslips uploaded by the office will show up here. '
                    'Pull down to refresh.',
              )
            else
              ...payslips.map(
                (payslip) => _PayslipRow(
                  payslip: payslip,
                  busy: _busyId == payslip.id,
                  onTap: () => _openPayslip(payslip),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Download -> temp file -> open. Falls back to the share sheet when no PDF
  /// viewer handles the file, which is the normal path on some devices.
  Future<void> _openPayslip(PayslipDocumentModel payslip) async {
    if (_busyId != null) return;
    setState(() => _busyId = payslip.id);
    unawaited(Haptics.selection());
    try {
      final bytes = await ref
          .read(mobileRepositoryProvider)
          .downloadPayslipPdf(payslip.id)
          .timeout(const Duration(seconds: 60));
      if (bytes.isEmpty) {
        throw Exception('The salary slip PDF was empty.');
      }
      if (kIsWeb) {
        // Browsers have no temp directory: hand the bytes to the download
        // manager instead of writing a file the viewer could open.
        downloadBytes(
          bytes,
          fileName: payslip.safeFileName,
          mimeType: 'application/pdf',
        );
        unawaited(Haptics.success());
        return;
      }
      final file = await ref
          .read(payslipFileWriterProvider)(payslip, bytes)
          .timeout(const Duration(seconds: 15));
      final opened = await ref.read(payslipFileOpenerProvider)(file);
      if (!opened) {
        await ref.read(payslipFileSharerProvider)(file, payslip);
      }
      unawaited(Haptics.success());
    } catch (error) {
      if (!mounted) return;
      // CissError.parse maps 401/403/404 and transport failures to plain text
      // and never echoes bytes, URLs or stack frames.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(CissError.parse(error))));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }
}

class _PayslipRow extends StatelessWidget {
  const _PayslipRow({
    required this.payslip,
    required this.onTap,
    this.busy = false,
  });

  final PayslipDocumentModel payslip;
  final VoidCallback onTap;

  /// True while this slip is downloading. The row shows progress and ignores
  /// taps until the download settles.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final createdAt = payslip.createdAt;
    final size = payslip.sizeLabel;
    final uploaded =
        createdAt == null
            ? null
            : 'Uploaded ${DateFormat('d MMM yyyy').format(createdAt)}';
    final subtitle =
        <String>[
          if (size.isNotEmpty) size,
          if (uploaded != null) uploaded,
        ].join(' • ');

    return GuardRecordCard(
      title: payslip.title,
      subtitle: subtitle.isEmpty ? 'PDF salary slip' : subtitle,
      icon: Icons.picture_as_pdf_rounded,
      chip:
          busy
              ? null
              : const StatusChip(label: 'PDF', tone: StatusChipTone.info),
      trailing:
          busy
              ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : null,
      onTap: busy ? null : onTap,
    );
  }
}
