import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../shared/utils/initials.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

class ClientGuardDetailScreen extends ConsumerStatefulWidget {
  const ClientGuardDetailScreen({super.key, required this.employeeId});

  final String employeeId;

  @override
  ConsumerState<ClientGuardDetailScreen> createState() =>
      _ClientGuardDetailScreenState();
}

class _ClientGuardDetailScreenState
    extends ConsumerState<ClientGuardDetailScreen> {
  Map<String, dynamic>? _guard;
  bool _loading = true;
  String? _error;

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

  Future<void> _downloadDocument(String? url, String label) async {
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label not available')),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open document')),
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
    final name =
        guard['name']?.toString() ?? guard['fullName']?.toString() ?? '';
    final status = guard['status']?.toString() ?? 'Active';
    final isActive = status.toLowerCase() == 'active';
    final employeeId = guard['employeeId']?.toString() ?? widget.employeeId;
    final clientName = guard['clientName']?.toString() ?? '';
    final district = guard['district']?.toString() ?? '';
    final siteName = guard['siteName']?.toString() ?? '';
    final phone = guard['phoneNumber']?.toString() ?? '';
    final email = guard['email']?.toString() ?? '';
    final address = guard['address']?.toString() ?? '';
    final doj = guard['dateOfJoining']?.toString() ??
        guard['createdAt']?.toString() ??
        '';
    final photoUrl = guard['profilePhotoUrl']?.toString() ??
        guard['photoUrl']?.toString() ??
        '';
    final idProofUrl = guard['idProofUrl']?.toString() ?? '';
    final addressProofUrl = guard['addressProofUrl']?.toString() ?? '';

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Guard Detail'),
        backgroundColor: tokens.canvas,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchGuard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ModernHero(
              eyebrow: employeeId,
              title: name,
              subtitle: '$status \u2022 $clientName',
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
                  if (employeeId.isNotEmpty)
                    _detailRow('Employee ID', employeeId, tokens),
                  if (phone.isNotEmpty) _divider(tokens),
                  if (phone.isNotEmpty) _detailRow('Phone', phone, tokens),
                  if (email.isNotEmpty) _divider(tokens),
                  if (email.isNotEmpty) _detailRow('Email', email, tokens),
                  if (address.isNotEmpty) _divider(tokens),
                  if (address.isNotEmpty)
                    _detailRow('Address', address, tokens),
                  if (doj.isNotEmpty) _divider(tokens),
                  if (doj.isNotEmpty)
                    _detailRow('Date of Joining', _formatDate(doj), tokens),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionHeader('ASSIGNMENT', tokens),
            const SizedBox(height: 12),
            ModernCard(
              child: Column(
                children: [
                  _detailRow(
                      'Client', clientName.isNotEmpty ? clientName : '\u2014', tokens),
                  _divider(tokens),
                  _detailRow(
                      'Site', siteName.isNotEmpty ? siteName : '\u2014', tokens),
                  _divider(tokens),
                  _detailRow(
                      'District', district.isNotEmpty ? district : '\u2014', tokens),
                  _divider(tokens),
                  Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          'Status',
                          style:
                              TextStyle(fontSize: 13, color: tokens.inkMuted),
                        ),
                      ),
                      StatusChip(
                        label: isActive ? 'Active' : status,
                        tone: isActive
                            ? StatusChipTone.success
                            : StatusChipTone.neutral,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionHeader('DOCUMENTS', tokens),
            const SizedBox(height: 12),
            ModernCard(
              child: Column(
                children: [
                  _docRow(
                    Icons.photo_camera_rounded,
                    'Profile Photo',
                    photoUrl,
                    tokens,
                  ),
                  _divider(tokens),
                  _docRow(
                    Icons.badge_rounded,
                    'ID Proof',
                    idProofUrl,
                    tokens,
                  ),
                  _divider(tokens),
                  _docRow(
                    Icons.home_rounded,
                    'Address Proof',
                    addressProofUrl,
                    tokens,
                  ),
                ],
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

  Widget _docRow(
      IconData icon, String label, String? url, CissThemeTokens tokens) {
    final hasDoc = url != null && url.isNotEmpty;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: tokens.primary),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: hasDoc
          ? Text(
              'Tap to download',
              style: TextStyle(fontSize: 12, color: tokens.inkMuted),
            )
          : Text(
              'Not uploaded',
              style: TextStyle(fontSize: 12, color: tokens.inkMuted),
            ),
      trailing: Icon(
        hasDoc ? Icons.download_rounded : Icons.block_rounded,
        color: hasDoc ? tokens.primary : tokens.inkMuted,
      ),
      onTap: hasDoc ? () => _downloadDocument(url, label) : null,
    );
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
