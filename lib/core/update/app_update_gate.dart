import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../settings/remote_config.dart';
import '../settings/remote_config_provider.dart';
import 'apk_downloader.dart';
import 'app_update_service.dart';
import 'update_url_policy.dart';

/// Whether an available update must be installed before the app is usable.
///
/// Combines the app-update endpoint's own mandatory flag with the server-driven
/// [RemoteConfig] `app.forceUpdate` flag (spec §2: only `forceUpdate` /
/// `maintenance` produce a blocking gate).
bool updateIsMandatory(AppUpdateCheckResult result, RemoteConfig config) =>
    result.isMandatory || config.app.forceUpdate;

/// Server-driven maintenance and forced-update gate.
///
/// F-25: the gate used to run exactly once from `didChangeDependencies`, with
/// a `ref.read` snapshot of the remote config. Two consequences:
///
/// * a `maintenance` flag that arrived after the first frame (or during the
///   session) was ignored, so the kill switch could not contain a bad release;
/// * routine flags read at first frame were usually cached/default values.
///
/// The gate now watches the remote config, re-checks on
/// [AppLifecycleState.resumed], and stays mounted so the blocking UI can be
/// torn down reactively.
///
/// Note: [AppUpdateGate] is installed through `MaterialApp.builder`, which is
/// *above* the application [Navigator]. Route-based `showDialog` calls from
/// this position fail with "Navigator operation requested with a context that
/// does not include a Navigator", so the gate renders its blocking UI as an
/// in-tree overlay instead of pushing dialog routes.
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

enum _UpdatePhase {
  idle,
  downloading,
  verifying,
  installing,
  installPermission,
  done,
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate>
    with WidgetsBindingObserver {
  bool _startupScheduled = false;
  bool _checkInFlight = false;
  AppUpdateCheckResult? _pendingUpdate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _refreshAndRecheck();
  }

  /// Pull a fresh config snapshot, then re-run the update check.
  ///
  /// Runs on resume so a maintenance window or a pulled release reaches
  /// already-open sessions instead of waiting for the next cold start.
  Future<void> _refreshAndRecheck() async {
    try {
      await ref.read(remoteConfigProvider.notifier).refresh(force: true);
    } catch (error) {
      debugPrint('AppUpdateGate: remote config refresh failed: $error');
    }
    if (!mounted) return;
    if (ref.read(remoteConfigProvider).app.maintenance) {
      // The maintenance overlay already blocks the app.
      return;
    }
    await _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    if (!mounted || _checkInFlight) return;
    if (ref.read(remoteConfigProvider).app.maintenance) return;

    _checkInFlight = true;
    try {
      final result =
          await ref.read(appUpdateServiceProvider).checkForAndroidUpdate();
      if (!mounted) return;
      if (result == null || !result.hasUpdate || result.update == null) {
        if (_pendingUpdate != null) {
          setState(() => _pendingUpdate = null);
        }
        return;
      }
      setState(() => _pendingUpdate = result);
    } catch (error) {
      debugPrint('AppUpdateGate: update check failed: $error');
    } finally {
      _checkInFlight = false;
    }
  }

  void _dismissUpdate() {
    if (!mounted || _pendingUpdate == null) return;
    setState(() => _pendingUpdate = null);
  }

  @override
  Widget build(BuildContext context) {
    final maintenance = ref.watch(
      remoteConfigProvider.select((config) => config.app.maintenance),
    );

    // Reactive kill switch: a flag flip tears the update overlay down and a
    // cleared flag re-runs the update check once maintenance is over.
    ref.listen<bool>(
      remoteConfigProvider.select((config) => config.app.maintenance),
      (previous, next) {
        if (!next && (previous ?? false)) {
          _checkForUpdate();
        }
      },
    );
    // A forced update that arrives after the check must still block; the
    // overlay reads forceUpdate itself, so only a fresh check is needed when
    // no update dialog is pending.
    ref.listen<bool>(
      remoteConfigProvider.select((config) => config.app.forceUpdate),
      (previous, next) {
        if (next && _pendingUpdate == null) {
          _checkForUpdate();
        }
      },
    );

    if (!_startupScheduled) {
      _startupScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(remoteConfigProvider).app.maintenance) return;
        _checkForUpdate();
      });
    }

    final pending = _pendingUpdate;
    return Stack(
      children: [
        widget.child,
        if (maintenance) const _MaintenanceOverlay(),
        if (!maintenance && pending != null && pending.update != null)
          _UpdateOverlay(result: pending, onDismiss: _dismissUpdate),
      ],
    );
  }
}

/// Blocking card chrome shared by the maintenance and update overlays.
Widget _blockingOverlay(Widget card) {
  return Material(
    type: MaterialType.transparency,
    // Expand so the scrim covers the whole screen instead of shrink-wrapping
    // the card (the parent Stack hands out loose constraints).
    child: Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen, non-dismissible scrim: absorbs taps aimed at the app
        // beneath the gate.
        const Positioned.fill(
          child: AbsorbPointer(child: ColoredBox(color: Colors.black54)),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: card,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Blocking gate shown while the server reports `app.maintenance` (spec §2).
class _MaintenanceOverlay extends StatelessWidget {
  const _MaintenanceOverlay();

  @override
  Widget build(BuildContext context) {
    return _blockingOverlay(
      const AlertDialog(
        icon: Icon(Icons.build_rounded, size: 32),
        title: Text('Under maintenance'),
        content: Text(
          'CISS Workforce is temporarily unavailable for scheduled '
          'maintenance. Please try again shortly.',
        ),
      ),
    );
  }
}

/// The update-available card (download, verify, install).
class _UpdateOverlay extends ConsumerStatefulWidget {
  const _UpdateOverlay({required this.result, required this.onDismiss});

  final AppUpdateCheckResult result;
  final VoidCallback onDismiss;

  @override
  ConsumerState<_UpdateOverlay> createState() => _UpdateOverlayState();
}

class _UpdateOverlayState extends ConsumerState<_UpdateOverlay> {
  _UpdatePhase _phase = _UpdatePhase.idle;
  int _received = 0;
  int _total = 0;
  String? _errorMessage;
  String? _downloadedPath;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel('Update dialog closed.');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watching `forceUpdate` (rather than snapshotting it) makes a server flip
    // while the card is already open immediately remove the "Later" escape
    // hatch and re-title the dialog.
    final mandatory = updateIsMandatory(
      widget.result,
      ref.watch(remoteConfigProvider),
    );
    final update = widget.result.update!;
    final sizeMb =
        update.sizeBytes > 0
            ? (update.sizeBytes / (1024 * 1024)).toStringAsFixed(1)
            : null;

    return _blockingOverlay(
      AlertDialog(
        icon: _phaseIcon(),
        title: Text(_phaseTitle(mandatory)),
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
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verifying download integrity and signature...',
                      ),
                    ),
                  ],
                ),
              ),
            if (_phase == _UpdatePhase.installing)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
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
                  'Update downloaded and verified. The system Package Installer '
                  'will now open to complete the installation.',
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
        actions: _actions(context, update, mandatory),
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    AndroidUpdateInfo update,
    bool mandatory,
  ) {
    final canLeave = !mandatory;
    switch (_phase) {
      case _UpdatePhase.idle:
        return [
          if (canLeave)
            TextButton(onPressed: widget.onDismiss, child: const Text('Later')),
          FilledButton.icon(
            icon: const Icon(Icons.download_rounded),
            onPressed: _startDownload,
            label: const Text('Download & Install'),
          ),
        ];
      case _UpdatePhase.downloading:
        return [
          TextButton(onPressed: _cancelDownload, child: const Text('Cancel')),
          FilledButton(onPressed: null, child: const Text('Downloading...')),
        ];
      case _UpdatePhase.verifying:
      case _UpdatePhase.installing:
        return const [SizedBox.shrink()];
      case _UpdatePhase.installPermission:
        return [
          if (canLeave)
            TextButton(onPressed: _cancelInstall, child: const Text('Cancel')),
          TextButton(
            onPressed: _openBrowserFallback,
            child: const Text('Download in browser'),
          ),
          FilledButton(
            onPressed: _openInstallPermissionSettings,
            child: const Text('Open settings'),
          ),
        ];
      case _UpdatePhase.done:
        return [
          if (canLeave)
            TextButton(onPressed: widget.onDismiss, child: const Text('Later')),
        ];
    }
  }

  Future<void> _startDownload() async {
    final update = widget.result.update!;

    // Never fetch bytes from a URL the update policy rejects (F-08 / P-04).
    final policy = UpdateUrlPolicy.check(update.apkUrl);
    if (!policy.isAllowed) {
      setState(() {
        _errorMessage =
            'This update link is not a trusted CISS download URL, '
            'so nothing was downloaded. Please contact support.';
      });
      return;
    }

    setState(() {
      _phase = _UpdatePhase.downloading;
      _errorMessage = null;
      _received = 0;
      _total = update.sizeBytes;
    });

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
          setState(() {
            _received = received;
            _total = total;
          });
        },
      );
    } on ApkManifestError catch (error) {
      _failDownload(error.message);
      return;
    } on ApkHashMismatchError {
      _failDownload(
        'Download integrity check failed. This may indicate a corrupted '
        'download. Please try again.',
      );
      return;
    } on ApkSizeExceededError catch (error) {
      _failDownload(error.message);
      return;
    } on ApkDiskFullError catch (error) {
      _failDownload(error.message);
      return;
    } on ApkNetworkError catch (error) {
      _failDownload(
        cancelToken.isCancelled
            ? 'Download cancelled.'
            : 'Network error: ${error.message}. Check your connection and try '
                'again.',
      );
      return;
    } on ApkStorageError catch (error) {
      _failDownload(error.message);
      return;
    } catch (error) {
      _failDownload('Download failed: $error');
      return;
    } finally {
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
    }

    if (!mounted) return;
    _downloadedPath = localPath;
    setState(() => _phase = _UpdatePhase.verifying);
    await Future<void>.delayed(const Duration(milliseconds: 300)); // UX pause
    if (!mounted) return;

    final canInstall = await service.canInstallApk();
    if (!mounted) return;
    if (!canInstall) {
      setState(() => _phase = _UpdatePhase.installPermission);
      return;
    }
    await _install(localPath);
  }

  Future<void> _install(String localPath) async {
    setState(() {
      _phase = _UpdatePhase.installing;
      _errorMessage = null;
    });

    // [AppUpdateService.installUpdate] verifies the package name and signer
    // certificate natively before it hands anything to the installer.
    final result = await ref
        .read(appUpdateServiceProvider)
        .installUpdate(localPath);
    if (!mounted) return;

    switch (result) {
      case InstallSuccess():
        setState(() => _phase = _UpdatePhase.done);
      case InstallSignatureRejected(reason: final reason):
        // Security refusal: keep the blocking card, never fall back.
        setState(() {
          _phase = _UpdatePhase.idle;
          _errorMessage =
              'The downloaded update could not be verified as a '
              'genuine CISS Workforce build, so installation was blocked. '
              '($reason)';
        });
      case InstallNeedsPermission():
        setState(() => _phase = _UpdatePhase.installPermission);
      case InstallFailed(message: final message):
        setState(() {
          _phase = _UpdatePhase.idle;
          _errorMessage = 'Installation failed: $message';
        });
    }
  }

  Future<void> _openInstallPermissionSettings() async {
    final service = ref.read(appUpdateServiceProvider);
    await service.openInstallSettings();
    if (!mounted) return;
    final canInstall = await service.canInstallApk();
    if (!mounted) return;
    if (canInstall && _downloadedPath != null) {
      await _install(_downloadedPath!);
    } else {
      setState(() {
        _errorMessage =
            'Install permission is still disabled. Grant '
            '"Install unknown apps" for CISS Workforce and try again.';
      });
    }
  }

  void _cancelInstall() {
    setState(() {
      _phase = _UpdatePhase.idle;
      _errorMessage = null;
    });
  }

  Future<void> _openBrowserFallback() async {
    final update = widget.result.update!;
    // The browser fallback is a launch sink too, so it gets the same policy.
    final target = UpdateUrlPolicy.check(update.apkUrl);
    if (!target.isAllowed) {
      setState(() {
        _errorMessage =
            'This update link is not a trusted CISS download URL '
            'and was not opened.';
      });
      return;
    }
    final opened = await launchUrl(
      target.uri!,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      setState(() {
        _errorMessage = 'Could not open the APK download link.';
      });
    }
  }

  void _failDownload(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _UpdatePhase.idle;
      _errorMessage = message;
    });
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
      case _UpdatePhase.installPermission:
        return const Icon(Icons.admin_panel_settings_rounded, size: 32);
      case _UpdatePhase.done:
        return const Icon(
          Icons.check_circle_rounded,
          size: 32,
          color: Colors.green,
        );
    }
  }

  String _phaseTitle(bool mandatory) {
    switch (_phase) {
      case _UpdatePhase.idle:
        return mandatory ? 'Update required' : 'Update available';
      case _UpdatePhase.downloading:
        return 'Downloading update...';
      case _UpdatePhase.verifying:
        return 'Verifying download...';
      case _UpdatePhase.installing:
        return 'Installing update...';
      case _UpdatePhase.installPermission:
        return 'Permission required';
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
            Text('What changed', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...update.releaseNotes
                .take(4)
                .map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [const Text('• '), Expanded(child: Text(note))],
                    ),
                  ),
                ),
          ],
        ],
      );
    }
    if (_phase == _UpdatePhase.installPermission) {
      return const Text(
        'To install this update, CISS Workforce needs permission to install '
        'apps from unknown sources. Open system settings to grant it?',
      );
    }
    return const SizedBox.shrink();
  }
}
