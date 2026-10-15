import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/duty_models.dart';
import '../../../../../core/settings/module_gate.dart';
import '../../../../../core/utils/date_format.dart';
import '../../../../../shared/widgets/adaptive_dropdown.dart';
import '../../../../../shared/widgets/primary_action.dart';
import '../../../auth/presentation/protected_workspace_modal.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../../../core/models/app_role.dart';
import '../../application/duty_willingness_controller.dart';

class DutyDetailSheet extends ConsumerStatefulWidget {
  const DutyDetailSheet({super.key, required this.duty, this.onAccessRevoked});
  final GuardDuty duty;
  final VoidCallback? onAccessRevoked;
  @override
  ConsumerState<DutyDetailSheet> createState() => _DutyDetailSheetState();
}

class _DutyDetailSheetState extends ConsumerState<DutyDetailSheet> {
  WillingnessStatus? _choice;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _choice = widget.duty.willingness;
  }

  Future<void> _save(GuardDuty duty) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(dutyWillingnessControllerProvider).choose(duty, _choice!);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final accessKey = ref.watch(workspaceAccessSessionKeyProvider);
    if (session?.role != AppRole.guard ||
        accessKey != 'guard:${session?.uid}') {
      return ProtectedWorkspaceModal(
        role: AppRole.guard,
        onAccessRevoked: widget.onAccessRevoked,
        child: const SizedBox.shrink(),
      );
    }
    return ProtectedWorkspaceModal(
      role: AppRole.guard,
      onAccessRevoked: widget.onAccessRevoked,
      child: _buildProtectedContent(context),
    );
  }

  Widget _buildProtectedContent(BuildContext context) {
    // Refresh may close/cancel a previously opened sheet. Never retain stale
    // eligibility for its next tap.
    final feed = ref.watch(guardDutiesProvider).valueOrNull;
    final duty =
        feed?.where((e) => e.id == widget.duty.id).firstOrNull ?? widget.duty;
    final local = ref.watch(dutyResponseProvider(duty.workOrderId ?? duty.id));
    final enabled =
        moduleEnabled(ref, 'workOrders') &&
        duty.canRespond &&
        feed != null &&
        feed.any((e) => e.id == duty.id);
    final tokens = CissThemeTokens.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      duty.examName ?? 'Assigned duty',
                      style: AppTypography.title(context),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(duty.siteName, style: AppTypography.cardTitle(context)),
              const SizedBox(height: 12),
              Text(
                '${formatDutyDate(duty.date)}${duty.district.isEmpty ? '' : ' · ${duty.district}'}',
              ),
              const SizedBox(height: 8),
              Text(
                duty.shiftLabel?.trim().isNotEmpty == true
                    ? duty.shiftLabel!
                    : 'Shift to be confirmed',
              ),
              if (duty.startsAt != null) Text('Starts: ${duty.startsAt}'),
              if (duty.endsAt != null) Text('Ends: ${duty.endsAt}'),
              if (duty.status == 'cancelled')
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Cancelled'),
                ),
              if (duty.relieving)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Relieving assignment'),
                ),
              if (duty.isExam) ...[
                const SizedBox(height: 12),
                Text(
                  '${duty.maleGuardsRequired ?? 0} male · ${duty.femaleGuardsRequired ?? 0} female required',
                ),
                const SizedBox(height: 12),
                const Text('This does not confirm assignment.'),
                if (duty.respondBy != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Responses close when the duty day starts (India time).',
                    ),
                  ),
                if (local?.state == 'pending')
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Pending — your response is not yet saved.'),
                  ),
                if (local?.state == 'saved')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Response saved: ${local!.response.name}'),
                  ),
                if (local?.state == 'rejected')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Response not sent: ${local!.reason ?? 'Refresh and choose again.'}',
                      style: TextStyle(color: tokens.danger),
                    ),
                  ),
                if (local?.state == 'rejected' && local?.serverResponse != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Server response at rejection: ${local!.serverResponse!.name}',
                    ),
                  ),
                if (duty.willingness != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Current server response: ${duty.willingness!.name}',
                    ),
                  ),
                if (enabled) ...[
                  const SizedBox(height: 16),
                  AdaptiveDropdownFormField<WillingnessStatus>(
                    value: _choice,
                    label: 'Your response',
                    items: const [
                      DropdownMenuItem(
                        value: WillingnessStatus.willing,
                        child: Text('Willing'),
                      ),
                      DropdownMenuItem(
                        value: WillingnessStatus.unavailable,
                        child: Text('Unavailable'),
                      ),
                    ],
                    onChanged:
                        _saving ? null : (v) => setState(() => _choice = v),
                  ),
                  const SizedBox(height: 16),
                  PrimaryAction(
                    icon: Icons.check,
                    label: _saving ? 'Sending response…' : 'Save response',
                    enabled: !_saving && _choice != null,
                    onTap: () => _save(duty),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      duty.ineligibilityReason ??
                          'Responses are unavailable for this duty.',
                    ),
                  ),
                TextButton(
                  onPressed:
                      _saving
                          ? null
                          : () => ref.invalidate(guardDutiesProvider),
                  child: const Text('Refresh duty details'),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: TextStyle(color: tokens.danger)),
                ),
              const SizedBox(height: 12),
              const Text('Attendance is available independently of this duty.'),
            ],
          ),
        ),
      ),
    );
  }
}
