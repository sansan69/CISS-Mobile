import '../core/models/attendance_models.dart';
import '../core/models/guard_profile.dart';
import '../core/models/incident_models.dart';
import '../core/models/leave_models.dart';
import '../core/models/mobile_dashboard_models.dart';
import '../core/models/patrol_models.dart';
import '../core/models/payslip_models.dart';
import '../core/models/report_models.dart';
import '../core/models/training_models.dart';

/// Development-only mock data used by the preview harness.
/// Never referenced from production code paths.

const String mockDistrict = 'Thiruvananthapuram';
const String mockClientName = 'Kerala State Bank';

final GuardDashboardSnapshot mockGuardDashboard = GuardDashboardSnapshot(
  employeeName: 'Rahul Kumar',
  employeeId: 'CISS-1042',
  clientName: mockClientName,
  district: mockDistrict,
  profilePhotoUrl: null,
  presentDays: 18,
  absentDays: 2,
  workingDays: 22,
  leaveBalance: const LeaveBalanceModel(entitled: 12, taken: 3, balance: 9),
  latestEvalScore: 86,
  latestEvalPeriod: 'June 2026',
  nextShiftLabel: 'On Duty',
  nextShiftSiteName: 'Main Branch – MG Road',
  nextShiftDate: '31 Jul, 08:00',
  recentAttendance: mockAttendanceHistory,
);

final GuardProfileModel mockGuardProfile = GuardProfileModel(
  id: 'emp_1042',
  fullName: 'Rahul Kumar',
  employeeId: 'CISS-1042',
  clientName: mockClientName,
  district: mockDistrict,
  phoneNumber: '+91 98470 12345',
  status: 'Active',
  gender: 'Male',
  joiningDate: '12 Apr 2021',
  resourceIdNumber: 'RES-2021-00142',
  profilePhotoUrl: null,
  address: 'Flat 4B, Sea View Apartments, Kovalam Road',
  emailAddress: 'rahul.kumar@example.com',
  idProofType: 'Aadhaar',
  idProofNumber: 'XXXX XXXX 6789',
  idProofFrontUrl: '',
  idProofBackUrl: '',
  addressProofType: 'Voter ID',
  addressProofNumber: 'KL/01/123/456789',
  addressProofFrontUrl: '',
  addressProofBackUrl: '',
  signatureUrl: '',
  bankAccountNumber: 'XXXXXXXXXXXX5678',
  bankIfscCode: 'SBIN0001234',
  bankName: 'State Bank of India',
);

final List<SiteOptionModel> mockAttendanceSites = <SiteOptionModel>[
  SiteOptionModel(
    id: 'site_001',
    siteName: 'Main Branch – MG Road',
    clientName: mockClientName,
    district: mockDistrict,
    geofenceRadiusMeters: 150,
    strictGeofence: true,
    shiftMode: 'templates',
    shiftPattern: 'fixed',
    shiftTemplates: const <ShiftTemplateModel>[
      ShiftTemplateModel(
        code: 'M',
        label: 'Morning',
        startTime: '08:00',
        endTime: '16:00',
      ),
      ShiftTemplateModel(
        code: 'E',
        label: 'Evening',
        startTime: '16:00',
        endTime: '00:00',
      ),
      ShiftTemplateModel(
        code: 'N',
        label: 'Night',
        startTime: '00:00',
        endTime: '08:00',
      ),
    ],
    sourceCollection: 'sites',
    lat: 8.5241,
    lng: 76.9366,
    dutyPoints: const <DutyPointModel>[
      DutyPointModel(
        id: 'dp_001',
        name: 'Main Gate',
        coverageMode: '24x7',
        dutyHours: '24 hours',
        shiftTemplates: <ShiftTemplateModel>[
          ShiftTemplateModel(
            code: 'M',
            label: 'Morning',
            startTime: '08:00',
            endTime: '16:00',
          ),
        ],
      ),
      DutyPointModel(
        id: 'dp_002',
        name: 'ATM Lobby',
        coverageMode: '24x7',
        dutyHours: '24 hours',
        shiftTemplates: <ShiftTemplateModel>[
          ShiftTemplateModel(
            code: 'E',
            label: 'Evening',
            startTime: '16:00',
            endTime: '00:00',
          ),
        ],
      ),
    ],
  ),
  SiteOptionModel(
    id: 'site_002',
    siteName: 'Corporate Office – Technopark',
    clientName: mockClientName,
    district: mockDistrict,
    geofenceRadiusMeters: 200,
    strictGeofence: false,
    shiftMode: 'manual',
    shiftPattern: null,
    shiftTemplates: const <ShiftTemplateModel>[],
    sourceCollection: 'sites',
    lat: 8.5509,
    lng: 76.9110,
    dutyPoints: const <DutyPointModel>[],
  ),
];

final List<AttendanceRecordModel> mockAttendanceHistory =
    <AttendanceRecordModel>[
      AttendanceRecordModel(
        siteName: 'Main Branch – MG Road',
        dateLabel: '30 Jul 2026',
        status: 'In',
        dutyPointName: 'Main Gate',
        shiftLabel: 'Morning',
        time: '07:58',
        distanceMeters: 12,
      ),
      AttendanceRecordModel(
        siteName: 'Main Branch – MG Road',
        dateLabel: '30 Jul 2026',
        status: 'Out',
        dutyPointName: 'Main Gate',
        shiftLabel: 'Morning',
        time: '16:05',
        distanceMeters: 18,
      ),
      AttendanceRecordModel(
        siteName: 'Corporate Office – Technopark',
        dateLabel: '29 Jul 2026',
        status: 'In',
        dutyPointName: 'ATM Lobby',
        shiftLabel: 'Evening',
        time: '15:55',
        distanceMeters: 42,
      ),
      AttendanceRecordModel(
        siteName: 'Corporate Office – Technopark',
        dateLabel: '29 Jul 2026',
        status: 'Out',
        dutyPointName: 'ATM Lobby',
        shiftLabel: 'Evening',
        time: '23:10',
        distanceMeters: 55,
      ),
    ];

final List<PayslipSummaryModel> mockPayslips = const <PayslipSummaryModel>[
  PayslipSummaryModel(id: 'p_001', periodLabel: 'June 2026', netPayLabel: '₹18,240'),
  PayslipSummaryModel(id: 'p_002', periodLabel: 'May 2026', netPayLabel: '₹18,240'),
  PayslipSummaryModel(id: 'p_003', periodLabel: 'April 2026', netPayLabel: '₹17,890'),
];

final List<IncidentModel> mockIncidents = <IncidentModel>[
  IncidentModel(
    id: 'inc_001',
    category: 'Suspicious Activity',
    severity: 'High',
    status: 'Open',
    siteName: 'Main Branch – MG Road',
    reportedAtLabel: '28 Jul 2026, 21:14',
    summary:
        'Unknown person attempted to enter the ATM lobby after closing hours. Asked to leave.',
  ),
  IncidentModel(
    id: 'inc_002',
    category: 'Equipment Fault',
    severity: 'Medium',
    status: 'In Progress',
    siteName: 'Corporate Office – Technopark',
    reportedAtLabel: '25 Jul 2026, 09:40',
    summary: 'CCTV camera at the rear gate stopped recording.',
  ),
];

final List<EvaluationModel> mockEvaluations = <EvaluationModel>[
  EvaluationModel(
    id: 'ev_001',
    title: 'June 2026',
    status: 'submitted',
    scoreLabel: '86%',
    employeeName: 'Rahul Kumar',
    employeeId: 'CISS-1042',
    period: 'June 2026',
    totalScore: 86,
    punctualityScore: 90,
    uniformScore: 85,
    behaviorScore: 88,
    skillScore: 84,
    clientFeedbackScore: 83,
    comments: 'Reliable and punctual. Good rapport with the client.',
    district: mockDistrict,
    clientName: mockClientName,
  ),
];

final List<TrainingAssignmentModel> mockTrainingAssignments =
    <TrainingAssignmentModel>[
      TrainingAssignmentModel(
        id: 'tr_001',
        title: 'Fire Safety & Evacuation',
        status: 'assigned',
        dueLabel: 'Assigned 25 Jul 2026',
        contentType: 'pdf',
        contentFileName: 'fire-safety-module.pdf',
      ),
      TrainingAssignmentModel(
        id: 'tr_002',
        title: 'Customer Interaction Basics',
        status: 'completed',
        dueLabel: 'Completed 10 Jul 2026',
        contentType: 'video',
        contentFileName: 'customer-interaction.mp4',
      ),
    ];

final Map<String, dynamic> mockLeaveOverview = <String, dynamic>{
  'balance': <String, dynamic>{
    'casual': <String, dynamic>{'entitled': 12, 'taken': 3, 'balance': 9},
    'sick': <String, dynamic>{'entitled': 10, 'taken': 1, 'balance': 9},
    'earned': <String, dynamic>{'entitled': 15, 'taken': 4, 'balance': 11},
  },
  'requests': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'lv_001',
      'type': 'casual',
      'fromDate': '10 Aug 2026',
      'toDate': '11 Aug 2026',
      'days': 2,
      'reason': 'Family function at home.',
      'status': 'Pending',
    },
    <String, dynamic>{
      'id': 'lv_002',
      'type': 'sick',
      'fromDate': '01 Jun 2026',
      'toDate': '01 Jun 2026',
      'days': 1,
      'reason': 'Fever',
      'status': 'Approved',
    },
  ],
};

final GuardPatrolStatusModel mockPatrolStatus = GuardPatrolStatusModel(
  enabled: true,
  guardName: 'Rahul Kumar',
  employeeId: 'CISS-1042',
  employeeDocId: 'emp_1042',
  clientId: 'cl_001',
  clientName: mockClientName,
  settings: const PatrolSettingsModel(
    enabled: true,
    hourlyNightPhotoEnabled: true,
    hourlyIntervalMinutes: 60,
    nightWindowStart: '20:00',
    nightWindowEnd: '06:00',
    photoRequiredForPatrol: true,
  ),
  hourlyRequirement: const HourlyRequirementModel(
    enabled: true,
    dueNow: false,
    overdueMinutes: 0,
    nightWindowLabel: '20:00 – 06:00',
    nextDueAt: '23:00',
    lastSubmittedAt: '22:02',
  ),
  patrolPoints: const <PatrolPointModel>[
    PatrolPointModel(
      id: 'pp_001',
      name: 'Perimeter Gate',
      description: 'Verify gate is locked and secure.',
      requiresPhoto: true,
    ),
    PatrolPointModel(
      id: 'pp_002',
      name: 'Vault Door',
      description: 'Check vault door seals and report anomalies.',
      requiresPhoto: true,
    ),
  ],
  recentActivities: const <GuardPatrolActivityModel>[
    GuardPatrolActivityModel(
      id: 'pa_001',
      type: 'patrol',
      siteName: 'Main Branch – MG Road',
      district: mockDistrict,
      guardName: 'Rahul Kumar',
      activityAt: '22:00',
      dutyPointName: 'Main Gate',
      patrolPointName: 'Perimeter Gate',
      shiftLabel: 'Night',
      notes: 'All clear',
    ),
  ],
  activeDuty: ActiveDutyModel(
    siteId: 'site_001',
    siteName: 'Main Branch – MG Road',
    district: mockDistrict,
    dutyPointId: 'dp_001',
    dutyPointName: 'Main Gate',
    shiftCode: 'N',
    shiftLabel: 'Night',
    checkedInAt: '2026-07-30T22:58:00',
    activeSinceLabel: 'Since 23:00',
  ),
);

// ── Field Officer mocks ────────────────────────────────────────────────

/// FO patrol-activity payload matching `GET /api/admin/patrol-activities`.
final Map<String, dynamic> mockPatrolActivitiesPayload = <String, dynamic>{
  'summary': <String, dynamic>{
    'total': 3,
    'hourlyPhotos': 1,
    'patrolRounds': 2,
    'activeSites': 2,
    'uniqueGuards': 2,
  },
  'settings': null,
  'activities': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'pa_101',
      'type': 'hourly_photo',
      'siteName': 'iON Digital Zone iDZ Aluva',
      'district': mockDistrict,
      'guardName': 'Sandeep S',
      'employeeId': 'CISS-1042',
      'dutyPointName': 'Main Gate',
      'shiftLabel': 'Night',
      'photoUrl': '',
      'notes': 'Night check photo',
      'activityAt': '2026-08-09T23:30:00',
    },
    <String, dynamic>{
      'id': 'pa_102',
      'type': 'patrol',
      'siteName': 'Samsung HQ',
      'district': mockDistrict,
      'guardName': 'Rahul Kumar',
      'employeeId': 'CISS-1011',
      'dutyPointName': 'Perimeter',
      'patrolPointName': 'Vault Door',
      'shiftLabel': 'Night',
      'notes': 'Vault door sealed, no anomalies.',
      'activityAt': '2026-08-09T23:05:00',
    },
    <String, dynamic>{
      'id': 'pa_103',
      'type': 'patrol',
      'siteName': 'Main Branch – MG Road',
      'district': mockDistrict,
      'guardName': 'Rahul Kumar',
      'dutyPointName': 'Main Gate',
      'patrolPointName': 'Perimeter Gate',
      'shiftLabel': 'Day',
      'notes': 'All clear',
      'activityAt': '2026-08-09T09:15:00',
    },
  ],
};

// ── Field Officer mocks ────────────────────────────────────────────────

final FieldOfficerDashboardSnapshot mockFieldOfficerDashboard =
    FieldOfficerDashboardSnapshot(
  name: 'Anitha Nair',
  stateCode: 'KL',
  assignedDistricts: <String>[mockDistrict, 'Kollam'],
  totalGuards: 340,
  activeGuards: 312,
  totalSitesInScope: 24,
  attendanceSummary: FieldOfficerAttendanceSummary.fromJson(
    <String, dynamic>{
      'date': '2026-07-31',
      'checkedInToday': 289,
      'onDutyNow': 241,
      'districts': <Map<String, dynamic>>[
        <String, dynamic>{
          'district': mockDistrict,
          'checkedInToday': 152,
          'onDutyNow': 128,
        },
        <String, dynamic>{
          'district': 'Kollam',
          'checkedInToday': 137,
          'onDutyNow': 113,
        },
      ],
    },
  ),
  todayOverview: FieldOfficerTodayOverview.fromJson(
    <String, dynamic>{
      'sitesScheduled': 12,
      'dutiesScheduled': 18,
      'requiredGuards': 96,
      'assignedGuards': 84,
      'unassignedGuards': 12,
      'sitesWithoutAttendance': 2,
      'visitReportsToday': 4,
      'trainingReportsToday': 1,
      'pendingSiteReports': 2,
      'underAssignedSites': 5,
    },
  ),
  todaySites: const <FieldOfficerTodaySiteBrief>[
    FieldOfficerTodaySiteBrief(
      siteId: 'site_001',
      siteName: 'Main Branch – MG Road',
      district: mockDistrict,
      clientName: mockClientName,
      requiredGuards: 8,
      assignedGuards: 8,
      shiftLabel: 'Morning',
      dateLabel: '31 Jul 2026',
      hasAttendance: true,
    ),
    FieldOfficerTodaySiteBrief(
      siteId: 'site_002',
      siteName: 'Corporate Office – Technopark',
      district: mockDistrict,
      clientName: mockClientName,
      requiredGuards: 6,
      assignedGuards: 4,
      shiftLabel: 'Evening',
      dateLabel: '31 Jul 2026',
      hasAttendance: false,
    ),
  ],
  attendanceSites: const <FieldOfficerAttendanceSite>[
    FieldOfficerAttendanceSite(
      siteId: 'site_001',
      siteName: 'Main Branch – MG Road',
      district: mockDistrict,
      checkedInToday: 7,
      onDutyNow: 6,
      clientName: mockClientName,
    ),
    FieldOfficerAttendanceSite(
      siteId: 'site_002',
      siteName: 'Corporate Office – Technopark',
      district: mockDistrict,
      checkedInToday: 3,
      onDutyNow: 2,
      clientName: mockClientName,
    ),
  ],
  upcomingWorkOrders: mockWorkOrders,
  recentVisitReports: mockVisitReports,
  recentTrainingReports: mockTrainingReports,
  recentWorkOrders: mockWorkOrders,
);

final List<WorkOrderModel> mockWorkOrders = <WorkOrderModel>[
  WorkOrderModel(
    id: 'wo_001',
    siteId: 'site_001',
    siteName: 'Main Branch – MG Road',
    clientId: 'cl_001',
    clientName: mockClientName,
    district: mockDistrict,
    examName: 'Bank Audit Duty',
    examCode: 'AUDIT-01',
    dateLabel: '31 Jul 2026',
    totalManpowerLabel: '8',
    totalManpower: 8,
    assignedCount: 8,
  ),
  WorkOrderModel(
    id: 'wo_002',
    siteId: 'site_002',
    siteName: 'Corporate Office – Technopark',
    clientId: 'cl_001',
    clientName: mockClientName,
    district: mockDistrict,
    examName: 'AGM Security',
    examCode: 'AGM-2026',
    dateLabel: '02 Aug 2026',
    totalManpowerLabel: '6',
    totalManpower: 6,
    assignedCount: 4,
  ),
];

final List<GuardProfileModel> mockFieldOfficerGuards = <GuardProfileModel>[
  mockGuardProfile,
  GuardProfileModel(
    id: 'emp_1098',
    fullName: 'Suresh Pillai',
    employeeId: 'CISS-1098',
    clientName: mockClientName,
    district: mockDistrict,
    phoneNumber: '+91 98470 67890',
    status: 'Active',
    gender: 'Male',
    joiningDate: '02 Jan 2022',
    idProofType: 'Aadhaar',
    idProofNumber: 'XXXX XXXX 1122',
    bankName: 'Canara Bank',
    bankIfscCode: 'CNRB0001122',
    bankAccountNumber: 'XXXXXXXXXXXX2211',
  ),
  GuardProfileModel(
    id: 'emp_1177',
    fullName: 'Deepa Menon',
    employeeId: 'CISS-1177',
    clientName: mockClientName,
    district: 'Kollam',
    phoneNumber: '+91 98470 55667',
    status: 'Active',
    gender: 'Female',
    joiningDate: '18 Mar 2023',
    idProofType: 'Aadhaar',
    idProofNumber: 'XXXX XXXX 9900',
    bankName: 'Federal Bank',
    bankIfscCode: 'FDRL0004455',
    bankAccountNumber: 'XXXXXXXXXXXX0099',
  ),
];

final List<FieldOfficerAttendanceEntry> mockFieldOfficerAttendance =
    const <FieldOfficerAttendanceEntry>[
  FieldOfficerAttendanceEntry(
    id: 'att_001',
    guardName: 'Rahul Kumar',
    guardId: 'emp_1042',
    employeeId: 'CISS-1042',
    siteName: 'Main Branch – MG Road',
    clientName: mockClientName,
    district: mockDistrict,
    dateLabel: '31 Jul 2026',
    checkIn: '07:58',
    checkOut: '16:05',
    dutyPointName: 'Main Gate',
    shiftLabel: 'Morning',
    status: 'Present',
  ),
  FieldOfficerAttendanceEntry(
    id: 'att_002',
    guardName: 'Suresh Pillai',
    guardId: 'emp_1098',
    employeeId: 'CISS-1098',
    siteName: 'Main Branch – MG Road',
    clientName: mockClientName,
    district: mockDistrict,
    dateLabel: '31 Jul 2026',
    checkIn: '08:02',
    checkOut: null,
    dutyPointName: 'ATM Lobby',
    shiftLabel: 'Morning',
    status: 'On Duty',
  ),
  FieldOfficerAttendanceEntry(
    id: 'att_003',
    guardName: 'Deepa Menon',
    guardId: 'emp_1177',
    employeeId: 'CISS-1177',
    siteName: 'Corporate Office – Technopark',
    clientName: mockClientName,
    district: 'Kollam',
    dateLabel: '31 Jul 2026',
    checkIn: null,
    checkOut: null,
    dutyPointName: 'Lobby',
    shiftLabel: 'Evening',
    status: 'Absent',
  ),
];

final List<VisitReportModel> mockVisitReports = <VisitReportModel>[
  VisitReportModel(
    id: 'vr_001',
    fieldOfficerName: 'Anitha Nair',
    siteName: 'Main Branch – MG Road',
    clientName: mockClientName,
    district: mockDistrict,
    dateLabel: '30 Jul 2026',
    summary: 'Morning inspection completed. All guards present.',
    issuesFound: 'One broken lock on the side gate reported.',
    guardsPresentCount: 8,
    guardsAbsentCount: 0,
    status: 'submitted',
  ),
  VisitReportModel(
    id: 'vr_002',
    fieldOfficerName: 'Anitha Nair',
    siteName: 'Corporate Office – Technopark',
    clientName: mockClientName,
    district: mockDistrict,
    dateLabel: '29 Jul 2026',
    summary: 'Evening visit. Security drill observed.',
    issuesFound: '',
    guardsPresentCount: 6,
    guardsAbsentCount: 0,
    status: 'submitted',
  ),
];

final List<TrainingReportModel> mockTrainingReports = <TrainingReportModel>[
  TrainingReportModel(
    id: 'trr_001',
    fieldOfficerName: 'Anitha Nair',
    siteName: 'Main Branch – MG Road',
    clientName: mockClientName,
    district: mockDistrict,
    dateLabel: '28 Jul 2026',
    topic: 'Fire Safety Refresher',
    description: 'Hands-on demonstration of extinguisher usage.',
    attendeeCount: 8,
    durationMinutes: 45,
    status: 'submitted',
    attendeeNames: const <String>['Rahul Kumar', 'Suresh Pillai'],
  ),
];
