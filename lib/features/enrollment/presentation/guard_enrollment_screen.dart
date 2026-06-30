import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';
import '../../../core/network/api_config.dart';

class GuardEnrollmentScreen extends StatefulWidget {
  const GuardEnrollmentScreen({super.key});

  @override
  State<GuardEnrollmentScreen> createState() => _GuardEnrollmentScreenState();
}

class _GuardEnrollmentScreenState extends State<GuardEnrollmentScreen> {
  int _step = 0;
  bool _loading = false;
  String? _error;

  final _formKey = GlobalKey<FormState>();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _fatherNameCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();

  String? _gender;
  String _district = '';
  String? _maritalStatus;
  DateTime? _dateOfBirth;
  String? _educationalQualification;
  String _clientName = '';
  String _idProofType = 'Aadhar Card';
  String _addressProofType = 'Voter ID';

  File? _profilePicture;
  File? _signature;
  File? _idFront;
  File? _idBack;
  File? _addressFront;
  File? _addressBack;

  static const _genders = ['Male', 'Female', 'Other'];
  static const _maritalStatuses = ['Married', 'Unmarried'];
  static const _educationOptions = [
    'Below 10th', '10th Pass', '12th Pass', 'Graduate', 'Post Graduate', 'ITI', 'Diploma', 'Any Other Qualification',
  ];
  static const _keralaDistricts = [
    'Alappuzha', 'Ernakulam', 'Idukki', 'Kannur', 'Kasaragod',
    'Kollam', 'Kottayam', 'Kozhikode', 'Malappuram', 'Palakkad',
    'Pathanamthitta', 'Thiruvananthapuram', 'Thrissur', 'Wayanad',
  ];
  static const _idTypes = ['Aadhar Card', 'PAN Card', 'Voter ID', 'Passport', 'Driving License'];
  static const _clientNames = ['TCS', 'J & K Bank', 'Logiware', 'Geodis India Ltd.'];

  int get _totalSteps => 5;
  bool get _isLastStep => _step == _totalSteps - 1;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _fatherNameCtrl.dispose();
    _motherNameCtrl.dispose();
    _addressCtrl.dispose();
    _idNumberCtrl.dispose();
    _bankAccountCtrl.dispose();
    _ifscCtrl.dispose();
    _bankNameCtrl.dispose();
    super.dispose();
  }

  Future<String> _uploadFile(File file, String folder) async {
    final phone = _phoneCtrl.text.trim();
    final ext = file.path.split('.').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'enrollments/$phone/$folder/${timestamp}_$folder.$ext';

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/public/enroll/upload');
    final request = http.MultipartRequest('POST', uri);
    request.fields['path'] = path;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['url'] as String;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    Haptics.medium();
    setState(() { _loading = true; _error = null; });

    try {
      final profilePicUrl = _profilePicture != null ? await _uploadFile(_profilePicture!, 'profilePictures') : '';
      final signatureUrl = _signature != null ? await _uploadFile(_signature!, 'signatures') : '';
      final idFrontUrl = _idFront != null ? await _uploadFile(_idFront!, 'idProofs') : '';
      final idBackUrl = _idBack != null ? await _uploadFile(_idBack!, 'idProofs') : '';
      final addrFrontUrl = _addressFront != null ? await _uploadFile(_addressFront!, 'addressProofs') : '';
      final addrBackUrl = _addressBack != null ? await _uploadFile(_addressBack!, 'addressProofs') : '';

      final payload = <String, dynamic>{
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'emailAddress': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'fatherName': _fatherNameCtrl.text.trim(),
        'motherName': _motherNameCtrl.text.trim(),
        'gender': _gender,
        'maritalStatus': _maritalStatus,
        'dateOfBirth': _dateOfBirth?.toIso8601String(),
        'educationalQualification': _educationalQualification,
        'district': _district,
        'clientName': _clientName,
        'fullAddress': _addressCtrl.text.trim(),
        'identityProofType': _idProofType,
        'identityProofNumber': _idNumberCtrl.text.trim(),
        'identityProofUrlFront': idFrontUrl,
        'identityProofUrlBack': idBackUrl,
        'addressProofType': _addressProofType,
        'addressProofNumber': _idNumberCtrl.text.trim(),
        'addressProofUrlFront': addrFrontUrl,
        'addressProofUrlBack': addrBackUrl,
        'profilePictureUrl': profilePicUrl,
        'signatureUrl': signatureUrl,
        'bankAccountNumber': _bankAccountCtrl.text.trim().isEmpty ? null : _bankAccountCtrl.text.trim(),
        'ifscCode': _ifscCtrl.text.trim().isEmpty ? null : _ifscCtrl.text.trim(),
        'bankName': _bankNameCtrl.text.trim().isEmpty ? null : _bankNameCtrl.text.trim(),
        'joiningDate': DateTime.now().toIso8601String(),
        'termsAccepted': true,
      };

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/employees/enroll');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Haptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Enrolled successfully!'),
            backgroundColor: CissThemeTokens.of(context).success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(body['error'] ?? 'Enrollment failed (HTTP ${response.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      Haptics.error();
      setState(() => _error = 'Failed to submit enrollment: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final stepLabels = ['Client', 'Personal', 'Documents', 'Bank', 'Review'];

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
              LinearProgressIndicator(
                value: (_step + 1) / _totalSteps,
                backgroundColor: tokens.surfaceMuted,
                color: tokens.primary,
                minHeight: 3,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: List.generate(_totalSteps, (i) {
                    final isActive = i <= _step;
                    return Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive ? tokens.primary : tokens.surfaceMuted,
                            ),
                            child: Center(
                              child: Text('${i + 1}',
                                style: TextStyle(color: isActive ? tokens.canvas : tokens.inkMuted, fontSize: 13, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          if (i < _totalSteps - 1)
                            Expanded(child: Container(height: 2, color: i < _step ? tokens.primary : tokens.surfaceMuted)),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  stepLabels[_step],
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: tokens.ink),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tokens.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_error!, style: TextStyle(color: tokens.danger, fontSize: 13)),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildStep()),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: tokens.canvas,
                  border: Border(top: BorderSide(color: tokens.border.withValues(alpha: 0.3))),
                ),
                child: Row(children: [
                  if (_step > 0)
                    Expanded(child: OutlinedButton(onPressed: _loading ? null : () => setState(() { _step--; _error = null; }), child: const Text('Back'))),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _loading ? null : () {
                        if (_formKey.currentState!.validate()) {
                          if (_isLastStep) { _submit(); } else { Haptics.selection(); setState(() { _step++; _error = null; }); }
                        }
                      },
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isLastStep ? 'Submit' : 'Continue'),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _buildClientStep();
      case 1: return _buildPersonalStep();
      case 2: return _buildDocumentsStep();
      case 3: return _buildBankStep();
      case 4: return _buildReviewStep();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildClientStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DropdownButtonFormField<String>(
        value: _clientName.isEmpty ? null : _clientName,
        decoration: const InputDecoration(labelText: 'Client *', prefixIcon: Icon(Icons.business)),
        items: _clientNames.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() => _clientName = v ?? ''),
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: _district.isEmpty ? null : _district,
        decoration: const InputDecoration(labelText: 'District *', prefixIcon: Icon(Icons.map)),
        items: _keralaDistricts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
        onChanged: (v) => setState(() => _district = v ?? ''),
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      ),
    ]);
  }

  Widget _buildPersonalStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: TextFormField(
          controller: _firstNameCtrl, decoration: const InputDecoration(labelText: 'First Name *', prefixIcon: Icon(Icons.person_outline)),
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        )),
        const SizedBox(width: 12),
        Expanded(child: TextFormField(
          controller: _lastNameCtrl, decoration: const InputDecoration(labelText: 'Last Name *', prefixIcon: Icon(Icons.person_outline)),
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        )),
      ]),
      const SizedBox(height: 14),
      TextFormField(
        controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone *', prefixIcon: Icon(Icons.phone), hintText: '10-digit mobile'),
        keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
        validator: (v) => (v == null || v.trim().length != 10) ? '10 digits required' : null,
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: TextFormField(
          controller: _fatherNameCtrl, decoration: const InputDecoration(labelText: "Father's Name *", prefixIcon: Icon(Icons.person)),
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        )),
        const SizedBox(width: 12),
        Expanded(child: TextFormField(
          controller: _motherNameCtrl, decoration: const InputDecoration(labelText: "Mother's Name *", prefixIcon: Icon(Icons.person)),
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        )),
      ]),
      const SizedBox(height: 14),
      TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Date of Birth *',
          prefixIcon: const Icon(Icons.calendar_today),
          hintText: _dateOfBirth != null ? DateFormat('dd-MM-yyyy').format(_dateOfBirth!) : 'Tap to select',
        ),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _dateOfBirth ?? DateTime(1990, 1, 1),
            firstDate: DateTime(1950),
            lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
          );
          if (picked != null) setState(() => _dateOfBirth = picked);
        },
        validator: (_) => _dateOfBirth == null ? 'Required' : null,
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: 'Gender *', prefixIcon: Icon(Icons.wc)),
        items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
        onChanged: (v) => setState(() => _gender = v),
        validator: (v) => v == null ? 'Required' : null,
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: 'Marital Status *', prefixIcon: Icon(Icons.favorite_border)),
        items: _maritalStatuses.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
        onChanged: (v) => setState(() => _maritalStatus = v),
        validator: (v) => v == null ? 'Required' : null,
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: 'Education *', prefixIcon: Icon(Icons.school)),
        items: _educationOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) => setState(() => _educationalQualification = v),
        validator: (v) => v == null ? 'Required' : null,
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Full Address *', prefixIcon: Icon(Icons.home)),
        maxLines: 3, textCapitalization: TextCapitalization.sentences,
        validator: (v) => (v == null || v.trim().length < 10) ? 'Min 10 characters' : null,
      ),
      const SizedBox(height: 14),
      _buildImageField('Profile Photo', _profilePicture, (f) => setState(() => _profilePicture = f)),
    ]);
  }

  Widget _buildDocumentsStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DropdownButtonFormField<String>(
        value: _idProofType,
        decoration: const InputDecoration(labelText: 'ID Proof Type *', prefixIcon: Icon(Icons.badge)),
        items: _idTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: (v) => setState(() => _idProofType = v ?? _idProofType),
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _idNumberCtrl, decoration: const InputDecoration(labelText: 'ID Proof Number *', prefixIcon: Icon(Icons.tag)),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 14),
      _buildImageField('ID Proof Front', _idFront, (f) => setState(() => _idFront = f)),
      const SizedBox(height: 14),
      _buildImageField('ID Proof Back', _idBack, (f) => setState(() => _idBack = f)),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: _addressProofType,
        decoration: const InputDecoration(labelText: 'Address Proof Type *', prefixIcon: Icon(Icons.map)),
        items: _idTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: (v) => setState(() => _addressProofType = v ?? _addressProofType),
      ),
      const SizedBox(height: 14),
      _buildImageField('Address Proof Front', _addressFront, (f) => setState(() => _addressFront = f)),
      const SizedBox(height: 14),
      _buildImageField('Address Proof Back', _addressBack, (f) => setState(() => _addressBack = f)),
      const SizedBox(height: 14),
      _buildImageField('Signature', _signature, (f) => setState(() => _signature = f)),
    ]);
  }

  Widget _buildBankStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextFormField(
        controller: _bankAccountCtrl, decoration: const InputDecoration(labelText: 'Bank Account Number', prefixIcon: Icon(Icons.account_balance), hintText: 'Optional'),
        keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _ifscCtrl, decoration: const InputDecoration(labelText: 'IFSC Code', prefixIcon: Icon(Icons.tag), hintText: 'Optional'),
        textCapitalization: TextCapitalization.characters,
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _bankNameCtrl, decoration: const InputDecoration(labelText: 'Bank Name', prefixIcon: Icon(Icons.business), hintText: 'Optional'),
        textCapitalization: TextCapitalization.words,
      ),
    ]);
  }

  Widget _buildReviewStep() {
    final tokens = CissThemeTokens.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _reviewRow(tokens, 'Name', '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'),
      _reviewRow(tokens, 'Phone', _phoneCtrl.text.trim()),
      _reviewRow(tokens, 'Client', _clientName),
      _reviewRow(tokens, 'District', _district),
      _reviewRow(tokens, 'Gender', _gender ?? ''),
      _reviewRow(tokens, 'DOB', _dateOfBirth != null ? DateFormat('dd-MM-yyyy').format(_dateOfBirth!) : ''),
      _reviewRow(tokens, 'Documents', '$_idProofType / $_addressProofType'),
      const SizedBox(height: 16),
      Text(
        'By submitting you confirm that all information provided is accurate.',
        style: TextStyle(fontSize: 12, color: tokens.inkMuted, fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      ),
    ]);
  }

  Widget _reviewRow(CissThemeTokens tokens, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 13, color: tokens.inkMuted, fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: tokens.ink))),
      ]),
    );
  }

  Widget _buildImageField(String label, File? current, ValueChanged<File?> onPicked) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 13, color: CissThemeTokens.of(context).inkMuted)),
      const SizedBox(height: 6),
      Row(children: [
        if (current != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(current, width: 64, height: 64, fit: BoxFit.cover),
            ),
          ),
        TextButton.icon(
          onPressed: () => _pickImageFromGallery(onPicked),
          icon: const Icon(Icons.photo_library, size: 18),
          label: const Text('Gallery'),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => _pickImageFromCamera(onPicked),
          icon: const Icon(Icons.camera_alt, size: 18),
          label: const Text('Camera'),
        ),
        if (current != null)
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => onPicked(null),
          ),
      ]),
      const SizedBox(height: 14),
    ]);
  }

  Future<void> _pickImageFromGallery(ValueChanged<File?> onPicked) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 70);
    if (picked != null) onPicked(File(picked.path));
  }

  Future<void> _pickImageFromCamera(ValueChanged<File?> onPicked) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024, imageQuality: 70);
    if (picked != null) onPicked(File(picked.path));
  }
}
