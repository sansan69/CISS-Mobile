import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';
import '../../../core/models/attendance_models.dart';
import '../../../core/network/providers.dart';
import '../../../core/sync/providers.dart';
import '../../../core/qr/qr_parser.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/camera_capture_screen.dart';
import '../../../core/location/live_location_service.dart';
import '../../../core/fcm/providers.dart';

enum _QrFlowStep { scan, action, confirmation }

class QrAttendanceFlow extends ConsumerStatefulWidget {
  const QrAttendanceFlow({super.key});

  @override
  ConsumerState<QrAttendanceFlow> createState() => _QrAttendanceFlowState();
}

class _QrAttendanceFlowState extends ConsumerState<QrAttendanceFlow> {
  static const Uuid _uuid = Uuid();

  _QrFlowStep _step = _QrFlowStep.scan;

  PublicAttendanceEmployeeModel? _employee;
  SiteOptionModel? _selectedSite;
  String? _error;
  bool _loading = false;

  String _attendanceStatus = 'In';
  DateTime? _attendanceTime;
  String? _photoPath;
  String? _photoDataUrl; // base64 data URL for offline queue

  MobileScannerController? _scannerController;
  DateTime? _lastScannedAt;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _QrFlowStep.scan || _step == _QrFlowStep.confirmation,
      onPopInvokedWithResult: (didPop, _) {
        if (_step == _QrFlowStep.action && !didPop) {
          _showExitConfirmation();
        }
      },
      child: Scaffold(
        body: switch (_step) {
          _QrFlowStep.scan => _buildScanner(),
          _QrFlowStep.action => _buildAction(),
          _QrFlowStep.confirmation => _buildConfirmation(),
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Scanner
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildScanner() {
    final tokens = CissThemeTokens.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            // Debounce: ignore repeated detections of the same QR within 3s
            if (_loading) return;
            if (_lastScannedAt != null &&
                DateTime.now().difference(_lastScannedAt!).inSeconds < 3) {
              return;
            }
            final barcode = capture.barcodes.firstOrNull;
            if (barcode?.rawValue == null) return;
            _lastScannedAt = DateTime.now();
            _onQrDetected(barcode!.rawValue!);
          },
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        _loading
                            ? tokens.warning
                            : Colors.white.withValues(alpha: 0.7),
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Column(
                  children: [
                    if (_loading)
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    else ...[
                      const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white70,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Align QR code within the frame',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.danger.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed:
                            () => setState(() {
                              _error = null;
                              _lastScannedAt = null;
                            }),
                        child: const Text(
                          'Try again',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onQrDetected(String rawValue) async {
    Haptics.heavy();
    setState(() => _loading = true);

    try {
      final employeeId = parseEmployeeIdFromQrText(rawValue);
      if (employeeId == null || employeeId.isEmpty) {
        setState(() {
          _error = 'Could not read QR code. Please try again.';
          _loading = false;
          _lastScannedAt = null;
        });
        return;
      }

      final repo = ref.read(mobileRepositoryProvider);
      final employee = await repo.fetchAttendanceEmployee(employeeId);
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
        nearest = _findNearestSite(sites, position);
      }

      final status = employee.attendanceHint?.lastStatus == 'In' ? 'Out' : 'In';

      if (!mounted) return;
      setState(() {
        _employee = employee;
        _selectedSite = nearest ?? (sites.isNotEmpty ? sites.first : null);
        _error = null;
        _loading = false;
        _step = _QrFlowStep.action;
        _attendanceStatus = status;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            'Could not verify guard. '
            '${e.toString().replaceFirst('Exception: ', '')}';
        _loading = false;
        _lastScannedAt = null;
      });
    }
  }

  SiteOptionModel? _findNearestSite(
    List<SiteOptionModel> sites,
    Position position,
  ) {
    SiteOptionModel? best;
    double bestDist = double.infinity;
    for (final site in sites) {
      if (site.lat == null || site.lng == null) continue;
      final dist = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        site.lat!,
        site.lng!,
      );
      if (dist < bestDist) {
        bestDist = dist;
        best = site;
      }
    }
    return best;
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Cancel attendance?'),
            content: const Text(
              'You haven\'t submitted yet. Leave without recording?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Leave'),
              ),
            ],
          ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Action
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAction() {
    final tokens = CissThemeTokens.of(context);
    final employee = _employee;
    if (employee == null) {
      return const Center(
        child: Text('Employee data missing. Please scan again.'),
      );
    }
    final site = _selectedSite;
    final hint = employee.attendanceHint;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _showExitConfirmation,
                ),
                const SizedBox(width: 4),
                Text(
                  _attendanceStatus == 'In' ? 'CLOCK IN' : 'CLOCK OUT',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color:
                        _attendanceStatus == 'In'
                            ? tokens.success
                            : tokens.danger,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _InfoCard(
              icon: Icons.person_rounded,
              label: 'GUARD',
              value: employee.fullName,
              subValue: employee.employeeCode ?? '—',
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.location_on_rounded,
              label: 'SITE',
              value: site?.siteName ?? 'Select a site',
              subValue:
                  site != null ? '${site.clientName} · ${site.district}' : null,
              onTap: () => _pickSite(site),
            ),
            if (site != null && site.dutyPoints.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.schedule_rounded,
                label: 'DUTY POINT',
                value: site.dutyPoints.first.name,
                subValue: site.dutyPoints.first.dutyHours,
              ),
            ],
            if (hint != null && hint.lastAttendanceDate != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.warningSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: tokens.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Last ${hint.lastStatus ?? 'attendance'}: ${hint.lastAttendanceDate}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (_photoPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.file(
                  File(_photoPath!),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _capturePhoto,
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: Text(
                    'CAPTURE PHOTO (optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _loading ? null : _submitAttendance,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _attendanceStatus == 'In'
                          ? tokens.success
                          : tokens.danger,
                ),
                child:
                    _loading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                        : Text(
                          _attendanceStatus == 'In' ? 'MARK IN' : 'MARK OUT',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: Colors.white,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSite(SiteOptionModel? current) async {
    final repo = ref.read(mobileRepositoryProvider);
    List<SiteOptionModel> sites;
    try {
      sites = await repo.fetchAttendanceSites();
    } catch (_) {
      return;
    }
    if (!mounted) return;

    final selected = await showModalBottomSheet<SiteOptionModel>(
      context: context,
      builder:
          (_) => ListView.builder(
            itemCount: sites.length,
            itemBuilder:
                (_, i) => ListTile(
                  title: Text(sites[i].siteName),
                  subtitle: Text(
                    '${sites[i].clientName} · ${sites[i].district}',
                  ),
                  selected: sites[i].id == current?.id,
                  onTap: () => Navigator.pop(context, sites[i]),
                ),
          ),
    );

    if (selected != null && mounted) {
      setState(() => _selectedSite = selected);
    }
  }

  Future<void> _capturePhoto() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );
    if (result != null && mounted) {
      // Pre-encode photo for offline queue support
      try {
        final file = File(result);
        final bytes = await file.readAsBytes();
        _photoDataUrl = await ref
            .read(mobileRepositoryProvider)
            .encodeFileToDataUrl(bytes, 'image/jpeg');
      } catch (_) {
        _photoDataUrl = null;
      }
      setState(() => _photoPath = result);
    }
  }

  Future<void> _submitAttendance() async {
    final site = _selectedSite;
    final employee = _employee;
    if (site == null || employee == null) return;
    if (site.lat == null || site.lng == null) {
      setState(() => _error = 'Selected site does not have GPS coordinates.');
      return;
    }
    if (_photoDataUrl == null) {
      setState(() => _error = 'Please capture a photo before submitting.');
      return;
    }

    setState(() => _loading = true);
    Haptics.heavy();

    Map<String, dynamic>? submissionPayload;

    try {
      final repo = ref.read(mobileRepositoryProvider);

      // Capture GPS position for location data in payload
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {}
      if (pos == null) {
        throw Exception('Could not capture GPS location. Please try again.');
      }

      final dutyPoint =
          site.dutyPoints.isNotEmpty ? site.dutyPoints.first : null;
      final shift = resolveActiveShiftTemplate(
        dutyPoint?.shiftTemplates.isNotEmpty == true
            ? dutyPoint!.shiftTemplates
            : site.shiftTemplates,
      );

      final now = DateTime.now();
      final clientRequestId = _uuid.v4();

      final distanceMeters = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        site.lat!,
        site.lng!,
      );

      final payload = <String, dynamic>{
        'employeeId': employee.employeeCode ?? employee.id,
        'employeeName': employee.fullName,
        'employeeDocId': employee.id,
        'employeePhoneNumber': employee.phoneNumber ?? '',
        'employeeClientName': employee.clientName ?? '',
        'reportedAtClient': now.toUtc().toIso8601String(),
        'status': _attendanceStatus,
        'district': site.district,
        'clientName': site.clientName,
        'siteId': site.id,
        'siteName': site.siteName,
        if (dutyPoint != null) 'dutyPointId': dutyPoint.id,
        if (dutyPoint != null) 'dutyPointName': dutyPoint.name,
        if (shift != null) 'shiftCode': shift.code,
        if (shift != null) 'shiftLabel': shift.label,
        if (shift != null) 'shiftStartTime': shift.startTime,
        if (shift != null) 'shiftEndTime': shift.endTime,
        'siteCoords': <String, dynamic>{'lat': site.lat, 'lng': site.lng},
        'locationText':
            'GPS ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
        'locationCoords': <String, dynamic>{
          'lat': pos.latitude,
          'lon': pos.longitude,
          'accuracyMeters': pos.accuracy,
        },
        'gpsAccuracyMeters': pos.accuracy,
        'locationAccuracyMeters': pos.accuracy,
        'distanceMeters': distanceMeters,
        'geofenceRadiusAtTime': site.geofenceRadiusMeters,
        'sourceCollection': site.sourceCollection,
        'photoCapturedAt': now.toUtc().toIso8601String(),
        'deviceInfo': <String, dynamic>{'userAgent': 'flutter-mobile-qr'},
        'clientRequestId': clientRequestId,
      };
      submissionPayload = payload;

      final uploadResult = await repo.uploadAttendancePhoto(
        path:
            'employees/${employee.id}/attendance/${DateTime.now().millisecondsSinceEpoch}.jpg',
        dataUrl: _photoDataUrl!,
        siteId: site.id,
      );
      final photoUrl = uploadResult['url'] as String?;
      if (photoUrl == null || photoUrl.isEmpty) {
        throw Exception('Photo upload did not return a URL.');
      }
      payload['photoUrl'] = photoUrl;

      await repo.submitAttendance(payload);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _attendanceTime = now;
        _step = _QrFlowStep.confirmation;
      });

      // Write to Firestore for live tracking
      if (_attendanceStatus == 'In') {
        _writeLiveLocation(pos);
      } else {
        LiveLocationService().markOut(employee.employeeCode ?? employee.id);
      }

      // Notify field officers
      await ref
          .read(notificationServiceProvider)
          .triggerSystemNotification(
            type: 'attendance_marked',
            title:
                'Guard ${_attendanceStatus == 'In' ? 'Checked In' : 'Checked Out'}',
            body:
                '${employee.fullName} marked ${_attendanceStatus.toLowerCase()} at ${_selectedSite!.siteName}',
            role: 'fieldOfficer',
            district: site.district,
            data: {'employeeId': employee.employeeCode ?? employee.id},
          );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        // Offline: queue for sync
        try {
          await ref
              .read(offlineQueueProvider)
              .enqueue(
                path: '/api/attendance/submit',
                method: 'POST',
                body: {...?submissionPayload, 'photoDataUrl': _photoDataUrl},
              );

          if (!mounted) return;
          // Still write to Firestore so FO can see the guard
          if (_attendanceStatus == 'In') {
            _writeLiveLocation(null);
          }

          setState(() {
            _loading = false;
            _attendanceTime = DateTime.now();
            _photoPath = null;
            _photoDataUrl = null;
            _error = null;
            _step = _QrFlowStep.confirmation;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline: Attendance queued for sync.'),
            ),
          );
        } catch (_) {
          if (!mounted) return;
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to queue. Please try again.')),
          );
        }
        return;
      }
      rethrow;
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          action: SnackBarAction(label: 'Retry', onPressed: _submitAttendance),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Live Location
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _writeLiveLocation(Position? pos) async {
    final employee = _employee;
    final site = _selectedSite;
    if (employee == null || site == null) return;
    try {
      await LiveLocationService().setLocation(
        GuardLocationData(
          employeeId: employee.employeeCode ?? employee.id,
          guardName: employee.fullName,
          siteId: site.id,
          siteName: site.siteName,
          clientName: employee.clientName ?? '',
          district: site.district,
          lat: pos?.latitude ?? 0,
          lng: pos?.longitude ?? 0,
          accuracy: pos?.accuracy ?? 0,
          isOutOfZone: false,
          status: _attendanceStatus,
          updatedAt: DateTime.now(),
          siteLat: site.lat,
          siteLng: site.lng,
          geofenceRadius: site.geofenceRadiusMeters.toDouble(),
        ),
      );
    } catch (e) {
      debugPrint('QR LiveLocation write error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Confirmation
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildConfirmation() {
    final tokens = CissThemeTokens.of(context);
    final employee = _employee;
    final site = _selectedSite;
    final attendanceTime = _attendanceTime;
    if (employee == null || site == null || attendanceTime == null) {
      return const Center(
        child: Text('Attendance data incomplete. Please scan again.'),
      );
    }

    final shareText = '''
CISS Workforce — Attendance Confirmed
────────────────────────────────────
Guard:         ${employee.fullName}
Employee ID:   ${employee.employeeCode ?? employee.id}
Site:          ${site.siteName}
Date/Time:     ${formatAttendanceDateTime(attendanceTime)}
Status:        ${_attendanceStatus.toUpperCase()}
────────────────────────────────────
Verified by CISS Workforce Platform''';

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: tokens.successSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: tokens.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ATTENDANCE MARKED',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: tokens.ink,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _attendanceStatus == 'In'
                    ? 'You are clocked IN'
                    : 'You are clocked OUT',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.inkMuted),
              ),
              const SizedBox(height: 28),
              _ConfirmationCard(
                employee: employee,
                site: site,
                time: _attendanceTime!,
                status: _attendanceStatus,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed:
                      () => Share.share(
                        shareText,
                        subject: 'CISS Attendance Confirmation',
                      ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                  ),
                  icon: const Icon(Icons.chat_rounded, color: Colors.white),
                  label: Text(
                    'Share via WhatsApp',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed:
                      () => Share.share(
                        shareText,
                        subject: 'CISS Attendance Confirmation',
                      ),
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: Text(
                    'Share',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Done',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Helper Widgets
// ═════════════════════════════════════════════════════════════════════════════

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subValue,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: tokens.primary, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: tokens.inkMuted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: tokens.ink,
                      ),
                    ),
                    if (subValue != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subValue!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: tokens.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({
    required this.employee,
    required this.site,
    required this.time,
    required this.status,
  });

  final PublicAttendanceEmployeeModel employee;
  final SiteOptionModel site;
  final DateTime time;
  final String status;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: [
          _row(context, 'Guard', employee.fullName),
          _row(context, 'ID', employee.employeeCode ?? '—'),
          _row(context, 'Site', site.siteName),
          _row(context, 'Time', formatAttendanceDateTime(time)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: status == 'In' ? tokens.successSoft : tokens.dangerSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: status == 'In' ? tokens.success : tokens.danger,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final tokens = CissThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(color: tokens.inkMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
