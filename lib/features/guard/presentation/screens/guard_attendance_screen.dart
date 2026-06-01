import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
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
import '../../../../../core/location/live_location_service.dart';
import '../../../../../core/fcm/providers.dart';
import '../../../../../shared/widgets/camera_capture_screen.dart';
import '../../../../../shared/widgets/section_card.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/portal_primitives.dart';
import '../widgets/guard_portal_widgets.dart';
import 'guard_profile_screen.dart';

class GuardAttendanceScreen extends ConsumerStatefulWidget {
  const GuardAttendanceScreen({super.key});

  @override
  ConsumerState<GuardAttendanceScreen> createState() =>
      _GuardAttendanceScreenState();
}

class _GuardAttendanceScreenState extends ConsumerState<GuardAttendanceScreen> {
  static const Uuid _uuid = Uuid();

  SiteOptionModel? _site;
  DutyPointModel? _dutyPoint;
  ShiftTemplateModel? _shift;
  String _status = 'In';
  String? _error;
  bool _busy = false;
  String? _photoPath;
  Position? _position;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationCheck();
      _initStatusFromHistory();
    });
  }

  /// Determine default IN/OUT status from attendance history.
  /// If the most recent record is IN, default to OUT (guard is checking out).
  /// If the most recent record is OUT or no history, default to IN.
  Future<void> _initStatusFromHistory() async {
    try {
      final records = await ref.read(attendanceHistoryProvider.future);
      if (records.isEmpty) return;

      final latest = records.first;
      if (!mounted) return;

      // If latest is IN, the guard probably wants to OUT now
      // If latest is OUT, the guard probably wants to IN now
      setState(() {
        _status = latest.status == 'In' ? 'Out' : 'In';
      });
    } catch (e) {
      // Silently ignore — default IN is fine
    }
  }

  Future<void> _initLocationCheck() async {
    await _captureLocation();
    if (_position != null) {
      final sites = await ref.read(attendanceSitesProvider.future);
      final profile = await ref.read(guardProfileProvider.future);

      final guardDist = profile.district.trim().toLowerCase();
      var filtered =
          sites
              .where((s) => s.district.trim().toLowerCase() == guardDist)
              .toList();

      // Fallback: If no sites match the district, use all sites so guard isn't blocked
      if (filtered.isEmpty) {
        filtered = sites;
      }

      final nearest = _findNearestSite(_position!, filtered);
      if (nearest != null && mounted) {
        setState(() {
          _site = nearest;
          _dutyPoint =
              nearest.dutyPoints.isNotEmpty ? nearest.dutyPoints.first : null;
          _shift =
              _dutyPoint?.shiftTemplates.isNotEmpty == true
                  ? _dutyPoint!.shiftTemplates.first
                  : null;
        });
      }
    }
  }

  Future<void> _captureLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(
        () => _error = 'Location services are off. Please turn them on.',
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(
        () => _error = 'Location permission is required for attendance.',
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _position = position;
        _error = null;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(
        () =>
            _error =
                'GPS timed out. Please ensure location services are enabled and try again.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not get location: $e');
    }
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
      builder:
          (context) => StatefulBuilder(
            builder: (context, setModalState) {
              final filtered =
                  sites
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
                                  color:
                                      isSelected ? tokens.primary : tokens.ink,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                site.district,
                                style: TextStyle(color: tokens.inkMuted),
                              ),
                              trailing:
                                  isSelected
                                      ? Icon(
                                        Icons.check_circle_rounded,
                                        color: tokens.primary,
                                      )
                                      : null,
                              onTap: () {
                                setState(() {
                                  _site = site;
                                  _dutyPoint =
                                      site.dutyPoints.isNotEmpty == true
                                          ? site.dutyPoints.first
                                          : null;
                                  _shift =
                                      _dutyPoint?.shiftTemplates.isNotEmpty ==
                                              true
                                          ? _dutyPoint!.shiftTemplates.first
                                          : null;
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

  Future<void> _submitAttendance(GuardProfileModel profile) async {
    if (_site == null) {
      setState(() => _error = 'Please select a site.');
      return;
    }
    if (_site!.lat == null || _site!.lng == null) {
      setState(
        () =>
            _error =
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
      if (_position == null) {
        setState(
          () =>
              _error =
                  'Could not determine your location. Please check GPS and try again.',
        );
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });

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
          resolveActiveShiftTemplate(
            dutyPoint?.shiftTemplates.isNotEmpty == true
                ? dutyPoint!.shiftTemplates
                : _site!.shiftTemplates,
          );
      final distanceMeters = Geolocator.distanceBetween(
        _position!.latitude,
        _position!.longitude,
        _site!.lat!,
        _site!.lng!,
      );

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
        'gpsAccuracyMeters': _position!.accuracy,
        'locationAccuracyMeters': _position!.accuracy,
        'geofenceRadiusAtTime': _site!.geofenceRadiusMeters,
        'sourceCollection': _site!.sourceCollection,
        'photoCapturedAt': DateTime.now().toUtc().toIso8601String(),
        'deviceInfo': <String, dynamic>{'userAgent': 'flutter-mobile'},
        'clientRequestId': _uuid.v4(),
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
            );
          } else {
            debugPrint('Tracking skipped: site coordinates missing.');
          }
          // Write initial location to Firestore for live tracking
          _writeLiveLocation(profile, _status);
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
          // Mark OUT in Firestore
          LiveLocationService().markOut(profile.employeeId);
        }

        if (mounted) {
          Haptics.heavy();
          setState(() {
            _photoPath = null;
            _error = 'Attendance submitted successfully.';
          });
          ref.invalidate(attendanceHistoryProvider);
        }
      } catch (uploadOrSubmitError) {
        if (uploadOrSubmitError is DioException &&
            (uploadOrSubmitError.type == DioExceptionType.connectionTimeout ||
                uploadOrSubmitError.type == DioExceptionType.sendTimeout ||
                uploadOrSubmitError.type == DioExceptionType.receiveTimeout ||
                uploadOrSubmitError.type == DioExceptionType.connectionError)) {
          // If network failed, queue the request WITH the base64 photo data.
          // The backend /api/attendance/submit must be updated to handle
          // 'photoDataUrl' directly if 'photoUrl' is missing.
          await ref
              .read(offlineQueueProvider)
              .enqueue(
                path: '/api/attendance/submit',
                method: 'POST',
                body: {...payload, 'photoDataUrl': dataUrl},
              );
          if (mounted) {
            Haptics.medium();
            // Still write to Firestore so FO can see live location
            _writeLiveLocation(profile, _status);
            if (mounted) {
              setState(() {
                _photoPath = null;
                _error = 'Offline: Attendance queued for sync.';
              });
              ref.invalidate(attendanceHistoryProvider);
            }
          }
        } else {
          rethrow;
        }
      }
    } catch (error) {
      setState(() {
        _error = CissError.parse(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _writeLiveLocation(
    GuardProfileModel profile,
    String status,
  ) async {
    final site = _site;
    if (site == null || _position == null) return;
    try {
      await LiveLocationService().setLocation(
        GuardLocationData(
          employeeId: profile.employeeId,
          guardName: profile.fullName,
          siteId: site.id,
          siteName: site.siteName,
          clientName: profile.clientName,
          district: profile.district,
          lat: _position!.latitude,
          lng: _position!.longitude,
          accuracy: _position!.accuracy,
          isOutOfZone: false,
          status: status,
          updatedAt: DateTime.now(),
          siteLat: site.lat,
          siteLng: site.lng,
          geofenceRadius: site.geofenceRadiusMeters.toDouble(),
        ),
      );
    } catch (e) {
      debugPrint('LiveLocation write error: $e');
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
      onRefresh: () async {
        ref.invalidate(attendanceSitesProvider);
        ref.invalidate(guardProfileProvider);
      },
      actions: <Widget>[
        IconButton(
          onPressed: () => ref.invalidate(attendanceSitesProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      children: <Widget>[
        profileAsync.when(
          loading:
              () => const StateBlock(
                icon: Icons.person_outline_rounded,
                title: 'Loading profile',
                message: 'Fetching employee details...',
              ),
          error:
              (Object error, StackTrace stackTrace) => SectionCard(
                title: 'Profile error',
                subtitle: guardErrorMessage(error),
                icon: Icons.error_outline_rounded,
              ),
          data: (profile) {
            return sitesAsync.when(
              loading:
                  () => const StateBlock(
                    icon: Icons.place_rounded,
                    title: 'Loading sites',
                    message: 'Fetching duty centers...',
                  ),
              error:
                  (Object error, StackTrace stackTrace) => SectionCard(
                    title: 'Site error',
                    subtitle: guardErrorMessage(error),
                    icon: Icons.error_outline_rounded,
                  ),
              data: (sites) {
                final guardDist = profile.district.trim().toLowerCase();
                var filteredSites =
                    sites
                        .where(
                          (s) => s.district.trim().toLowerCase() == guardDist,
                        )
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
                      icon: Icons.badge_rounded,
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
                    // ── Stale session warning ──────────────────────────────
                    _StaleSessionBanner(),
                    GuardFormCard(
                      children: <Widget>[
                        InkWell(
                          onTap: () => _showSitePicker(filteredSites),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: IgnorePointer(
                            child: TextFormField(
                              key: ValueKey(_site?.id),
                              initialValue:
                                  _site != null
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
                          items:
                              dutyPoints
                                  .map(
                                    (
                                      dutyPoint,
                                    ) => DropdownMenuItem<DutyPointModel>(
                                      value: dutyPoint,
                                      child: Text(
                                        '${dutyPoint.name} • ${dutyPoint.dutyHours} hrs',
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              dutyPoints.isEmpty
                                  ? null
                                  : (dutyPoint) {
                                    setState(() {
                                      _dutyPoint = dutyPoint;
                                      _shift = resolveAttendanceShiftTemplate(
                                        dutyPoint?.shiftTemplates ??
                                            const <ShiftTemplateModel>[],
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
                            setState(() => _status = selected.first);
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
                              color:
                                  _error!.toLowerCase().contains('success') ||
                                          _error!.toLowerCase().contains(
                                            'queued',
                                          )
                                      ? tokens.successSoft
                                      : tokens.dangerSoft,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color:
                                    _error!.toLowerCase().contains('success') ||
                                            _error!.toLowerCase().contains(
                                              'queued',
                                            )
                                        ? tokens.success
                                        : tokens.danger,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed:
                                _busy ? null : () => _submitAttendance(profile),
                            child:
                                _busy
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
                      subtitle:
                          _site == null
                              ? 'Select a site to load duty points and shifts.'
                              : '${_site!.siteName} • ${_site!.district} • ${_site!.dutyPoints.length} duty points',
                      icon: Icons.location_on_rounded,
                      trailing: StatusChip(
                        label: _site == null ? 'Pending' : 'Ready',
                        tone:
                            _site == null
                                ? StatusChipTone.neutral
                                : StatusChipTone.success,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ── Attendance History ──────────────────────────
                    _AttendanceHistorySection(),
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

/// Shows a warning banner if the guard has an open IN session from a previous day.
/// This helps guards realize they forgot to check out.
class _StaleSessionBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final historyAsync = ref.watch(attendanceHistoryProvider);

    return historyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (records) {
        if (records.isEmpty) return const SizedBox.shrink();

        final latest = records.first;
        if (latest.status != 'In') return const SizedBox.shrink();

        // Check if the latest IN is from a previous day
        final today = DateTime.now();
        final todayStr =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

        if (latest.dateLabel == todayStr || latest.dateLabel.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.dangerSoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: tokens.danger.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.warning_rounded, color: tokens.danger, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Open session from ${latest.dateLabel}',
                      style: TextStyle(
                        color: tokens.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'You forgot to check out on ${latest.dateLabel}. Please mark OUT first, or contact your supervisor.',
                      style: TextStyle(
                        color: tokens.danger.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

final FutureProvider<List<SiteOptionModel>> attendanceSitesProvider =
    FutureProvider<List<SiteOptionModel>>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchAttendanceSites();
    });

final FutureProvider<List<AttendanceRecordModel>> attendanceHistoryProvider =
    FutureProvider<List<AttendanceRecordModel>>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchAttendanceHistory();
    });

class _AttendanceHistorySection extends ConsumerWidget {
  const _AttendanceHistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final historyAsync = ref.watch(attendanceHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: 'Attendance Log',
          subtitle: 'Your check-in and check-out history',
          icon: Icons.history_rounded,
        ),
        const SizedBox(height: 12),
        historyAsync.when(
          loading: () => _buildLoadingSkeleton(tokens),
          error: (error, _) => StateBlock(
            icon: Icons.error_outline_rounded,
            title: 'Could not load history',
            message: error.toString().replaceFirst('Exception: ', ''),
            action: FilledButton.tonal(
              onPressed: () => ref.invalidate(attendanceHistoryProvider),
              child: const Text('Retry'),
            ),
          ),
          data: (records) {
            if (records.isEmpty) {
              return const StateBlock(
                icon: Icons.history_toggle_off_rounded,
                title: 'No attendance records yet',
                message: 'Your check-in and check-out records will appear here.',
              );
            }
            return _buildAttendanceLog(records, tokens, context);
          },
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton(CissThemeTokens tokens) {
    return Column(
      children: List.generate(5, (_) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: tokens.border.withValues(alpha: 0.3)),
          ),
        ),
      )),
    );
  }

  Widget _buildAttendanceLog(
    List<AttendanceRecordModel> records,
    CissThemeTokens tokens,
    BuildContext context,
  ) {
    // Group records by month (YYYY-MM)
    final grouped = <String, List<AttendanceRecordModel>>{};
    for (final record in records) {
      String monthKey;
      try {
        final dt = DateTime.tryParse(record.createdAt);
        if (dt != null) {
          monthKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        } else {
          monthKey = record.dateLabel.isNotEmpty ? record.dateLabel : 'Unknown';
        }
      } catch (_) {
        monthKey = record.dateLabel.isNotEmpty ? record.dateLabel : 'Unknown';
      }
      grouped.putIfAbsent(monthKey, () => <AttendanceRecordModel>[]).add(record);
    }

    // Sort month keys descending
    final sortedMonths = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final allWidgets = <Widget>[];

    // ── Summary Statistics Card ──
    allWidgets.add(_buildSummaryCard(records, tokens));
    allWidgets.add(const SizedBox(height: 16));

    // ── Month-Sectioned Records ──
    for (final monthKey in sortedMonths) {
      final monthRecords = grouped[monthKey]!;
      allWidgets.add(_buildMonthHeader(monthKey, monthRecords.length, tokens));
      allWidgets.add(const SizedBox(height: 8));

      for (final record in monthRecords) {
        allWidgets.add(_buildAttendanceCard(record, tokens, context));
        allWidgets.add(const SizedBox(height: 6));
      }
      allWidgets.add(const SizedBox(height: 12));
    }

    return Column(children: allWidgets);
  }

  /// Summary statistics: total, present, absent, late
  Widget _buildSummaryCard(List<AttendanceRecordModel> records, CissThemeTokens tokens) {
    final total = records.length;
    final presentCount = records.where((r) => r.status == 'In' || r.status == 'Present').length;
    final absentCount = records.where((r) => r.status == 'Absent').length;
    final lateCount = records.where((r) => r.status == 'Late').length;
    // Check-out records are the OUT ones
    final outCount = records.where((r) => r.status == 'Out').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tokens.accent.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 18, color: tokens.accent),
              const SizedBox(width: 8),
              Text(
                'SUMMARY',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: tokens.accent, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Total', '$total', tokens.accent, tokens),
              _buildStatDivider(tokens),
              _buildStatItem('Present', '$presentCount', tokens.success, tokens),
              _buildStatDivider(tokens),
              _buildStatItem('Out', '$outCount', tokens.warning, tokens),
              _buildStatDivider(tokens),
              _buildStatItem('Absent', '$absentCount', tokens.danger, tokens),
            ],
          ),
          if (lateCount > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: tokens.warning),
                const SizedBox(width: 6),
                Text(
                  '$lateCount late check-in(s)',
                  style: TextStyle(fontSize: 12, color: tokens.warning, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, CissThemeTokens tokens) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color, height: 1.1)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: tokens.inkMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildStatDivider(CissThemeTokens tokens) {
    return Container(
      width: 1,
      height: 36,
      color: tokens.border.withValues(alpha: 0.3),
    );
  }

  /// Month section header with count badge
  Widget _buildMonthHeader(String monthKey, int count, CissThemeTokens tokens) {
    String displayTitle;
    try {
      final parts = monthKey.split('-');
      if (parts.length == 2) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        displayTitle = '${monthNames[m - 1]} $y';
      } else {
        displayTitle = monthKey;
      }
    } catch (_) {
      displayTitle = monthKey;
    }

    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: tokens.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          displayTitle,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.ink, letterSpacing: -0.2),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: tokens.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count records',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tokens.accent),
          ),
        ),
      ],
    );
  }

  /// Redesigned attendance record card
  Widget _buildAttendanceCard(
    AttendanceRecordModel record,
    CissThemeTokens tokens,
    BuildContext context,
  ) {
    final isIn = record.status == 'In' || record.status == 'Present';
    final isLate = record.status == 'Late';
    final isOut = record.status == 'Out';
    final isAbsent = record.status == 'Absent';

    final Color accentColor;
    final String statusLabel;
    final IconData statusIcon;
    final StatusChipTone chipTone;

    if (isIn) {
      accentColor = tokens.success;
      statusLabel = 'Check-in';
      statusIcon = Icons.login_rounded;
      chipTone = StatusChipTone.success;
    } else if (isLate) {
      accentColor = tokens.warning;
      statusLabel = 'Late In';
      statusIcon = Icons.warning_amber_rounded;
      chipTone = StatusChipTone.warning;
    } else if (isOut) {
      accentColor = tokens.warning;
      statusLabel = 'Check-out';
      statusIcon = Icons.logout_rounded;
      chipTone = StatusChipTone.warning;
    } else if (isAbsent) {
      accentColor = tokens.danger;
      statusLabel = 'Absent';
      statusIcon = Icons.cancel_rounded;
      chipTone = StatusChipTone.danger;
    } else {
      accentColor = tokens.inkMuted;
      statusLabel = record.status;
      statusIcon = Icons.info_outline_rounded;
      chipTone = StatusChipTone.neutral;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Date badge (left)
          _buildDateBadge(record, accentColor, tokens),
          const SizedBox(width: 14),
          // Center info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.siteName.isNotEmpty ? record.siteName : 'Unknown Site',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.ink),
                ),
                const SizedBox(height: 4),
                if (record.shiftLabel.isNotEmpty || record.time != null)
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: tokens.inkMuted),
                      const SizedBox(width: 4),
                      Text(
                        [
                          if (record.time != null) record.time!,
                          if (record.shiftLabel.isNotEmpty) record.shiftLabel,
                        ].join(' · '),
                        style: TextStyle(fontSize: 11, color: tokens.inkMuted),
                      ),
                    ],
                  ),
                if (record.distanceMeters != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.pin_drop_rounded, size: 12, color: record.distanceMeters! > 200 ? tokens.danger : tokens.inkMuted),
                      const SizedBox(width: 4),
                      Text(
                        record.distanceMeters! < 1000
                            ? '${record.distanceMeters!.round()} m from site'
                            : '${(record.distanceMeters! / 1000).toStringAsFixed(1)} km from site',
                        style: TextStyle(
                          fontSize: 11,
                          color: record.distanceMeters! > 200 ? tokens.danger : tokens.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Right side: photo thumbnail + status
          if (record.photoUrl != null && record.photoUrl!.isNotEmpty)
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: Colors.black,
                    appBar: AppBar(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      title: const Text('Photo'),
                    ),
                    body: Center(
                      child: InteractiveViewer(
                        child: Image.network(record.photoUrl!),
                      ),
                    ),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Image.network(
                  record.photoUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 44,
                    height: 44,
                    color: tokens.inkMuted.withValues(alpha: 0.1),
                    child: Icon(Icons.photo_rounded, color: tokens.inkMuted, size: 18),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 10),
          StatusChip(label: statusLabel, tone: chipTone),
        ],
      ),
    );
  }

  /// Circular date badge showing day + weekday
  Widget _buildDateBadge(AttendanceRecordModel record, Color accentColor, CissThemeTokens tokens) {
    String dayStr = '--';
    String weekdayStr = '';
    try {
      final dt = DateTime.tryParse(record.createdAt);
      if (dt != null) {
        dayStr = '${dt.day}';
        const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        weekdayStr = weekdays[dt.weekday - 1];
      } else if (record.dateLabel.isNotEmpty) {
        // Try parsing from dateLabel
        final parts = record.dateLabel.split(' ');
        if (parts.isNotEmpty) {
          dayStr = parts.last;
          weekdayStr = parts.length > 1 ? parts.first : '';
        }
      }
    } catch (_) {}

    return Container(
      width: 44,
      height: 48,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dayStr,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: accentColor, height: 1),
          ),
          if (weekdayStr.isNotEmpty)
            Text(
              weekdayStr,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: accentColor.withValues(alpha: 0.7)),
            ),
        ],
      ),
    );
  }
}
