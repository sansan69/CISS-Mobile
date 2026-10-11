class TrainingAssignmentModel {
  const TrainingAssignmentModel({
    required this.id,
    required this.title,
    required this.status,
    required this.dueLabel,
    this.contentUrl,
    this.contentType,
    this.contentFileName,
  });

  final String id;
  final String title;
  final String status;
  final String dueLabel;
  final String? contentUrl;
  final String? contentType;
  final String? contentFileName;

  factory TrainingAssignmentModel.fromJson(Map<String, dynamic> json) {
    return TrainingAssignmentModel(
      id: (json['id'] as String?) ?? '',
      title:
          (json['contentFileName'] as String?) ??
          (json['moduleTitle'] as String?) ??
          (json['title'] as String?) ??
          'Training Module',
      status: (json['status'] as String?) ?? 'assigned',
      dueLabel:
          (json['assignedAt'] as String?) ??
          (json['dueDate'] as String?) ??
          (json['createdAt'] as String?) ??
          '',
      contentUrl: json['contentUrl'] as String?,
      contentType: json['contentType'] as String?,
      contentFileName: json['contentFileName'] as String?,
    );
  }
}

/// A single ranked row on the guard training leaderboard.
class GuardTrainingLeaderboardEntry {
  const GuardTrainingLeaderboardEntry({
    required this.rank,
    required this.id,
    required this.employeeName,
    required this.trainingScore,
    required this.totalTrainingsCompleted,
    required this.trainingAttempts,
    this.employeeId = '',
    this.employeeCode = '',
    this.clientName = '',
    this.district = '',
    this.profilePicUrl,
    this.lastAttemptAt,
  });

  final int rank;

  /// Firestore employee document id (stable per guard).
  final String id;
  final String employeeName;
  final String employeeId;
  final String employeeCode;
  final String clientName;
  final String district;
  final String? profilePicUrl;

  /// Most recent quiz score (0–100). Used as the primary ranking metric.
  final int trainingScore;
  final int totalTrainingsCompleted;
  final int trainingAttempts;
  final DateTime? lastAttemptAt;

  factory GuardTrainingLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return GuardTrainingLeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      id: (json['id'] as String?) ?? '',
      employeeName: (json['employeeName'] as String?) ?? '',
      employeeId: (json['employeeId'] as String?) ?? '',
      employeeCode: (json['employeeCode'] as String?) ?? '',
      clientName: (json['clientName'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      profilePicUrl: json['profilePicUrl'] as String?,
      trainingScore: (json['trainingScore'] as num?)?.toInt() ?? 0,
      totalTrainingsCompleted:
          (json['totalTrainingsCompleted'] as num?)?.toInt() ?? 0,
      trainingAttempts: (json['trainingAttempts'] as num?)?.toInt() ?? 0,
      lastAttemptAt: DateTime.tryParse(json['lastAttemptAt']?.toString() ?? ''),
    );
  }
}

/// Container for the guard training leaderboard response.
class GuardTrainingLeaderboard {
  const GuardTrainingLeaderboard({
    required this.district,
    required this.currentMonth,
    required this.entries,
    this.myRank,
    this.myEntry,
  });

  final String district;
  final String currentMonth;
  final List<GuardTrainingLeaderboardEntry> entries;
  final int? myRank;
  final GuardTrainingLeaderboardEntry? myEntry;

  factory GuardTrainingLeaderboard.fromJson(Map<String, dynamic> json) {
    final rawScores = json['scores'] as List<dynamic>? ?? const <dynamic>[];
    final dynamic myEntryJson = json['myEntry'];
    return GuardTrainingLeaderboard(
      district: (json['district'] as String?) ?? '',
      currentMonth: (json['currentMonth'] as String?) ?? '',
      entries: rawScores
          .whereType<Map>()
          .map(
            (entry) => GuardTrainingLeaderboardEntry.fromJson(
              Map<String, dynamic>.from(entry),
            ),
          )
          .toList(),
      myRank: (json['myRank'] as num?)?.toInt(),
      myEntry: myEntryJson is Map
          ? GuardTrainingLeaderboardEntry.fromJson(
              Map<String, dynamic>.from(myEntryJson),
            )
          : null,
    );
  }
}

class EvaluationModel {
  const EvaluationModel({
    required this.id,
    required this.title,
    required this.status,
    required this.scoreLabel,
    this.employeeName = '',
    this.employeeId = '',
    this.period = '',
    this.totalScore = 0,
    this.punctualityScore = 0,
    this.uniformScore = 0,
    this.behaviorScore = 0,
    this.skillScore = 0,
    this.clientFeedbackScore = 0,
    this.comments = '',
    this.district = '',
    this.clientName = '',
  });

  final String id;
  final String title;
  final String status;
  final String scoreLabel;
  final String employeeName;
  final String employeeId;
  final String period;
  final double totalScore;
  final double punctualityScore;
  final double uniformScore;
  final double behaviorScore;
  final double skillScore;
  final double clientFeedbackScore;
  final String comments;
  final String district;
  final String clientName;

  factory EvaluationModel.fromJson(Map<String, dynamic> json) {
    final criteria = json['criteria'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['criteria'] as Map)
        : null;
    final total = (json['totalScore'] as num?)?.toDouble() ??
        (criteria != null
            ? (criteria.values
                    .whereType<num>()
                    .fold<double>(0, (sum, v) => sum + v.toDouble()))
            : 0);

    return EvaluationModel(
      id: (json['id'] as String?) ?? '',
      title: (json['period'] as String?) ??
          (json['title'] as String?) ??
          'Evaluation',
      status: (json['status'] as String?) ?? 'submitted',
      scoreLabel: json['normalizedScore'] != null
          ? '${json['normalizedScore']}%'
          : (json['score'] != null ? '${json['score']}' : '-'),
      employeeName: json['employeeName']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? '',
      period: json['period']?.toString() ?? '',
      totalScore: total,
      punctualityScore: (criteria?['punctuality'] as num?)?.toDouble() ?? 0,
      uniformScore: (criteria?['uniformCompliance'] as num?)?.toDouble() ?? 0,
      behaviorScore: (criteria?['behaviorProfessionalism'] as num?)?.toDouble() ?? 0,
      skillScore: (criteria?['skillCompetency'] as num?)?.toDouble() ?? 0,
      clientFeedbackScore: (criteria?['clientFeedback'] as num?)?.toDouble() ?? 0,
      comments: json['comments']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
    );
  }
}
