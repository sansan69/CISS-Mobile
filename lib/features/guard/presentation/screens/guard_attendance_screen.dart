import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/attendance_models.dart';
import '../../../../../core/models/guard_profile.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/sync/providers.dart';
import '../../../../../core/location/background_tracking_service.dart';
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

class _GuardAttendanceScreenState extends ConsumerState<GuardAttendanceScreen> {
  final ImagePicker _picker = ImagePicker();
  SiteOptionModel? _site;
  DutyPointModel? _dutyPoint;
  ShiftTemplateModel? _shift;
  String _status = 'In';
  String? _error;
  bool _busy = false;
  XFile? _photo;
  Position? _position;

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

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    setState(() {
      _position = position;
      _error = null;
    });
  }

  Future<void> _capturePhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _photo = picked;
        _error = null;
      });
    }
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
    if (_photo == null) {
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

    try {
      final bytes = await _photo!.readAsBytes();
      final mimeType = _photo!.mimeType ?? 'image/jpeg';
      final dataUrl = await ref
          .read(mobileRepositoryProvider)
          .encodeFileToDataUrl(bytes, mimeType);

      final dutyPoint =
          _dutyPoint ??
          (_site!.dutyPoints.length == 1 ? _site!.dutyPoints.first : null);
      final shift =
          _shift ??
          (dutyPoint?.shiftTemplates.isNotEmpty == true
              ? dutyPoint!.shiftTemplates.first
              : _site!.shiftTemplates.isNotEmpty
              ? _site!.shiftTemplates.first
              : null);

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
        'distanceMeters': 0,
        'gpsAccuracyMeters': _position!.accuracy,
        'locationAccuracyMeters': _position!.accuracy,
        'geofenceRadiusAtTime': _site!.geofenceRadiusMeters,
        'sourceCollection': _site!.sourceCollection,
        'photoCapturedAt': DateTime.now().toUtc().toIso8601String(),
        'deviceInfo': <String, dynamic>{'userAgent': 'flutter-mobile'},
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
        } else {
          BackgroundTrackingService.stop();
        }

        if (mounted) {
          setState(() {
            _photo = null;
            _error = 'Attendance submitted successfully.';
          });
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
          await ref.read(offlineQueueProvider).enqueue(
            path: '/api/attendance/submit',
            method: 'POST',
            body: {
              ...payload,
              'photoDataUrl': dataUrl,
            },
          );
          if (mounted) {
            setState(() {
              _photo = null;
              _error = 'Offline: Attendance queued for sync.';
            });
          }
        } else {
          rethrow;
        }
      }
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
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
                final filteredSites = sites
                    .where((s) => s.district == profile.district)
                    .toList();
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
                    GuardFormCard(
                      children: <Widget>[
                        DropdownButtonFormField<SiteOptionModel>(
                          isExpanded: true,
                          initialValue: _site,
                          items: filteredSites
                              .map(
                                (site) => DropdownMenuItem<SiteOptionModel>(
                                  value: site,
                                  child: Text(
                                    '${site.siteName} • ${site.district}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (site) {
                            setState(() {
                              _site = site;
                              _dutyPoint = site?.dutyPoints.isNotEmpty == true
                                  ? site!.dutyPoints.first
                                  : null;
                              _shift =
                                  _dutyPoint?.shiftTemplates.isNotEmpty == true
                                  ? _dutyPoint!.shiftTemplates.first
                                  : null;
                            });
                          },
                          decoration: const InputDecoration(labelText: 'Site'),
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
                                        dutyPoint?.shiftTemplates.isNotEmpty ==
                                            true
                                        ? dutyPoint!.shiftTemplates.first
                                        : null;
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
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: Text(
                                _photo == null
                                    ? 'Capture Photo'
                                    : 'Photo selected',
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
                                      _error!.toLowerCase().contains('queued')
                                  ? tokens.successSoft
                                  : tokens.dangerSoft,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color:
                                    _error!.toLowerCase().contains('success') ||
                                        _error!.toLowerCase().contains('queued')
                                    ? tokens.success
                                    : tokens.danger,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        ElevatedButton(
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
      return ref.read(mobileRepositoryProvider).fetchAttendanceSites();
    });
