import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../shared/utils/initials.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/document_list_tile.dart';

class AdminGuardDetailScreen extends ConsumerStatefulWidget {
  const AdminGuardDetailScreen({super.key, required this.employeeId});

  final String employeeId;

  @override
  ConsumerState<AdminGuardDetailScreen> createState() =>
      _AdminGuardDetailScreenState();
}

class _AdminGuardDetailScreenState extends ConsumerState<AdminGuardDetailScreen> {
  Map<String, dynamic>? _guard;
  bool _loading = true;
  String? _error;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchGuard();
  }

  Future<void> _fetchGuard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final data = await repo.fetchEmployeeDetail(widget.employeeId);
      if (!mounted) return;
      setState(() {
        _guard = data;
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

  Future<void> _toggleStatus() async {
    final current = _guard?['status']?.toString() ?? 'Active';
    final newStatus = current.toLowerCase() == 'active' ? 'Exited' : 'Active';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Status'),
        content: Text('Change status from $current to $newStatus?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Set $newStatus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionLoading = true);
    try {
      final repo = ref.read(mobileRepositoryProvider);
      await repo.updateEmployeeStatus(
        employeeId: widget.employeeId,
        status: newStatus,
      );
      await _fetchGuard();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: CissThemeTokens.of(context).danger,
        ),
      );
    }
  }

  Future<void> _deleteGuard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Guard'),
        content: const Text(
          'This action cannot be undone. Are you sure you want to delete this guard?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: CissThemeTokens.of(context).danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionLoading = true);
    try {
      final repo = ref.read(mobileRepositoryProvider);
      await repo.deleteEmployee(widget.employeeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guard deleted')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: CissThemeTokens.of(context).danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _guard == null) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        appBar: AppBar(backgroundColor: tokens.canvas),
        body: Center(
          child: StateBlock(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load guard',
            message: _error ?? 'Guard not found',
            action: FilledButton.tonal(
              onPressed: _fetchGuard,
              child: const Text('Retry'),
            ),
          ),
        ),
      );
    }

    final guard = _guard!;
    final name = guard['name']?.toString() ?? guard['fullName']?.toString() ?? '';
    final status = guard['status']?.toString() ?? 'Active';
    final isActive = status.toLowerCase() == 'active';
    final employeeId = guard['employeeId']?.toString() ?? widget.employeeId;
    final clientName = guard['clientName']?.toString() ?? '';
    final district = guard['district']?.toString() ?? '';
    final siteName = guard['siteName']?.toString() ?? '';
    final phone = guard['phoneNumber']?.toString() ?? '';
    final email = guard['email']?.toString() ?? '';
    final address = guard['address']?.toString() ?? '';
    final doj = guard['dateOfJoining']?.toString() ?? guard['createdAt']?.toString() ?? '';
    // ── Document fields ─────────────────────────────────────────────
    final profilePhotoUrl = guard['profilePhotoUrl']?.toString() ?? '';
    final idProofFrontUrl = guard['idProofFrontUrl']?.toString() ?? '';
    final idProofBackUrl = guard['idProofBackUrl']?.toString() ?? '';
    final addressProofFrontUrl = guard['addressProofFrontUrl']?.toString() ?? '';
    final addressProofBackUrl = guard['addressProofBackUrl']?.toString() ?? '';
    final signatureUrl = guard['signatureUrl']?.toString() ?? '';
    final idProofType = guard['idProofType']?.toString() ?? '';
    final addressProofType = guard['addressProofType']?.toString() ?? '';

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Guard Detail'),
        backgroundColor: tokens.canvas,
        actions: [
          if (_actionLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchGuard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ModernHero(
              eyebrow: employeeId,
              title: name,
              subtitle: '$status - $clientName',
              avatarText: initials(name, fallback: 'G'),
            ),
            const SizedBox(height: 24),
            _sectionHeader('PERSONAL INFO', tokens),
            const SizedBox(height: 12),
            ModernCard(
              child: Column(
                children: [
                  _detailRow('Name', name, tokens),
                  if (employeeId.isNotEmpty) _divider(tokens),
                  if (employeeId.isNotEmpty) _detailRow('Employee ID', employeeId, tokens),
                  if (phone.isNotEmpty) _divider(tokens),
                  if (phone.isNotEmpty) _detailRow('Phone', phone, tokens),
                  if (email.isNotEmpty) _divider(tokens),
                  if (email.isNotEmpty) _detailRow('Email', email, tokens),
                  if (address.isNotEmpty) _divider(tokens),
                  if (address.isNotEmpty) _detailRow('Address', address, tokens),
                  if (doj.isNotEmpty) _divider(tokens),
                  if (doj.isNotEmpty)
                    _detailRow('Date of Joining', _formatDate(doj), tokens),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionHeader('CONTACT & SITE', tokens),
            const SizedBox(height: 12),
            ModernCard(
              child: Column(
                children: [
                  _detailRow('Client', clientName.isNotEmpty ? clientName : '—', tokens),
                  _divider(tokens),
                  _detailRow('Site', siteName.isNotEmpty ? siteName : '—', tokens),
                  _divider(tokens),
                  _detailRow('District', district.isNotEmpty ? district : '—', tokens),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionHeader('STATUS', tokens),
            const SizedBox(height: 12),
            ModernCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      StatusChip(
                        label: status,
                        tone: isActive
                            ? StatusChipTone.success
                            : StatusChipTone.neutral,
                      ),
                      const Spacer(),
                      FilledButton.tonal(
                        onPressed: _actionLoading ? null : _toggleStatus,
                        child: Text(isActive ? 'Mark Exited' : 'Mark Active'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionHeader('DOCUMENTS', tokens),
            const SizedBox(height: 12),
            ..._buildDocumentTiles(
              tokens: tokens,
              profilePhotoUrl: profilePhotoUrl,
              idProofType: idProofType,
              idProofFrontUrl: idProofFrontUrl,
              idProofBackUrl: idProofBackUrl,
              addressProofType: addressProofType,
              addressProofFrontUrl: addressProofFrontUrl,
              addressProofBackUrl: addressProofBackUrl,
              signatureUrl: signatureUrl,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _actionLoading ? null : _deleteGuard,
                icon: const Icon(Icons.delete_rounded),
                label: const Text('Delete Guard'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.danger,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text, CissThemeTokens tokens) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: tokens.inkMuted,
        letterSpacing: 2,
      ),
    );
  }

  Widget _detailRow(String label, String value, CissThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: tokens.inkMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDocumentTiles({
    required CissThemeTokens tokens,
    required String profilePhotoUrl,
    required String idProofType,
    required String idProofFrontUrl,
    required String idProofBackUrl,
    required String addressProofType,
    required String addressProofFrontUrl,
    required String addressProofBackUrl,
    required String signatureUrl,
  }) {
    final docs = <Widget>[];

    if (profilePhotoUrl.isNotEmpty) {
      docs.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: DocumentListTile(
          name: 'Profile Photo',
          url: profilePhotoUrl,
          fileType: _guessFileType(profilePhotoUrl),
        ),
      ));
    }

    if (idProofFrontUrl.isNotEmpty) {
      docs.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: DocumentListTile(
          name: idProofType.isNotEmpty
              ? '$idProofType (Front)'
              : 'ID Proof (Front)',
          url: idProofFrontUrl,
          fileType: _guessFileType(idProofFrontUrl),
        ),
      ));
    }

    if (idProofBackUrl.isNotEmpty) {
      docs.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: DocumentListTile(
          name: idProofType.isNotEmpty
              ? '$idProofType (Back)'
              : 'ID Proof (Back)',
          url: idProofBackUrl,
          fileType: _guessFileType(idProofBackUrl),
        ),
      ));
    }

    if (addressProofFrontUrl.isNotEmpty) {
      docs.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: DocumentListTile(
          name: addressProofType.isNotEmpty
              ? '$addressProofType (Front)'
              : 'Address Proof (Front)',
          url: addressProofFrontUrl,
          fileType: _guessFileType(addressProofFrontUrl),
        ),
      ));
    }

    if (addressProofBackUrl.isNotEmpty) {
      docs.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: DocumentListTile(
          name: addressProofType.isNotEmpty
              ? '$addressProofType (Back)'
              : 'Address Proof (Back)',
          url: addressProofBackUrl,
          fileType: _guessFileType(addressProofBackUrl),
        ),
      ));
    }

    if (signatureUrl.isNotEmpty) {
      docs.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: DocumentListTile(
          name: 'Signature',
          url: signatureUrl,
          fileType: _guessFileType(signatureUrl),
        ),
      ));
    }

    if (docs.isEmpty) {
      docs.add(ModernCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              'No documents uploaded',
              style: TextStyle(fontSize: 13, color: tokens.inkMuted),
            ),
          ),
        ),
      ));
    }

    return docs;
  }

  String _guessFileType(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.pdf')) return 'pdf';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image';
    if (lower.endsWith('.png')) return 'image';
    if (lower.endsWith('.gif')) return 'image';
    if (lower.endsWith('.webp')) return 'image';
    return 'image';
  }

  Widget _divider(CissThemeTokens tokens) {
    return Divider(height: 16, color: tokens.border.withValues(alpha: 0.3));
  }

  String _formatDate(String value) {
    if (value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }
}
