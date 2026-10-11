import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/models/guard_profile.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../app/theme/app_tokens.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';

/// Identity proof types accepted by the backend (`IDENTITY_PROOF_TYPES`).
const List<String> kIdentityProofTypes = <String>[
  'PAN Card',
  'Voter ID',
  'Passport',
  'Driving License',
  'Government Photo ID',
];

/// Address proof types accepted by the backend (`ADDRESS_PROOF_TYPES`).
const List<String> kAddressProofTypes = <String>[
  'Voter ID',
  'Passport',
  'Driving License',
  'Residence Certificate',
  'Utility Bill',
  'Bank Statement',
];

/// Aadhaar consent notice shown ahead of upload (mirrors the web copy).
const String kAadhaarConsentText =
    'I voluntarily provide my Aadhaar copy and Aadhaar information to CISS for '
    'the limited purpose of completing and administering my registration, '
    'correction, seeding and statutory obligations with ESIC and EPFO. I '
    'authorize designated CISS personnel to submit this information through '
    'the official ESIC and EPFO systems. CISS shall not use my Aadhaar for '
    'client registration or disclose my Aadhaar copy to a client.';

const double _kMaxFileBytes = 5 * 1024 * 1024;

/// Screen that shows which enrolment documents are still missing and lets the
/// guard upload them from their phone (Aadhaar / identity / address).
class GuardDocumentUploadScreen extends ConsumerWidget {
  const GuardDocumentUploadScreen({super.key, required this.profile});

  final GuardProfileModel profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final entries = <_UploadEntry>[
      if (profile.canUploadAadhaar)
        const _UploadEntry(
          key: 'aadhaar',
          title: 'Aadhaar card',
          subtitle: 'Aadhaar copy for ESIC / EPF registration',
          icon: Icons.perm_identity_rounded,
        ),
      if (profile.canUploadIdentity)
        const _UploadEntry(
          key: 'identity',
          title: 'Identity proof',
          subtitle: 'PAN, Voter ID, Passport, etc.',
          icon: Icons.badge_rounded,
        ),
      if (profile.canUploadAddress)
        const _UploadEntry(
          key: 'address',
          title: 'Address proof',
          subtitle: 'Utility bill, bank statement, etc.',
          icon: Icons.home_work_rounded,
        ),
    ];

    return ScreenScaffold(
      title: 'Upload documents',
      subtitle: 'Missing enrolment documents',
      children: <Widget>[
        if (entries.isEmpty)
          ModernCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: <Widget>[
                  Icon(
                    Icons.verified_user_rounded,
                    size: 40,
                    color: tokens.success,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'All documents are on file.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Contact the administrator if a correction is needed.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ModernCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  leading: Icon(entry.icon, color: tokens.primary),
                  title: Text(
                    entry.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(entry.subtitle,
                      style: TextStyle(color: tokens.inkMuted)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _GuardDocumentUploadForm(
                        category: entry.key,
                        profile: profile,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UploadEntry {
  const _UploadEntry({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
}

// ═══════════════════════════════════════════════════════════════════════════
// Upload form
// ═══════════════════════════════════════════════════════════════════════════

class _GuardDocumentUploadForm extends ConsumerStatefulWidget {
  const _GuardDocumentUploadForm({
    required this.category,
    required this.profile,
  });

  final String category;
  final GuardProfileModel profile;

  @override
  ConsumerState<_GuardDocumentUploadForm> createState() =>
      _GuardDocumentUploadFormState();
}

class _GuardDocumentUploadFormState
    extends ConsumerState<_GuardDocumentUploadForm> {
  final _documentNumber = TextEditingController();
  final _aadhaarNumber = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _documentType;
  bool _consentAccepted = false;
  DocumentUploadFile? _front;
  DocumentUploadFile? _back;
  String? _error;
  bool _submitting = false;
  bool _succeeded = false;

  bool get _isAadhaar => widget.category == 'aadhaar';

  @override
  void dispose() {
    _documentNumber.dispose();
    _aadhaarNumber.dispose();
    super.dispose();
  }

  Future<void> _pickFront() async {
    final file = await _pickDocument();
    if (file != null && mounted) setState(() => _front = file);
  }

  Future<void> _pickBack() async {
    final file = await _pickDocument();
    if (file != null && mounted) setState(() => _back = file);
  }

  Future<DocumentUploadFile?> _pickDocument() async {
    try {
      // Allow image or PDF (backend accepts JPEG/PNG/PDF ≤ 5 MB).
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'pdf'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.first;
      final path = file.path;
      if (path == null || path.isEmpty) {
        throw StateError('Could not resolve picked file path.');
      }
      if (await File(path).length() > _kMaxFileBytes) {
        throw StateError('Document must be no larger than 5 MB.');
      }
      return DocumentUploadFile(
        path: path,
        name: file.name.isEmpty ? 'document.${_extensionOf(path)}' : file.name,
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
      return null;
    }
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    return dot < 0 ? 'jpg' : path.substring(dot + 1);
  }

  Future<void> _takeFrontPhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        setState(
          () => _front = DocumentUploadFile(
            path: picked.path,
            name: picked.name.isEmpty ? 'aadhaar.jpg' : picked.name,
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not capture photo: $error');
    }
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(mobileRepositoryProvider).uploadGuardDocument(
            category: widget.category,
            documentType: _isAadhaar ? null : _documentType,
            documentNumber: _isAadhaar ? null : _documentNumber.text.trim(),
            aadhaarNumber: _isAadhaar ? _aadhaarNumber.text.trim() : null,
            front: _front!,
            back: _back,
          );
      if (mounted) setState(() => _succeeded = true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validate() {
    if (_isAadhaar) {
      if (!_consentAccepted) {
        return 'Please accept the Aadhaar consent to continue.';
      }
      if (!RegExp(r'^\d{12}$').hasMatch(_aadhaarNumber.text.trim())) {
        return 'Enter a valid 12-digit Aadhaar number.';
      }
      if (_front == null) return 'Aadhaar copy is required.';
      return null;
    }
    if (_documentType == null) return 'Select the document type.';
    if (_documentNumber.text.trim().isEmpty) {
      return 'Document number is required.';
    }
    if (_front == null) return 'Front copy is required.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.category) {
      'aadhaar' => 'Upload Aadhaar',
      'identity' => 'Upload ID proof',
      'address' => 'Upload address proof',
      _ => 'Upload document',
    };

    return ScreenScaffold(
      title: title,
      children: <Widget>[
        if (_succeeded)
          _buildSuccess(context)
        else ...[
          if (_isAadhaar) _buildConsentCard(context),
          if (!_isAadhaar) _buildTypeSelector(context),
          if (!_isAadhaar)
            _buildTextField(
              context,
              controller: _documentNumber,
              label: 'Document number',
              icon: Icons.tag_rounded,
            ),
          if (_isAadhaar)
            _buildTextField(
              context,
              controller: _aadhaarNumber,
              label: 'Aadhaar number',
              icon: Icons.perm_identity_rounded,
              keyboardType: TextInputType.number,
              maxLength: 12,
            ),
          const SizedBox(height: AppSpacing.sm),
          _buildFilePickerCard(
            context,
            title: 'Front copy',
            value: _front,
            onPick: _pickFront,
            onCamera: _isAadhaar ? _takeFrontPhoto : null,
            required: true,
          ),
          if (!_isAadhaar)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _buildFilePickerCard(
                context,
                title: 'Back copy (optional)',
                value: _back,
                onPick: _pickBack,
                required: false,
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(_error!, style: TextStyle(color: _danger(context))),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Upload document'),
          ),
        ],
      ],
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            Icon(Icons.check_circle_rounded, size: 48, color: tokens.success),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Document uploaded',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'It is now pending review. The administrator will verify it.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentCard(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.lock_rounded, color: tokens.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Limited Aadhaar consent',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              kAadhaarConsentText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.inkMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Checkbox(
                  value: _consentAccepted,
                  activeColor: tokens.primary,
                  onChanged: (value) =>
                      setState(() => _consentAccepted = value ?? false),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'I consent to this limited Aadhaar use for ESIC and EPF.',
                      style: TextStyle(fontSize: 14, height: 1.25),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final options = widget.category == 'identity'
        ? kIdentityProofTypes
        : kAddressProofTypes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _fieldLabel(context, 'Document type'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children:
              options
                  .map(
                    (option) => ChoiceChip(
                      label: Text(option),
                      selected: _documentType == option,
                      selectedColor: tokens.primarySoft,
                      labelStyle: TextStyle(
                        color: _documentType == option
                            ? tokens.primaryStrong
                            : tokens.inkMuted,
                        fontWeight: _documentType == option
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      onSelected: (_) => setState(() => _documentType = option),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildFilePickerCard(
    BuildContext context, {
    required String title,
    required DocumentUploadFile? value,
    required VoidCallback onPick,
    VoidCallback? onCamera,
    required bool required,
  }) {
    final tokens = CissThemeTokens.of(context);
    return ModernCard(
      child: ListTile(
        leading: Icon(
          value == null ? Icons.attach_file_rounded : Icons.check_circle,
          color: value == null ? tokens.inkMuted : tokens.success,
        ),
        title: Text(
          value == null ? '$title (optional)' : value.name,
          style: TextStyle(
            color: value == null ? tokens.inkMuted : tokens.ink,
            fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
        subtitle: value == null
            ? const Text('JPEG, PNG or PDF · max 5 MB')
            : const Text('Ready to upload'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (onCamera != null)
              IconButton(
                onPressed: onCamera,
                icon: const Icon(Icons.photo_camera_rounded),
                tooltip: 'Take photo',
              ),
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Pick'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(BuildContext context, String text) {
    final tokens = CissThemeTokens.of(context);
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: tokens.inkMuted,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Minimal helpers
// ═════════════════════════════════════════════════════════════════════════

Color? _danger(BuildContext context) => CissThemeTokens.of(context).danger;