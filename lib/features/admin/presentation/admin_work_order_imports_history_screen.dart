import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

class AdminWorkOrderImportsHistoryScreen extends ConsumerStatefulWidget {
  const AdminWorkOrderImportsHistoryScreen({super.key});

  @override
  ConsumerState<AdminWorkOrderImportsHistoryScreen> createState() =>
      _AdminWorkOrderImportsHistoryScreenState();
}

class _AdminWorkOrderImportsHistoryScreenState
    extends ConsumerState<AdminWorkOrderImportsHistoryScreen> {
  List<Map<String, dynamic>> _imports = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(mobileRepositoryProvider)
          .getJson('/api/admin/work-orders/imports');
      if (!mounted) return;
      setState(() {
        _imports = (data['imports'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            const <Map<String, dynamic>>[];
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

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: StateBlock(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load import history',
                      message: _error!,
                      action: FilledButton.tonal(
                        onPressed: _fetch,
                        child: const Text('Try again'),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: <Widget>[
                      ModernHero(
                        eyebrow: 'Work Orders',
                        title: 'Import History',
                        subtitle: '${_imports.length} imports',
                      ),
                      const SizedBox(height: 16),
                      if (_imports.isEmpty)
                        StateBlock(
                          icon: Icons.upload_file_outlined,
                          title: 'No imports yet',
                          message:
                              'Work order import history will appear here after you upload spreadsheets.',
                        )
                      else
                        ..._imports.map((imp) {
                          final fileName =
                              imp['fileName'] as String? ??
                              imp['filename'] as String? ??
                              'Import';
                          final status =
                              imp['status'] as String? ??
                              imp['recordStatus'] as String? ??
                              'completed';
                          final createdAt =
                              imp['createdAt'] as String? ??
                              imp['timestamp'] as String? ??
                              '';
                          final rows =
                              (imp['rowCount'] as num?)?.toInt() ??
                              (imp['rows'] as num?)?.toInt() ??
                              0;
                          final success =
                              (imp['successCount'] as num?)?.toInt() ??
                              (imp['successful'] as num?)?.toInt();
                          final errors =
                              (imp['errorCount'] as num?)?.toInt() ??
                              (imp['errors'] as num?)?.toInt();

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: ModernCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: status == 'completed'
                                              ? tokens.successSoft
                                              : status == 'processing'
                                                  ? tokens.warningSoft
                                                  : tokens.dangerSoft,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          status == 'completed'
                                              ? Icons.check_circle_rounded
                                              : status == 'processing'
                                                  ? Icons.sync_rounded
                                                  : Icons.error_rounded,
                                          color: status == 'completed'
                                              ? tokens.success
                                              : status == 'processing'
                                                  ? tokens.warning
                                                  : tokens.danger,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              fileName,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: tokens.ink,
                                              ),
                                            ),
                                            if (createdAt.isNotEmpty)
                                              Text(
                                                createdAt
                                                    .split('T')
                                                    .first,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: tokens.inkMuted,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      StatusChip(
                                        label: status.toUpperCase(),
                                        tone: status == 'completed'
                                            ? StatusChipTone.success
                                            : status == 'processing'
                                                ? StatusChipTone.warning
                                                : StatusChipTone.danger,
                                      ),
                                    ],
                                  ),
                                  if (rows > 0) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: <Widget>[
                                        _statChip(
                                            tokens, '$rows rows',
                                            tokens.primary),
                                        if (success != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 6),
                                            child: _statChip(
                                                tokens,
                                                '$success succeeded',
                                                tokens.success),
                                          ),
                                        if (errors != null && errors > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 6),
                                            child: _statChip(
                                                tokens,
                                                '$errors errors',
                                                tokens.danger),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
      ),
    );
  }

  Widget _statChip(
      CissThemeTokens tokens, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}
