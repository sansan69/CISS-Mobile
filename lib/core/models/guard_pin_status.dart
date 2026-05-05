class GuardPinStatus {
  const GuardPinStatus({
    required this.found,
    required this.hasPin,
    this.employeeName,
    this.employeeId,
  });

  final bool found;
  final bool hasPin;
  final String? employeeName;
  final String? employeeId;
}
