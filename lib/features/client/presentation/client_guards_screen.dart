import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/utils/initials.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';
import 'client_guard_detail_screen.dart';

class ClientGuardsScreen extends ConsumerStatefulWidget {
  const ClientGuardsScreen({super.key});

  @override
  ConsumerState<ClientGuardsScreen> createState() =>
      _ClientGuardsScreenState();
}

class _ClientGuardsScreenState extends ConsumerState<ClientGuardsScreen> {
  List<Map<String, dynamic>>? _guards;
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

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
      final session = ref.read(authSessionProvider).value;
      final clientId = session?.clientId ?? '';

      final guards = await ref
          .read(mobileRepositoryProvider)
          .fetchClientGuards(clientId);

      if (!mounted) return;

      setState(() {
        _guards = guards;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredGuards {
    final guards = _guards ?? const <Map<String, dynamic>>[];
    if (_searchQuery.isEmpty) return guards;
    return guards.where((g) {
      final name =
          (g['fullName'] as String?) ?? (g['name'] as String?) ?? '';
      final empId = g['employeeId']?.toString() ?? '';
      final site = g['siteName']?.toString() ?? '';
      final q = _searchQuery.toLowerCase();
      return name.toLowerCase().contains(q) ||
          empId.toLowerCase().contains(q) ||
          site.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StateBlock(
              icon: Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
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

    final filtered = _filteredGuards;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchGuards,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: <Widget>[
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search guards...',
                  hintStyle: TextStyle(color: tokens.inkMuted, fontSize: 14),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: tokens.inkMuted, size: 20),
                  filled: true,
                  fillColor: tokens.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: tokens.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: tokens.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: tokens.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const StateBlock(
                  icon: Icons.person_off_rounded,
                  title: 'No guards found',
                  message:
                      'Guards assigned to your sites will appear here once deployed.',
                )
              else
                ...filtered.map((guard) {
                  final name =
                      (guard['fullName'] as String?) ??
                          (guard['name'] as String?) ??
                          'Guard';
                  final employeeId =
                      guard['employeeId']?.toString() ?? '';
                  final site =
                      guard['siteName']?.toString() ?? '';
                  final status =
                      guard['status']?.toString() ?? 'active';
                  final isActive = status.toLowerCase() == 'active';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ModernCard(
                      onTap: () {
                        final empId = guard['employeeId']?.toString();
                        if (empId != null && empId.isNotEmpty) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ClientGuardDetailScreen(
                                employeeId: empId,
                              ),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: tokens.primarySoft,
                            child: Text(
                              initials(name, fallback: 'G'),
                              style: TextStyle(
                                color: tokens.primaryStrong,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.ink,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (employeeId.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'ID: $employeeId',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: tokens.inkMuted,
                                    ),
                                  ),
                                ],
                                if (site.isNotEmpty)
                                  Text(
                                    site,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: tokens.inkMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusChip(
                            label: isActive ? 'Active' : 'Inactive',
                            tone: isActive
                                ? StatusChipTone.success
                                : StatusChipTone.neutral,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
