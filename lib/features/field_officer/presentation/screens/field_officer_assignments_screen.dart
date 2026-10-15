import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../../core/models/duty_models.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/network/ciss_error.dart';
import '../../../../../core/settings/module_gate.dart';
import '../../../../../shared/widgets/primary_action.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../widgets/assignment_editor_sheet.dart';

final fieldOfficerAssignmentsProvider = FutureProvider<List<GuardAssignment>>((
  ref,
) {
  ref.watch(
    authSessionProvider.select(
      (state) => (state.valueOrNull?.uid, state.valueOrNull?.role),
    ),
  );
  return ref.watch(mobileRepositoryProvider).fetchGuardAssignments();
});

class FieldOfficerAssignmentsScreen extends ConsumerStatefulWidget {
  const FieldOfficerAssignmentsScreen({super.key});
  @override
  ConsumerState<FieldOfficerAssignmentsScreen> createState() =>
      _FieldOfficerAssignmentsScreenState();
}

class _FieldOfficerAssignmentsScreenState
    extends ConsumerState<FieldOfficerAssignmentsScreen> {
  final _cancelIds = <String, String>{};
  final _busy = <String>{};
  void _editor([GuardAssignment? assignment]) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder:
        (_) => AssignmentEditorSheet(
          assignment: assignment,
          onSaved: () => ref.invalidate(fieldOfficerAssignmentsProvider),
        ),
  );
  Future<void> _cancel(GuardAssignment assignment) async {
    if (_busy.contains(assignment.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Cancel assignment?'),
            content: const Text(
              'Attendance remains available. This cancellation applies only to this duty.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep duty'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Cancel assignment'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted || !moduleEnabled(ref, 'workOrders')) {
      return;
    }
    setState(() => _busy.add(assignment.id));
    try {
      await ref
          .read(mobileRepositoryProvider)
          .updateGuardAssignment(assignment.id, {
            'expectedVersion': assignment.version,
            'clientRequestId': _cancelIds.putIfAbsent(
              '${assignment.id}:${assignment.version}',
              () => const Uuid().v4(),
            ),
            'status': 'cancelled',
          });
      ref.invalidate(fieldOfficerAssignmentsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cancellation not saved: ${CissError.parse(e)}'),
          ),
        );
      }
      ref.invalidate(fieldOfficerAssignmentsProvider);
    } finally {
      if (mounted) setState(() => _busy.remove(assignment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(fieldOfficerAssignmentsProvider);
    final enabled = moduleEnabled(ref, 'workOrders');
    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled duties')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(fieldOfficerAssignmentsProvider);
          try {
            await ref.read(fieldOfficerAssignmentsProvider.future);
          } catch (_) {}
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            if (enabled)
              PrimaryAction(
                icon: Icons.add,
                label: 'Schedule duty',
                onTap: () => _editor(),
              ),
            const SizedBox(height: 16),
            const Text(
              'Regular and relieving assignments are informational. Attendance is independent.',
            ),
            const SizedBox(height: 16),
            data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (_, __) => StateBlock(
                    icon: Icons.cloud_off,
                    title: 'Could not load scheduled duties',
                    message: 'Try again to load assignments.',
                    action: TextButton(
                      onPressed:
                          () => ref.invalidate(fieldOfficerAssignmentsProvider),
                      child: const Text('Try again'),
                    ),
                  ),
              data:
                  (rows) => Column(
                    children: [
                      if (rows.isEmpty) const Text('No scheduled duties'),
                      ...rows.map(
                        (a) => Card(
                          child: ListTile(
                            title: Text('${a.guardName} · ${a.siteName}'),
                            subtitle: Text(
                              '${a.date} · ${a.data['shiftLabel'] ?? 'Shift to be confirmed'}\n${a.data['type'] ?? 'regular'} · ${a.status}',
                            ),
                            trailing:
                                enabled && a.status != 'cancelled'
                                    ? PopupMenuButton<String>(
                                      enabled: !_busy.contains(a.id),
                                      onSelected:
                                          (v) =>
                                              v == 'edit'
                                                  ? _editor(a)
                                                  : _cancel(a),
                                      itemBuilder:
                                          (_) => const [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit duty'),
                                            ),
                                            PopupMenuItem(
                                              value: 'cancel',
                                              child: Text('Cancel assignment'),
                                            ),
                                          ],
                                    )
                                    : null,
                          ),
                        ),
                      ),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
