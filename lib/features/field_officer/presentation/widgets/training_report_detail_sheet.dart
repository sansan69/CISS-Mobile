import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/models/report_models.dart';
import '../../../../core/network/providers.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/status_chip.dart';

final _dateFmt = DateFormat('dd MMM yyyy');

class TrainingReportDetailSheet extends ConsumerStatefulWidget {
  const TrainingReportDetailSheet({
    super.key,
    required this.report,
    required this.isAdmin,
    required this.isOwner,
    required this.onUpdated,
  });

  final TrainingReportModel report;
  final bool isAdmin;
  final bool isOwner;
  final VoidCallback onUpdated;

  @override
  ConsumerState<TrainingReportDetailSheet> createState() => _TrainingReportDetailSheetState();
}

class _TrainingReportDetailSheetState extends ConsumerState<TrainingReportDetailSheet> {
  bool _editing = false;
  bool _saving = false;
  bool _acknowledging = false;
  String? _error;

  late final TextEditingController _topicCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _attendeeCtrl;
  final List<String> _photoUrls = [];

  bool get _canEdit => widget.report.status == 'draft' && (widget.isAdmin || widget.isOwner);
  bool get _canAddMedia => widget.isAdmin || (widget.isOwner && widget.report.status != 'draft');
  bool get _canAcknowledge => widget.isAdmin && widget.report.status == 'submitted';

  @override
  void initState() {
    super.initState();
    _topicCtrl = TextEditingController(text: widget.report.topic);
    _descCtrl = TextEditingController(text: widget.report.description);
    _durationCtrl = TextEditingController(text: widget.report.durationMinutes.toString());
    _attendeeCtrl = TextEditingController(text: widget.report.attendeeCount.toString());
    _photoUrls.addAll(widget.report.photoUrls);
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _attendeeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(mobileRepositoryProvider).apiClient.dio.patch(
        '/api/admin/training-reports/${widget.report.id}',
        data: {
          'topic': _topicCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'durationMinutes': int.tryParse(_durationCtrl.text.trim()) ?? 60,
          'attendeeCount': int.tryParse(_attendeeCtrl.text.trim()) ?? 0,
          'photoUrls': _photoUrls,
        },
      );
      setState(() { _editing = false; _saving = false; });
      widget.onUpdated();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report updated')));
    } catch (e) {
      setState(() { _saving = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _submit() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(mobileRepositoryProvider).apiClient.dio.patch(
        '/api/admin/training-reports/${widget.report.id}',
        data: {
          'status': 'submitted',
          if (_editing) ...{
            'topic': _topicCtrl.text.trim(),
            'description': _descCtrl.text.trim(),
            'durationMinutes': int.tryParse(_durationCtrl.text.trim()) ?? 60,
            'attendeeCount': int.tryParse(_attendeeCtrl.text.trim()) ?? 0,
            'photoUrls': _photoUrls,
          },
        },
      );
      setState(() { _editing = false; _saving = false; });
      widget.onUpdated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _saving = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _acknowledge() async {
    setState(() { _acknowledging = true; _error = null; });
    try {
      await ref.read(mobileRepositoryProvider).apiClient.dio.patch(
        '/api/admin/training-reports/${widget.report.id}',
        data: {'status': 'acknowledged'},
      );
      widget.onUpdated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _acknowledging = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final report = widget.report;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(color: tokens.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: tokens.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      StatusChip(label: report.status.toUpperCase(), tone: report.status == 'acknowledged' ? StatusChipTone.success : report.status == 'submitted' ? StatusChipTone.info : StatusChipTone.warning),
                      const SizedBox(width: 8),
                      if (report.district.isNotEmpty) Text(report.district, style: TextStyle(fontSize: 12, color: tokens.inkMuted)),
                    ]),
                    const SizedBox(height: 4),
                    Text('Training Report', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tokens.ink)),
                    Text('${report.fieldOfficerName} · ${_dateFmt.format(DateTime.tryParse(report.dateLabel) ?? DateTime.now())}',
                      style: TextStyle(fontSize: 12, color: tokens.inkMuted)),
                  ])),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ]),
              ]),
            ),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  // Client / Site
                  _TCard(tokens: tokens, icon: Icons.business_rounded, title: 'Client & Site',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(report.clientName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tokens.ink)),
                      if (report.siteName.isNotEmpty)
                        Text(report.siteName, style: TextStyle(fontSize: 13, color: tokens.inkMuted)),
                    ])),

                  // Topic
                  _TCard(tokens: tokens, icon: Icons.book_rounded, title: 'Topic',
                    child: _editing
                        ? TextField(controller: _topicCtrl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tokens.ink),
                            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(10)))
                        : Text(report.topic, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tokens.ink))),

                  // Duration & Attendees
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      Expanded(child: _CountCard(label: 'Duration', value: _editing ? null : report.durationMinutes, suffix: 'min', color: tokens.accent, controller: _editing ? _durationCtrl : null, tokens: tokens)),
                      const SizedBox(width: 12),
                      Expanded(child: _CountCard(label: 'Attendees', value: _editing ? null : report.attendeeCount, suffix: '', color: tokens.primary, controller: _editing ? _attendeeCtrl : null, tokens: tokens)),
                    ]),
                  ),

                  // Description
                  if (_editing || report.description.isNotEmpty)
                    _TCard(tokens: tokens, icon: Icons.description_rounded, title: 'Description',
                      child: _editing
                          ? TextField(controller: _descCtrl, maxLines: 4, style: TextStyle(fontSize: 14, color: tokens.ink),
                              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(10)))
                          : Text(report.description, style: TextStyle(fontSize: 14, color: tokens.ink))),

                  // GPS
                  _TCard(tokens: tokens, icon: Icons.location_on_rounded, title: 'GPS Location',
                    child: report.visitLocation != null
                        ? Text('${report.visitLocation!['lat']!.toStringAsFixed(5)}, ${report.visitLocation!['lng']!.toStringAsFixed(5)}',
                            style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: tokens.inkMuted))
                        : Text('No GPS data', style: TextStyle(fontSize: 13, color: tokens.inkMuted))),

                  // Photos
                  _TCard(tokens: tokens, icon: Icons.image_rounded,
                    title: 'Training Photos (${report.photoUrls.length})',
                    child: report.photoUrls.isNotEmpty
                        ? Wrap(spacing: 8, runSpacing: 8, children: report.photoUrls.map((url) => GestureDetector(
                            onTap: () => _openFullScreen(context, url),
                            child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover)),
                          )).toList())
                        : Text('No photos attached', style: TextStyle(fontSize: 13, color: tokens.inkMuted))),

                  // Client Report
                  _TCard(tokens: tokens, icon: Icons.file_present_rounded, title: 'Client-Signed Report',
                    child: report.clientReportUrl != null && report.clientReportUrl!.isNotEmpty
                        ? GestureDetector(onTap: () => _openFullScreen(context, report.clientReportUrl!),
                            child: Row(children: [Icon(Icons.description_rounded, size: 18, color: tokens.primary), const SizedBox(width: 8),
                              Text('View Report', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.primary))]))
                        : Text('Not attached', style: TextStyle(fontSize: 13, color: tokens.inkMuted))),

                  // Attachments
                  if (report.attachmentUrls.isNotEmpty)
                    _TCard(tokens: tokens, icon: Icons.attach_file_rounded,
                      title: 'Attachments (${report.attachmentUrls.length})',
                      child: Column(children: report.attachmentUrls.map((url) =>
                          Padding(padding: const EdgeInsets.only(bottom: 4),
                            child: Text(url, style: TextStyle(fontSize: 12, color: tokens.primary), maxLines: 1, overflow: TextOverflow.ellipsis))
                          ).toList())),

                  // Acknowledged Info
                  if (report.status == 'acknowledged')
                    Container(margin: const EdgeInsets.only(top: 16), padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                      child: Row(children: [Icon(Icons.verified_rounded, size: 16, color: Colors.green.shade700), const SizedBox(width: 6),
                        Text('Acknowledged', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green.shade700))])),

                  if (_error != null)
                    Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(fontSize: 13, color: tokens.danger))),

                  if (_canAcknowledge && !_editing)
                    Padding(padding: const EdgeInsets.only(top: 16),
                      child: SizedBox(width: double.infinity, child: FilledButton.icon(
                        onPressed: _acknowledging ? null : _acknowledge,
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(_acknowledging ? 'Saving...' : 'Acknowledge Report'),
                        style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
                      ))),
                ],
              ),
            ),

            // Bottom bar
            Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(color: tokens.surface, border: Border(top: BorderSide(color: tokens.border))),
              child: Row(children: [
                if (_canEdit && !_editing)
                  Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => _editing = true), icon: const Icon(Icons.edit_rounded, size: 18), label: const Text('Edit Draft')))
                else if (_canEdit && _editing) ...[
                  Expanded(child: OutlinedButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel'))),
                  const SizedBox(width: 8),
                  Expanded(child: FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Save'))),
                  const SizedBox(width: 8),
                  Expanded(child: FilledButton(onPressed: _saving ? null : _submit, style: FilledButton.styleFrom(backgroundColor: tokens.accent), child: const Text('Submit'))),
                ] else if (_canAddMedia && !_editing)
                  Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => _editing = true), icon: const Icon(Icons.add_photo_alternate_rounded, size: 18), label: const Text('Add Photos')))
                else if (_canAddMedia && _editing)
                  Expanded(child: FilledButton(onPressed: () => setState(() => _editing = false), child: const Text('Done'))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _TCard extends StatelessWidget {
  const _TCard({required this.tokens, required this.icon, required this.title, required this.child});
  final CissThemeTokens tokens;
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 14, color: tokens.inkMuted), const SizedBox(width: 6),
            Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.inkMuted, letterSpacing: 0.5))]),
          const SizedBox(height: 8),
          child,
        ]),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, this.value, required this.suffix, required this.color, this.controller, required this.tokens});
  final String label;
  final int? value;
  final String suffix;
  final Color color;
  final TextEditingController? controller;
  final CissThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.inkMuted, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        if (controller != null)
          TextField(controller: controller, keyboardType: TextInputType.number, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero))
        else
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(value.toString(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
            if (suffix.isNotEmpty) ...[const SizedBox(width: 4), Text(suffix, style: TextStyle(fontSize: 14, color: tokens.inkMuted))],
          ]),
      ]),
    );
  }
}

void _openFullScreen(BuildContext context, String url) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(child: InteractiveViewer(child: Image.network(url))),
    ),
  ));
}
