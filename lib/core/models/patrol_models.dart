class PatrolPointModel {
  const PatrolPointModel({
    required this.id,
    required this.name,
    required this.description,
    required this.requiresPhoto,
  });

  final String id;
  final String name;
  final String description;
  final bool requiresPhoto;

  factory PatrolPointModel.fromJson(Map<String, dynamic> json) {
    return PatrolPointModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      requiresPhoto: json['requiresPhoto'] != false,
    );
  }
}

class GuardPatrolActivityModel {
  const GuardPatrolActivityModel({
    required this.id,
    required this.type,
    required this.siteName,
    required this.district,
    required this.guardName,
    required this.activityAt,
    this.dutyPointName,
    this.patrolPointName,
    this.shiftLabel,
    this.photoUrl,
    this.notes,
  });

  final String id;
  final String type;
  final String siteName;
  final String district;
  final String guardName;
  final String activityAt;
  final String? dutyPointName;
  final String? patrolPointName;
  final String? shiftLabel;
  final String? photoUrl;
  final String? notes;

  factory GuardPatrolActivityModel.fromJson(Map<String, dynamic> json) {
    return GuardPatrolActivityModel(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'patrol',
      siteName: (json['siteName'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      guardName: (json['guardName'] as String?) ?? '',
      activityAt:
          (json['activityAt'] as String?) ??
          (json['createdAt'] as String?) ??
          '',
      dutyPointName: json['dutyPointName'] as String?,
      patrolPointName: json['patrolPointName'] as String?,
      shiftLabel: json['shiftLabel'] as String?,
      photoUrl: json['photoUrl'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class PatrolSettingsModel {
  const PatrolSettingsModel({
    required this.enabled,
    required this.hourlyNightPhotoEnabled,
    required this.hourlyIntervalMinutes,
    required this.nightWindowStart,
    required this.nightWindowEnd,
    required this.photoRequiredForPatrol,
  });

  final bool enabled;
  final bool hourlyNightPhotoEnabled;
  final int hourlyIntervalMinutes;
  final String nightWindowStart;
  final String nightWindowEnd;
  final bool photoRequiredForPatrol;

  factory PatrolSettingsModel.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return PatrolSettingsModel(
      enabled: data['enabled'] == true,
      hourlyNightPhotoEnabled: data['hourlyNightPhotoEnabled'] == true,
      hourlyIntervalMinutes:
          (data['hourlyIntervalMinutes'] as num?)?.toInt() ?? 60,
      nightWindowStart: (data['nightWindowStart'] as String?) ?? '20:00',
      nightWindowEnd: (data['nightWindowEnd'] as String?) ?? '06:00',
      photoRequiredForPatrol: data['photoRequiredForPatrol'] != false,
    );
  }
}

class ActiveDutyModel {
  const ActiveDutyModel({
    required this.siteId,
    required this.siteName,
    required this.district,
    this.dutyPointId,
    this.dutyPointName,
    this.shiftCode,
    this.shiftLabel,
    this.checkedInAt,
    this.activeSinceLabel,
  });

  final String siteId;
  final String siteName;
  final String district;
  final String? dutyPointId;
  final String? dutyPointName;
  final String? shiftCode;
  final String? shiftLabel;
  final String? checkedInAt;
  final String? activeSinceLabel;

  factory ActiveDutyModel.fromJson(Map<String, dynamic> json) {
    return ActiveDutyModel(
      siteId: (json['siteId'] as String?) ?? '',
      siteName: (json['siteName'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      dutyPointId: json['dutyPointId'] as String?,
      dutyPointName: json['dutyPointName'] as String?,
      shiftCode: json['shiftCode'] as String?,
      shiftLabel: json['shiftLabel'] as String?,
      checkedInAt: json['checkedInAt'] as String?,
      activeSinceLabel: json['activeSinceLabel'] as String?,
    );
  }
}

class HourlyRequirementModel {
  const HourlyRequirementModel({
    required this.enabled,
    required this.dueNow,
    required this.overdueMinutes,
    required this.nightWindowLabel,
    this.nextDueAt,
    this.lastSubmittedAt,
  });

  final bool enabled;
  final bool dueNow;
  final int overdueMinutes;
  final String nightWindowLabel;
  final String? nextDueAt;
  final String? lastSubmittedAt;

  factory HourlyRequirementModel.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return HourlyRequirementModel(
      enabled: data['enabled'] == true,
      dueNow: data['dueNow'] == true,
      overdueMinutes: (data['overdueMinutes'] as num?)?.toInt() ?? 0,
      nightWindowLabel: (data['nightWindowLabel'] as String?) ?? '',
      nextDueAt: data['nextDueAt'] as String?,
      lastSubmittedAt: data['lastSubmittedAt'] as String?,
    );
  }
}

class GuardPatrolStatusModel {
  const GuardPatrolStatusModel({
    required this.enabled,
    required this.guardName,
    required this.employeeId,
    required this.clientId,
    required this.clientName,
    required this.settings,
    required this.hourlyRequirement,
    required this.patrolPoints,
    required this.recentActivities,
    this.activeDuty,
  });

  final bool enabled;
  final String guardName;
  final String employeeId;
  final String clientId;
  final String clientName;
  final PatrolSettingsModel settings;
  final HourlyRequirementModel hourlyRequirement;
  final List<PatrolPointModel> patrolPoints;
  final List<GuardPatrolActivityModel> recentActivities;
  final ActiveDutyModel? activeDuty;

  factory GuardPatrolStatusModel.fromJson(Map<String, dynamic> json) {
    return GuardPatrolStatusModel(
      enabled: json['enabled'] == true,
      guardName: (json['guardName'] as String?) ?? '',
      employeeId: (json['employeeId'] as String?) ?? '',
      clientId: (json['clientId'] as String?) ?? '',
      clientName: (json['clientName'] as String?) ?? '',
      settings: PatrolSettingsModel.fromJson(
        json['settings'] as Map<String, dynamic>?,
      ),
      hourlyRequirement: HourlyRequirementModel.fromJson(
        json['hourlyRequirement'] as Map<String, dynamic>?,
      ),
      patrolPoints:
          (json['patrolPoints'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(PatrolPointModel.fromJson)
              .toList(),
      recentActivities:
          (json['recentActivities'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(GuardPatrolActivityModel.fromJson)
              .toList(),
      activeDuty: json['activeDuty'] is Map<String, dynamic>
          ? ActiveDutyModel.fromJson(
              Map<String, dynamic>.from(json['activeDuty'] as Map),
            )
          : null,
    );
  }
}
