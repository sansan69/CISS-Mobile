import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/haptics.dart';
import '../../../../../core/models/attendance_models.dart';
import '../../../../../core/models/guard_profile.dart';
import '../../../../../core/network/ciss_error.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/sync/providers.dart';
import '../../../../../core/location/background_tracking_service.dart';
import '../../../../../core/fcm/providers.dart';
import '../../../../../shared/widgets/camera_capture_screen.dart';
import '../../../../../shared/widgets/section_card.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../widgets/guard_portal_widgets.dart';
import 'guard_profile_screen.dart';

class GuardAttendanceScreen extends ConsumerStatefulWidget {
  const GuardAttendanceScreen({super.key});

  @override
  ConsumerState<GuardAttendanceScreen> createState() =>
      _GuardAttendanceScreenState();
}

enum _MessageTone { success, error }

class _GuardAttendanceScreenState extends ConsumerState<GuardAttendanceScreen> {
  SiteOptionModel? _site;
  DutyPointModel? _dutyPoint;
  ShiftTemplateModel? _shift;
  AttendanceHintModel? _attendanceHint;
  String _status = 'In';
  String? _error;
  _MessageTone _messageTone = _MessageTone.error;
  bool _busy = false;
  String? _photoPath;
  Position? _position;
  String? _overrideReason;
  bool _showOverrideField = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationCheck();
    });
  }

  Future<void> _initLocationCheck() async {
    await _captureLocation();
    if (!mounted) return;
    if (_position != null) {
      final sites = await ref.read(attendanceSitesProvider.future);
      final profile = await ref.read(guardProfileProvider.future);
      AttendanceHintModel? hint;
      try {
        final employee = await ref
            .read(mobileRepositoryProvider)
            .fetchAttendanceEmployee(profile.employeeId);
        hint = employee.attendanceHint;
      } catch (_) {
        hint = null;
      }

      final guardDist = profile.district.trim().toLowerCase();
      var filtered = sites
          .where((s) => s.district.trim().toLowerCase() == guardDist)
          .toList();

      // Fallback: If no sites match the district, use all sites so guard isn't blocked
      if (filtered.isEmpty) {
        filtered = sites;
      }

      final status =
          hint?.recommendedStatus == 'Out' || hint?.hasOpenSession == true
          ? 'Out'
          : 'In';
      final sessionSite = _findSessionSite(filtered, hint);
      final nearest = sessionSite ?? _findNearestSite(_position!, filtered);
      if (nearest != null && mounted) {
        final dutyPoint = _resolveDutyPointForSubmission(nearest, hint, status);
        setState(() {
          _attendanceHint = hint;
          _status = status;
          _site = nearest;
          _dutyPoint = dutyPoint;
          _shift = resolveAttendanceSubmissionShiftTemplate(
            dutyPoint?.shiftTemplates.isNotEmpty == true
                ? dutyPoint!.shiftTemplates
                : nearest.shiftTemplates,
            status: status,
            attendanceHint: hint,
          );
        });
      }
    }
  }

  Future<void> _captureLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (!mounted) return;
      setState(() {
        _error = 'Location services are off. Please turn them on.';
        _messageTone = _MessageTone.error;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _error = 'Location permission is required for attendance.';
        _messageTone = _MessageTone.error;
      });
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    if (!mounted) return;
    setState(() {
      _position = position;
      _error = null;
      _messageTone = _MessageTone.error;
    });
  }

  Future<void> _capturePhoto() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CameraCaptureScreen(),
      ),
    );
    if (path != null && mounted) {
      Haptics.light();
      setState(() {
        _photoPath = path;
        _error = null;
      });
    }
  }

  void _showSitePicker(List<SiteOptionModel> sites) {
    final tokens = CissThemeTokens.of(context);
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = sites
              .where(
                (s) =>
                    s.siteName.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ) ||
                    s.district.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ),
              )
              .toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 1.0,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: tokens.inkMuted.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: true,
                      style: TextStyle(color: tokens.ink),
                      decoration: InputDecoration(
                        hintText: 'Search site name or district...',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: tokens.inkMuted,
                        ),
                        filled: true,
                        fillColor: tokens.surfaceMuted,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemBuilder: (context, index) {
                        final site = filtered[index];
                        final isSelected = _site?.id == site.id;
                        return ListTile(
                          title: Text(
                            site.siteName,
                            style: TextStyle(
                              color: isSelected ? tokens.primary : tokens.ink,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            site.district,
                            style: TextStyle(color: tokens.inkMuted),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: tokens.primary,
                                )
                              : null,
                          onTap: () {
                            final dutyPoint = site.dutyPoints.isNotEmpty
                                ? _resolveDutyPointForSubmission(
                                    site,
                                    _attendanceHint,
                                    _status,
                                  )
                                : null;
                            setState(() {
                              _site = site;
                              _dutyPoint = dutyPoint;
                              _shift = resolveAttendanceSubmissionShiftTemplate(
                                dutyPoint?.shiftTemplates.isNotEmpty == true
                                    ? dutyPoint!.shiftTemplates
                                    : site.shiftTemplates,
                                status: _status,
                                attendanceHint: _attendanceHint,
                              );
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  SiteOptionModel? _findNearestSite(
    Position position,
    List<SiteOptionModel> sites,
  ) {
    if (sites.isEmpty) return null;
    SiteOptionModel? nearest;
    double minDistance = double.infinity;

    for (final site in sites) {
      if (site.lat == null || site.lng == null) continue;
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        site.lat!,
        site.lng!,
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearest = site;
      }
    }
    return nearest;
  }

  SiteOptionModel? _findSessionSite(
    List<SiteOptionModel> sites,
    AttendanceHintModel? hint,
  ) {
    final lastSiteId = hint?.lastSiteId?.trim();
    if (lastSiteId == null || lastSiteId.isEmpty) return null;
    for (final site in sites) {
      if (site.id == lastSiteId) return site;
    }
    return null;
  }

  DutyPointModel? _resolveDutyPointForSubmission(
    SiteOptionModel site,
    AttendanceHintModel? hint,
    String status,
  ) {
    if (status == 'Out' && hint?.lastDutyPointId?.trim().isNotEmpty == true) {
      for (final dutyPoint in site.dutyPoints) {
        if (dutyPoint.id == hint!.lastDutyPointId) return dutyPoint;
      }
    }
    return site.dutyPoints.isNotEmpty ? site.dutyPoints.first : null;
  }

  Future<void> _submitAttendance(GuardProfileModel profile) async {
    if (_site == null) {
      setState(() => _error = 'Please select a site.');
      return;
    }
    if (_site!.lat == null || _site!.lng == null) {
      setState(
        () => _error =
            'Selected site does not have GPS coordinates. Please contact the office.',
      );
      return;
    }
    if (_photoPath == null) {
      setState(() => _error = 'Please capture a photo for attendance.');
      return;
    }
    if (_position == null) {
      await _captureLocation();
      if (_position == null) return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    // Guard: ensure _busy is reset if we return early from geofence check.
    void resetBusy() {
      if (mounted) setState(() => _busy = false);
    }

    try {
      final file = File(_photoPath!);
      final bytes = await file.readAsBytes();
      final dataUrl = await ref
          .read(mobileRepositoryProvider)
          .encodeFileToDataUrl(bytes, 'image/jpeg');

      final dutyPoint =
          _dutyPoint ??
          (_site!.dutyPoints.length == 1 ? _site!.dutyPoints.first : null);
      final shift =
          _shift ??
          resolveAttendanceSubmissionShiftTemplate(
            dutyPoint?.shiftTemplates.isNotEmpty == true
                ? dutyPoint!.shiftTemplates
                : _site!.shiftTemplates,
            status: _status,
            attendanceHint: _attendanceHint,
          );

      // Compute distance from site if we have both coordinates
      double distanceMeters = 0;
      bool isOutOfZone = false;
      if (_position != null && _site!.lat != null && _site!.lng != null) {
        distanceMeters = Geolocator.distanceBetween(
          _position!.latitude,
          _position!.longitude,
          _site!.lat!,
          _site!.lng!,
        );
        isOutOfZone = distanceMeters > _site!.geofenceRadiusMeters;
      }

      // Geofence enforcement
      if (_status == 'In' && isOutOfZone && _site!.strictGeofence) {
        resetBusy();
        if (!mounted) return;
        setState(() {
          _error =
              'You are ${distanceMeters.toStringAsFixed(0)}m from ${_site!.siteName}. '
              'You must be within ${_site!.geofenceRadiusMeters.toStringAsFixed(0)}m to check in.';
          _messageTone = _MessageTone.error;
        });
        return;
      }

      final clientRequestId = const Uuid().v4();

      final payload = <String, dynamic>{
        'employeeId': profile.employeeId,
        'employeeName': profile.fullName,
        'employeeDocId': profile.id,
        'employeePhoneNumber': profile.phoneNumber,
        'employeeClientName': profile.clientName,
        'status': _status,
        'district': profile.district,
        'clientName': _site!.clientName,
        'siteId': _site!.id,
        'siteName': _site!.siteName,
        'dutyPointId': dutyPoint?.id,
        'dutyPointName': dutyPoint?.name,
        'shiftCode': shift?.code,
        'shiftLabel': shift?.label,
        'shiftStartTime': shift?.startTime,
        'shiftEndTime': shift?.endTime,
        'siteCoords': <String, dynamic>{'lat': _site!.lat, 'lng': _site!.lng},
        'locationText':
            'GPS ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
        'locationCoords': <String, dynamic>{
          'lat': _position!.latitude,
          'lon': _position!.longitude,
          'accuracyMeters': _position!.accuracy,
        },
        'distanceMeters': distanceMeters,
        'isOutOfZone': isOutOfZone,
        'gpsAccuracyMeters': _position!.accuracy,
        'locationAccuracyMeters': _position!.accuracy,
        'geofenceRadiusAtTime': _site!.geofenceRadiusMeters,
        'sourceCollection': _site!.sourceCollection,
        'photoCapturedAt': DateTime.now().toUtc().toIso8601String(),
        'deviceInfo': <String, dynamic>{'userAgent': 'flutter-mobile'},
        'clientRequestId': clientRequestId,
        if (_overrideReason != null && _overrideReason!.trim().isNotEmpty)
          'overrideReason': _overrideReason!.trim(),
      };

      try {
        final uploadPath =
            'employees/${profile.id.isNotEmpty ? profile.id : profile.employeeId}/attendance/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final uploadResult = await ref
            .read(mobileRepositoryProvider)
            .uploadAttendancePhoto(path: uploadPath, dataUrl: dataUrl);

        await ref.read(mobileRepositoryProvider).submitAttendance({
          ...payload,
          'photoUrl': uploadResult['url'],
        });

        if (_status == 'In') {
          if (_site!.lat != null && _site!.lng != null) {
            BackgroundTrackingService.start(
              siteId: _site!.id,
              siteName: _site!.siteName,
              lat: _site!.lat!,
              lng: _site!.lng!,
              radiusMeters: _site!.geofenceRadiusMeters.toDouble(),
              employeeId: profile.employeeId,
              guardName: profile.fullName,
              clientName: profile.clientName,
              district: profile.district,
            );
          } else {
            debugPrint('Tracking skipped: site coordinates missing.');
          }
          // Attendance submit writes the authoritative live-location record server-side.
          // Notify field officers
          await ref
              .read(notificationServiceProvider)
              .triggerSystemNotification(
                type: 'attendance_marked',
                title:
                    'Guard ${_status == 'In' ? 'Checked In' : 'Checked Out'}',
                body:
                    '${profile.fullName} marked ${_status.toLowerCase()} at ${_site!.siteName}',
                role: 'fieldOfficer',
                district: profile.district,
                data: {'employeeId': profile.employeeId, 'siteId': _site!.id},
              );
        } else {
          BackgroundTrackingService.stop();
        }

        if (mounted) {
          Haptics.heavy();
          setState(() {
            _photoPath = null;
            _error = 'Attendance submitted successfully.';
            _messageTone = _MessageTone.success;
          });
        }
      } catch (uploadOrSubmitError) {
        final isOffline = ref
            .read(mobileRepositoryProvider)
            .shouldQueueOffline(uploadOrSubmitError);
        if (isOffline) {
          // If network failed, queue the request WITH the base64 photo data.
          await ref
              .read(offlineQueueProvider)
              .enqueue(
                path: '/api/attendance/submit',
                method: 'POST',
                body: {
                  ...payload,
                  'photoDataUrl': dataUrl,
                  if (_overrideReason != null && _overrideReason!.trim().isNotEmpty)
                    'overrideReason': _overrideReason!.trim(),
                },
              );
          if (mounted) {
            Haptics.medium();
            setState(() {
              _photoPath = null;
              _error = 'Offline: Attendance queued for sync.';
              _messageTone = _MessageTone.success;
            });
          }
        } else {
          rethrow;
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = CissError.parse(error);
        _messageTone = _MessageTone.error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final sitesAsync = ref.watch(attendanceSitesProvider);
    final profileAsync = ref.watch(guardProfileProvider);
    return ScreenScaffold(
      title: 'Attendance',
      subtitle: 'Mark attendance with site, duty point, shift, photo, and GPS',
      actions: <Widget>[
        IconButton(
          onPressed: () => ref.invalidate(attendanceSitesProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      children: <Widget>[
        profileAsync.when(
          loading: () => const StateBlock(
            icon: Icons.person_outline_rounded,
            title: 'Loading profile',
            message: 'Fetching employee details...',
          ),
          error: (Object error, StackTrace stackTrace) => SectionCard(
            title: 'Profile error',
            subtitle: guardErrorMessage(error),
            icon: Icons.error_outline_rounded,
          ),
          data: (profile) {
            return sitesAsync.when(
              loading: () => const StateBlock(
                icon: Icons.place_outlined,
                title: 'Loading sites',
                message: 'Fetching duty centers...',
              ),
              error: (Object error, StackTrace stackTrace) => SectionCard(
                title: 'Site error',
                subtitle: guardErrorMessage(error),
                icon: Icons.error_outline_rounded,
              ),
              data: (sites) {
                final guardDist = profile.district.trim().toLowerCase();
                var filteredSites = sites
                    .where((s) => s.district.trim().toLowerCase() == guardDist)
                    .toList();

                bool isFiltered = true;
                if (filteredSites.isEmpty) {
                  filteredSites = sites;
                  isFiltered = false;
                }

                final dutyPoints =
                    _site?.dutyPoints ?? const <DutyPointModel>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SectionCard(
                      title: profile.fullName,
                      subtitle:
                          '${profile.employeeId} • ${profile.clientName} • ${profile.district}',
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 14),
                    if (!isFiltered && sites.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tokens.warningSoft,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: tokens.warning,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No sites found for your district (${profile.district}). Showing all available sites.',
                                  style: TextStyle(
                                    color: tokens.warning,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_error != null && _error!.contains('Location')) ...[
                      StateBlock(
                        icon: Icons.location_off_rounded,
                        title: 'Location Required',
                        message: _error!,
                        action: FilledButton.tonal(
                          onPressed: _initLocationCheck,
                          child: const Text('Retry'),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    GuardFormCard(
                      children: <Widget>[
                        InkWell(
                          onTap: () => _showSitePicker(filteredSites),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: IgnorePointer(
                            child: TextFormField(
                              key: ValueKey(_site?.id),
                              initialValue: _site != null
                                  ? '${_site!.siteName} • ${_site!.district}'
                                  : '',
                              decoration: const InputDecoration(
                                labelText: 'Site',
                                suffixIcon: Icon(Icons.search_rounded),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<DutyPointModel>(
                          isExpanded: true,
                          initialValue: _dutyPoint,
                          items: dutyPoints
                              .map(
                                (dutyPoint) => DropdownMenuItem<DutyPointModel>(
                                  value: dutyPoint,
                                  child: Text(
                                    '${dutyPoint.name} • ${dutyPoint.dutyHours} hrs',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: dutyPoints.isEmpty
                              ? null
                              : (dutyPoint) {
                                  setState(() {
                                    _dutyPoint = dutyPoint;
                                    _shift =
                                        resolveAttendanceSubmissionShiftTemplate(
                                          dutyPoint
                                                      ?.shiftTemplates
                                                      .isNotEmpty ==
                                                  true
                                              ? dutyPoint!.shiftTemplates
                                              : _site?.shiftTemplates ??
                                                    const <
                                                      ShiftTemplateModel
                                                    >[],
                                          status: _status,
                                          attendanceHint: _attendanceHint,
                                        );
                                  });
                                },
                          decoration: const InputDecoration(
                            labelText: 'Duty Point',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<ShiftTemplateModel>(
                          isExpanded: true,
                          initialValue: _shift,
                          items:
                              (_dutyPoint?.shiftTemplates ??
                                      const <ShiftTemplateModel>[])
                                  .map(
                                    (
                                      shift,
                                    ) => DropdownMenuItem<ShiftTemplateModel>(
                                      value: shift,
                                      child: Text(
                                        '${shift.label} • ${shift.startTime}-${shift.endTime}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (_dutyPoint?.shiftTemplates.isNotEmpty == true)
                              ? (shift) => setState(() => _shift = shift)
                              : null,
                          decoration: const InputDecoration(labelText: 'Shift'),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          segments: const <ButtonSegment<String>>[
                            ButtonSegment<String>(
                              value: 'In',
                              label: Text('Mark In'),
                            ),
                            ButtonSegment<String>(
                              value: 'Out',
                              label: Text('Mark Out'),
                            ),
                          ],
                          selected: <String>{_status},
                          onSelectionChanged: (Set<String> selected) {
                            final nextStatus = selected.first;
                            final nextDutyPoint = _site == null
                                ? _dutyPoint
                                : _resolveDutyPointForSubmission(
                                    _site!,
                                    _attendanceHint,
                                    nextStatus,
                                  );
                            setState(() {
                              _status = nextStatus;
                              _dutyPoint = nextDutyPoint;
                              _shift = resolveAttendanceSubmissionShiftTemplate(
                                nextDutyPoint?.shiftTemplates.isNotEmpty == true
                                    ? nextDutyPoint!.shiftTemplates
                                    : _site?.shiftTemplates ??
                                          const <ShiftTemplateModel>[],
                                status: nextStatus,
                                attendanceHint: _attendanceHint,
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            OutlinedButton.icon(
                              onPressed: _captureLocation,
                              icon: const Icon(Icons.my_location_rounded),
                              label: Text(
                                _position == null
                                    ? 'Capture GPS'
                                    : 'GPS ${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _capturePhoto,
                              icon: const Icon(Icons.camera_alt_rounded),
                              label: Text(
                                _photoPath == null
                                    ? 'Capture Photo'
                                    : 'Photo captured',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: _messageTone == _MessageTone.success
                                  ? tokens.successSoft
                                  : tokens.dangerSoft,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: _messageTone == _MessageTone.success
                                    ? tokens.success
                                    : tokens.danger,
                              ),
                            ),
                          ),
                        // Override reason for out-of-zone attendance
                        if (_showOverrideField) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: tokens.warningSoft,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: tokens.warning, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Out-of-zone override',
                                        style: TextStyle(color: tokens.warning, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  onChanged: (value) => setState(() => _overrideReason = value),
                                  decoration: InputDecoration(
                                    hintText: 'e.g., Site gate is 200m from checkpoint',
                                    filled: true,
                                    fillColor: tokens.surface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  maxLength: 500,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: () => setState(() => _showOverrideField = true),
                            icon: Icon(Icons.warning_amber_rounded, size: 16, color: tokens.warning),
                            label: Text(
                              'Outside geofence? Request override',
                              style: TextStyle(color: tokens.warning, fontSize: 12),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _submitAttendance(profile),
                            child: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator.adaptive(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Submit ${_status == 'In' ? 'Check-In' : 'Check-Out'}',
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                    SectionCard(
                      title: 'Selected Site Details',
                      subtitle: _site == null
                          ? 'Select a site to load duty points and shifts.'
                          : '${_site!.siteName} • ${_site!.district} • ${_site!.dutyPoints.length} duty points',
                      icon: Icons.location_on_outlined,
                      trailing: StatusChip(
                        label: _site == null ? 'Pending' : 'Ready',
                        tone: _site == null
                            ? StatusChipTone.neutral
                            : StatusChipTone.success,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

final FutureProvider<List<SiteOptionModel>> attendanceSitesProvider =
    FutureProvider<List<SiteOptionModel>>((Ref ref) {
      return ref.watch(mobileRepositoryProvider).fetchAttendanceSites();
    });
