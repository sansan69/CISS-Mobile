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
