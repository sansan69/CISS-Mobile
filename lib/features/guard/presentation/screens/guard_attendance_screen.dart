import 'dart:async';
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
import '../../../../../core/attendance/attendance_session.dart';
import '../../../../../core/attendance/attendance_validation.dart';
import '../../../../../core/attendance/early_checkout.dart';
import '../../../../../core/location/background_tracking_service.dart';
import '../../../../../core/location/public_ip.dart';
import '../../../../../core/settings/module_gate.dart';
import '../../../../../core/settings/remote_config_provider.dart';
import '../../../../../core/fcm/providers.dart';
import '../../../../../shared/widgets/camera_capture_screen.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/success_overlay.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';
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
  bool _isSuccess = false;
  bool _busy = false;
  String? _photoPath;
  String? _clientRequestId; // Stable across retries for idempotency
  Position? _position;
  final TextEditingController _notesController = TextEditingController();
  bool _showNotesField = false;

  /// Server-authoritative break state for the open attendance session.
  final AttendanceSession _attendance = AttendanceSession();
  Timer? _breakTicker;

  @override
  void dispose() {
    _breakTicker?.cancel();
    _notesController.dispose();
    super.dispose();
  }

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

  /// Server-authoritative geo + IP pre-check before check-in/out.
  ///
  /// Opt-in behind the `ipAttendance` module flag only (default OFF); the
  /// server still enforces geo + IP on submit. Fails open on any error.
  Future<bool> _validateBeforeSubmit(GuardProfileModel profile) async {
    if (!mounted) return false;
    if (!shouldRunAttendancePreCheck(ref.read(remoteConfigProvider).modules)) {
      return false;
    }
    final position = _position;
    final site = _site;
    if (position == null || site == null) return false;

    if (position.accuracy > 100 && mounted) {
      final accuracy = position.accuracy.toStringAsFixed(0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Low GPS accuracy (±$accuracy m). Your location may be imprecise.',
          ),
        ),
      );
    }

    final publicIp = await fetchPublicIp();
    try {
      final result = await ref
          .read(mobileRepositoryProvider)
          .validateAttendance(
            employeeDocId:
                profile.id.isNotEmpty ? profile.id : profile.employeeId,
            siteId: site.id,
            lat: position.latitude,
            lon: position.longitude,
            status: _status,
            publicIp: publicIp,
          );
      if (!result.blocksSubmit) return false;
      if (mounted) {
        final reason = result.reason ?? 'Attendance blocked by server validation.';
        setState(() => _error = reason);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(reason)));
      }
      return true;
    } catch (_) {
      // Fail-open: offline or validation endpoint unavailable.
      return false;
    }
  }

  Future<void> _toggleBreak() async {
    final action = _attendance.onBreak ? BreakAction.stop : BreakAction.start;
    final position = _position;
    final body = <String, dynamic>{
      'action': action.name,
      'lat': position?.latitude,
      'lng': position?.longitude,
      'accuracy': position?.accuracy,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      final res = await ref
          .read(mobileRepositoryProvider)
          .attendanceBreak(
            action: action.name,
            lat: position?.latitude,
            lng: position?.longitude,
            accuracy: position?.accuracy,
          );
      if (!mounted) return;
      setState(() => _attendance.applyBreakResponse(res));
      _syncBreakTicker();
    } catch (error) {
      if (CissError.isRetryableNetworkError(error)) {
        await ref
            .read(offlineQueueProvider)
            .enqueue(
              path: '/api/mobile/attendance/break',
              method: 'POST',
              body: body,
            );
        if (!mounted) return;
        final optimistic = <String, dynamic>{
          'onBreak': action == BreakAction.start,
          'breakSeconds': _attendance.totalBreakSeconds,
          'canCheckOut': action != BreakAction.start,
          if (action == BreakAction.start)
            'breakStartedAt': DateTime.now().toUtc().toIso8601String(),
        };
        setState(() => _attendance.applyBreakResponse(optimistic));
        _syncBreakTicker();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline: break saved and will sync.')),
        );
      } else if (mounted) {
        setState(() => _error = CissError.parse(error));
      }
    }
  }

  void _syncBreakTicker() {
    _breakTicker?.cancel();
    if (_attendance.onBreak) {
      _breakTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  bool _requiresEarlyCheckoutReason(Map<String, dynamic> response) =>
      response['requiresEarlyCheckOutReason'] == true ||
      response['requiresReason'] == true;

  Future<void> _submitAttendance(GuardProfileModel profile) async {
    setState(() => _isSuccess = false);
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

    if (await _validateBeforeSubmit(profile)) return;

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
        'locationCapturedAt': DateTime.now().toUtc().toIso8601String(),
        'attendanceAttemptId': _clientRequestId ??= _uuid.v4(),
        'deviceInfo': <String, dynamic>{'userAgent': 'flutter-mobile'},
        'clientRequestId': _clientRequestId ??= _uuid.v4(),
        if (_notesController.text.trim().isNotEmpty) ...{
          'overrideReason': _notesController.text.trim(),
          'dutyNotes': _notesController.text.trim(),
        },
      };

      try {
        final uploadResult = await ref
            .read(mobileRepositoryProvider)
            .uploadAttendancePhoto(
              employeeDocId:
                  profile.id.isNotEmpty ? profile.id : profile.employeeId,
              dataUrl: dataUrl,
              siteId: _site!.id,
              attemptId: _clientRequestId,
            );

        var submitResult = await ref
            .read(mobileRepositoryProvider)
            .submitAttendance({
              ...payload,
              'photoUrl': uploadResult['url'],
              'photoStoragePath': uploadResult['path'],
            });

        if (_status == 'Out' &&
            _requiresEarlyCheckoutReason(submitResult) &&
            mounted) {
          final reason = await showEarlyCheckoutReasonSheet(context);
          if (reason != null && reason.isNotEmpty) {
            _clientRequestId = _uuid.v4();
            submitResult = await ref
                .read(mobileRepositoryProvider)
                .submitAttendance({
                  ...payload,
                  'photoUrl': uploadResult['url'],
                  'photoStoragePath': uploadResult['path'],
                  'clientRequestId': _clientRequestId,
                  'earlyCheckOutReason': reason,
                });
          }
        }

        if (_status == 'In') {
          // Start the background tracking service (best-effort — a failure
          // here must never fail the check-in itself).
          if (_site!.lat != null && _site!.lng != null) {
            try {
              await BackgroundTrackingService.start(
                siteId: _site!.id,
                siteName: _site!.siteName,
                lat: _site!.lat!,
                lng: _site!.lng!,
                radiusMeters: _site!.geofenceRadiusMeters.toDouble(),
                employeeId: profile.employeeId,
                employeeDocId: profile.id,
                guardName: profile.fullName,
                clientName: profile.clientName,
                district: profile.district,
              );
            } catch (error) {
              debugPrint(
                'Tracking start failed (attendance still saved): $error',
              );
            }
          } else {
            debugPrint('Tracking skipped: site coordinates missing.');
          }
          // Notify field officers — best-effort. The server rejects
          // guard-created system notifications, so this must never surface
          // as a check-in failure.
          try {
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
          } catch (error) {
            debugPrint(
              'FO attendance notification failed (attendance saved): $error',
            );
          }
        } else {
          await BackgroundTrackingService.stop();
        }

        if (mounted) {
          Haptics.heavy();
          _notesController.clear();
          setState(() {
            _photoPath = null;
            _isSuccess = true;
            _error = null;
            _showNotesField = false;
            // After a successful punch the next action is the opposite one,
            // so the form reflects the guard's current clocked state.
            _status = _status == 'In' ? 'Out' : 'In';
          });
          ref.invalidate(attendanceHistoryProvider);
          unawaited(
            SuccessOverlay.show(
              context,
              title: _status == 'In' ? 'Checked in' : 'Checked out',
              message: 'Your attendance was recorded.',
            ),
          );
        }
      } catch (uploadOrSubmitError) {
        if (CissError.isRetryableNetworkError(uploadOrSubmitError)) {
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
          if (_status == 'Out') {
            await BackgroundTrackingService.stop();
          }
          if (mounted) {
            Haptics.medium();
            if (mounted) {
              setState(() {
                _photoPath = null;
                _isSuccess = true;
                _error =
                    'No internet — your attendance is saved and will be sent automatically when connected.';
                _status = _status == 'In' ? 'Out' : 'In';
              });
              ref.invalidate(attendanceHistoryProvider);
            }
          }
        } else {
          rethrow;
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = CissError.parse(error);
        });
      }
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
      showBackButton: false,
      onRefresh: () async {
        ref.invalidate(attendanceSitesProvider);
        ref.invalidate(guardProfileProvider);
      },
      actions: <Widget>[
        SyncStatusBadge(
          onTap: () => ref.read(syncServiceProvider).processQueue(),
        ),
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
              (Object error, StackTrace stackTrace) => ModernCard(
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.error_outline_rounded,
                      color: tokens.danger,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Profile error',
                            style: AppTypography.bodyStrong(context),
                          ),
                          Text(
                            guardErrorMessage(error),
                            style: AppTypography.micro(
                              context,
                            ).copyWith(color: tokens.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                  (Object error, StackTrace stackTrace) => ModernCard(
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.error_outline_rounded,
                          color: tokens.danger,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Site error',
                                style: AppTypography.bodyStrong(context),
                              ),
                              Text(
                                guardErrorMessage(error),
                                style: AppTypography.micro(
                                  context,
                                ).copyWith(color: tokens.inkMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                    GuardHeroPanel(
                      eyebrow: 'Attendance',
                      title: profile.fullName,
                      subtitle:
                          '${profile.employeeId} • ${profile.clientName} • ${profile.district}',
                      icon: Icons.badge_rounded,
                      accentColor:
                          _status == 'In' ? tokens.success : tokens.warning,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    GuardMetricStrip(
                      items: <GuardMetricItem>[
                        GuardMetricItem(
                          label: 'Mode',
                          value: _status == 'In' ? 'In' : 'Out',
                          icon:
                              _status == 'In'
                                  ? Icons.login_rounded
                                  : Icons.logout_rounded,
                          color:
                              _status == 'In' ? tokens.success : tokens.primary,
                        ),
                        GuardMetricItem(
                          label: 'GPS',
                          value: _position == null ? 'Needed' : 'Ready',
                          icon: Icons.my_location_rounded,
                          color:
                              _position == null
                                  ? tokens.warning
                                  : tokens.success,
                        ),
                        GuardMetricItem(
                          label: 'Photo',
                          value: _photoPath == null ? 'Needed' : 'Ready',
                          icon: Icons.camera_alt_rounded,
                          color:
                              _photoPath == null
                                  ? tokens.warning
                                  : tokens.success,
                        ),
                      ],
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
                    // ── 2026 Geofence Radar Card ───────────────────────────
                    _GeofenceRadarCard(
                      site: _site,
                      position: _position,
                      onRecalibrate: _captureLocation,
                    ),
                    const SizedBox(height: 14),
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
                                labelText: 'Assigned Site / Post',
                                suffixIcon: Icon(Icons.search_rounded),
                              ),
                            ),
                          ),
                        ),
                        if (dutyPoints.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<DutyPointModel>(
                            isExpanded: true,
                            value: _dutyPoint,
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
                            onChanged: (dutyPoint) {
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
                        ],
                        if ((_dutyPoint?.shiftTemplates ??
                                const <ShiftTemplateModel>[])
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<ShiftTemplateModel>(
                            isExpanded: true,
                            value: _shift,
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
                                (shift) => setState(() => _shift = shift),
                            decoration: const InputDecoration(
                              labelText: 'Shift Template',
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // ── Tactical In/Out Switcher ──
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Haptics.light();
                                  setState(() => _status = 'In');
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _status == 'In'
                                        ? tokens.glowEmerald.withValues(alpha: 0.15)
                                        : tokens.surfaceMuted,
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(
                                      color: _status == 'In'
                                          ? tokens.glowEmerald
                                          : tokens.border,
                                      width: _status == 'In' ? 1.5 : 1.0,
                                    ),
                                    boxShadow: _status == 'In'
                                        ? AppShadows.glow(tokens.glowEmerald)
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.login_rounded,
                                        size: 18,
                                        color: _status == 'In'
                                            ? tokens.glowEmerald
                                            : tokens.inkMuted,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'CLOCK IN',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: _status == 'In'
                                              ? tokens.glowEmerald
                                              : tokens.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Haptics.light();
                                  setState(() => _status = 'Out');
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _status == 'Out'
                                        ? tokens.glowAmber.withValues(alpha: 0.15)
                                        : tokens.surfaceMuted,
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(
                                      color: _status == 'Out'
                                          ? tokens.glowAmber
                                          : tokens.border,
                                      width: _status == 'Out' ? 1.5 : 1.0,
                                    ),
                                    boxShadow: _status == 'Out'
                                        ? AppShadows.glow(tokens.glowAmber)
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.logout_rounded,
                                        size: 18,
                                        color: _status == 'Out'
                                            ? tokens.glowAmber
                                            : tokens.inkMuted,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'CLOCK OUT',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: _status == 'Out'
                                              ? tokens.glowAmber
                                              : tokens.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // ── Biometric HUD Photo Card ──
                        _BiometricPhotoCard(
                          photoPath: _photoPath,
                          onCapture: _capturePhoto,
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed:
                                () => setState(
                                  () => _showNotesField = !_showNotesField,
                                ),
                            icon: Icon(
                              _showNotesField
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.add_comment_outlined,
                              size: 16,
                              color: tokens.primary,
                            ),
                            label: Text(
                              _showNotesField
                                  ? 'Hide duty notes'
                                  : 'Add handover notes (optional)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: tokens.primary,
                              ),
                            ),
                          ),
                        ),
                        if (_showNotesField) ...[
                          const SizedBox(height: 4),
                          TextField(
                            controller: _notesController,
                            maxLines: 2,
                            maxLength: 500,
                            decoration: InputDecoration(
                              hintText:
                                  'e.g. Relieved Guard Rajesh, perimeter secure, key handed over...',
                              labelText: 'Duty / Handover Notes',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: tokens.inkMuted,
                              ),
                              filled: true,
                              fillColor: tokens.surfaceMuted,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                                borderSide: BorderSide(color: tokens.border),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color:
                                  _isSuccess
                                      ? tokens.successSoft
                                      : tokens.dangerSoft,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color:
                                    _isSuccess ? tokens.success : tokens.danger,
                              ),
                            ),
                          ),
                        if (moduleEnabled(ref, 'break') && _status == 'Out') ...[
                          const SizedBox(height: 8),
                          _BreakPanel(
                            onBreak: _attendance.onBreak,
                            breakStartedAt: _attendance.breakStartedAt,
                            onToggle: _busy ? null : _toggleBreak,
                          ),
                        ],
                        const SizedBox(height: 14),
                        // ── Tactile Glowing Submit Button ──
                        GestureDetector(
                          onTap: (_busy ||
                                  (_status == 'Out' && !_attendance.canCheckOut))
                              ? null
                              : () => _submitAttendance(profile),
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _status == 'In'
                                    ? [const Color(0xFF059669), tokens.glowEmerald]
                                    : [const Color(0xFFD97706), tokens.glowAmber],
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              boxShadow: _status == 'In'
                                  ? AppShadows.glow(tokens.glowEmerald)
                                  : AppShadows.glow(tokens.glowAmber),
                            ),
                            child: Center(
                              child: _busy
                                  ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator.adaptive(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                  : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _status == 'In'
                                            ? Icons.fingerprint_rounded
                                            : Icons.verified_user_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'CONFIRM & SUBMIT ${_status == 'In' ? 'CLOCK-IN' : 'CLOCK-OUT'}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // ── Offline Resilience Badge ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_done_rounded,
                              size: 14,
                              color: tokens.glowEmerald,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ZERO-LOSS OFFLINE QUEUE ACTIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: tokens.inkMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                    GuardRecordCard(
                      title: _site == null ? 'Select a site' : _site!.siteName,
                      subtitle:
                          _site == null
                              ? 'Select a site to load duty points and shifts.'
                              : '${_site!.district} • ${_site!.dutyPoints.length} duty points',
                      icon: Icons.location_on_rounded,
                      chip: StatusChip(
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
        ModernCard(
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: tokens.primaryStrong,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Attendance Log',
                      style: AppTypography.bodyStrong(context),
                    ),
                    Text(
                      'Your check-in and check-out history',
                      style: AppTypography.micro(
                        context,
                      ).copyWith(color: tokens.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        historyAsync.when(
          loading: () => _buildLoadingSkeleton(tokens),
          error:
              (error, _) => StateBlock(
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
                message:
                    'Your check-in and check-out records will appear here.',
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
      children: List.generate(
        5,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: tokens.border.withValues(alpha: 0.3)),
            ),
          ),
        ),
      ),
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
        final dt = DateTime.tryParse(record.dateLabel);
        if (dt != null) {
          monthKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        } else {
          monthKey = record.dateLabel.isNotEmpty ? record.dateLabel : 'Unknown';
        }
      } catch (_) {
        monthKey = record.dateLabel.isNotEmpty ? record.dateLabel : 'Unknown';
      }
      grouped
          .putIfAbsent(monthKey, () => <AttendanceRecordModel>[])
          .add(record);
    }

    // Sort month keys descending
    final sortedMonths = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

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
  Widget _buildSummaryCard(
    List<AttendanceRecordModel> records,
    CissThemeTokens tokens,
  ) {
    final total = records.length;
    final presentCount =
        records.where((r) => r.status == 'In' || r.status == 'Present').length;
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
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: tokens.accent,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Total', '$total', tokens.accent, tokens),
              _buildStatDivider(tokens),
              _buildStatItem(
                'Present',
                '$presentCount',
                tokens.success,
                tokens,
              ),
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
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: tokens.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  '$lateCount late check-in(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    CissThemeTokens tokens,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: tokens.inkMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
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
        const monthNames = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: tokens.ink,
            letterSpacing: 0,
          ),
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
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: tokens.accent,
            ),
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
    final StatusChipTone chipTone;

    if (isIn) {
      accentColor = tokens.success;
      statusLabel = 'Check-in';
      chipTone = StatusChipTone.success;
    } else if (isLate) {
      accentColor = tokens.warning;
      statusLabel = 'Late In';
      chipTone = StatusChipTone.warning;
    } else if (isOut) {
      accentColor = tokens.primary;
      statusLabel = 'Check-out';
      chipTone = StatusChipTone.info;
    } else if (isAbsent) {
      accentColor = tokens.danger;
      statusLabel = 'Absent';
      chipTone = StatusChipTone.danger;
    } else {
      accentColor = tokens.inkMuted;
      statusLabel = record.status;
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 4),
                if (record.shiftLabel.isNotEmpty || record.time != null)
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: tokens.inkMuted,
                      ),
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
                      Icon(
                        Icons.pin_drop_rounded,
                        size: 12,
                        color:
                            record.distanceMeters! > 200
                                ? tokens.danger
                                : tokens.inkMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        record.distanceMeters! < 1000
                            ? '${record.distanceMeters!.round()} m from site'
                            : '${(record.distanceMeters! / 1000).toStringAsFixed(1)} km from site',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              record.distanceMeters! > 200
                                  ? tokens.danger
                                  : tokens.inkMuted,
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
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => Scaffold(
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
                  errorBuilder:
                      (_, __, ___) => Container(
                        width: 44,
                        height: 44,
                        color: tokens.inkMuted.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.photo_rounded,
                          color: tokens.inkMuted,
                          size: 18,
                        ),
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
  Widget _buildDateBadge(
    AttendanceRecordModel record,
    Color accentColor,
    CissThemeTokens tokens,
  ) {
    String dayStr = '--';
    String weekdayStr = '';
    try {
      final dt = DateTime.tryParse(record.dateLabel);
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: accentColor,
              height: 1,
            ),
          ),
          if (weekdayStr.isNotEmpty)
            Text(
              weekdayStr,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: accentColor.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }
}

class _GeofenceRadarCard extends StatelessWidget {
  const _GeofenceRadarCard({
    required this.site,
    required this.position,
    required this.onRecalibrate,
  });

  final SiteOptionModel? site;
  final Position? position;
  final VoidCallback onRecalibrate;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final hasSiteCoords = site?.lat != null && site?.lng != null;
    final hasPosition = position != null;

    double? distanceMeters;
    bool isInside = false;
    if (hasSiteCoords && hasPosition) {
      distanceMeters = Geolocator.distanceBetween(
        position!.latitude,
        position!.longitude,
        site!.lat!,
        site!.lng!,
      );
      isInside = distanceMeters <= site!.geofenceRadiusMeters;
    }

    final Color toneColor = !hasPosition || site == null
        ? tokens.inkMuted
        : isInside
            ? tokens.glowEmerald
            : tokens.glowAmber;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: toneColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: isInside ? AppShadows.glow(tokens.glowEmerald) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: toneColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: toneColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Icon(
              hasPosition && site != null
                  ? (isInside ? Icons.radar_rounded : Icons.location_off_rounded)
                  : Icons.my_location_rounded,
              color: toneColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'GEOFENCE RADAR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: toneColor,
                      ),
                    ),
                    const Spacer(),
                    if (hasPosition && site != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: toneColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          isInside ? 'SECURED IN ZONE' : 'OUTSIDE ZONE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: toneColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  site == null
                      ? 'Select an assigned post to calibrate radar'
                      : !hasPosition
                          ? 'Awaiting high-precision GPS lock...'
                          : isInside
                              ? 'Within perimeter (${distanceMeters!.round()}m from center)'
                              : 'Distance: ${distanceMeters!.round()}m (Limit: ${site!.geofenceRadiusMeters}m)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                ),
                if (site != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${site!.siteName} • ${site!.district}',
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRecalibrate,
            icon: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: tokens.inkMuted,
            ),
            tooltip: 'Recalibrate GPS',
          ),
        ],
      ),
    );
  }
}

class _BiometricPhotoCard extends StatelessWidget {
  const _BiometricPhotoCard({
    required this.photoPath,
    required this.onCapture,
  });

  final String? photoPath;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    if (photoPath != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: tokens.glowEmerald.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Stack(
            children: [
              Image.file(
                File(photoPath!),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: tokens.glowEmerald, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: tokens.glowEmerald,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'BIOMETRIC VERIFIED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: tokens.glowEmerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: GestureDetector(
                  onTap: onCapture,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Retake',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onCapture,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: tokens.surfaceMuted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: tokens.specularBorder,
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // HUD Corner bracket styling
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: tokens.glowCyan, width: 2),
                    left: BorderSide(color: tokens.glowCyan, width: 2),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: tokens.glowCyan, width: 2),
                    right: BorderSide(color: tokens.glowCyan, width: 2),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: tokens.glowCyan, width: 2),
                    left: BorderSide(color: tokens.glowCyan, width: 2),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: tokens.glowCyan, width: 2),
                    right: BorderSide(color: tokens.glowCyan, width: 2),
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tokens.glowCyan.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: tokens.glowCyan.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.face_retouching_natural_rounded,
                      color: tokens.glowCyan,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'CAPTURE BIOMETRIC PHOTO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'GPS and timestamp automatically embedded',
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact break control shown while the guard is clocked in. Mirrors the
/// server-authoritative [AttendanceSession] state.
class _BreakPanel extends StatelessWidget {
  const _BreakPanel({
    required this.onBreak,
    required this.breakStartedAt,
    required this.onToggle,
  });

  final bool onBreak;
  final DateTime? breakStartedAt;
  final VoidCallback? onToggle;

  String get _elapsed {
    final started = breakStartedAt;
    if (started == null) return '00:00';
    final d = DateTime.now().toUtc().difference(started.toUtc());
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            onBreak
                ? Icons.pause_circle_filled_rounded
                : Icons.free_breakfast_rounded,
            color: onBreak ? tokens.warning : tokens.inkMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              onBreak ? 'On break · $_elapsed' : 'Take a break',
              style: TextStyle(fontWeight: FontWeight.w700, color: tokens.ink),
            ),
          ),
          TextButton(
            onPressed: onToggle,
            child: Text(onBreak ? 'End break' : 'Start break'),
          ),
        ],
      ),
    );
  }
}
