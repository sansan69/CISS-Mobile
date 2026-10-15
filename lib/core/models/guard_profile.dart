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
    this.tcsCategory,
    this.dateOfBirth,
    this.fatherName,
    this.motherName,
    this.maritalStatus,
    this.spouseName,
    this.educationalQualification,
    this.otherQualification,
    this.qualificationName,
    this.nationality,
    this.identificationMark,
    this.heightCm,
    this.weightKg,
    this.joiningDate,
    this.resourceIdNumber,
    this.jobDesignation,
    this.siteName,
    this.profilePhotoUrl,
    this.address,
    this.emailAddress,
    this.exitDate,
    this.createdAt,
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
    this.documentStatus = const <String, String>{},
    this.documentAvailability = const <String, bool>{},
    this.missingDocuments = const <String>[],
  });

  final String id;
  final String fullName;
  final String employeeId;
  final String clientName;
  final String district;
  final String phoneNumber;
  final String status;
  final String? gender;
  final String? tcsCategory;
  bool get isTcs => clientName.trim().toUpperCase() == 'TCS';
  String? get categoryLabel =>
      !isTcs
          ? null
          : switch (tcsCategory) {
            'adhoc' => 'Adhoc',
            'permanent' => 'Permanent',
            _ => 'Category not set',
          };
  final String? dateOfBirth;
  final String? fatherName;
  final String? motherName;
  final String? maritalStatus;
  final String? spouseName;
  final String? educationalQualification;
  final String? otherQualification;
  final String? qualificationName;
  final String? nationality;
  final String? identificationMark;
  final double? heightCm;
  final double? weightKg;
  final String? joiningDate;
  final String? resourceIdNumber;
  final String? jobDesignation;
  final String? siteName;
  final String? profilePhotoUrl;
  final String? address;
  final String? emailAddress;
  final String? exitDate;
  final String? createdAt;
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

  /// Per-category enrolment completion: `aadhaar`/`identity`/`address` → "complete" | "missing".
  final Map<String, String> documentStatus;

  /// Availability of individual documents exposed by the scoped profile API.
  final Map<String, bool> documentAvailability;
  final List<String> missingDocuments;

  /// True when the guard still owes the Aadhaar proof for ESIC/EPF registration.
  bool get canUploadAadhaar => _isMissing('aadhaar');

  /// True when the guard still owes an identity proof document.
  bool get canUploadIdentity => _isMissing('identity');

  /// True when the guard still owes an address proof document.
  bool get canUploadAddress => _isMissing('address');

  /// True when any enrolment document is still missing and can be self-uploaded.
  bool get anyMissingDocuments => missingDocuments.isNotEmpty;

  bool _isMissing(String category) {
    return missingDocuments.contains(category) ||
        documentStatus[category] == 'missing';
  }

  factory GuardProfileModel.fromJson(
    Map<String, dynamic> json, {
    String id = '',
  }) {
    return GuardProfileModel(
      id: id,
      fullName:
          (json['fullName'] as String?)?.trim().isNotEmpty == true
              ? json['fullName'] as String
              : ((json['name'] as String?) ?? '').trim(),
      employeeId: (json['employeeId'] as String?) ?? '',
      clientName: (json['clientName'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      phoneNumber: (json['phoneNumber'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      gender: json['gender'] as String?,
      tcsCategory:
          (json['clientName']?.toString().trim().toUpperCase() == 'TCS' &&
                  ['adhoc', 'permanent'].contains(json['tcsCategory']))
              ? json['tcsCategory'] as String
              : null,
      dateOfBirth: json['dateOfBirth'] as String?,
      fatherName: json['fatherName'] as String?,
      motherName: json['motherName'] as String?,
      maritalStatus: json['maritalStatus'] as String?,
      spouseName: json['spouseName'] as String?,
      educationalQualification: json['educationalQualification'] as String?,
      otherQualification: json['otherQualification'] as String?,
      qualificationName: json['qualificationName'] as String?,
      nationality: json['nationality'] as String?,
      identificationMark: json['identificationMark'] as String?,
      heightCm: _numberValue(json['heightCm']),
      weightKg: _numberValue(json['weightKg']),
      joiningDate: json['joiningDate'] as String?,
      resourceIdNumber: json['resourceIdNumber'] as String?,
      jobDesignation: json['jobDesignation'] as String?,
      siteName: json['siteName'] as String?,
      profilePhotoUrl:
          (json['profilePhotoUrl'] as String?) ??
          (json['profilePictureUrl'] as String?),
      address: json['address'] as String?,
      emailAddress: json['emailAddress'] as String?,
      exitDate: json['exitDate'] as String?,
      createdAt: json['createdAt'] as String?,
      // ── Document fields ─────────────────────────────────────────────
      idProofType:
          (json['idProofType'] as String?) ??
          (json['identityProofType'] as String?),
      idProofNumber:
          (json['idProofNumber'] as String?) ??
          (json['identityProofNumber'] as String?),
      idProofFrontUrl:
          (json['idProofFrontUrl'] as String?) ??
          (json['identityProofUrlFront'] as String?),
      idProofBackUrl:
          (json['idProofBackUrl'] as String?) ??
          (json['identityProofUrlBack'] as String?),
      addressProofType: json['addressProofType'] as String?,
      addressProofNumber: json['addressProofNumber'] as String?,
      addressProofFrontUrl: json['addressProofFrontUrl'] as String?,
      addressProofBackUrl: json['addressProofBackUrl'] as String?,
      signatureUrl: json['signatureUrl'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      bankIfscCode: json['bankIfscCode'] as String?,
      bankName: json['bankName'] as String?,
      documentStatus: _stringMap(
        json['documentStatus'] ?? json['documentCompletion'],
      ),
      documentAvailability: _boolMap(json['documentAvailability']),
      missingDocuments:
          (json['missingDocuments'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
    );
  }

  static double? _numberValue(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) return <String, String>{};
    return Map<String, String>.from(
      value.map((key, item) => MapEntry(key.toString(), item.toString())),
    );
  }

  static Map<String, bool> _boolMap(Object? value) {
    if (value is! Map) return <String, bool>{};
    return Map<String, bool>.from(
      value.map((key, item) => MapEntry(key.toString(), item == true)),
    );
  }

  /// Documents that have a download URL available.
  List<GuardDocument> get documents {
    final docs = <GuardDocument>[];
    if (profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty) {
      docs.add(
        GuardDocument(
          label: 'Profile Photo',
          url: profilePhotoUrl!,
          icon: 'photo',
        ),
      );
    }
    if (idProofFrontUrl != null && idProofFrontUrl!.isNotEmpty) {
      docs.add(
        GuardDocument(
          label:
              idProofType != null && idProofType!.isNotEmpty
                  ? '$idProofType (Front)'
                  : 'ID Proof (Front)',
          url: idProofFrontUrl!,
          icon: 'document',
        ),
      );
    }
    if (idProofBackUrl != null && idProofBackUrl!.isNotEmpty) {
      docs.add(
        GuardDocument(
          label:
              idProofType != null && idProofType!.isNotEmpty
                  ? '$idProofType (Back)'
                  : 'ID Proof (Back)',
          url: idProofBackUrl!,
          icon: 'document',
        ),
      );
    }
    if (addressProofFrontUrl != null && addressProofFrontUrl!.isNotEmpty) {
      docs.add(
        GuardDocument(
          label:
              addressProofType != null && addressProofType!.isNotEmpty
                  ? '$addressProofType (Front)'
                  : 'Address Proof (Front)',
          url: addressProofFrontUrl!,
          icon: 'document',
        ),
      );
    }
    if (addressProofBackUrl != null && addressProofBackUrl!.isNotEmpty) {
      docs.add(
        GuardDocument(
          label:
              addressProofType != null && addressProofType!.isNotEmpty
                  ? '$addressProofType (Back)'
                  : 'Address Proof (Back)',
          url: addressProofBackUrl!,
          icon: 'document',
        ),
      );
    }
    if (signatureUrl != null && signatureUrl!.isNotEmpty) {
      docs.add(
        GuardDocument(
          label: 'Signature',
          url: signatureUrl!,
          icon: 'signature',
        ),
      );
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

/// A locally picked document file to be submitted for guard enrolment.
/// Kept intentionally decoupled from image_picker/file_picker so the
/// repository and tests never depend on a concrete picker package.
class DocumentUploadFile {
  const DocumentUploadFile({required this.path, required this.name});

  /// Absolute path to the file on disk (JPEG/PNG/PDF allowed, ≤5 MB).
  final String path;

  /// Original file name used as the storage name.
  final String name;
}
