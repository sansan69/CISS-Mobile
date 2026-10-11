import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/providers.dart';
import '../../../../../app/theme/app_tokens.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';

/// Lets the guard request a correction to the Aadhaar used for ESIC/EPF
/// registration. Submits a reason (10–500 characters) to
/// `POST /api/guard/profile/aadhaar-correction`.
class GuardAadhaarCorrectionScreen extends ConsumerStatefulWidget {
  const GuardAadhaarCorrectionScreen({super.key});

  @override
  ConsumerState<GuardAadhaarCorrectionScreen> createState() =>
      _GuardAadhaarCorrectionScreenState();
}

class _GuardAadhaarCorrectionScreenState
    extends ConsumerState<GuardAadhaarCorrectionScreen> {
  final _reason = TextEditingController();
  String? _error;
  bool _submitting = false;
  bool _succeeded = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (reason.length < 10 || reason.length > 500) {
      setState(
        () => _error = 'Give a correction reason between 10 and 500 characters.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(mobileRepositoryProvider)
          .requestAadhaarCorrection(reason);
      if (mounted) setState(() => _succeeded = true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return ScreenScaffold(
      title: 'Request Aadhaar correction',
      subtitle: 'ESIC / EPF registration',
      children: <Widget>[
        if (_succeeded)
          ModernCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: <Widget>[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 48,
                    color: tokens.success,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Request received',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'A correction request is already pending. Our team will '
                    'review and update it.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          ModernCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Tell us what needs to be corrected on your Aadhaar used '
                    'for ESIC and EPF registration.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.inkMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _reason,
                    maxLines: 5,
                    minLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Correction reason',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                _error!,
                style: TextStyle(color: tokens.danger),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit request'),
          ),
        ],
      ],
    );
  }
}