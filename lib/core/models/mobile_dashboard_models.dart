import 'attendance_models.dart';
import 'leave_models.dart';
import 'report_models.dart';

class GuardDashboardSnapshot {
  const GuardDashboardSnapshot({
    required this.employeeName,
    required this.employeeId,
    required this.clientName,
    required this.district,
    required this.profilePhotoUrl,
    required this.presentDays,
    required this.absentDays,
    required this.workingDays,
    required this.leaveBalance,
    required this.latestEvalScore,
    required this.latestEvalPeriod,
    required this.nextShiftLabel,
    required this.nextShiftSiteName,
    required this.nextShiftDate,
    required this.recentAttendance,
  });

  final String employeeName;
  final String employeeId;
  final String clientName;
  final String district;
  final String? profilePhotoUrl;
  final int presentDays;
  final int absentDays;
  final int workingDays;
  final LeaveBalanceModel? leaveBalance;
  final num? latestEvalScore;
  final String? latestEvalPeriod;
  final String? nextShiftLabel;
  final String? nextShiftSiteName;
  final String? nextShiftDate;
  final List<AttendanceRecordModel> recentAttendance;
}

class FieldOfficerDashboardSnapshot {
  const FieldOfficerDashboardSnapshot({
    required this.name,
    required this.stateCode,
    required this.assignedDistricts,
    required this.totalGuards,
    required this.activeGuards,
    required this.attendanceSummary,
    required this.attendanceSites,
    required this.upcomingWorkOrders,
    required this.recentVisitReports,
    required this.recentTrainingReports,
    required this.recentWorkOrders,
  });

  final String name;
  final String stateCode;
  final List<String> assignedDistricts;
  final int totalGuards;
  final int activeGuards;
  final FieldOfficerAttendanceSummary attendanceSummary;
  final List<FieldOfficerAttendanceSite> attendanceSites;
  final List<WorkOrderModel> upcomingWorkOrders;
  final List<VisitReportModel> recentVisitReports;
  final List<TrainingReportModel> recentTrainingReports;
  final List<WorkOrderModel> recentWorkOrders;
}

class FieldOfficerAttendanceSummary {
  const FieldOfficerAttendanceSummary({
    required this.date,
    required this.checkedInToday,
    required this.onDutyNow,
    required this.districts,
  });

  final String date;
  final int checkedInToday;
  final int onDutyNow;
  final List<FieldOfficerDistrictAttendance> districts;

  factory FieldOfficerAttendanceSummary.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return FieldOfficerAttendanceSummary(
      date: (data['date'] as String?) ?? '',
      checkedInToday: (data['checkedInToday'] as num?)?.toInt() ?? 0,
      onDutyNow: (data['onDutyNow'] as num?)?.toInt() ?? 0,
      districts: (data['districts'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(FieldOfficerDistrictAttendance.fromJson)
          .toList(),
    );
  }
}

class FieldOfficerDistrictAttendance {
  const FieldOfficerDistrictAttendance({
    required this.district,
    required this.checkedInToday,
    required this.onDutyNow,
  });

  final String district;
  final int checkedInToday;
  final int onDutyNow;

  factory FieldOfficerDistrictAttendance.fromJson(Map<String, dynamic> json) {
    return FieldOfficerDistrictAttendance(
      district: (json['district'] as String?) ?? '',
      checkedInToday: (json['checkedInToday'] as num?)?.toInt() ?? 0,
      onDutyNow: (json['onDutyNow'] as num?)?.toInt() ?? 0,
    );
  }
}

class FieldOfficerAttendanceSite {
  const FieldOfficerAttendanceSite({
    required this.siteId,
    required this.siteName,
    required this.district,
    required this.checkedInToday,
    required this.onDutyNow,
    required this.clientName,
  });

  final String siteId;
  final String siteName;
  final String district;
  final int checkedInToday;
  final int onDutyNow;
  final String clientName;

  factory FieldOfficerAttendanceSite.fromJson(Map<String, dynamic> json) {
    return FieldOfficerAttendanceSite(
      siteId: (json['siteId'] as String?) ?? '',
      siteName: (json['siteName'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      checkedInToday: (json['checkedInToday'] as num?)?.toInt() ?? 0,
      onDutyNow: (json['onDutyNow'] as num?)?.toInt() ?? 0,
      clientName: (json['clientName'] as String?) ?? '',
    );
  }
}

class FieldOfficerAttendanceEntry {
  const FieldOfficerAttendanceEntry({
    required this.id,
    required this.guardName,
    required this.guardId,
    required this.employeeId,
    required this.siteName,
    required this.clientName,
    required this.district,
    required this.dateLabel,
    this.checkIn,
    this.checkOut,
    required this.dutyPointName,
    required this.shiftLabel,
    required this.status,
    this.photoUrl,
  });

  final String id;
  final String guardName;
  final String guardId;
  final String employeeId;
  final String siteName;
  final String clientName;
  final String district;
  final String dateLabel;
  final String? checkIn;
  final String? checkOut;
  final String dutyPointName;
  final String shiftLabel;
  final String status;
  final String? photoUrl;

  factory FieldOfficerAttendanceEntry.fromJson(Map<String, dynamic> json) {
    return FieldOfficerAttendanceEntry(
      id: (json['id'] as String?) ?? '',
      guardName: (json['guardName'] as String?) ?? '',
      guardId: (json['guardId'] as String?) ?? '',
      employeeId: (json['employeeId'] as String?) ?? '',
      siteName: (json['siteName'] as String?) ?? '',
      clientName: (json['clientName'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      dateLabel: (json['date'] as String?) ?? '',
      checkIn: json['checkIn'] as String?,
      checkOut: json['checkOut'] as String?,
      dutyPointName: (json['dutyPointName'] as String?) ?? '',
      shiftLabel: (json['shiftLabel'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      photoUrl: json['photoUrl'] as String?,
    );
  }
}
