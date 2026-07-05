import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/models/report_models.dart';
import '../../../../core/network/providers.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/status_chip.dart';

final _dateFmt = DateFormat('dd MMM yyyy');

class VisitReportDetailSheet extends ConsumerStatefulWidget {
  const VisitReportDetailSheet({
    super.key,
    required this.report,
    required this.isAdmin,
    required this.isOwner,
    required this.onUpdated,
  });

  final VisitReportModel report;
  final bool isAdmin;
  final bool isOwner;
  final VoidCallback onUpdated;

  @override
  ConsumerState<VisitReportDetailSheet> createState() => _VisitReportDetailSheetState();
}

class _VisitReportDetailSheetState extends ConsumerState<VisitReportDetailSheet> {
  bool _editing = false;
  bool _saving = false;
  bool _reviewing = false;
  String? _error;

  late final TextEditingController _summaryCtrl;
  late final TextEditingController _issuesCtrl;
  late final TextEditingController _actionsCtrl;
  late final TextEditingController _presentCtrl;
  late final TextEditingController _absentCtrl;
  final List<String> _photoUrls = [];

  bool get _canEdit => widget.report.status == 'draft' && (widget.isAdmin || widget.isOwner);
  bool get _canAddPhotos => widget.isAdmin || (widget.isOwner && widget.report.status != 'draft');
  bool get _canReview => widget.isAdmin && widget.report.status == 'submitted';

  @override
  void initState() {
    super.initState();
    _summaryCtrl = TextEditingController(text: widget.report.summary);
    _issuesCtrl = TextEditingController(text: widget.report.issuesFound);
    _actionsCtrl = TextEditingController();
    _presentCtrl = TextEditingController(text: widget.report.guardsPresentCount.toString());
    _absentCtrl = TextEditingController(text: widget.report.guardsAbsentCount.toString());
    _photoUrls.addAll(widget.report.photoUrls);
  }

  @override
  void dispose() {
    _summaryCtrl.dispose();
    _issuesCtrl.dispose();
    _actionsCtrl.dispose();
    _presentCtrl.dispose();
    _absentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(mobileRepositoryProvider).apiClient.dio.patch(
        '/api/admin/visit-reports/${widget.report.id}',
        data: {
          'summary': _summaryCtrl.text.trim(),
          'issuesFound': _issuesCtrl.text.trim(),
          'actionsRequired': _actionsCtrl.text.trim(),
          'guardsPresentCount': int.tryParse(_presentCtrl.text.trim()) ?? 0,
          'guardsAbsentCount': int.tryParse(_absentCtrl.text.trim()) ?? 0,
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
        '/api/admin/visit-reports/${widget.report.id}',
        data: {
          'status': 'submitted',
          if (_editing) ...{
            'summary': _summaryCtrl.text.trim(),
            'issuesFound': _issuesCtrl.text.trim(),
            'guardsPresentCount': int.tryParse(_presentCtrl.text.trim()) ?? 0,
            'guardsAbsentCount': int.tryParse(_absentCtrl.text.trim()) ?? 0,
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

  Future<void> _review() async {
    setState(() { _reviewing = true; _error = null; });
    try {
      await ref.read(mobileRepositoryProvider).apiClient.dio.patch(
        '/api/admin/visit-reports/${widget.report.id}',
        data: {'status': 'reviewed'},
      );
      widget.onUpdated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _reviewing = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _addPhotos() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(mobileRepositoryProvider).apiClient.dio.patch(
        '/api/admin/visit-reports/${widget.report.id}',
        data: {'photoUrls': _photoUrls},
      );
      setState(() { _editing = false; _saving = false; });
      widget.onUpdated();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photos added')));
    } catch (e) {
      setState(() { _saving = false; _error = e.toString().replaceFirst('Exception: ', ''); });
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
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle + Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: tokens.border, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              StatusChip(label: report.status.toUpperCase(), tone: report.status == 'reviewed' ? StatusChipTone.success : report.status == 'submitted' ? StatusChipTone.info : StatusChipTone.warning),
                              const SizedBox(width: 8),
                              if (report.district.isNotEmpty)
                                Text(report.district, style: TextStyle(fontSize: 12, color: tokens.inkMuted)),
                            ]),
                            const SizedBox(height: 4),
                            Text('Visit Report', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tokens.ink)),
                            Text('${report.fieldOfficerName} · ${_dateFmt.format(DateTime.tryParse(report.dateLabel) ?? DateTime.now())}',
                              style: TextStyle(fontSize: 12, color: tokens.inkMuted)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  // Client / Site
                  _SectionCard(
                    icon: Icons.business_rounded,
                    title: 'Client & Site',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.clientName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tokens.ink)),
                        if (report.siteName.isNotEmpty)
                          Text(report.siteName, style: TextStyle(fontSize: 13, color: tokens.inkMuted)),
                      ],
                    ),
                  ),

                  // Guard Counts
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(child: _CountCard(label: 'Guards Present', value: _editing ? null : report.guardsPresentCount, color: Colors.green, controller: _editing ? _presentCtrl : null, tokens: tokens)),
                        const SizedBox(width: 12),
                        Expanded(child: _CountCard(label: 'Guards Absent', value: _editing ? null : report.guardsAbsentCount, color: Colors.red, controller: _editing ? _absentCtrl : null, tokens: tokens)),
                      ],
                    ),
                  ),

                  // Summary
                  _FieldSection(
                    icon: Icons.description_rounded,
                    title: 'Summary',
                    editing: _editing,
                    controller: _summaryCtrl,
                    value: report.summary,
                    maxLines: 4,
                  ),

                  // Issues Found
                  _FieldSection(
                    icon: Icons.warning_amber_rounded,
                    title: 'Issues Found',
                    editing: _editing,
                    controller: _issuesCtrl,
                    value: report.issuesFound.isNotEmpty ? report.issuesFound : 'None reported',
                    maxLines: 3,
                  ),

                  // Actions Required
                  _FieldSection(
                    icon: Icons.checklist_rounded,
                    title: 'Actions Required',
                    editing: _editing,
                    controller: _actionsCtrl,
                    value: 'None specified',
                    maxLines: 3,
                  ),

                  // GPS
                  _SectionCard(
                    icon: Icons.location_on_rounded,
                    title: 'GPS Location',
                    child: report.visitLocation != null
                        ? Row(children: [
                            Text('${report.visitLocation!['lat']!.toStringAsFixed(5)}, ${report.visitLocation!['lng']!.toStringAsFixed(5)}',
                              style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: tokens.inkMuted)),
                          ])
                        : Text('No GPS data', style: TextStyle(fontSize: 13, color: tokens.inkMuted)),
                  ),

                  // Photos
                  _SectionCard(
                    icon: Icons.image_rounded,
                    title: 'Site Photos (${_editing || _canAddPhotos ? _photoUrls.length : report.photoUrls.length})',
                    child: (_editing || _canAddPhotos)
                        ? Column(children: [
                            if (_canAddPhotos && !_editing)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: OutlinedButton.icon(
                                  onPressed: () { setState(() => _editing = true); },
                                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                                  label: const Text('Manage Photos'),
                                ),
                              )
                            else if (_editing)
                              Text('Photo management available when submitting from mobile', style: TextStyle(fontSize: 12, color: tokens.inkMuted)),
                          ])
                        : report.photoUrls.isNotEmpty
                            ? Wrap(spacing: 8, runSpacing: 8, children: report.photoUrls.map((url) => GestureDetector(
                                onTap: () => _openFullScreen(context, url),
                                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover)),
                              )).toList())
                            : Text('No photos attached', style: TextStyle(fontSize: 13, color: tokens.inkMuted)),
                  ),

                  // Reviewed Info
                  if (report.status == 'reviewed')
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Icon(Icons.verified_rounded, size: 16, color: Colors.green.shade700), const SizedBox(width: 6),
                          Text('Reviewed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green.shade700))]),
                      ]),
                    ),

                  // Error
                  if (_error != null)
                    Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(fontSize: 13, color: tokens.danger))),

                  // Review Action
                  if (_canReview && !_editing)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SizedBox(width: double.infinity, child: FilledButton.icon(
                        onPressed: _reviewing ? null : _review,
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(_reviewing ? 'Saving...' : 'Mark as Reviewed'),
                        style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
                      )),
                    ),
                ],
              ),
            ),

            // Bottom Action Bar
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
                ] else if (_canAddPhotos && !_editing)
                  Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => _editing = true), icon: const Icon(Icons.add_photo_alternate_rounded, size: 18), label: const Text('Add Photos')))
                else if (_canAddPhotos && _editing) ...[
                  Expanded(child: OutlinedButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel'))),
                  const SizedBox(width: 8),
                  Expanded(child: FilledButton(onPressed: _saving ? null : _addPhotos, child: Text(_saving ? 'Saving...' : 'Save Photos'))),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
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
  const _CountCard({required this.label, this.value, required this.color, this.controller, required this.tokens});
  final String label;
  final int? value;
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
          Text(value.toString(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

class _FieldSection extends StatelessWidget {
  const _FieldSection({required this.icon, required this.title, required this.editing, this.controller, required this.value, this.maxLines = 3});
  final IconData icon;
  final String title;
  final bool editing;
  final TextEditingController? controller;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 14, color: tokens.inkMuted), const SizedBox(width: 6),
            Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.inkMuted, letterSpacing: 0.5))]),
          const SizedBox(height: 8),
          editing && controller != null
              ? TextField(controller: controller, maxLines: maxLines, style: TextStyle(fontSize: 14, color: tokens.ink),
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(10)))
              : Text(value, style: TextStyle(fontSize: 14, color: tokens.ink)),
        ]),
      ),
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
