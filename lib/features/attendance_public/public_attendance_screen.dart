import 'dart:io';

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';
import '../../../core/models/attendance_models.dart';
import '../../../core/network/providers.dart';
import '../../../core/sync/providers.dart';
import '../../../shared/widgets/camera_capture_screen.dart';
import '../../../shared/widgets/state_block.dart';

enum _PublicAttendanceStep { identify, details, submit }

class PublicAttendanceScreen extends ConsumerStatefulWidget {
  const PublicAttendanceScreen({super.key});

  @override
  ConsumerState<PublicAttendanceScreen> createState() =>
      _PublicAttendanceScreenState();
}

class _PublicAttendanceScreenState
    extends ConsumerState<PublicAttendanceScreen> {
  static const Uuid _uuid = Uuid();

  _PublicAttendanceStep _step = _PublicAttendanceStep.identify;

  // Identification
  final _empIdCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _resourceCtrl = TextEditingController();
  String _lookupError = '';
  bool _isLookingUp = false;

  // Attendance details
  PublicAttendanceEmployeeModel? _employee;
  SiteOptionModel? _selectedSite;
  List<SiteOptionModel> _sites = [];
  String _status = 'In';
  String? _photoPath;
  Position? _position;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _empIdCtrl.dispose();
    _phoneCtrl.dispose();
    _resourceCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupGuard() async {
    final id = _empIdCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final rid = _resourceCtrl.text.trim();
    if (id.isEmpty && phone.isEmpty && rid.isEmpty) {
      setState(() => _lookupError = 'Enter employee ID, phone number, or resource ID');
      return;
    }
    setState(() {
      _isLookingUp = true;
      _lookupError = '';
    });
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final employee = await repo.fetchAttendanceEmployee(id, phone, rid);
      if (employee == null) {
        setState(() {
          _lookupError = 'No guard found with that information.';
          _isLookingUp = false;
        });
        return;
      }
      final sites = await repo.fetchAttendanceSites();
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {}
      SiteOptionModel? nearest;
      if (position != null && sites.isNotEmpty) {
        double best = double.infinity;
        for (final site in sites) {
          if (site.lat == null || site.lng == null) continue;
          final dist = Geolocator.distanceBetween(
            position.latitude, position.longitude,
            site.lat!, site.lng!,
          );
          if (dist < best) { best = dist; nearest = site; }
        }
      }
      final status = employee.attendanceHint?.lastStatus == 'In' ? 'Out' : 'In';
      if (!mounted) return;
      setState(() {
        _employee = employee;
        _sites = sites;
        _selectedSite = nearest ?? (sites.isNotEmpty ? sites.first : null);
        _position = position;
        _status = status;
        _isLookingUp = false;
        _step = _PublicAttendanceStep.details;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lookupError = 'Lookup failed. ${e.toString().replaceFirst("Exception: ", "")}';
        _isLookingUp = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    final file = await CameraCaptureScreen.capture();
    if (file != null && mounted) {
      setState(() => _photoPath = file.path);
    }
  }

  Future<void> _submit() async {
    if (_employee == null || _selectedSite == null || _photoPath == null) {
      setState(() => _submitError = 'Guard, site, and photo are required.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final photoFile = File(_photoPath!);
      final bytes = await photoFile.readAsBytes();
      final mimeType = 'image/jpeg';
      final dataUrl = await repo.encodeFileToDataUrl(bytes.toList(), mimeType);

      // Upload photo
      final ownerKey = _employee!.id.replaceAll(RegExp(r'[^0-9A-Za-z_-]'), '_');
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = 'employees/$ownerKey/attendance/${ts}_attendance.jpg';
      final uploadResp = await repo.uploadAttendancePhoto(
        path: path,
        dataUrl: dataUrl,
        siteId: _selectedSite!.id,
      );
      final photoUrl = uploadResp['url'] as String;

      final pos = _position;
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final payload = <String, dynamic>{
        'employeeId': _employee!.employeeCode ?? _employee!.id,
        'employeeDocId': _employee!.id,
        'employeeName': _employee!.fullName,
        'employeePhoneNumber': _employee!.phoneNumber ?? '',
        'employeeClientName': _employee!.clientName ?? '',
        'clientName': _selectedSite!.clientName,
        'status': _status,
        'district': _selectedSite!.district,
        'siteId': _selectedSite!.id,
        'siteName': _selectedSite!.siteName,
        'sourceCollection': 'sites',
        'siteCoords': {
          'lat': _selectedSite!.lat,
          'lng': _selectedSite!.lng,
        },
        'locationText': pos != null
            ? 'Lat: ${pos.latitude.toStringAsFixed(4)}, Lon: ${pos.longitude.toStringAsFixed(4)}'
            : '',
        'locationCoords': pos != null
            ? {
                'lat': pos.latitude,
                'lon': pos.longitude,
                'accuracyMeters': pos.accuracy,
              }
            : {'lat': 0, 'lon': 0, 'accuracyMeters': 0},
        'distanceMeters': pos != null && _selectedSite!.lat != null
            ? Geolocator.distanceBetween(
                pos.latitude, pos.longitude,
                _selectedSite!.lat!, _selectedSite!.lng!,
              ).round()
            : 0,
        'gpsAccuracyMeters': pos?.accuracy.round(),
        'geofenceRadiusAtTime': _selectedSite!.geofenceRadiusMeters ?? 150,
        'photoUrl': photoUrl,
        'photoCapturedAt': DateTime.now().toUtc().toIso8601String(),
        'clientRequestId': _uuid.v4(),
        'reportedAtClient': DateTime.now().toUtc().toIso8601String(),
        'deviceInfo': {'userAgent': 'flutter-mobile-public'},
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
        'attendanceDate': dateStr,
      };

      await repo.submitAttendance(payload);

      if (!mounted) return;
      Haptics.success();
      setState(() {
        _isSubmitting = false;
        _step = _PublicAttendanceStep.submit;
      });
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        final payload = <String, dynamic>{
          'employeeId': _employee!.employeeCode ?? _employee!.id,
          'employeeDocId': _employee!.id,
          'employeeName': _employee!.fullName,
          'status': _status,
          'siteId': _selectedSite!.id,
        };
        await ref.read(offlineQueueProvider).enqueue(
          path: '/api/attendance/submit',
          method: 'POST',
          body: payload,
        );
        if (!mounted) return;
        Haptics.success();
        setState(() {
          _isSubmitting = false;
          _step = _PublicAttendanceStep.submit;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _submitError = e.message ?? 'Submission failed.';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.toString().replaceFirst('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Record Attendance'),
        centerTitle: true,
      ),
      body: switch (_step) {
        _PublicAttendanceStep.identify => _buildIdentifyStep(tokens),
        _PublicAttendanceStep.details => _buildDetailsStep(tokens),
        _PublicAttendanceStep.submit => _buildConfirmation(tokens),
      },
    );
  }

  Widget _buildIdentifyStep(CissThemeTokens tokens) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.fact_check_rounded, size: 48, color: tokens.primary),
        const SizedBox(height: 16),
        Text('Identify Guard',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tokens.ink)),
        const SizedBox(height: 8),
        Text('Enter employee ID, phone number, or resource ID',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: tokens.inkMuted)),
        const SizedBox(height: 32),
        TextField(
          controller: _empIdCtrl,
          decoration: const InputDecoration(
            labelText: 'Employee ID (e.g. CISS/TCS/...)',
            prefixIcon: Icon(Icons.badge_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR', style: TextStyle(fontSize: 11, color: tokens.inkMuted)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: const InputDecoration(
            labelText: 'Phone number (10 digits)',
            prefixIcon: Icon(Icons.phone_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR', style: TextStyle(fontSize: 11, color: tokens.inkMuted)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _resourceCtrl,
          decoration: const InputDecoration(
            labelText: 'Resource ID',
            prefixIcon: Icon(Icons.qr_code_rounded),
          ),
        ),
        if (_lookupError.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_lookupError, style: TextStyle(color: tokens.danger, fontSize: 13)),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _isLookingUp ? null : _lookupGuard,
            child: _isLookingUp
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Look Up', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsStep(CissThemeTokens tokens) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_employee != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.border),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: tokens.primary.withValues(alpha: 0.15),
                  child: Text(
                    _employee!.fullName.isNotEmpty
                        ? _employee!.fullName[0].toUpperCase()
                        : 'G',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: tokens.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(_employee!.fullName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tokens.ink)),
                if (_employee!.employeeCode != null)
                  Text(_employee!.employeeCode!, style: TextStyle(fontSize: 12, color: tokens.inkMuted)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (_sites.isNotEmpty) ...[
          DropdownButtonFormField<SiteOptionModel>(
            value: _selectedSite,
            decoration: const InputDecoration(
              labelText: 'Site',
              prefixIcon: Icon(Icons.location_on_rounded),
            ),
            items: _sites.map((s) => DropdownMenuItem(
              value: s,
              child: Text(s.siteName, overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: (v) => setState(() => _selectedSite = v),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'In', label: Text('IN'), icon: Icon(Icons.login_rounded, size: 16)),
                  ButtonSegment(value: 'Out', label: Text('OUT'), icon: Icon(Icons.logout_rounded, size: 16)),
                ],
                selected: {_status},
                onSelectionChanged: (v) => setState(() => _status = v.first),
                showSelectedIcon: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('PHOTO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.inkMuted, letterSpacing: 1)),
        const SizedBox(height: 8),
        if (_photoPath != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(_photoPath!), height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _photoPath = null),
                  child: Container(
                    decoration: const BoxDecoration(Colors.black54, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ] else
          GestureDetector(
            onTap: _takePhoto,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: tokens.surfaceStrong,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.border, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_rounded, size: 36, color: tokens.inkMuted),
                  const SizedBox(height: 8),
                  Text('Tap to take photo', style: TextStyle(color: tokens.inkMuted, fontSize: 13)),
                ],
              ),
            ),
          ),
        if (_submitError != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_submitError!, style: TextStyle(color: tokens.danger, fontSize: 13)),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit Attendance', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmation(CissThemeTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: StateBlock(
          icon: Icons.check_circle_rounded,
          title: 'Attendance Recorded',
          message: '${_employee?.fullName ?? "Guard"} — $_status',
          action: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ),
      ),
    );
  }
}
