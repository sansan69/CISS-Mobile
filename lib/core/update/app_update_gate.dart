import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_update_service.dart';

class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

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
    if (!mounted || _dialogOpen) {
      return;
    }
    final result =
        await ref.read(appUpdateServiceProvider).checkForAndroidUpdate();
    if (!mounted ||
        result == null ||
        !result.hasUpdate ||
        result.update == null) {
      return;
    }

    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: !result.isMandatory,
      builder: (context) {
        final update = result.update!;
        final sizeMb =
            update.sizeBytes > 0
                ? (update.sizeBytes / (1024 * 1024)).toStringAsFixed(1)
                : null;

        return PopScope(
          canPop: !result.isMandatory,
          child: AlertDialog(
            icon: const Icon(Icons.system_update_alt_rounded),
            title: Text(
              result.isMandatory ? 'Update required' : 'Update available',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CISS Workforce ${update.latestVersionName} is available. '
                  'You are using ${result.currentVersionName}.',
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
                      .map(
                        (note) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• '),
                              Expanded(child: Text(note)),
                            ],
                          ),
                        ),
                      ),
                ],
              ],
            ),
            actions: [
              if (!result.isMandatory)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Later'),
                ),
              FilledButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  final opened = await ref
                      .read(appUpdateServiceProvider)
                      .openUpdate(update);
                  if (!opened) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Could not open the APK download link.'),
                      ),
                    );
                    return;
                  }
                  if (!result.isMandatory && navigator.canPop()) {
                    navigator.pop();
                  }
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download update'),
              ),
            ],
          ),
        );
      },
    );
    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
