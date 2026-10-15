import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/models/duty_models.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/settings/module_gate.dart';
import '../../../../../shared/widgets/primary_action.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../auth/presentation/protected_workspace_modal.dart';
import '../../../../../core/models/app_role.dart';

final workOrderWillingnessProvider =
    FutureProvider.family<WorkOrderWillingness, String>((ref, id) {
      ref.watch(
        authSessionProvider.select(
          (state) => (state.valueOrNull?.uid, state.valueOrNull?.role),
        ),
      );
      return ref.watch(mobileRepositoryProvider).fetchWorkOrderWillingness(id);
    });

class WorkOrderWillingnessSheet extends ConsumerStatefulWidget {
  const WorkOrderWillingnessSheet({
    super.key,
    required this.workOrderId,
    required this.onSelect,
    this.onAccessRevoked,
  });
  final String workOrderId;
  final void Function(Set<String>) onSelect;
  final VoidCallback? onAccessRevoked;
  @override
  ConsumerState<WorkOrderWillingnessSheet> createState() =>
      _WorkOrderWillingnessSheetState();
}

class _WorkOrderWillingnessSheetState
    extends ConsumerState<WorkOrderWillingnessSheet> {
  final _selected = <String>{};
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final accessKey = ref.watch(workspaceAccessSessionKeyProvider);
    if (session?.role != AppRole.fieldOfficer ||
        accessKey != 'fieldOfficer:${session?.uid}') {
      return ProtectedWorkspaceModal(
        role: AppRole.fieldOfficer,
        onAccessRevoked: widget.onAccessRevoked,
        child: const SizedBox.shrink(),
      );
    }
    final data = ref.watch(workOrderWillingnessProvider(widget.workOrderId));
    return ProtectedWorkspaceModal(
      role: AppRole.fieldOfficer,
      onAccessRevoked: widget.onAccessRevoked,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Exam responses',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              data.when(
                loading: () => const CircularProgressIndicator(),
                error:
                    (_, __) => StateBlock(
                      icon: Icons.cloud_off,
                      title: 'Could not load responses',
                      message:
                          'Manual exam roster assignment remains available.',
                      action: TextButton(
                        onPressed:
                            () => ref.invalidate(
                              workOrderWillingnessProvider(widget.workOrderId),
                            ),
                        child: const Text('Try again'),
                      ),
                    ),
                data:
                    (value) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${value.willingCount} willing · ${value.unavailableCount} unavailable',
                        ),
                        const SizedBox(height: 12),
                        if (value.responses.isEmpty)
                          const Text('No eligible responses yet.'),
                        ...value.responses.map((row) {
                          final id = row['employeeDocId'] as String? ?? '';
                          final willing = row['response'] == 'willing';
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(row['name'] as String? ?? 'Guard'),
                            subtitle: Text(
                              '${row['employeeId'] ?? ''} · ${row['gender'] ?? ''} · ${row['response']}',
                            ),
                            value: _selected.contains(id),
                            onChanged:
                                !willing ||
                                        id.isEmpty ||
                                        !moduleEnabled(ref, 'workOrders')
                                    ? null
                                    : (v) => setState(
                                      () =>
                                          v == true
                                              ? _selected.add(id)
                                              : _selected.remove(id),
                                    ),
                          );
                        }),
                        const Text(
                          'Unavailable guards can still be assigned manually.',
                        ),
                        const SizedBox(height: 16),
                        PrimaryAction(
                          icon: Icons.assignment_outlined,
                          label: 'Review exam roster',
                          enabled:
                              _selected.isNotEmpty &&
                              moduleEnabled(ref, 'workOrders'),
                          onTap: () => widget.onSelect(Set.of(_selected)),
                        ),
                      ],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
