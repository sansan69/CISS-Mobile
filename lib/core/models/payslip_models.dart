class PayslipSummaryModel {
  const PayslipSummaryModel({
    required this.id,
    required this.periodLabel,
    required this.netPayLabel,
  });

  final String id;
  final String periodLabel;
  final String netPayLabel;

  factory PayslipSummaryModel.fromJson(Map<String, dynamic> json) {
    return PayslipSummaryModel(
      id: (json['id'] as String?) ?? '',
      periodLabel: (json['period'] as String?) ?? '',
      netPayLabel: json['netPay'] is num
          ? '₹${json['netPay']}'
          : (json['netPayLabel'] as String?) ?? '₹0',
    );
  }
}
