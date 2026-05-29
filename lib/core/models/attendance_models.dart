class ShiftTemplateModel {
  const ShiftTemplateModel({
    required this.code,
    required this.label,
    required this.startTime,
    required this.endTime,
  });

  final String code;
  final String label;
  final String startTime;
  final String endTime;

  factory ShiftTemplateModel.fromJson(Map<String, dynamic> json) {
    return ShiftTemplateModel(
      code: (json['code'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      startTime: (json['startTime'] as String?) ?? '',
      endTime: (json['endTime'] as String?) ?? '',
    );
  }
}

int? _shiftMinutes(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

ShiftTemplateModel? resolveActiveShiftTemplate(
  Iterable<ShiftTemplateModel> shiftTemplates, {
  DateTime? at,
}) {
  final shifts = shiftTemplates.toList(growable: false);
  if (shifts.isEmpty) return null;

  final now = at ?? DateTime.now();
  final totalMinutes = now.hour * 60 + now.minute;

  for (final shift in shifts) {
    final start = _shiftMinutes(shift.startTime);
    final end = _shiftMinutes(shift.endTime);
    if (start == null || end == null) continue;

    final crossesMidnight = start >= end;
    final inShift = crossesMidnight
        ? totalMinutes >= start || totalMinutes < end
        : totalMinutes >= start && totalMinutes < end;

    if (inShift) {
      return shift;
    }
  }

  return shifts.first;
}

class DutyPointModel {
  const DutyPointModel({
    required this.id,
    required this.name,
    required this.coverageMode,
    required this.dutyHours,
    this.shiftTemplates = const <ShiftTemplateModel>[],
  });

  final String id;
  final String name;
  final String coverageMode;
  final String dutyHours;
  final List<ShiftTemplateModel> shiftTemplates;

  factory DutyPointModel.fromJson(Map<String, dynamic> json) {
    return DutyPointModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      coverageMode: (json['coverageMode'] as String?) ?? '',
      dutyHours: (json['dutyHours'] as String?) ?? '',
      shiftTemplates:
          (json['shiftTemplates'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(ShiftTemplateModel.fromJson)
              .toList(),
    );
  }
}

class SiteOptionModel {
  const SiteOptionModel({
    required this.id,
    required this.siteName,
    required this.clientName,
    required this.district,
    required this.geofenceRadiusMeters,
    required this.strictGeofence,
    required this.shiftMode,
    required this.shiftPattern,
    required this.shiftTemplates,
    required this.sourceCollection,
    this.lat,
    this.lng,
    this.dutyPoints = const <DutyPointModel>[],
  });

  final String id;
  final String siteName;
  final String clientName;
  final String district;
  final num geofenceRadiusMeters;
  final bool strictGeofence;
  final String shiftMode;
  final String? shiftPattern;
  final List<ShiftTemplateModel> shiftTemplates;
  final String sourceCollection;
  final double? lat;
  final double? lng;
  final List<DutyPointModel> dutyPoints;

  factory SiteOptionModel.fromJson(Map<String, dynamic> json) {
    return SiteOptionModel(
      id: (json['id'] as String?) ?? '',
      siteName: (json['siteName'] as String?) ?? '',
      clientName: (json['clientName'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      geofenceRadiusMeters: (json['geofenceRadiusMeters'] as num?) ?? 150,
      strictGeofence: json['strictGeofence'] == true,
      shiftMode: (json['shiftMode'] as String?) ?? 'none',
      shiftPattern: json['shiftPattern'] as String?,
      shiftTemplates:
          (json['shiftTemplates'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(ShiftTemplateModel.fromJson)
              .toList(),
      sourceCollection: (json['sourceCollection'] as String?) ?? 'sites',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      dutyPoints: (json['dutyPoints'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(DutyPointModel.fromJson)
          .toList(),
    );
  }
}

class AttendanceRecordModel {
  const AttendanceRecordModel({
    required this.siteName,
    required this.dateLabel,
    required this.status,
    required this.dutyPointName,
    required this.shiftLabel,
    this.time,
    this.distanceMeters,
    this.photoUrl,
  });

  final String siteName;
  final String dateLabel;
  final String status;
  final String dutyPointName;
  final String shiftLabel;
  final String? time;
  final num? distanceMeters;
  final String? photoUrl;

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      siteName: (json['siteName'] as String?) ?? '',
      dateLabel:
          (json['date'] as String?) ?? (json['dateLabel'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      dutyPointName: (json['dutyPointName'] as String?) ?? '',
      shiftLabel: (json['shiftLabel'] as String?) ?? '',
      time: json['time'] as String?,
      distanceMeters: json['distanceMeters'] as num?,
      photoUrl: json['photoUrl'] as String?,
    );
  }
}

class AttendanceHintModel {
  const AttendanceHintModel({
    this.lastAttendanceDate,
    this.lastStatus,
    this.lastDutyPointId,
    this.lastShiftCode,
  });

  final String? lastAttendanceDate;
  final String? lastStatus;
  final String? lastDutyPointId;
  final String? lastShiftCode;
}

class PublicAttendanceEmployeeModel {
  const PublicAttendanceEmployeeModel({
    required this.id,
    required this.fullName,
    this.employeeCode,
    this.phoneNumber,
    this.clientName,
    this.attendanceHint,
  });

  final String id;
  final String? employeeCode;
  final String fullName;
  final String? phoneNumber;
  final String? clientName;
  final AttendanceHintModel? attendanceHint;
}
