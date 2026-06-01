# QR Attendance Flow — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add zero-login QR-code attendance flow triggered by long-pressing the guard portal card on the login hub.

**Architecture:** Single go_router route (`/qr-attendance`) hosts a 3-step inline flow (scan → action → confirmation) managed by a `_QrFlowStep` enum inside a `ConsumerStatefulWidget`. QR parser mirrors the existing web parser. All API calls reuse existing public attendance endpoints and `MobileRepository` methods.

**Tech Stack:** Flutter/Dart, `mobile_scanner` (QR), `share_plus` (share sheet), existing `geolocator`, `camera`, Riverpod, go_router, google_fonts.

---

### Task 1: Add packages

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add `mobile_scanner` and `share_plus` to pubspec.yaml**

In `pubspec.yaml`, add under `dependencies:` in alphabetical position:

```yaml
  mobile_scanner: ^6.0.3
  share_plus: ^10.1.4
```

Place them between `json_annotation` and `path_provider` (alphabetically).

- [ ] **Step 2: Install packages**

```bash
cd /Users/mymac/Documents/CISS-Mobile && flutter pub get
```

Expected: Resolves without conflicts.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add mobile_scanner and share_plus for QR attendance flow"
```

---

### Task 2: Create QR text parser

**Files:**
- Create: `lib/core/qr/qr_parser.dart`

- [ ] **Step 1: Create the parser file**

Mirrors the CISS web app's `src/lib/qr/employee-qr.ts` — `parseEmployeeQrText()`.

```dart
/// Mirrors the QR parsing logic from the CISS web app:
///   src/lib/qr/employee-qr.ts  —  parseEmployeeQrText()
///
/// Expected QR text format:
///   Employee ID: CISS/EMP001
///   Phone: 9876543210

const _employeeIdLabelRe = r'Employee\s*ID\s*:\s*([^\n\r]+)';
const _phoneLabelRe = r'Phone\s*:\s*([^\n\r]+)';
const _cissIdRe = r'CISS/[^\s\r\n]+';

String _normalizeQrText(String text) {
  return text.replaceAll('\u0000', '').trim();
}

({String? employeeId, String? phoneNumber}) parseEmployeeQrText(String text) {
  final normalized = _normalizeQrText(text);
  if (normalized.isEmpty) {
    return (employeeId: null, phoneNumber: null);
  }

  // Try labeled extraction
  final labeledMatch =
      RegExp(_employeeIdLabelRe, caseSensitive: false).firstMatch(normalized);
  final cissMatch =
      RegExp(_cissIdRe, caseSensitive: false).firstMatch(normalized);
  final employeeId =
      labeledMatch?.group(1)?.trim() ?? cissMatch?.group(0)?.trim();

  // Phone number
  final phoneMatch =
      RegExp(_phoneLabelRe, caseSensitive: false).firstMatch(normalized);
  final rawPhone =
      phoneMatch?.group(1)?.replaceAll(RegExp(r'\D'), '').trim() ?? '';
  final last10 = rawPhone.length >= 10 ? rawPhone.substring(rawPhone.length - 10) : rawPhone;
  final phoneNumber = RegExp(r'^\d{10}$').hasMatch(last10) ? last10 : null;

  // Fallback: first line starting with CISS/
  final firstLine = normalized.split(RegExp(r'\r?\n')).first.trim();
  final fallbackEmployeeId =
      (firstLine.isNotEmpty && firstLine.startsWith('CISS/')) ? firstLine : null;

  return (
    employeeId: employeeId ?? fallbackEmployeeId,
    phoneNumber: phoneNumber,
  );
}

String? parseEmployeeIdFromQrText(String text) {
  return parseEmployeeQrText(text).employeeId;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/qr/qr_parser.dart
git commit -m "feat: add QR text parser mirroring web app logic"
```

---

### Task 3: Create QR attendance flow screen

**Files:**
- Create: `lib/features/attendance_qr/qr_attendance_flow.dart`

- [ ] **Step 1: Create the flow screen**

Single `ConsumerStatefulWidget` managing three steps: scan → action → confirmation.

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';
import '../../../core/models/attendance_models.dart';
import '../../../core/network/mobile_repository.dart';
import '../../../core/network/providers.dart';
import '../../../core/qr/qr_parser.dart';
import '../../../shared/widgets/camera_capture_screen.dart';

enum _QrFlowStep { scan, action, confirmation }

class QrAttendanceFlow extends ConsumerStatefulWidget {
  const QrAttendanceFlow({super.key});

  @override
  ConsumerState<QrAttendanceFlow> createState() => _QrAttendanceFlowState();
}

class _QrAttendanceFlowState extends ConsumerState<QrAttendanceFlow> {
  _QrFlowStep _step = _QrFlowStep.scan;

  PublicAttendanceEmployeeModel? _employee;
  SiteOptionModel? _selectedSite;
  String? _error;
  bool _loading = false;

  String _attendanceStatus = 'In';
  DateTime? _attendanceTime;
  String? _photoPath;

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

  // ── Scanner ──────────────────────────────────────────────────────────────

  MobileScannerController? _scannerController;

  Widget _buildScanner() {
    final tokens = CissThemeTokens.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            if (_loading) return;
            final barcode = capture.barcodes.firstOrNull;
            if (barcode?.rawValue == null) return;
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
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
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
                    color: _loading
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
                      const Icon(Icons.qr_code_scanner_rounded,
                          color: Colors.white70, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        'Align QR code within the frame',
                        style: GoogleFonts.rajdhani(
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
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: tokens.danger.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() => _error = null),
                        child: const Text('Try again',
                            style: TextStyle(color: Colors.white)),
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

      final status =
          employee.attendanceHint?.lastStatus == 'In' ? 'Out' : 'In';

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
        _error = 'Could not verify guard. '
            '${e.toString().replaceFirst('Exception: ', '')}';
        _loading = false;
      });
    }
  }

  SiteOptionModel? _findNearestSite(
      List<SiteOptionModel> sites, Position position) {
    SiteOptionModel? best;
    double bestDist = double.infinity;
    for (final site in sites) {
      if (site.lat == null || site.lng == null) continue;
      final dist = Geolocator.distanceBetween(
        position.latitude, position.longitude, site.lat!, site.lng!,
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
      builder: (_) => AlertDialog(
        title: const Text('Cancel attendance?'),
        content:
            const Text('You haven\'t submitted yet. Leave without recording?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Stay')),
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

  // ── Action ───────────────────────────────────────────────────────────────

  Widget _buildAction() {
    final tokens = CissThemeTokens.of(context);
    final employee = _employee!;
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
                  style: GoogleFonts.rajdhani(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _attendanceStatus == 'In'
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
                    const Icon(Icons.info_outline,
                        size: 20, color: Colors.orange),
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
                    'CAPTURE PHOTO',
                    style: GoogleFonts.rajdhani(
                        fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: site == null ? null : _submitAttendance,
                style: FilledButton.styleFrom(
                  backgroundColor: _attendanceStatus == 'In'
                      ? tokens.success
                      : tokens.danger,
                ),
                child: Text(
                  _attendanceStatus == 'In' ? 'MARK IN' : 'MARK OUT',
                  style: GoogleFonts.rajdhani(
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
      builder: (_) => ListView.builder(
        itemCount: sites.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(sites[i].siteName),
          subtitle: Text('${sites[i].clientName} · ${sites[i].district}'),
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
      setState(() => _photoPath = result);
    }
  }

  Future<void> _submitAttendance() async {
    final site = _selectedSite;
    if (site == null) return;

    setState(() => _loading = true);
    Haptics.heavy();

    try {
      final repo = ref.read(mobileRepositoryProvider);

      String? photoUrl;
      if (_photoPath != null) {
        try {
          final file = File(_photoPath!);
          final bytes = await file.readAsBytes();
          final dataUrl =
              await repo.encodeFileToDataUrl(bytes, 'image/jpeg');
          final uploadResult = await repo.uploadAttendancePhoto(
            path:
                'attendance-qr/${_employee!.id}/${DateTime.now().millisecondsSinceEpoch}.jpg',
            dataUrl: dataUrl,
          );
          photoUrl = uploadResult['url'] as String?;
        } catch (_) {}
      }

      await repo.submitAttendance({
        'employeeId': _employee!.id,
        'siteId': site.id,
        'dutyPointId':
            site.dutyPoints.isNotEmpty ? site.dutyPoints.first.id : null,
        'status': _attendanceStatus,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'lat': null,
        'lng': null,
        if (photoUrl != null) 'photoUrl': photoUrl,
      });

      if (!mounted) return;
      setState(() {
        _loading = false;
        _attendanceTime = DateTime.now();
        _step = _QrFlowStep.confirmation;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed: ${e.toString().replaceFirst('Exception: ', '')}'),
          action: SnackBarAction(
              label: 'Retry', onPressed: _submitAttendance),
        ),
      );
    }
  }

  // ── Confirmation ─────────────────────────────────────────────────────────

  Widget _buildConfirmation() {
    final tokens = CissThemeTokens.of(context);
    final employee = _employee!;
    final site = _selectedSite!;

    final shareText = '''
CISS Workforce — Attendance Confirmed
────────────────────────────────────
Guard:         ${employee.fullName}
Employee ID:   ${employee.employeeCode ?? employee.id}
Site:          ${site.siteName}
Date/Time:     ${_formatDateTime(_attendanceTime!)}
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
                child: Icon(Icons.check_rounded,
                    color: tokens.success, size: 48),
              ),
              const SizedBox(height: 20),
              Text(
                'ATTENDANCE MARKED',
                style: GoogleFonts.rajdhani(
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
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: tokens.inkMuted),
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
                  onPressed: () => Share.share(shareText,
                      subject: 'CISS Attendance Confirmation'),
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366)),
                  icon: const Icon(Icons.chat_rounded, color: Colors.white),
                  label: Text(
                    'Share via WhatsApp',
                    style: GoogleFonts.rajdhani(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => Share.share(shareText,
                      subject: 'CISS Attendance Confirmation'),
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: Text('Share',
                      style: GoogleFonts.rajdhani(
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Done',
                  style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final am = dt.hour < 12 ? 'AM' : 'PM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$min $am';
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────

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
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                              color: tokens.inkMuted, letterSpacing: 1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.rajdhani(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: tokens.ink,
                      ),
                    ),
                    if (subValue != null) ...[
                      const SizedBox(height: 2),
                      Text(subValue!,
                          style: Theme.of(context).textTheme.bodySmall),
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
          _row(context, 'Time', _formatTime(time)),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: status == 'In'
                  ? tokens.successSoft
                  : tokens.dangerSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.rajdhani(
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
            child: Text(label,
                style:
                    TextStyle(color: tokens.inkMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final am = dt.hour < 12 ? 'AM' : 'PM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$min $am';
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/attendance_qr/qr_attendance_flow.dart
git commit -m "feat: add QR attendance flow screen (scan → action → confirmation)"
```

---

### Task 4: Wire up router and login hub long-press

**Files:**
- Modify: `lib/app/router/app_router.dart`
- Modify: `lib/features/auth/presentation/login_hub_screen.dart`

- [ ] **Step 1: Add `/qr-attendance` route to router**

In `lib/app/router/app_router.dart`, add the import and route after the existing `/permissions` route:

Add this import at the top:

```dart
import '../../features/attendance_qr/qr_attendance_flow.dart';
```

Add this route after the `/permissions` route (before the closing `]` of `routes`):

```dart
    GoRoute(
      path: '/qr-attendance',
      builder: (BuildContext context, GoRouterState state) {
        return const QrAttendanceFlow();
      },
    ),
```

- [ ] **Step 2: Add long-press to guard portal card**

In `lib/features/auth/presentation/login_hub_screen.dart`, add the import:

```dart
import 'package:share_plus/share_plus.dart';  // REMOVE — not needed here
```

Actually, just add the `onLongPress` to the existing guard `_RoleCard`. Find this block in `LoginHubScreen.build()`:

```dart
                    child: _RoleCard(
                      title: 'GUARD\nOPERATIONS',
                      tagline: 'Attendance  ·  Shifts  ·  Duty reports',
                      icon: Icons.verified_user_rounded,
                      accentColor: tokens.primary,
                      softColor: tokens.primarySoft,
                      infographic: _InfographicType.guard,
                      introDelay: const Duration(milliseconds: 360),
                      onTap: () => context.go('/login/guard'),
                    ),
```

Add a new field `onLongPress` to `_RoleCard` widget and configure it. First, modify `_RoleCard` to accept `onLongPress`:

Find the `_RoleCard` class fields and add:

```dart
  final VoidCallback? onLongPress;
```

Add to constructor. Then find the `GestureDetector` in `_RoleCard.build()` and wrap it in a long-press handler. Find this:

```dart
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
```

Add after `GestureDetector(`:

```dart
      onLongPress: widget.onLongPress,
```

Then in the `LoginHubScreen.build()`, add `onLongPress` to the guard `_RoleCard`:

```dart
                      onTap: () => context.go('/login/guard'),
                      onLongPress: () => context.go('/qr-attendance'),
```

- [ ] **Step 3: Commit**

```bash
git add lib/app/router/app_router.dart lib/features/auth/presentation/login_hub_screen.dart
git commit -m "feat: wire QR attendance route and guard portal long-press trigger"
```

---

### Task 5: Verify

- [ ] **Step 1: Run Flutter analyze**

```bash
cd /Users/mymac/Documents/CISS-Mobile && flutter analyze
```

Expected: No errors. Resolve any findings.

- [ ] **Step 2: Verify all imports compile**

```bash
cd /Users/mymac/Documents/CISS-Mobile && flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tail -5
```

Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: verify QR attendance flow compiles cleanly"
```
