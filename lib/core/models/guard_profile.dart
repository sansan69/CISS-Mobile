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
    this.emailAddress,
    // ── Document fields ─────────────────────────────────────────────
    this.idProofType,
    this.idProofNumber,
    this.idProofFrontUrl,
    this.idProofBackUrl,
    this.addressProofType,
    this.addressProofNumber,
    this.addressProofFrontUrl,
    this.addressProofBackUrl,
    this.signatureUrl,
    this.bankAccountNumber,
    this.bankIfscCode,
    this.bankName,
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
  final String? emailAddress;
  // ── Document fields ─────────────────────────────────────────────
  final String? idProofType;
  final String? idProofNumber;
  final String? idProofFrontUrl;
  final String? idProofBackUrl;
  final String? addressProofType;
  final String? addressProofNumber;
  final String? addressProofFrontUrl;
  final String? addressProofBackUrl;
  final String? signatureUrl;
  final String? bankAccountNumber;
  final String? bankIfscCode;
  final String? bankName;

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
      profilePhotoUrl:
          (json['profilePhotoUrl'] as String?) ??
          (json['profilePictureUrl'] as String?),
      address: json['address'] as String?,
      emailAddress: json['emailAddress'] as String?,
      // ── Document fields ─────────────────────────────────────────────
      idProofType: json['idProofType'] as String?,
      idProofNumber: json['idProofNumber'] as String?,
      idProofFrontUrl: json['idProofFrontUrl'] as String?,
      idProofBackUrl: json['idProofBackUrl'] as String?,
      addressProofType: json['addressProofType'] as String?,
      addressProofNumber: json['addressProofNumber'] as String?,
      addressProofFrontUrl: json['addressProofFrontUrl'] as String?,
      addressProofBackUrl: json['addressProofBackUrl'] as String?,
      signatureUrl: json['signatureUrl'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      bankIfscCode: json['bankIfscCode'] as String?,
      bankName: json['bankName'] as String?,
    );
  }

  /// Documents that have a download URL available.
  List<GuardDocument> get documents {
    final docs = <GuardDocument>[];
    if (profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty) {
      docs.add(GuardDocument(
        label: 'Profile Photo',
        url: profilePhotoUrl!,
        icon: 'photo',
      ));
    }
    if (idProofFrontUrl != null && idProofFrontUrl!.isNotEmpty) {
      docs.add(GuardDocument(
        label: idProofType != null && idProofType!.isNotEmpty
            ? '$idProofType (Front)'
            : 'ID Proof (Front)',
        url: idProofFrontUrl!,
        icon: 'document',
      ));
    }
    if (idProofBackUrl != null && idProofBackUrl!.isNotEmpty) {
      docs.add(GuardDocument(
        label: idProofType != null && idProofType!.isNotEmpty
            ? '$idProofType (Back)'
            : 'ID Proof (Back)',
        url: idProofBackUrl!,
        icon: 'document',
      ));
    }
    if (addressProofFrontUrl != null && addressProofFrontUrl!.isNotEmpty) {
      docs.add(GuardDocument(
        label: addressProofType != null && addressProofType!.isNotEmpty
            ? '$addressProofType (Front)'
            : 'Address Proof (Front)',
        url: addressProofFrontUrl!,
        icon: 'document',
      ));
    }
    if (addressProofBackUrl != null && addressProofBackUrl!.isNotEmpty) {
      docs.add(GuardDocument(
        label: addressProofType != null && addressProofType!.isNotEmpty
            ? '$addressProofType (Back)'
            : 'Address Proof (Back)',
        url: addressProofBackUrl!,
        icon: 'document',
      ));
    }
    if (signatureUrl != null && signatureUrl!.isNotEmpty) {
      docs.add(GuardDocument(
        label: 'Signature',
        url: signatureUrl!,
        icon: 'signature',
      ));
    }
    return docs;
  }
}

/// A single document with label and download URL.
class GuardDocument {
  const GuardDocument({
    required this.label,
    required this.url,
    required this.icon,
  });

  final String label;
  final String url;
  final String icon; // 'photo', 'document', 'signature'
}
