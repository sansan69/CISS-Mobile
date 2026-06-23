import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_role.dart';
import '../models/attendance_models.dart';
import '../models/auth_session.dart';
import '../models/guard_pin_status.dart';
import '../models/guard_profile.dart';
import '../models/incident_models.dart';
import '../models/leave_models.dart';
import '../models/mobile_dashboard_models.dart';
import '../models/patrol_models.dart';
import '../models/payroll_models.dart';
import '../models/report_models.dart';
import '../models/training_models.dart';
import 'api_client.dart';

class MobileRepository {
  MobileRepository(this._apiClient, this._auth);

  final ApiClient _apiClient;
  final FirebaseAuth _auth;

  ApiClient get apiClient => _apiClient;
  User? get currentUser => _auth.currentUser;

  static const String _mobileNotificationsPath = '/api/mobile/notifications';
  static const String _mobileTokenPath = '/api/mobile/token';

  Future<String?> _token() async => _auth.currentUser?.getIdToken(false);

  Future<Map<String, String>> authHeaders() async => _authHeaders();

  Future<void> updateFcmToken(String token) async {
    try {
      await _postJson(_mobileTokenPath, <String, String>{'fcmToken': token});
    } catch (error) {
      if (await _saveFcmTokenDirectly(token)) {
        debugPrint(
          'Saved FCM token directly because $_mobileTokenPath is unavailable: $error',
        );
        return;
      }

      // Non-critical: failure here shouldn't block the app, but log it.
      debugPrint('Error updating FCM token: $error');
    }
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      final data = await _getJson(_mobileNotificationsPath);
      final rawNotifications =
          (data['notifications'] as List<dynamic>? ?? const <dynamic>[]);

      return rawNotifications
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (error) {
      try {
        return _fetchNotificationsDirectly();
      } catch (_) {
        rethrow;
      }
    }
  }

  Future<int> fetchUnreadNotificationCount() async {
    try {
      final data = await _getJson(_mobileNotificationsPath);
      return (data['unreadCount'] as num?)?.toInt() ?? 0;
    } catch (error) {
      try {
        final notifications = await _fetchNotificationsDirectly();
        return notifications.where((item) => item['read'] != true).length;
      } catch (_) {
        rethrow;
      }
    }
  }

  Future<void> markNotificationAsRead(String notifId) async {
    try {
      await _postJson(_mobileNotificationsPath, <String, dynamic>{
        'action': 'markRead',
        'notifId': notifId,
      });
    } catch (error) {
      if (await _markNotificationAsReadDirectly(notifId)) {
        return;
      }
      rethrow;
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      await _postJson(_mobileNotificationsPath, const <String, dynamic>{
        'action': 'markAllRead',
      });
    } catch (error) {
      if (await _markAllNotificationsAsReadDirectly()) {
        return;
      }
      rethrow;
    }
  }

  Future<void> createSystemNotification({
    required String type,
    required String title,
    required String body,
    required String role,
    String? district,
    Map<String, String>? data,
  }) async {
    await _postJson(_mobileNotificationsPath, <String, dynamic>{
      'action': 'createSystem',
      'type': type,
      'title': title,
      'body': body,
      'role': role,
      if (district != null && district.trim().isNotEmpty) 'district': district,
      if (data != null && data.isNotEmpty) 'data': data,
    });
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: Options(headers: await _authHeaders()),
      );
      final data = response.data;
      if (data is! Map) {
        throw Exception('Unexpected response format from server');
      }
      return Map<String, dynamic>.from(data);
    } catch (error) {
      if (_isOfflineDioError(error)) rethrow;
      throw Exception(_extractApiError(error));
    }
  }

  Future<Map<String, dynamic>> postGeneric(
    String path,
    Map<String, dynamic> body,
  ) async {
    return _postJson(path, body);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        path,
        data: body,
        options: Options(headers: await _authHeaders()),
      );
      final data = response.data;
      if (data is! Map) {
        throw Exception('Unexpected response format from server');
      }
      return Map<String, dynamic>.from(data);
    } catch (error) {
      if (_isOfflineDioError(error)) rethrow;
      throw Exception(_extractApiError(error));
    }
  }

  Future<Map<String, dynamic>> _patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _apiClient.dio.patch<dynamic>(
        path,
        data: body,
        options: Options(headers: await _authHeaders()),
      );
      final data = response.data;
      if (data is! Map) {
        throw Exception('Unexpected response format from server');
      }
      return Map<String, dynamic>.from(data);
    } catch (error) {
      if (_isOfflineDioError(error)) rethrow;
      throw Exception(_extractApiError(error));
    }
  }

  bool _isOfflineDioError(Object error) {
    return error is DioException &&
        (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.unknown ||
            error.type == DioExceptionType.badCertificate);
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      throw StateError('Not authenticated');
    }
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  Future<AuthSession?> resolveCurrentSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final backendSession = await _resolveSessionFromBackend();
      if (backendSession != null) {
        return backendSession;
      }
    } catch (e) {
      // Backend may be temporarily unavailable; fall back to Firebase claims.
      debugPrint('Backend session resolution failed: $e');
    }

    final token = await user.getIdTokenResult(false);
    final claims = token.claims ?? <String, dynamic>{};
    final role = _roleFromClaims(claims);
    if (role != null) {
      if (role == AppRole.guard) {
        final guardSession = await _resolveGuardSessionFromProfile(user);
        if (guardSession != null) {
          return guardSession;
        }
      }

      return _buildSessionFromClaims(user: user, claims: claims, role: role);
    }

    return null;
  }

  AuthSession _buildSessionFromClaims({
    required User user,
    required Map<String, dynamic> claims,
    required AppRole role,
  }) {
    if (role == AppRole.guard) {
      return AuthSession(
        role: role,
        displayName: (claims['name'] as String?)?.trim().isNotEmpty == true
            ? claims['name'] as String
            : (user.displayName ?? user.email ?? 'Guard'),
        primaryId: (claims['employeeId'] as String?) ?? user.uid,
        uid: user.uid,
        email: user.email,
        employeeDocId: claims['employeeDocId'] as String?,
        clientId: claims['clientId'] as String?,
        clientName: claims['clientName'] as String?,
        district: claims['district'] as String?,
        stateCode: claims['stateCode'] as String?,
      );
    }

    if (role == AppRole.client) {
      return AuthSession(
        role: role,
        displayName: (claims['name'] as String?)?.trim().isNotEmpty == true
            ? claims['name'] as String
            : (claims['clientName'] as String?) ?? (user.displayName ?? user.email ?? 'Client'),
        primaryId: user.uid,
        uid: user.uid,
        email: user.email,
        clientId: claims['clientId'] as String?,
        clientName: claims['clientName'] as String?,
      );
    }

    return AuthSession(
      role: role,
      displayName: (claims['name'] as String?)?.trim().isNotEmpty == true
          ? claims['name'] as String
          : (user.displayName ?? user.email ?? 'Field Officer'),
      primaryId: user.uid,
      uid: user.uid,
      email: user.email,
      assignedDistricts:
          (claims['assignedDistricts'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      stateCode: claims['stateCode'] as String?,
    );
  }

  Future<AuthSession?> _resolveSessionFromBackend() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final data = await _getJson('/api/mobile/session');
    final role = _roleFromWire(data['role']);
    if (role == null) {
      return null;
    }

    return AuthSession(
      role: role,
      displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? data['displayName'] as String
          : (user.displayName ?? user.email ?? role.label),
      primaryId: (data['primaryId'] as String?)?.trim().isNotEmpty == true
          ? data['primaryId'] as String
          : user.uid,
      uid: (data['uid'] as String?)?.trim().isNotEmpty == true
          ? data['uid'] as String
          : user.uid,
      email: data['email'] as String? ?? user.email,
      employeeDocId: data['employeeDocId'] as String?,
      assignedDistricts:
          (data['assignedDistricts'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      clientId: data['clientId'] as String?,
      clientName: data['clientName'] as String?,
      district: data['district'] as String?,
      stateCode: data['stateCode'] as String?,
    );
  }

  Future<AuthSession?> _resolveGuardSessionFromProfile(User user) async {
    try {
      final profile = await fetchGuardProfile();
      return AuthSession(
        role: AppRole.guard,
        displayName: profile.fullName.isNotEmpty
            ? profile.fullName
            : (user.displayName ?? user.email ?? 'Guard'),
        primaryId: profile.employeeId.isNotEmpty ? profile.employeeId : user.uid,
        uid: user.uid,
        email: user.email,
        employeeDocId: profile.id.isNotEmpty ? profile.id : null,
        clientName: profile.clientName.isNotEmpty ? profile.clientName : null,
        district: profile.district.isNotEmpty ? profile.district : null,
      );
    } catch (e) {
      debugPrint('Session fallback failed: $e');
      return null;
    }
  }

  AppRole? _roleFromClaims(Map<String, dynamic>? claims) {
    return _roleFromWire(claims?['role']);
  }

  AppRole? _roleFromWire(Object? value) {
    return appRoleFromWire(value);
  }

  String _extractApiError(Object error) {
    if (error is FirebaseAuthException) {
      return _extractFirebaseAuthError(error);
    }
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final message = data['error'] ?? data['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!.trim();
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<bool> _saveFcmTokenDirectly(String token) async {
    final user = _auth.currentUser;
    if (user == null || token.trim().isEmpty) {
      return false;
    }

    try {
      await FirebaseFirestore.instance
          .collection('fcmTokens')
          .doc('${user.uid}_mobile')
          .set(<String, dynamic>{
            'uid': user.uid,
            'token': token.trim(),
            'platform': 'mobile',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Repository fallback failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchNotificationsDirectly() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const <Map<String, dynamic>>[];
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    return snapshot.docs
        .map((doc) => _serializeNotificationDocument(doc))
        .toList();
  }

  Future<bool> _markNotificationAsReadDirectly(String notifId) async {
    final user = _auth.currentUser;
    if (user == null || notifId.trim().isEmpty) {
      return false;
    }

    try {
      final docRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc(notifId.trim());
      final snapshot = await docRef.get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null || data['recipientUid'] != user.uid) {
        return false;
      }

      await docRef.update(<String, dynamic>{
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Repository fallback failed: $e');
      return false;
    }
  }

  Future<bool> _markAllNotificationsAsReadDirectly() async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientUid', isEqualTo: user.uid)
          .limit(50)
          .get();

      if (snapshot.docs.isEmpty) {
        return true;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        if (doc.data()['read'] == true) continue;
        batch.update(doc.reference, <String, dynamic>{
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Repository fallback failed: $e');
      return false;
    }
  }

  Map<String, dynamic> _serializeNotificationDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    final readAt = data['readAt'];

    return <String, dynamic>{
      'id': doc.id,
      'type': data['type'] ?? 'broadcast',
      'title': data['title'] ?? '',
      'body': data['body'] ?? '',
      'read': data['read'] == true,
      'createdAt': createdAt is Timestamp
          ? createdAt.toDate().toIso8601String()
          : createdAt?.toString(),
      'readAt': readAt is Timestamp
          ? readAt.toDate().toIso8601String()
          : readAt?.toString(),
      'recipientUid': data['recipientUid'],
      'recipientRole': data['recipientRole'],
      'recipientDistrict': data['recipientDistrict'],
      'data': data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : null,
    };
  }

  String _extractFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Invalid email or password.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many login attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network error while contacting Firebase. Please check the connection.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Could not sign in. Please try again.';
    }
  }

  Map<String, String> _guardIdentityPayload(String loginIdOrPhone) {
    final normalizedInput = loginIdOrPhone.trim();
    final compactDigits = normalizedInput.replaceAll(RegExp(r'\D+'), '');
    final isPhoneLike = RegExp(r'^\d{8,15}$').hasMatch(compactDigits);
    return <String, String>{
      if (isPhoneLike)
        'phoneNumber': normalizedInput
      else
        'employeeId': normalizedInput,
    };
  }

  Future<GuardPinStatus> checkGuardPinStatus({
    required String loginIdOrPhone,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/api/guard/auth/pin-status',
        data: _guardIdentityPayload(loginIdOrPhone),
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      return GuardPinStatus(
        found: data['found'] == true,
        hasPin: data['hasPin'] == true,
        employeeName: data['employeeName'] as String?,
        employeeId: data['employeeId'] as String?,
      );
    } catch (error) {
      throw Exception(_extractApiError(error));
    }
  }

  Future<void> setupGuardPin({
    required String employeeId,
    required String phoneNumber,
    required String dateOfBirth,
    required String pin,
  }) async {
    try {
      await _apiClient.dio.post<dynamic>(
        '/api/guard/auth/setup-pin',
        data: <String, String>{
          if (employeeId.trim().isNotEmpty) 'employeeId': employeeId.trim(),
          'phoneNumber': phoneNumber.trim(),
          'dateOfBirth': dateOfBirth.trim(),
          'pin': pin.trim(),
        },
      );
    } catch (error) {
      throw Exception(_extractApiError(error));
    }
  }

  Future<AuthSession> signInGuard({
    required String loginIdOrPhone,
    required String pin,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/api/guard/auth/login',
        data: <String, String>{
          ..._guardIdentityPayload(loginIdOrPhone),
          'pin': pin.trim(),
        },
      );

      final data = Map<String, dynamic>.from(response.data as Map);
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw StateError('Guard login did not return a Firebase custom token.');
      }

      await _auth.signInWithCustomToken(token);
      final session = await resolveCurrentSession();
      if (session == null || session.role != AppRole.guard) {
        await _auth.signOut();
        throw StateError('Guard login is only allowed for guard accounts.');
      }
      return session;
    } catch (error) {
      throw Exception(_extractApiError(error));
    }
  }

  Future<AuthSession> signInFieldOfficer({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final session = await resolveCurrentSession();
      if (session == null || session.role != AppRole.fieldOfficer) {
        await _auth.signOut();
        throw StateError(
          'Field officer login is only allowed for field officer accounts.',
        );
      }
      return session;
    } catch (error) {
      throw Exception(_extractApiError(error));
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<GuardDashboardSnapshot> fetchGuardDashboard() async {
    final data = await _getJson('/api/guard/dashboard');
    final leaveBalance = data['leaveBalance'] is Map<String, dynamic>
        ? _parseLeaveBalance(
            Map<String, dynamic>.from(data['leaveBalance'] as Map),
          )
        : null;
    final recentAttendance =
        (data['recentAttendance'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map((item) => AttendanceRecordModel.fromJson(item))
            .toList();

    final nextShift = data['nextShift'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(data['nextShift'] as Map)
        : null;

    return GuardDashboardSnapshot(
      employeeName: (data['employeeName'] as String?) ?? '',
      employeeId: (data['employeeId'] as String?) ?? '',
      clientName: (data['clientName'] as String?) ?? '',
      district: (data['district'] as String?) ?? '',
      profilePhotoUrl: data['profilePhotoUrl'] as String?,
      presentDays:
          (data['attendanceStats'] as Map<String, dynamic>?)?['presentDays']
              is num
          ? ((data['attendanceStats'] as Map<String, dynamic>)['presentDays']
                    as num)
                .toInt()
          : 0,
      absentDays:
          (data['attendanceStats'] as Map<String, dynamic>?)?['absentDays']
              is num
          ? ((data['attendanceStats'] as Map<String, dynamic>)['absentDays']
                    as num)
                .toInt()
          : 0,
      workingDays:
          (data['attendanceStats'] as Map<String, dynamic>?)?['workingDays']
              is num
          ? ((data['attendanceStats'] as Map<String, dynamic>)['workingDays']
                    as num)
                .toInt()
          : 0,
      leaveBalance: leaveBalance,
      latestEvalScore: data['latestEvalScore'] as num?,
      latestEvalPeriod: data['latestEvalPeriod'] as String?,
      nextShiftLabel: nextShift?['shiftLabel'] as String?,
      nextShiftSiteName: nextShift?['siteName'] as String?,
      nextShiftDate: nextShift?['date'] as String?,
      recentAttendance: recentAttendance,
    );
  }

  Future<GuardProfileModel> fetchGuardProfile() async {
    final data = await _getJson('/api/guard/profile');
    final employee = data['employee'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(data['employee'] as Map)
        : <String, dynamic>{};
    return GuardProfileModel.fromJson(
      employee,
      id: employee['id'] as String? ?? '',
    );
  }

  Future<List<SiteOptionModel>> fetchAttendanceSites() async {
    final data = await _getJson('/api/public/attendance');
    final options = data['options'] as List<dynamic>? ?? const <dynamic>[];
    return options
        .whereType<Map<String, dynamic>>()
        .map(SiteOptionModel.fromJson)
        .toList();
  }

  Future<PublicAttendanceEmployeeModel> fetchAttendanceEmployee(
    String employeeId,
  ) async {
    final data = await _getJson(
      '/api/public/attendance/employee',
      queryParameters: <String, dynamic>{'employeeId': employeeId},
    );
    final employee = data['employee'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(data['employee'] as Map)
        : <String, dynamic>{};
    final hint = employee['attendanceHint'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(employee['attendanceHint'] as Map)
        : null;
    return PublicAttendanceEmployeeModel(
      id: employee['id'] as String? ?? '',
      employeeCode: employee['employeeCode'] as String?,
      fullName: employee['fullName'] as String? ?? '',
      phoneNumber: employee['phoneNumber'] as String?,
      clientName: employee['clientName'] as String?,
      attendanceHint: hint == null
          ? null
          : AttendanceHintModel(
              lastAttendanceDate: hint['lastAttendanceDate'] as String?,
              lastStatus:
                  hint['lastStatus'] == 'In' || hint['lastStatus'] == 'Out'
                  ? hint['lastStatus'] as String
                  : null,
              lastDutyPointId: hint['lastDutyPointId'] as String?,
              lastShiftCode: hint['lastShiftCode'] as String?,
            ),
    );
  }

  Future<Map<String, dynamic>> uploadAttendancePhoto({
    required String path,
    required String dataUrl,
    String? siteId,
  }) async {
    final ownerMatch = RegExp(r'^employees/([^/]+)/attendance/').firstMatch(path);
    final ownerKey = ownerMatch?.group(1);
    if (ownerKey == null || ownerKey.isEmpty) {
      throw Exception('Attendance photo path must use employees/{id}/attendance.');
    }
    if (siteId == null || siteId.isEmpty) {
      throw Exception('Attendance site id is required for photo upload.');
    }
    final tokenResponse = await _apiClient.dio.post<dynamic>(
      '/api/public/attendance/upload-token',
      data: <String, dynamic>{'employeeId': ownerKey, 'siteId': siteId},
    );
    final tokenData = Map<String, dynamic>.from(tokenResponse.data as Map);
    final uploadToken = tokenData['uploadToken'] as String?;
    if (uploadToken == null || uploadToken.isEmpty) {
      throw Exception('Attendance photo upload token missing.');
    }
    final response = await _apiClient.dio.post<dynamic>(
      '/api/public/attendance/upload',
      data: <String, dynamic>{
        'path': path,
        'photoDataUrl': dataUrl,
        'uploadToken': uploadToken,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> uploadReportPhoto({
    required String path,
    required String dataUrl,
  }) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/api/field-officer/upload',
      data: <String, dynamic>{'path': path, 'photoDataUrl': dataUrl},
      options: Options(headers: await _authHeaders()),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> submitAttendance(
    Map<String, dynamic> payload,
  ) async {
    return _postJson('/api/attendance/submit', payload);
  }

  Future<List<AttendanceRecordModel>> fetchAttendanceHistory({
    String? month,
  }) async {
    final data = await _getJson(
      '/api/guard/attendance',
      queryParameters: month == null ? null : <String, dynamic>{'month': month},
    );
    final logs = data['logs'] as List<dynamic>? ?? const <dynamic>[];
    return logs
        .whereType<Map<String, dynamic>>()
        .map(AttendanceRecordModel.fromJson)
        .toList();
  }

  Future<List<TrainingAssignmentModel>> fetchTrainingAssignments() async {
    final data = await _getJson('/api/guard/training');
    final assignments =
        data['assignments'] as List<dynamic>? ?? const <dynamic>[];
    return assignments
        .whereType<Map<String, dynamic>>()
        .map(TrainingAssignmentModel.fromJson)
        .toList();
  }

  Future<void> acknowledgeTraining(String assignmentId) async {
    await _postJson('/api/guard/training/acknowledge', <String, String>{
      'assignmentId': assignmentId,
      'acknowledgedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<EvaluationModel>> fetchEvaluations() async {
    final data = await _getJson('/api/guard/evaluations');
    final evaluations =
        data['evaluations'] as List<dynamic>? ?? const <dynamic>[];
    return evaluations
        .whereType<Map<String, dynamic>>()
        .map(EvaluationModel.fromJson)
        .toList();
  }

  Future<List<PayslipSummaryModel>> fetchPayslips() async {
    final data = await _getJson('/api/guard/payslips');
    final payslips = data['payslips'] as List<dynamic>? ?? const <dynamic>[];
    return payslips
        .whereType<Map<String, dynamic>>()
        .map(PayslipSummaryModel.fromJson)
        .toList();
  }

  Future<GuardPatrolStatusModel> fetchGuardPatrolStatus() async {
    final data = await _getJson('/api/guard/patrol');
    return GuardPatrolStatusModel.fromJson(data);
  }

  Future<Map<String, dynamic>> submitGuardPatrolActivity(
    Map<String, dynamic> payload,
  ) async {
    return _postJson('/api/guard/patrol', payload);
  }

  Future<Map<String, dynamic>> fetchLeaveOverview() async {
    return _getJson('/api/guard/leave');
  }

  Future<Map<String, dynamic>> createLeaveRequest(
    Map<String, dynamic> payload,
  ) async {
    return _postJson('/api/guard/leave', payload);
  }

  Future<Map<String, dynamic>> cancelLeaveRequest(String requestId) async {
    return _patchJson('/api/guard/leave', <String, dynamic>{
      'requestId': requestId,
    });
  }

  Future<List<IncidentModel>> fetchGuardIncidents() async {
    final data = await _getJson('/api/guard/incidents');
    final incidents = data['incidents'] as List<dynamic>? ?? const <dynamic>[];
    return incidents
        .whereType<Map<String, dynamic>>()
        .map(IncidentModel.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> createGuardIncident(
    Map<String, dynamic> payload,
  ) async {
    return _postJson('/api/guard/incidents', payload);
  }

  Future<FieldOfficerDashboardSnapshot> fetchFieldOfficerDashboard() async {
    final data = await _getJson('/api/field-officer/dashboard');
    final upcoming =
        (data['upcomingWorkOrders'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(WorkOrderModel.fromJson)
            .toList();
    final visitReports =
        (data['recentVisitReports'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(VisitReportModel.fromJson)
            .toList();
    final trainingReports =
        (data['recentTrainingReports'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(TrainingReportModel.fromJson)
            .toList();
    final recentWorkOrders =
        (data['recentWorkOrders'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(WorkOrderModel.fromJson)
            .toList();
    return FieldOfficerDashboardSnapshot(
      name: (data['name'] as String?) ?? '',
      stateCode: (data['stateCode'] as String?) ?? '',
      assignedDistricts:
          (data['assignedDistricts'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      totalGuards: (data['totalGuards'] as num?)?.toInt() ?? 0,
      activeGuards: (data['activeGuards'] as num?)?.toInt() ?? 0,
      attendanceSummary: FieldOfficerAttendanceSummary.fromJson(
        data['attendanceSummary'] as Map<String, dynamic>?,
      ),
      recentVisitReports: visitReports,
      attendanceSites:
          (data['attendanceSites'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (item) => FieldOfficerAttendanceSite.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
      upcomingWorkOrders: upcoming,
      recentTrainingReports: trainingReports,
      recentWorkOrders: recentWorkOrders,
    );
  }

  Future<List<WorkOrderModel>> fetchFieldOfficerWorkOrders() async {
    final data = await _getJson('/api/field-officer/work-orders');
    final rows = data['workOrders'] as List<dynamic>? ?? const <dynamic>[];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(WorkOrderModel.fromJson)
        .toList();
  }

  Future<List<FieldOfficerSiteOption>> fetchFieldOfficerSites({
    String? district,
  }) async {
    final data = await _getJson(
      '/api/field-officer/sites',
      queryParameters: (district != null && district.trim().isNotEmpty)
          ? <String, dynamic>{'district': district.trim()}
          : null,
    );
    final rows = data['sites'] as List<dynamic>? ?? const <dynamic>[];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(FieldOfficerSiteOption.fromJson)
        .toList();
  }

  Future<List<GuardProfileModel>> fetchFieldOfficerGuards({
    String? district,
  }) async {
    final data = await _getJson(
      '/api/field-officer/guards',
      queryParameters: (district != null && district.trim().isNotEmpty)
          ? <String, dynamic>{'district': district.trim()}
          : null,
    );
    final guards = data['guards'] as List<dynamic>? ?? const <dynamic>[];
    return guards
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => GuardProfileModel.fromJson(
            json,
            id: (json['id'] as String?) ?? '',
          ),
        )
        .toList();
  }

  /// Fetch guards for a specific client/site (used by guard attendee picker)
  Future<List<Map<String, dynamic>>> fetchGuardsForSite({
    required String clientId,
    required String siteId,
  }) async {
    final data = await _getJson(
      '/api/field-officer/guards',
      queryParameters: <String, dynamic>{
        if (clientId.isNotEmpty) 'clientId': clientId,
        if (siteId.isNotEmpty) 'siteId': siteId,
      },
    );
    final guards = data['guards'] as List<dynamic>? ?? const <dynamic>[];
    return guards
        .whereType<Map<String, dynamic>>()
        .map((g) => <String, dynamic>{
              'id': g['id']?.toString() ?? '',
              'name': g['name']?.toString() ?? g['fullName']?.toString() ?? '',
            })
        .toList();
  }

  Future<void> assignGuardsToWorkOrder({
    required String workOrderId,
    required List<Map<String, dynamic>> assignedGuards,
  }) async {
    await _patchJson(
      '/api/field-officer/work-orders/$workOrderId',
      <String, dynamic>{'assignedGuards': assignedGuards},
    );
  }

  Future<List<FieldOfficerAttendanceEntry>> fetchFieldOfficerGuardAttendance({
    String? date,
    String? district,
  }) async {
    final data = await _getJson(
      '/api/field-officer/guard-attendance',
      queryParameters: <String, dynamic>{
        if (date != null && date.isNotEmpty) 'date': date,
        if (district != null && district.trim().isNotEmpty)
          'district': district.trim(),
      },
    );

    // Check multiple possible keys for robustness
    final entries =
        (data['attendance'] ?? data['records'] ?? data['logs'] ?? data['data'])
            as List<dynamic>? ??
        const <dynamic>[];

    return entries
        .whereType<Map<String, dynamic>>()
        .map(FieldOfficerAttendanceEntry.fromJson)
        .toList();
  }

  Future<List<VisitReportModel>> fetchVisitReports() async {
    final data = await _getJson('/api/field-officer/visit-reports');
    final reports = data['reports'] as List<dynamic>? ?? const <dynamic>[];
    return reports
        .whereType<Map<String, dynamic>>()
        .map(VisitReportModel.fromJson)
        .toList();
  }

  Future<List<TrainingReportModel>> fetchTrainingReports() async {
    final data = await _getJson('/api/field-officer/training-reports');
    final reports = data['reports'] as List<dynamic>? ?? const <dynamic>[];
    return reports
        .whereType<Map<String, dynamic>>()
        .map(TrainingReportModel.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> submitVisitReport(
    Map<String, dynamic> payload,
  ) async {
    return _postJson('/api/field-officer/visit-reports', payload);
  }

  Future<Map<String, dynamic>> submitTrainingReport(
    Map<String, dynamic> payload,
  ) async {
    return _postJson('/api/field-officer/training-reports', payload);
  }

  Future<Map<String, dynamic>> fetchFieldOfficerReportHistory() async {
    final results = await Future.wait<dynamic>([
      _getJson('/api/field-officer/visit-reports'),
      _getJson('/api/field-officer/training-reports'),
    ]);
    final visits = results[0] as Map<String, dynamic>;
    final trainings = results[1] as Map<String, dynamic>;
    return <String, dynamic>{
      'visitReports': visits['reports'] ?? <dynamic>[],
      'trainingReports': trainings['reports'] ?? <dynamic>[],
    };
  }

  LeaveBalanceModel _parseLeaveBalance(Map<String, dynamic> json) {
    final casual = json['casual'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['casual'] as Map)
        : const <String, dynamic>{};
    // We only need one summary card in the mobile shell right now.
    final balance =
        (casual['balance'] as num?)?.toInt() ??
        (json['earned'] is Map<String, dynamic>
            ? ((json['earned'] as Map)['balance'] as num?)?.toInt() ?? 0
            : 0);
    return LeaveBalanceModel(
      entitled: (casual['entitled'] as num?)?.toInt() ?? 0,
      taken: (casual['taken'] as num?)?.toInt() ?? 0,
      balance: balance,
    );
  }

  Future<String> encodeFileToDataUrl(List<int> bytes, String mimeType) async {
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }
}
