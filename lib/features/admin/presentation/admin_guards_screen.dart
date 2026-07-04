import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

class AdminGuardsScreen extends ConsumerStatefulWidget {
  const AdminGuardsScreen({super.key});

  @override
  ConsumerState<AdminGuardsScreen> createState() => _AdminGuardsScreenState();
}

class _AdminGuardsScreenState extends ConsumerState<AdminGuardsScreen> {
  List<Map<String, dynamic>> _guards = const <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchGuards();
  }

  Future<void> _fetchGuards() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final guards = await ref.read(mobileRepositoryProvider).fetchAdminGuards();
      if (!mounted) return;
      setState(() {
        _guards = guards;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StateBlock(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load guards',
              message: _error!,
              action: FilledButton.tonal(
                onPressed: _fetchGuards,
                child: const Text('Try again'),
              ),
            ),
          ),
        ),
      );
    }

    final activeCount = _guards
        .where((guard) => _text(guard['status']).toLowerCase() == 'active')
        .length;
    final clientCount = _guards
        .map((guard) => _text(guard['clientName']))
        .where((client) => client.isNotEmpty)
        .toSet()
        .length;

    return ScreenScaffold(
      title: 'Guards',
      subtitle: '${_guards.length} profiles, $activeCount active',
      onRefresh: _fetchGuards,
      children: <Widget>[
        _SummaryStrip(
          leftLabel: 'Active',
          leftValue: '$activeCount',
          rightLabel: 'Clients',
          rightValue: '$clientCount',
        ),
        if (_guards.isEmpty)
          const StateBlock(
            icon: Icons.person_off_rounded,
            title: 'No guards found',
            message: 'New guard profiles will appear here after enrollment.',
          )
        else
          ..._guards.map((guard) {
            final name = _text(guard['fullName']).isNotEmpty
                ? _text(guard['fullName'])
                : _text(guard['name']).isNotEmpty
                    ? _text(guard['name'])
                    : 'Guard';
            final employeeId = _text(guard['employeeId']).isNotEmpty
                ? _text(guard['employeeId'])
                : _text(guard['employeeCode']);
            final clientName = _text(guard['clientName']);
            final district = _text(guard['district']);
            final phone = _text(guard['phoneNumber']);
            final status = _text(guard['status']).isNotEmpty ? _text(guard['status']) : 'Active';
            final isActive = status.toLowerCase() == 'active';

            return GlassCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: tokens.primarySoft,
                    child: Text(
                      _initials(name),
                      style: TextStyle(
                        color: tokens.primaryStrong,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (employeeId.isNotEmpty) _MetaLine(Icons.badge_rounded, employeeId),
                        if (clientName.isNotEmpty) _MetaLine(Icons.business_rounded, clientName),
                        if (district.isNotEmpty) _MetaLine(Icons.place_rounded, district),
                        if (phone.isNotEmpty) _MetaLine(Icons.call_rounded, phone),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusChip(
                    label: isActive ? 'Active' : status,
                    tone: isActive ? StatusChipTone.success : StatusChipTone.neutral,
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  String _text(Object? value) => (value as String?)?.trim() ?? '';

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final initials = parts.map((part) => part[0]).take(2).join().toUpperCase();
    return initials.isEmpty ? 'G' : initials;
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 13, color: tokens.inkMuted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: tokens.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return GlassCard(
      child: Row(
        children: <Widget>[
          Expanded(child: _SummaryValue(label: leftLabel, value: leftValue, color: tokens.success)),
          Container(width: 1, height: 38, color: tokens.border),
          Expanded(child: _SummaryValue(label: rightLabel, value: rightValue, color: tokens.primary)),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Column(
      children: <Widget>[
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.inkMuted)),
      ],
    );
  }
}
