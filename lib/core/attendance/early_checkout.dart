import 'package:flutter/material.dart';

/// Canonical list of reasons a guard can pick when checking out before the
/// scheduled end of their shift.
///
/// [kEarlyCheckoutReasonOther] is a sentinel: choosing it reveals a free-text
/// field instead of submitting a fixed label.
const String kEarlyCheckoutReasonOther = 'Other';

const List<String> kEarlyCheckoutReasons = <String>[
  'Personal emergency',
  'Shift relief arrived',
  'Supervisor instruction',
  kEarlyCheckoutReasonOther,
];

/// Presents a bottom sheet asking why the guard is checking out early.
///
/// Returns the chosen reason, the trimmed free-text value when `Other` is
/// selected, or `null` when the guard dismisses the sheet or leaves the
/// free-text field blank.
Future<String?> showEarlyCheckoutReasonSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext sheetContext) => const _EarlyCheckoutReasonSheet(),
  );
}

class _EarlyCheckoutReasonSheet extends StatefulWidget {
  const _EarlyCheckoutReasonSheet();

  @override
  State<_EarlyCheckoutReasonSheet> createState() =>
      _EarlyCheckoutReasonSheetState();
}

class _EarlyCheckoutReasonSheetState extends State<_EarlyCheckoutReasonSheet> {
  final TextEditingController _otherController = TextEditingController();
  bool _showOther = false;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  void _select(String reason) {
    if (reason == kEarlyCheckoutReasonOther) {
      setState(() => _showOther = true);
      return;
    }
    Navigator.of(context).pop(reason);
  }

  void _submitOther() {
    final String text = _otherController.text.trim();
    Navigator.of(context).pop(text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Reason for early checkout', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Let your supervisor know why you are checking out before your shift ends.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final String reason in kEarlyCheckoutReasons)
            if (reason != kEarlyCheckoutReasonOther || !_showOther)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(reason),
                onTap: () => _select(reason),
              ),
          if (_showOther) ...<Widget>[
            TextField(
              controller: _otherController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Describe your reason',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submitOther(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submitOther,
              child: const Text('Submit reason'),
            ),
          ],
        ],
      ),
    );
  }
}
