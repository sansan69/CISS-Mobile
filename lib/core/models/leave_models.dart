class LeaveRequestModel {
  const LeaveRequestModel({
    required this.id,
    required this.type,
    required this.fromDate,
    required this.toDate,
    required this.days,
    required this.reason,
    required this.status,
  });

  final String id;
  final String type;
  final String fromDate;
  final String toDate;
  final int days;
  final String reason;
  final String status;

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'casual',
      fromDate: (json['fromDate'] as String?) ?? '',
      toDate: (json['toDate'] as String?) ?? '',
      days: (json['days'] as num?)?.toInt() ?? 0,
      reason: (json['reason'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
    );
  }
}

class LeaveBalanceModel {
  const LeaveBalanceModel({
    required this.entitled,
    required this.taken,
    required this.balance,
  });

  final int entitled;
  final int taken;
  final int balance;

  factory LeaveBalanceModel.fromJson(Map<String, dynamic> json) {
    return LeaveBalanceModel(
      entitled: (json['entitled'] as num?)?.toInt() ?? 0,
      taken: (json['taken'] as num?)?.toInt() ?? 0,
      balance: (json['balance'] as num?)?.toInt() ?? 0,
    );
  }
}
