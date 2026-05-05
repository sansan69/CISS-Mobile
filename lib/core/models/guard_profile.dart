class GuardProfileModel {
  const GuardProfileModel({
    required this.id,
    required this.fullName,
    required this.employeeId,
    required this.clientName,
    required this.district,
    required this.phoneNumber,
    required this.status,
    this.gender,
    this.joiningDate,
    this.resourceIdNumber,
    this.profilePhotoUrl,
    this.address,
  });

  final String id;
  final String fullName;
  final String employeeId;
  final String clientName;
  final String district;
  final String phoneNumber;
  final String status;
  final String? gender;
  final String? joiningDate;
  final String? resourceIdNumber;
  final String? profilePhotoUrl;
  final String? address;

  factory GuardProfileModel.fromJson(
    Map<String, dynamic> json, {
    String id = '',
  }) {
    return GuardProfileModel(
      id: id,
      fullName: (json['fullName'] as String?)?.trim().isNotEmpty == true
          ? json['fullName'] as String
          : ((json['name'] as String?) ?? '').trim(),
      employeeId: (json['employeeId'] as String?) ?? '',
      clientName: (json['clientName'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      phoneNumber: (json['phoneNumber'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      gender: json['gender'] as String?,
      joiningDate: json['joiningDate'] as String?,
      resourceIdNumber: json['resourceIdNumber'] as String?,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      address: json['address'] as String?,
    );
  }
}
