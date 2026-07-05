class AdminDashboardModel {
  final int totalGuards;
  final int activeGuards;
  final int checkedInToday;
  final int pendingWorkOrders;
  final int totalClients;
  final int totalSites;

  const AdminDashboardModel({
    required this.totalGuards,
    required this.activeGuards,
    required this.checkedInToday,
    required this.pendingWorkOrders,
    required this.totalClients,
    required this.totalSites,
  });

  factory AdminDashboardModel.fromJson(Map<String, dynamic> json) {
    return AdminDashboardModel(
      totalGuards: (json['totalGuards'] as num?)?.toInt() ?? 0,
      activeGuards: (json['activeGuards'] as num?)?.toInt() ?? 0,
      checkedInToday: (json['checkedInToday'] as num?)?.toInt() ?? 0,
      pendingWorkOrders: (json['pendingWorkOrders'] as num?)?.toInt() ?? 0,
      totalClients: (json['totalClients'] as num?)?.toInt() ?? 0,
      totalSites: (json['totalSites'] as num?)?.toInt() ?? 0,
    );
  }
}

class EmployeeModel {
  final String id;
  final String name;
  final String fullName;
  final String employeeId;
  final String employeeCode;
  final String phoneNumber;
  final String clientId;
  final String clientName;
  final String district;
  final String siteName;
  final String status;

  const EmployeeModel({
    required this.id,
    required this.name,
    required this.fullName,
    required this.employeeId,
    required this.employeeCode,
    required this.phoneNumber,
    required this.clientId,
    required this.clientName,
    required this.district,
    required this.siteName,
    required this.status,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['fullName']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? json['name']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      clientId: json['clientId']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      siteName: json['siteName']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
    );
  }
}

class TrainingModuleModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final int durationMinutes;
  final int passingScore;
  final String? contentUrl;
  final String? contentType;
  final String? contentPath;
  final String? contentFileName;
  final bool isActive;
  final String? createdAt;
  final String? createdBy;

  const TrainingModuleModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.durationMinutes,
    required this.passingScore,
    this.contentUrl,
    this.contentType,
    this.contentPath,
    this.contentFileName,
    required this.isActive,
    this.createdAt,
    this.createdBy,
  });

  factory TrainingModuleModel.fromJson(Map<String, dynamic> json) {
    return TrainingModuleModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'safety',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
      passingScore: (json['passingScore'] as num?)?.toInt() ?? 70,
      contentUrl: json['contentUrl']?.toString(),
      contentType: json['contentType']?.toString(),
      contentPath: json['contentPath']?.toString(),
      contentFileName: json['contentFileName']?.toString(),
      isActive: json['isActive'] == true,
      createdAt: _timestampToString(json['createdAt']),
      createdBy: json['createdBy']?.toString(),
    );
  }

  String get categoryLabel {
    switch (category.toLowerCase()) {
      case 'safety':
        return 'Safety';
      case 'legal':
        return 'Legal';
      case 'conduct':
        return 'Conduct';
      case 'skills':
        return 'Skills';
      case 'emergency':
        return 'Emergency';
      default:
        return category;
    }
  }
}

class QuestionBankModel {
  final String id;
  final String title;
  final String moduleId;
  final int questionsPerAttempt;
  final int timeLimitMinutes;
  final bool shuffle;
  final int maxAttempts;
  final int questionCount;
  final String? createdAt;

  const QuestionBankModel({
    required this.id,
    required this.title,
    required this.moduleId,
    required this.questionsPerAttempt,
    required this.timeLimitMinutes,
    required this.shuffle,
    required this.maxAttempts,
    required this.questionCount,
    this.createdAt,
  });

  factory QuestionBankModel.fromJson(Map<String, dynamic> json) {
    return QuestionBankModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      moduleId: json['moduleId']?.toString() ?? '',
      questionsPerAttempt: (json['questionsPerAttempt'] as num?)?.toInt() ?? 10,
      timeLimitMinutes: (json['timeLimitMinutes'] as num?)?.toInt() ?? 0,
      shuffle: json['shuffle'] == true,
      maxAttempts: (json['maxAttempts'] as num?)?.toInt() ?? 0,
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      createdAt: _timestampToString(json['createdAt']),
    );
  }
}

class LeaderboardEntryModel {
  final int rank;
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeCode;
  final String clientId;
  final String clientName;
  final String district;
  final double currentMonthScore;
  final double previousMonthScore;
  final double allTimeAvgScore;
  final int totalEvaluations;
  final int totalTrainingsCompleted;
  final double uniformComplianceRate;
  final double attendanceRate;
  final List<String> badges;

  const LeaderboardEntryModel({
    required this.rank,
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.clientId,
    required this.clientName,
    required this.district,
    required this.currentMonthScore,
    required this.previousMonthScore,
    required this.allTimeAvgScore,
    required this.totalEvaluations,
    required this.totalTrainingsCompleted,
    required this.uniformComplianceRate,
    required this.attendanceRate,
    required this.badges,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? '',
      clientId: json['clientId']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      currentMonthScore: (json['currentMonthScore'] as num?)?.toDouble() ?? 0,
      previousMonthScore: (json['previousMonthScore'] as num?)?.toDouble() ?? 0,
      allTimeAvgScore: (json['allTimeAvgScore'] as num?)?.toDouble() ?? 0,
      totalEvaluations: (json['totalEvaluations'] as num?)?.toInt() ?? 0,
      totalTrainingsCompleted: (json['totalTrainingsCompleted'] as num?)?.toInt() ?? 0,
      uniformComplianceRate: (json['uniformComplianceRate'] as num?)?.toDouble() ?? 0,
      attendanceRate: (json['attendanceRate'] as num?)?.toDouble() ?? 0,
      badges: (json['badges'] as List<dynamic>?)?.whereType<String>().toList() ?? const [],
    );
  }
}

class PayrollCycleModel {
  final String id;
  final String period;
  final String status;
  final double totalGross;
  final double totalNetPay;
  final double totalEpfEsic;
  final int employeeCount;
  final String? createdAt;

  const PayrollCycleModel({
    required this.id,
    required this.period,
    required this.status,
    required this.totalGross,
    required this.totalNetPay,
    required this.totalEpfEsic,
    required this.employeeCount,
    this.createdAt,
  });

  factory PayrollCycleModel.fromJson(Map<String, dynamic> json) {
    return PayrollCycleModel(
      id: json['id']?.toString() ?? '',
      period: json['period']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      totalGross: (json['totalGross'] as num?)?.toDouble() ?? 0,
      totalNetPay: (json['totalNetPay'] as num?)?.toDouble() ?? 0,
      totalEpfEsic: (json['totalEpfEsic'] as num?)?.toDouble() ?? 0,
      employeeCount: (json['employeeCount'] as num?)?.toInt() ?? 0,
      createdAt: _timestampToString(json['createdAt']),
    );
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'Draft';
      case 'processing':
        return 'Processing';
      case 'review':
        return 'Review';
      case 'finalized':
        return 'Finalized';
      case 'paid':
        return 'Paid';
      default:
        return status;
    }
  }
}

class PayrollEntryModel {
  final String id;
  final String cycleId;
  final String employeeName;
  final String employeeId;
  final double grossPay;
  final double netPay;
  final double epf;
  final double esic;
  final int daysWorked;
  final int overtimeHours;

  const PayrollEntryModel({
    required this.id,
    required this.cycleId,
    required this.employeeName,
    required this.employeeId,
    required this.grossPay,
    required this.netPay,
    required this.epf,
    required this.esic,
    required this.daysWorked,
    required this.overtimeHours,
  });

  factory PayrollEntryModel.fromJson(Map<String, dynamic> json) {
    return PayrollEntryModel(
      id: json['id']?.toString() ?? '',
      cycleId: json['cycleId']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? '',
      grossPay: (json['grossPay'] as num?)?.toDouble() ?? 0,
      netPay: (json['netPay'] as num?)?.toDouble() ?? 0,
      epf: (json['epf'] as num?)?.toDouble() ?? 0,
      esic: (json['esic'] as num?)?.toDouble() ?? 0,
      daysWorked: (json['daysWorked'] as num?)?.toInt() ?? 0,
      overtimeHours: (json['overtimeHours'] as num?)?.toInt() ?? 0,
    );
  }
}

class ClientModel {
  final String id;
  final String name;
  final String? stateCode;
  final String? portalSubdomain;
  final bool portalEnabled;
  final String? portalUrl;
  final List<String> nationalHolidayList;
  final double uniformAllowanceMonthly;
  final double fieldAllowanceMonthly;
  final String? createdAt;

  const ClientModel({
    required this.id,
    required this.name,
    this.stateCode,
    this.portalSubdomain,
    required this.portalEnabled,
    this.portalUrl,
    required this.nationalHolidayList,
    required this.uniformAllowanceMonthly,
    required this.fieldAllowanceMonthly,
    this.createdAt,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      stateCode: json['stateCode']?.toString(),
      portalSubdomain: json['portalSubdomain']?.toString(),
      portalEnabled: json['portalEnabled'] == true,
      portalUrl: json['portalUrl']?.toString(),
      nationalHolidayList: (json['nationalHolidayList'] as List<dynamic>?)?.whereType<String>().toList() ?? const [],
      uniformAllowanceMonthly: (json['uniformAllowanceMonthly'] as num?)?.toDouble() ?? 0,
      fieldAllowanceMonthly: (json['fieldAllowanceMonthly'] as num?)?.toDouble() ?? 0,
      createdAt: _timestampToString(json['createdAt']),
    );
  }
}

class FieldOfficerModel {
  final String id;
  final String uid;
  final String email;
  final String name;
  final String? stateCode;
  final List<String> assignedDistricts;
  final String? createdAt;

  const FieldOfficerModel({
    required this.id,
    required this.uid,
    required this.email,
    required this.name,
    this.stateCode,
    required this.assignedDistricts,
    this.createdAt,
  });

  factory FieldOfficerModel.fromJson(Map<String, dynamic> json) {
    return FieldOfficerModel(
      id: json['id']?.toString() ?? '',
      uid: json['uid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      stateCode: json['stateCode']?.toString(),
      assignedDistricts: (json['assignedDistricts'] as List<dynamic>?)?.whereType<String>().toList() ?? const [],
      createdAt: _timestampToString(json['createdAt']),
    );
  }
}

class AttendanceReportModel {
  final String employeeId;
  final String employeeName;
  final String clientName;
  final String district;
  final int presentDays;
  final int absentDays;
  final int workingDays;

  const AttendanceReportModel({
    required this.employeeId,
    required this.employeeName,
    required this.clientName,
    required this.district,
    required this.presentDays,
    required this.absentDays,
    required this.workingDays,
  });

  factory AttendanceReportModel.fromJson(Map<String, dynamic> json) {
    return AttendanceReportModel(
      employeeId: json['employeeId']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      presentDays: (json['presentDays'] as num?)?.toInt() ?? 0,
      absentDays: (json['absentDays'] as num?)?.toInt() ?? 0,
      workingDays: (json['workingDays'] as num?)?.toInt() ?? 0,
    );
  }
}

String? _timestampToString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  try {
    final dt = DateTime.tryParse(value.toString());
    return dt?.toIso8601String();
  } catch (_) {
    return null;
  }
}
