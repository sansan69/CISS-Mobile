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
  });

  final String id;
  final String title;
  final String status;
  final String scoreLabel;

  factory EvaluationModel.fromJson(Map<String, dynamic> json) {
    return EvaluationModel(
      id: (json['id'] as String?) ?? '',
      title:
          (json['period'] as String?) ??
          (json['title'] as String?) ??
          'Evaluation',
      status: (json['status'] as String?) ?? 'submitted',
      scoreLabel: json['normalizedScore'] != null
          ? '${json['normalizedScore']}%'
          : (json['score'] != null ? '${json['score']}' : '-'),
    );
  }
}
