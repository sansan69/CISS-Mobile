import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/attendance/attendance_session.dart';
import '../../../../../core/attendance/attendance_validation.dart';
import '../../../../../core/attendance/early_checkout.dart';
import '../../../../../core/haptics.dart';
import '../../../../../core/models/attendance_models.dart';
import '../../../../../core/models/guard_profile.dart';
import '../../../../../core/network/ciss_error.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/settings/module_gate.dart';
import '../../../../../core/settings/remote_config_provider.dart';
import '../../../../../core/sync/providers.dart';
import '../../../../../core/location/background_tracking_service.dart';
import '../../../../../core/location/public_ip.dart';
import '../../../../../core/fcm/providers.dart';
import '../../../../../shared/widgets/camera_capture_screen.dart';
import '../../../../../shared/widgets/modern_card.dart';
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

class _GuardAttendanceScreenState extends ConsumerState<GuardAttendanceScreen> {
  static const Uuid _uuid = Uuid();

  SiteOptionModel? _site;
  DutyPointModel? _dutyPoint;
  ShiftTemplateModel? _shift;
  String _status = 'In';
  String? _error;
  bool _busy = false;
  String? _photoPath;
  String? _clientRequestId; // Stable across retries for idempotency
  Position? _position;

  final AttendanceSession _breakSession = AttendanceSession();
  Timer? _breakTicker;
  bool _breakBusy = false;
  bool _checkedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationCheck();
      _initStatusFromHistory();
    });
  }

  @override
  void dispose() {
    _breakTicker?.cancel();
    super.dispose();
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
        _checkedIn = latest.status == 'In';
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

  bool _isOffline(Object error) {
    return error is DioException &&
        (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError);
  }

  /// True when the submit response asks the client to supply a reason for an
  /// early checkout.
  bool _requiresEarlyCheckoutReason(Map<String, dynamic> response) {
    return response['requiresEarlyCheckOutReason'] == true ||
        response['requiresReason'] == true;
  }

  String _formatBreakElapsed() {
    final started = _breakSession.breakStartedAt;
    if (started == null) return '00:00';
    final elapsed = DateTime.now().difference(started);
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return elapsed.inHours > 0
        ? '${elapsed.inHours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  void _syncBreakTicker() {
    _breakTicker?.cancel();
    if (_breakSession.onBreak) {
      _breakTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _toggleBreak() async {
    if (_breakBusy) return;
    final action = _breakSession.onBreak ? BreakAction.stop : BreakAction.start;
    final lat = _position?.latitude;
    final lng = _position?.longitude;
    final accuracy = _position?.accuracy;

    setState(() {
      _breakBusy = true;
      _error = null;
    });

    try {
      final response = await ref
          .read(mobileRepositoryProvider)
          .attendanceBreak(
            action: action.name,
            lat: lat,
            lng: lng,
            accuracy: accuracy,
          );
      if (!mounted) return;
      setState(() => _breakSession.applyBreakResponse(response));
      _syncBreakTicker();
      Haptics.light();
    } catch (error) {
      if (_isOffline(error)) {
        await ref
            .read(offlineQueueProvider)
            .enqueue(
              path: '/api/mobile/attendance/break',
              method: 'POST',
              body: <String, dynamic>{
                'action': action.name,
                'lat': lat,
                'lng': lng,
                'accuracy': accuracy,
                'capturedAt': DateTime.now().toUtc().toIso8601String(),
              },
            );
        if (!mounted) return;
        // Server state is unavailable offline — reflect the intent locally so
        // the timer and button stay in sync until the queue syncs.
        setState(() {
          _breakSession.onBreak = action == BreakAction.start;
          _breakSession.breakStartedAt =
              action == BreakAction.start ? DateTime.now().toUtc() : null;
          _breakSession.canCheckOut = action == BreakAction.stop;
        });
        _syncBreakTicker();
        Haptics.medium();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline: break change queued for sync.'),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _error = CissError.parse(error));
        }
      }
    } finally {
      if (mounted) {
        setState(() => _breakBusy = false);
      }
    }
  }

  Widget _buildBreakPanel(CissThemeTokens tokens) {
    final onBreak = _breakSession.onBreak;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ModernCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  onBreak
                      ? Icons.pause_circle_filled_rounded
                      : Icons.free_breakfast_rounded,
                  color: onBreak ? tokens.warning : tokens.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Break', style: AppTypography.bodyStrong(context)),
                      Text(
                        onBreak
                            ? 'On break • ${_formatBreakElapsed()}'
                            : 'Take a short break during your shift',
                        style: AppTypography.micro(
                          context,
                        ).copyWith(color: tokens.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _breakBusy ? null : _toggleBreak,
                icon:
                    _breakBusy
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                        : Icon(
                          onBreak
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                        ),
                label: Text(onBreak ? 'End break' : 'Start break'),
              ),
            ),
            if (!_breakSession.canCheckOut) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: tokens.warningSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.info_outline_rounded,
                      color: tokens.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Checkout is disabled until the break is ended.',
                        style: TextStyle(color: tokens.warning, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Server-authoritative geo + IP pre-check before check-in/out.
  ///
  /// Opt-in behind the `ipAttendance` module flag only (default OFF) per the
  /// controller ruling: by default the check-in/out path is unchanged (no
  /// `fetchPublicIp()` + `/attendance/validate` round trip) and the server
  /// still enforces geo + IP on submit. Returns true when the submit must be
  /// aborted because the server said the guard is not allowed. Fails open on
  /// any error — an unreachable pre-check must never block.
  Future<bool> _validateBeforeSubmit() async {
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

    // Best-effort public IP hint; never fatal. Only fetched when the IP-based
    // pre-check is enabled, so the default path adds no latency.
    final publicIp = await fetchPublicIp();

    try {
      final result = await ref
          .read(mobileRepositoryProvider)
          .validateAttendance(
            siteId: site.id,
            lat: position.latitude,
            lng: position.longitude,
            accuracy: position.accuracy,
            publicIp: publicIp,
          );
      if (!result.blocksSubmit) return false;

      if (mounted) {
        final reason =
            result.reason ?? 'Attendance blocked by server validation.';
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

  Future<void> _submitAttendance(GuardProfileModel profile) async {
    if (_status == 'Out' && !_breakSession.canCheckOut) {
      setState(() => _error = 'Please end your break before checking out.');
      return;
    }
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

    // Server-authoritative geo + IP pre-check (module-gated). Aborts the submit
    // when the server says the guard is not allowed; otherwise the submit
    // endpoint re-enforces the same checks server-side.
    if (await _validateBeforeSubmit()) return;

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
        'clientRequestId': _clientRequestId ??= _uuid.v4(),
      };

      // Local pre-check: if the guard is checking out before the selected
      // shift's scheduled end, capture the reason now. If the server also asks
      // via the submit response we reuse this value instead of double-prompting.
      if (_status == 'Out' &&
          payload['earlyCheckOutReason'] == null &&
          isEarlyCheckoutForShift(shift)) {
        if (!mounted) return;
        final reason = await showEarlyCheckoutReasonSheet(context);
        if (!mounted) return;
        if (reason != null) payload['earlyCheckOutReason'] = reason;
      }

      try {
        final uploadPath =
            'employees/${profile.id.isNotEmpty ? profile.id : profile.employeeId}/attendance/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final uploadResult = await ref
            .read(mobileRepositoryProvider)
            .uploadAttendancePhoto(
              path: uploadPath,
              dataUrl: dataUrl,
              siteId: _site!.id,
            );

        // Server-driven signal: the submit response may demand a reason for an
        // early checkout. Prompt (only if we don't already have one) and
        // re-submit exactly once with the reason attached.
        final response = await ref.read(mobileRepositoryProvider).submitAttendance(
          <String, dynamic>{...payload, 'photoUrl': uploadResult['url']},
        );
        if (_status == 'Out' &&
            payload['earlyCheckOutReason'] == null &&
            _requiresEarlyCheckoutReason(response)) {
          if (!mounted) return;
          final reason = await showEarlyCheckoutReasonSheet(context);
          if (!mounted) return;
          if (reason != null) {
            payload['earlyCheckOutReason'] = reason;
            // Rotate the idempotency key so the re-submit is a genuinely
            // distinct request. A server deduping on clientRequestId must not
            // treat the retry as a replay and drop the reason. The original id
            // stays on the first attempt (and on `_clientRequestId`).
            payload['clientRequestId'] = _uuid.v4();
            final retryResponse =
                await ref
                    .read(mobileRepositoryProvider)
                    .submitAttendance(
                      <String, dynamic>{
                        ...payload,
                        'photoUrl': uploadResult['url'],
                      },
                    );
            if (_requiresEarlyCheckoutReason(retryResponse)) {
              // The server still wants a reason. Do NOT loop — surface the
              // existing error path and abort this submit attempt.
              if (mounted) {
                setState(
                  () =>
                      _error =
                          'The server still requires an early-checkout reason.',
                );
              }
              return;
            }
          }
        }

        if (_status == 'In') {
          if (_site!.lat != null && _site!.lng != null) {
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
          } else {
            debugPrint('Tracking skipped: site coordinates missing.');
          }
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
          await BackgroundTrackingService.stop();
        }

        if (mounted) {
          Haptics.heavy();
          setState(() {
            _photoPath = null;
            _checkedIn = _status == 'In';
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
          if (_status == 'Out') {
            await BackgroundTrackingService.stop();
          }
          if (mounted) {
            Haptics.medium();
            if (mounted) {
              setState(() {
                _photoPath = null;
                _checkedIn = _status == 'In';
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
                          value: _status == 'In' ? 'Check-in' : 'Check-out',
                          icon:
                              _status == 'In'
                                  ? Icons.login_rounded
                                  : Icons.logout_rounded,
                          color:
                              _status == 'In' ? tokens.success : tokens.warning,
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
                    if (moduleEnabled(ref, 'break') && _checkedIn)
                      _buildBreakPanel(tokens),
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
                                _busy ||
                                        (_status == 'Out' &&
                                            !_breakSession.canCheckOut)
                                    ? null
                                    : () => _submitAttendance(profile),
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
                        if (_status == 'Out' && !_breakSession.canCheckOut) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Checkout is disabled until the break is ended.',
                            style: AppTypography.micro(
                              context,
                            ).copyWith(color: tokens.warning),
                          ),
                        ],
                        const SizedBox(height: 16),
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
      accentColor = tokens.warning;
      statusLabel = 'Check-out';
      chipTone = StatusChipTone.warning;
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
