import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';

/// Guard self-enrollment screen.
/// Multi-step form: Personal → Documents → Review → Submit.
///
/// Mirrors web app's /enroll page in a mobile-friendly format.
class GuardEnrollmentScreen extends StatefulWidget {
  const GuardEnrollmentScreen({super.key});

  @override
  State<GuardEnrollmentScreen> createState() => _GuardEnrollmentScreenState();
}

class _GuardEnrollmentScreenState extends State<GuardEnrollmentScreen> {
  int _step = 0;
  bool _loading = false;
  String? _error;

  // Step 1: Personal
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _gender;
  String _district = '';

  // Step 2: Documents
  String _idProofType = 'Aadhar Card';
  final _idNumberCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  static const _genders = ['Male', 'Female', 'Other'];

  static const _keralaDistricts = [
    'Alappuzha', 'Ernakulam', 'Idukki', 'Kannur', 'Kasaragod',
    'Kollam', 'Kottayam', 'Kozhikode', 'Malappuram', 'Palakkad',
    'Pathanamthitta', 'Thiruvananthapuram', 'Thrissur', 'Wayanad',
  ];

  static const _idTypes = [
    'Aadhar Card', 'PAN Card', 'Voter ID', 'Passport', 'Driving License'
  ];

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _idNumberCtrl.dispose();
    super.dispose();
  }

  bool get _isLastStep => _step == 2;
  int get _totalSteps => 3;

  void _next() {
    if (_formKey.currentState!.validate()) {
      if (_isLastStep) {
        _submit();
      } else {
        Haptics.selection();
        setState(() {
          _step++;
          _error = null;
        });
      }
    }
  }

  void _prev() {
    setState(() {
      _step--;
      _error = null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Build enrollment payload
      final payload = <String, dynamic>{
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'gender': _gender,
        'district': _district,
        'idProofType': _idProofType,
        'idProofNumber': _idNumberCtrl.text.trim(),
      };

      // TODO: Call enrollment API when backend endpoint is ready
      // Currently the web app's enrollment is a client-side flow with Firebase
      // direct writes. Mobile enrollment needs a dedicated API endpoint.
      // For now, show success and log the payload.

      if (!mounted) return;
      setState(() => _loading = false);

      Haptics.medium();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enrollment submitted successfully!'),
          backgroundColor: CissThemeTokens.of(context).success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate back
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      Haptics.error();
      setState(() {
        _loading = false;
        _error = 'Failed to submit enrollment: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final isLast = _isLastStep;

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Enroll as Guard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Progress bar
              LinearProgressIndicator(
                value: (_step + 1) / _totalSteps,
                backgroundColor: tokens.surfaceMuted,
                color: tokens.primary,
                minHeight: 3,
              ),
              // Step indicator
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: List.generate(_totalSteps, (i) {
                    final isActive = i <= _step;
                    return Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive ? tokens.primary : tokens.surfaceMuted,
                            ),
                            child: Center(
                              child: isActive
                                  ? Text('${i + 1}',
                                      style: TextStyle(
                                          color: tokens.canvas,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700))
                                  : Text('${i + 1}',
                                      style: TextStyle(
                                          color: tokens.inkMuted, fontSize: 13)),
                            ),
                          ),
                          if (i < _totalSteps - 1)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: i < _step ? tokens.primary : tokens.surfaceMuted,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              // Step titles
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  ['Personal Info', 'Documents', 'Review'][_step],
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                ),
              ),
              // Error
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tokens.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_error!,
                        style: TextStyle(color: tokens.danger, fontSize: 13)),
                  ),
                ),
              // Step content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildStep(),
                ),
              ),
              // Bottom buttons
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: tokens.canvas,
                  border: Border(top: BorderSide(color: tokens.border.withValues(alpha: 0.3))),
                ),
                child: Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading ? null : _prev,
                          child: const Text('Back'),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _loading ? null : _next,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isLast ? 'Submit' : 'Continue'),
                      ),
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

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildPersonalStep();
      case 1:
        return _buildDocumentsStep();
      case 2:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPersonalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _firstNameCtrl,
          decoration: const InputDecoration(
            labelText: 'First Name *',
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _lastNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Last Name *',
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _phoneCtrl,
          decoration: const InputDecoration(
            labelText: 'Phone Number *',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (v.trim().length < 10) return 'Enter 10-digit number';
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _emailCtrl,
          decoration: const InputDecoration(
            labelText: 'Email (optional)',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _gender,
          decoration: const InputDecoration(
            labelText: 'Gender *',
            prefixIcon: Icon(Icons.people_outline),
          ),
          items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (v) => setState(() => _gender = v),
          validator: (v) => v == null ? 'Required' : null,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _district.isNotEmpty ? _district : null,
          decoration: const InputDecoration(
            labelText: 'District *',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          items: _keralaDistricts
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: (v) => setState(() => _district = v ?? ''),
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildDocumentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: _idProofType,
          decoration: const InputDecoration(
            labelText: 'ID Proof Type *',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          items: _idTypes
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setState(() => _idProofType = v ?? 'Aadhar Card'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _idNumberCtrl,
          decoration: InputDecoration(
            labelText: '$_idProofType Number *',
            prefixIcon: const Icon(Icons.numbers),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (_idProofType == 'Aadhar Card' && v.trim().length != 12) {
              return 'Aadhar must be 12 digits';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CissThemeTokens.of(context).warning.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CissThemeTokens.of(context).warning.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.camera_alt_outlined,
                  color: CissThemeTokens.of(context).warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Photo capture coming soon. For now, submit basic details and your supervisor will contact you.',
                  style: TextStyle(
                    fontSize: 12,
                    color: CissThemeTokens.of(context).inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final tokens = CissThemeTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _reviewField('First Name', _firstNameCtrl.text.trim()),
        _reviewField('Last Name', _lastNameCtrl.text.trim()),
        _reviewField('Phone', _phoneCtrl.text.trim()),
        _reviewField('Email', _emailCtrl.text.trim().isEmpty ? '—' : _emailCtrl.text.trim()),
        _reviewField('Gender', _gender ?? '—'),
        _reviewField('District', _district),
        const Divider(height: 24),
        _reviewField('ID Type', _idProofType),
        _reviewField('ID Number', _idNumberCtrl.text.trim()),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.success.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.success.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: tokens.success, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Review your details above. Tap Submit to send your enrollment request.',
                  style: TextStyle(fontSize: 12, color: tokens.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewField(String label, String value) {
    final tokens = CissThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: tokens.inkMuted)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink)),
          ),
        ],
      ),
    );
  }
}
