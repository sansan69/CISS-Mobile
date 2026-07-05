import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import 'apk_downloader.dart';
import 'app_update_service.dart';

class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

enum _UpdatePhase { idle, downloading, verifying, installing, done }

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  bool _checked = false;
  bool _dialogOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    if (!mounted || _dialogOpen) return;
    final result =
        await ref.read(appUpdateServiceProvider).checkForAndroidUpdate();
    if (!mounted || result == null || !result.hasUpdate || result.update == null) {
      return;
    }

    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: !result.isMandatory,
      builder: (ctx) => _UpdateDialog(
        result: result,
        onLater: () {
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
        onBrowserFallback: (update) => _browserFallback(update),
      ),
    );
    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _browserFallback(AndroidUpdateInfo update) async {
    final uri = Uri.tryParse(update.apkUrl);
    if (uri == null || !mounted) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the APK download link.')),
      );
    }
  }
}

/// The initial update-available dialog.
class _UpdateDialog extends ConsumerStatefulWidget {
  const _UpdateDialog({
    required this.result,
    required this.onLater,
    required this.onBrowserFallback,
  });

  final AppUpdateCheckResult result;
  final VoidCallback onLater;
  final void Function(AndroidUpdateInfo) onBrowserFallback;

  @override
  ConsumerState<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<_UpdateDialog> {
  _UpdatePhase _phase = _UpdatePhase.idle;
  int _received = 0;
  int _total = 0;
  String? _errorMessage;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel('Update dialog closed.');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.result.update!;
    final sizeMb = update.sizeBytes > 0
        ? (update.sizeBytes / (1024 * 1024)).toStringAsFixed(1)
        : null;

    return PopScope(
      canPop: !widget.result.isMandatory && _phase == _UpdatePhase.idle,
      child: AlertDialog(
        icon: _phaseIcon(),
        title: Text(_phaseTitle()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _phaseDescription(update, sizeMb),
            if (_phase == _UpdatePhase.downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _total > 0 ? _received / _total : null,
              ),
              const SizedBox(height: 6),
              Text(
                '${_received ~/ 1024} KB / ${_total ~/ 1024} KB',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
            if (_phase == _UpdatePhase.verifying)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Verifying download integrity...'),
                  ],
                ),
              ),
            if (_phase == _UpdatePhase.installing)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Installing update...'),
                  ],
                ),
              ),
            if (_phase == _UpdatePhase.done)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Update downloaded. The system Package Installer will now '
                  'open to complete the installation.',
                ),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        actions: _actions(context, update),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, AndroidUpdateInfo update) {
    switch (_phase) {
      case _UpdatePhase.idle:
        return [
          if (!widget.result.isMandatory)
            TextButton(
              onPressed: widget.onLater,
              child: const Text('Later'),
            ),
          FilledButton.icon(
            icon: const Icon(Icons.download_rounded),
            onPressed: _startDownload,
            label: const Text('Download & Install'),
          ),
        ];
      case _UpdatePhase.downloading:
        return [
          TextButton(
            onPressed: () => _cancelDownload(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.download_rounded),
            onPressed: null, // Disabled while downloading
            label: const Text('Downloading...'),
          ),
        ];
      case _UpdatePhase.verifying:
      case _UpdatePhase.installing:
        return [const SizedBox()]; // No actions during verify/install
      case _UpdatePhase.done:
        return [
          if (!widget.result.isMandatory)
            TextButton(
              onPressed: widget.onLater,
              child: const Text('Later'),
            ),
        ];
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _phase = _UpdatePhase.downloading;
      _errorMessage = null;
    });

    final update = widget.result.update!;
    final service = ref.read(appUpdateServiceProvider);
    final downloader = ApkDownloader();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    late final String localPath;
    try {
      localPath = await downloader.downloadWithProgress(
        apkUrl: update.apkUrl,
        expectedSha256: update.sha256,
        expectedSizeBytes: update.sizeBytes,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() { _received = received; _total = total; });
        },
      );
    } on ApkHashMismatchError {
      if (!mounted) return;
      setState(() {
        _phase = _UpdatePhase.idle;
        _errorMessage = 'Download integrity check failed. This may indicate '
            'a corrupted download. Please try again or use the browser download.';
      });
      return;
    } on ApkDiskFullError catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _UpdatePhase.idle;
        _errorMessage = e.message;
      });
      return;
    } on ApkNetworkError catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _UpdatePhase.idle;
        _errorMessage = cancelToken.isCancelled
            ? 'Download cancelled.'
            : 'Network error: ${e.message}. Check your connection and try again.';
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _UpdatePhase.idle;
        _errorMessage = 'Download failed: $e';
      });
      return;
    } finally {
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
    }

    // SHA256 passed — now install
    if (!mounted) return;

    setState(() => _phase = _UpdatePhase.verifying);
    await Future.delayed(const Duration(milliseconds: 300)); // Brief UX pause
    if (!mounted) return;

    setState(() => _phase = _UpdatePhase.installing);

    // Check install permission
    final canInstall = await service.canInstallApk();
    if (!mounted) return;

    if (!canInstall) {
      // Guide user to the Install unknown apps settings
      final shouldOpen = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Permission required'),
          content: const Text(
            'To install this update, CISS Workforce needs permission to '
            'install apps from unknown sources. Open system settings to '
            'grant this?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );

      if (shouldOpen == true) {
        await service.openInstallSettings();
        // After returning from settings, try again
        final retryCanInstall = await service.canInstallApk();
        if (!retryCanInstall) {
          if (!mounted) return;
          widget.onBrowserFallback(update);
          Navigator.of(context).pop();
          return;
        }
      } else {
        // User declined — fall back to browser
        widget.onBrowserFallback(update);
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }
    }

    // Proceed with install
    final result = await service.installUpdate(localPath);
    if (!mounted) return;

    switch (result) {
      case InstallSuccess():
        setState(() => _phase = _UpdatePhase.done);
      case InstallNeedsPermission():
        // Should not reach here after the canInstall check above, but handle it
        widget.onBrowserFallback(update);
        Navigator.of(context).pop();
      case InstallFailed(message: final msg):
        setState(() {
          _phase = _UpdatePhase.idle;
          _errorMessage = 'Installation failed: $msg';
        });
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel('User cancelled update download.');
    setState(() {
      _phase = _UpdatePhase.idle;
      _errorMessage = null;
    });
  }

  Icon _phaseIcon() {
    switch (_phase) {
      case _UpdatePhase.idle:
        return const Icon(Icons.system_update_alt_rounded, size: 32);
      case _UpdatePhase.downloading:
        return const Icon(Icons.download_rounded, size: 32);
      case _UpdatePhase.verifying:
        return const Icon(Icons.verified_rounded, size: 32);
      case _UpdatePhase.installing:
        return const Icon(Icons.system_update_rounded, size: 32);
      case _UpdatePhase.done:
        return Icon(Icons.check_circle_rounded,
            size: 32, color: Colors.green);
    }
  }

  String _phaseTitle() {
    switch (_phase) {
      case _UpdatePhase.idle:
        if (widget.result.isMandatory) return 'Update required';
        return 'Update available';
      case _UpdatePhase.downloading:
        return 'Downloading update...';
      case _UpdatePhase.verifying:
        return 'Verifying download...';
      case _UpdatePhase.installing:
        return 'Installing update...';
      case _UpdatePhase.done:
        return 'Update ready';
    }
  }

  Widget _phaseDescription(AndroidUpdateInfo update, String? sizeMb) {
    if (_phase == _UpdatePhase.idle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'CISS Workforce ${update.latestVersionName} is available. '
            'You are using ${widget.result.currentVersionName}.',
          ),
          if (sizeMb != null) ...[
            const SizedBox(height: 8),
            Text('Download size: $sizeMb MB'),
          ],
          if (update.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'What changed',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...update.releaseNotes
                .take(4)
                .map((note) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(note)),
                        ],
                      ),
                    )),
          ],
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
