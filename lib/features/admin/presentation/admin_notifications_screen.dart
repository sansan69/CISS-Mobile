import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/glass_card.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  String _role = 'all';
  bool _sending = false;

  final List<String> _roles = ['all', 'guard', 'fieldOfficer'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _districtCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and body are required')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final result = await ref
          .read(mobileRepositoryProvider)
          .sendAdminNotification(
            title: title,
            body: body,
            role: _role,
            district: _districtCtrl.text.trim().isEmpty
                ? null
                : _districtCtrl.text.trim(),
          );
      Haptics.medium();
      if (!mounted) return;
      final count = result['recipientCount'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent to $count recipients'),
          backgroundColor: CissThemeTokens.of(context).success,
        ),
      );
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _districtCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: CissThemeTokens.of(context).danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Send Notification'),
        backgroundColor: tokens.canvas,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compose Push Notification',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This will send to all recipients matching the criteria below.',
                    style: TextStyle(fontSize: 13, color: tokens.inkMuted),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bodyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Body',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Target Audience',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: _roles
                        .map(
                          (r) => ButtonSegment<String>(
                            value: r,
                            label: Text(
                              r == 'all'
                                  ? 'All'
                                  : r == 'guard'
                                      ? 'Guards'
                                      : 'Field Officers',
                            ),
                          ),
                        )
                        .toList(),
                    selected: {_role},
                    onSelectionChanged: (s) =>
                        setState(() => _role = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _districtCtrl,
                    decoration: const InputDecoration(
                      labelText: 'District (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'Leave empty for all districts',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'Sending...' : 'Send Notification'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
