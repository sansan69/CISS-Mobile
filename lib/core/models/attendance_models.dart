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
  });

  final String siteName;
  final String dateLabel;
  final String status;
  final String dutyPointName;
  final String shiftLabel;

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      siteName: (json['siteName'] as String?) ?? '',
      dateLabel:
          (json['date'] as String?) ?? (json['dateLabel'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      dutyPointName: (json['dutyPointName'] as String?) ?? '',
      shiftLabel: (json['shiftLabel'] as String?) ?? '',
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
