import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../attendance/attendance_validation.dart';
import '../attendance/attendance_pairing.dart';
import '../models/app_role.dart';
import '../models/duty_models.dart';
import '../models/attendance_models.dart';
import '../models/auth_session.dart';
import '../models/guard_profile.dart';
import '../models/incident_models.dart';
import '../models/leave_models.dart';
import '../models/mobile_dashboard_models.dart';
import '../models/patrol_models.dart';
import '../models/payslip_models.dart';
import '../models/report_models.dart';
import '../models/training_models.dart';
import '../auth/guard_login_identifier.dart';
import '../cache/hive_read_cache_store.dart';
import '../cache/read_cache.dart';
import '../offline/willingness_queue.dart' show willingnessOrigin;
import 'api_client.dart'
    show
        ApiClient,
        kApiRequestIdentityGuard,
        kApiRequestIdentityChanged,
        kSkipApiAuth;
import 'authenticated_identity_mismatch_error.dart';
import 'authoritative_session_error.dart';
import 'auth_repository.dart';
import 'ciss_error.dart';
import 'guard_pin_verification_adapter.dart';
import '../region/region_service.dart';

class MobileRepository implements AuthRepository {
  MobileRepository(
    this._apiClient,
    this._auth,
    this._regionService, {
    GuardPinVerificationAdapter? guardPinVerificationAdapter,
    ReadCache? readCache,
    Future<String?> Function()? deviceIdProvider,
  }) : _guardPinVerificationAdapter =
           guardPinVerificationAdapter ?? GuardPinVerificationAdapter(),
       _readCache = readCache ?? ReadCache(store: HiveReadCacheStore()),
       _deviceIdProvider = deviceIdProvider;

  final ApiClient _apiClient;
  final FirebaseAuth _auth;
  final RegionService _regionService;
  final GuardPinVerificationAdapter _guardPinVerificationAdapter;
  final ReadCache _readCache;

  /// Supplies the handset identifier for writes that must say which device
  /// made them. Optional so an unconfigured repository (and every unit test)
  /// keeps working.
  final Future<String?> Function()? _deviceIdProvider;

  /// `X-Device-Id` for an attendance or duty-response write. A device whose id
  /// cannot be read simply omits the header.
  Future<Map<String, String>> _deviceHeaders() async {
    try {
      final id = (await _deviceIdProvider?.call())?.trim() ?? '';
      return id.isEmpty ? const <String, String>{} : <String, String>{
        'X-Device-Id': id,
      };
    } catch (error) {
      debugPrint('Device id unavailable for this request: $error');
      return const <String, String>{};
    }
  }

  ApiClient get apiClient => _apiClient;
  User? get currentUser => _auth.currentUser;

  static const String _mobileNotificationsPath = '/api/mobile/notifications';
  static const String _mobileTokenPath = '/api/mobile/token';
  static const String _remoteConfigPath = '/api/mobile/settings';
  static const String _attendanceBreakPath = '/api/mobile/attendance/break';
  static const String _attendanceValidatePath = '/api/attendance/validate';

  /// Read endpoints eligible for the Hive-backed read-through cache. The
  /// allowlist is deliberately narrow so identity/authorization responses
  /// (`/api/mobile/session`, auth, profile) are never served stale, and so
  /// dedicated live endpoints (streaming) are unaffected.
  static const Set<String> _cacheableReadPaths = <String>{
    '/api/guard/dashboard',
    '/api/guard/training',
    '/api/guard/evaluations',
    '/api/guard/payslips',
    '/api/guard/leave',
    '/api/guard/incidents',
    '/api/guard/leaderboard',
    '/api/field-officer/dashboard',
    '/api/field-officer/work-orders',
    '/api/field-officer/sites',
    '/api/field-officer/guards',
    '/api/field-officer/incidents',
    '/api/field-officer/visit-reports',
    '/api/field-officer/training-reports',
  };

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
      return _fetchNotificationsDirectly();
    }
  }

  Future<int> fetchUnreadNotificationCount() async {
    try {
      final data = await _getJson(_mobileNotificationsPath);
      return (data['unreadCount'] as num?)?.toInt() ?? 0;
    } catch (error) {
      final notifications = await _fetchNotificationsDirectly();
      return notifications.where((item) => item['read'] != true).length;
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

  String _readCacheKey(String path, Map<String, dynamic>? queryParameters) {
    final sorted =
        (queryParameters ?? <String, dynamic>{}).entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    final qs = sorted.map((e) => '${e.key}=${e.value}').join('&');
    final region = _regionService.activeRegion?.code ?? 'KL';
    return '$region|$path|$qs';
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    final cacheable = _cacheableReadPaths.contains(path);
    final cacheKey = cacheable ? _readCacheKey(path, queryParameters) : null;
    try {
      final response = await _apiClient.dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options:
            authenticated
                ? Options(headers: await _authHeaders())
                : Options(extra: <String, dynamic>{kSkipApiAuth: true}),
      );
      final data = response.data;
      if (data is! Map) {
        throw Exception('Unexpected response format from server');
      }
      final result = Map<String, dynamic>.from(data);
      if (cacheable && cacheKey != null) {
        _readCache.setJson(cacheKey, result);
      }
      return result;
    } catch (error) {
      // Offline/stale fallback: serve the last-known-good payload for cached
      // read endpoints so dashboards render from cache instead of erroring.
      if (cacheable && cacheKey != null) {
        final cached = await _readCache.readJson(cacheKey);
        if (cached != null) return cached;
      }
      if (_isOfflineDioError(error)) rethrow;
      throw Exception(_extractApiError(error));
    }
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _getJson(path, queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> postGeneric(
    String path,
    Map<String, dynamic> body,
  ) async {
    return _postJson(path, body);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
    bool identifyDevice = false,
  }) async {
    try {
      final deviceHeaders =
          identifyDevice
              ? await _deviceHeaders()
              : const <String, String>{};
      final response = await _apiClient.dio.post<dynamic>(
        path,
        data: body,
        options:
            authenticated
                ? Options(
                  headers: <String, String>{
                    ...await _authHeaders(),
                    ...deviceHeaders,
                  },
                )
                : Options(extra: <String, dynamic>{kSkipApiAuth: true}),
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
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) async {
    try {
      final response = await _apiClient.dio.patch<dynamic>(
        path,
        data: body,
        options:
            authenticated
                ? Options(headers: await _authHeaders())
                : Options(extra: <String, dynamic>{kSkipApiAuth: true}),
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
    if (error is! DioException) return false;

    // badCertificate = connection compromised, not simply offline
    if (error.type == DioExceptionType.badCertificate) {
      debugPrint('Connection compromised: bad certificate detected');
      return false;
    }

    // Server errors (>= 500) — queue for retry rather than dropping the data
    if (error.type == DioExceptionType.badResponse) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null && statusCode >= 500) {
        return true; // treat as queueable
      }
      return false;
    }

    return CissError.isRetryableNetworkError(error);
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      throw StateError('Not authenticated');
    }
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  @override
  Future<AuthSession?> resolveCurrentSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final backendSession = await _resolveSessionFromBackend();
      if (backendSession == null) {
        throw const AuthoritativeSessionResolutionError(
          'The server did not return an authorized mobile session.',
        );
      }
      return backendSession;
    } catch (error, st) {
      debugPrint('resolveCurrentSession caught error: $error\n$st');
      // Firebase authentication alone is not a CISS Mobile authorization
      // grant. Any missing, denied, malformed, unavailable, or UID-mismatched
      // authoritative response invalidates this Firebase identity too.
      await _signOutAfterAuthoritativeFailure(error);
      rethrow;
    }
  }

  Future<void> _signOutAfterAuthoritativeFailure(Object error) async {
    try {
      await _auth.signOut();
    } catch (signOutError) {
      // The caller still clears all UI state. Firebase sign-out failures must
      // not preserve an unauthorized application session.
      debugPrint(
        'Could not clear Firebase after authoritative session failure '
        '($error): $signOutError',
      );
    }
  }

  @visibleForTesting
  static bool allowsClaimsFallback(Object error) => false;

  Future<AuthSession?> _resolveSessionFromBackend() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('_resolveSessionFromBackend: _auth.currentUser is null');
      return null;
    }

    final data = await _getAuthoritativeSessionJson();
    debugPrint(
      '_resolveSessionFromBackend: received data=$data, user.uid=${user.uid}',
    );
    final role = _roleFromWire(data['role']);
    if (role == null) {
      debugPrint(
        '_resolveSessionFromBackend: _roleFromWire returned null for role=${data['role']}',
      );
      return null;
    }

    final firebaseUid = authoritativeSessionUid(
      firebaseUid: user.uid,
      backendUid: data['uid'] as String?,
    );

    return AuthSession(
      role: role,
      displayName:
          (data['displayName'] as String?)?.trim().isNotEmpty == true
              ? data['displayName'] as String
              : (user.displayName ?? user.email ?? role.label),
      primaryId:
          (data['primaryId'] as String?)?.trim().isNotEmpty == true
              ? data['primaryId'] as String
              : user.uid,
      uid: firebaseUid,
      email: data['email'] as String? ?? user.email,
      employeeDocId: data['employeeDocId'] as String?,
      assignedDistricts:
          (data['assignedDistricts'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      clientName: data['clientName'] as String?,
      district: data['district'] as String?,
      stateCode: data['stateCode'] as String?,
    );
  }

  Future<Map<String, dynamic>> _getAuthoritativeSessionJson() async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/api/mobile/session',
        options: Options(headers: await _authHeaders()),
      );
      final data = response.data;
      if (data is! Map) {
        throw const AuthoritativeSessionResolutionError(
          'The server returned an invalid mobile session response.',
        );
      }
      return Map<String, dynamic>.from(data);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        throw AuthoritativeSessionDeniedError(status!);
      }
      throw AuthoritativeSessionResolutionError(
        'Could not resolve the authoritative mobile session.',
      );
    } on AuthoritativeSessionResolutionError {
      rethrow;
    } catch (_) {
      throw const AuthoritativeSessionResolutionError(
        'Could not resolve the authoritative mobile session.',
      );
    }
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
    if (error is StateError) {
      return error.message.toString();
    }
    if (error is FormatException) {
      return 'The server returned an invalid response.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Map<String, dynamic> _mapResponse(Object? value) {
    if (value is! Map) {
      throw const FormatException('The server returned an invalid response.');
    }
    return Map<String, dynamic>.from(value);
  }

  List<dynamic> _listValue(Map<String, dynamic> data, Iterable<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is List) return value;
    }
    return const <dynamic>[];
  }

  Future<bool> _saveFcmTokenDirectly(String token) async {
    final user = _auth.currentUser;
    if (user == null || token.trim().isEmpty) {
      return false;
    }

    try {
      await _regionService.activeFirestore
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

    final snapshot =
        await _regionService.activeFirestore
            .collection('notifications')
            .where('recipientUid', isEqualTo: user.uid)
            .limit(50)
            .get();

    final notifications =
        snapshot.docs
            .map((doc) => _serializeNotificationDocument(doc))
            .toList();
    notifications.sort((a, b) {
      final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return notifications;
  }

  Future<bool> _markNotificationAsReadDirectly(String notifId) async {
    final user = _auth.currentUser;
    if (user == null || notifId.trim().isEmpty) {
      return false;
    }

    try {
      final docRef = _regionService.activeFirestore
          .collection('notifications')
          .doc(notifId.trim());
      final snapshot = await docRef.get();
      final data = snapshot.data();
      if (!snapshot.exists ||
          data == null ||
          data['recipientUid'] != user.uid) {
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
      final firestore = _regionService.activeFirestore;
      final snapshot =
          await firestore
              .collection('notifications')
              .where('recipientUid', isEqualTo: user.uid)
              .limit(50)
              .get();

      if (snapshot.docs.isEmpty) {
        return true;
      }

      final batch = firestore.batch();
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
      'createdAt':
          createdAt is Timestamp
              ? createdAt.toDate().toIso8601String()
              : createdAt?.toString(),
      'readAt':
          readAt is Timestamp
              ? readAt.toDate().toIso8601String()
              : readAt?.toString(),
      'recipientUid': data['recipientUid'],
      'recipientRole': data['recipientRole'],
      'recipientDistrict': data['recipientDistrict'],
      'data':
          data['data'] is Map
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

  /// Returns null when the reset outcome must remain neutral to callers.
  @visibleForTesting
  static String authoritativeSessionUid({
    required String firebaseUid,
    String? backendUid,
  }) {
    final normalizedBackendUid = backendUid?.trim();
    if (normalizedBackendUid != null &&
        normalizedBackendUid.isNotEmpty &&
        normalizedBackendUid != firebaseUid) {
      // The bearer token authenticates [firebaseUid]. Never attach that
      // user's client session to a UID supplied by a backend response.
      throw AuthenticatedIdentityMismatchError(
        firebaseUid: firebaseUid,
        backendUid: normalizedBackendUid,
      );
    }
    return firebaseUid;
  }

  @visibleForTesting
  static String? passwordResetErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
      case 'user-disabled':
        return null;
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'too-many-requests':
        return 'Too many password reset attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network error while sending reset instructions. Please check the connection.';
      case 'operation-not-allowed':
        return 'Password reset is currently unavailable. Please contact support.';
      default:
        return 'Could not send reset instructions. Please try again.';
    }
  }

  Map<String, String> _guardIdentityPayload(String loginIdOrPhone) {
    final normalizedInput = loginIdOrPhone.trim();
    final isPhoneLike = GuardLoginIdentifier.isPhoneNumber(normalizedInput);
    return <String, String>{
      if (isPhoneLike)
        'phoneNumber': normalizedInput
      else
        'employeeId': normalizedInput,
    };
  }

  Future<void> setupGuardPin({
    required String employeeId,
    required String phoneNumber,
    required String dateOfBirth,
    required String pin,
  }) async {
    try {
      final normalizedPhoneNumber = _normalizeGuardPhoneNumber(phoneNumber);
      await _apiClient.dio.post<dynamic>(
        '/api/guard/auth/setup-pin',
        data: <String, String>{
          if (employeeId.trim().isNotEmpty) 'employeeId': employeeId.trim(),
          'phoneNumber': normalizedPhoneNumber,
          'dateOfBirth': dateOfBirth.trim(),
          'pin': pin.trim(),
        },
      );
    } catch (error) {
      throw Exception(_guardPinSetupErrorMessage(error));
    }
  }

  /// Identity verification happens on an unauthenticated endpoint. Keep
  /// identity-dependent failures neutral so the setup screen cannot reveal
  /// whether a phone number, employee id, or date of birth matched.
  String _guardPinSetupErrorMessage(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 400 ||
          status == 401 ||
          status == 403 ||
          status == 404 ||
          status == 409) {
        return guardPinSetupClientMessage();
      }
    }

    final message = _extractApiError(error);
    return guardPinSetupClientMessage(serverMessage: message);
  }

  @visibleForTesting
  static String guardPinSetupClientMessage({String? serverMessage}) {
    final normalized = serverMessage?.toLowerCase() ?? '';
    const identityTerms = <String>[
      'employee',
      'phone',
      'date of birth',
      'dob',
      'identity',
      'not found',
      'does not match',
      'invalid details',
    ];
    if (identityTerms.any(normalized.contains)) {
      return 'Could not verify those details. Check them and try again.';
    }
    return serverMessage?.trim().isNotEmpty == true
        ? serverMessage!.trim()
        : 'Could not set the PIN. Please try again.';
  }

  String _normalizeGuardPhoneNumber(String phoneNumber) {
    final trimmedPhoneNumber = phoneNumber.trim();
    if (!RegExp(r'^[0-9\s()+-]+$').hasMatch(trimmedPhoneNumber)) {
      throw StateError('Phone number contains unsupported characters.');
    }
    final normalizedPhoneNumber = trimmedPhoneNumber.replaceAll(
      RegExp(r'\D+'),
      '',
    );
    if (!RegExp(r'^\d{8,15}$').hasMatch(normalizedPhoneNumber)) {
      throw StateError('Enter a valid registered phone number.');
    }
    return normalizedPhoneNumber;
  }

  Future<void> changeGuardPin({
    required String currentPin,
    required String newPin,
  }) async {
    try {
      await _apiClient.dio.post<dynamic>(
        '/api/guard/auth/change-pin',
        data: <String, String>{
          'currentPin': currentPin.trim(),
          'newPin': newPin.trim(),
        },
      );
    } catch (error) {
      throw Exception(_extractApiError(error));
    }
  }

  @override
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

      final data = _mapResponse(response.data);
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

  @override
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

  void _assertActiveIdentity(AuthSession expectedSession) {
    final user = _auth.currentUser;
    if (expectedSession.role != AppRole.guard &&
        expectedSession.role != AppRole.fieldOfficer) {
      throw const AuthenticatedIdentityMismatchError(
        firebaseUid: '',
        backendUid: '',
      );
    }
    if (user == null || user.uid != expectedSession.uid) {
      throw AuthenticatedIdentityMismatchError(
        firebaseUid: user?.uid ?? '',
        backendUid: expectedSession.uid,
      );
    }
  }

  @override
  Future<void> verifyCurrentFieldOfficerPassword({
    required AuthSession expectedSession,
    required String email,
    required String password,
  }) async {
    if (expectedSession.role != AppRole.fieldOfficer) {
      throw AuthenticatedIdentityMismatchError(
        firebaseUid: _auth.currentUser?.uid ?? '',
        backendUid: expectedSession.uid,
      );
    }
    _assertActiveIdentity(expectedSession);
    final user = _auth.currentUser!;
    if (user.email?.trim().toLowerCase() != email.trim().toLowerCase()) {
      throw AuthenticatedIdentityMismatchError(
        firebaseUid: user.uid,
        backendUid: expectedSession.uid,
      );
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email.trim(), password: password),
    );
    _assertActiveIdentity(expectedSession);
  }

  @override
  Future<void> verifyCurrentGuardPin({
    required AuthSession expectedSession,
    required String loginIdOrPhone,
    required String pin,
  }) async {
    if (expectedSession.role != AppRole.guard) {
      throw AuthenticatedIdentityMismatchError(
        firebaseUid: _auth.currentUser?.uid ?? '',
        backendUid: expectedSession.uid,
      );
    }
    _assertActiveIdentity(expectedSession);

    final response = await _apiClient.dio.post<dynamic>(
      '/api/guard/auth/login',
      data: <String, String>{
        ..._guardIdentityPayload(loginIdOrPhone),
        'pin': pin.trim(),
      },
    );
    final token = _mapResponse(response.data)['token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Guard verification did not return a Firebase token.');
    }

    // The primary identity may belong to a named regional Firebase app.
    // Verification uses those active app options in a disposable adapter,
    // never the default Firebase app's options.
    await _guardPinVerificationAdapter.verify(
      regionalOptions: _auth.app.options,
      token: token,
      expectedUid: expectedSession.uid,
    );
    _assertActiveIdentity(expectedSession);
  }

  /// Sends the Firebase password-reset email for a field officer account.
  ///
  /// Firebase owns this workflow; no application backend endpoint is involved.
  Future<void> sendFieldOfficerPasswordResetEmail({
    required String email,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      final message = passwordResetErrorMessage(error);
      // Keep the outcome neutral so this screen cannot be used to discover
      // whether a given email address exists or has been disabled.
      if (message == null) return;
      throw Exception(message);
    } catch (_) {
      throw Exception('Could not send reset instructions. Please try again.');
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  Future<GuardDashboardSnapshot> fetchGuardDashboard() async {
    final data = await _getJson('/api/guard/dashboard');
    final attendanceStats =
        data['attendanceStats'] is Map
            ? Map<String, dynamic>.from(data['attendanceStats'] as Map)
            : const <String, dynamic>{};
    final leaveBalance =
        data['leaveBalance'] is Map<String, dynamic>
            ? _parseLeaveBalance(
              Map<String, dynamic>.from(data['leaveBalance'] as Map),
            )
            : null;
    final recentAttendance =
        (data['recentAttendance'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map((item) => AttendanceRecordModel.fromJson(item))
            .toList();

    final nextShift =
        data['nextShift'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(data['nextShift'] as Map)
            : null;

    return GuardDashboardSnapshot(
      employeeName: (data['employeeName'] as String?) ?? '',
      employeeId: (data['employeeId'] as String?) ?? '',
      clientName: (data['clientName'] as String?) ?? '',
      district: (data['district'] as String?) ?? '',
      profilePhotoUrl: data['profilePhotoUrl'] as String?,
      presentDays: (attendanceStats['presentDays'] as num?)?.toInt() ?? 0,
      absentDays: (attendanceStats['absentDays'] as num?)?.toInt() ?? 0,
      workingDays: (attendanceStats['workingDays'] as num?)?.toInt() ?? 0,
      leaveBalance: leaveBalance,
      latestEvalScore: data['latestEvalScore'] as num?,
      latestEvalPeriod: data['latestEvalPeriod'] as String?,
      nextShiftLabel: nextShift?['shiftLabel'] as String?,
      nextShiftSiteName: nextShift?['siteName'] as String?,
      nextShiftDate: nextShift?['date'] as String?,
      nextShiftUnavailable: data['nextShiftUnavailable'] == true,
      recentAttendance: recentAttendance,
    );
  }

  Future<GuardProfileModel> fetchGuardProfile() async {
    final data = await _getJson('/api/guard/profile');
    // The backend returns the employee data flat (not wrapped in "employee").
    // Support both shapes for backward compatibility.
    final employee =
        data['employee'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(data['employee'] as Map)
            : data;
    // The /api/guard/profile endpoint does not include the document id, so
    // fall back to the employeeDocId custom claim (the Firestore doc id used
    // for photo storage paths like employees/{employeeDocId}/attendance).
    final backendId = employee['id'] as String? ?? '';
    return GuardProfileModel.fromJson(
      employee,
      id:
          backendId.isNotEmpty
              ? backendId
              : (await _guardEmployeeDocId() ?? ''),
    );
  }

  /// Reads the guard's employeeDocId from the Firebase custom token claims.
  /// This is the Firestore employee document id (no slashes) used as the
  /// storage owner key for attendance photos.
  Future<String?> _guardEmployeeDocId() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      final token = await user.getIdTokenResult(false);
      final employeeDocId = token.claims?['employeeDocId'] as String?;
      if (employeeDocId != null && employeeDocId.trim().isNotEmpty) {
        return employeeDocId.trim();
      }
    } catch (error) {
      debugPrint('Could not resolve guard employeeDocId from claims: $error');
    }
    return null;
  }

  Future<List<SiteOptionModel>> fetchAttendanceSites() async {
    final data = await _getJson('/api/public/attendance', authenticated: false);
    final options = data['options'] as List<dynamic>? ?? const <dynamic>[];
    return options
        .whereType<Map<String, dynamic>>()
        .map(SiteOptionModel.fromJson)
        .toList();
  }

  Future<PublicAttendanceEmployeeModel?> fetchAttendanceEmployee(
    String employeeId, [
    String? phoneNumber,
    String? resourceId,
  ]) async {
    final params = <String, dynamic>{};
    if (employeeId.isNotEmpty) params['employeeId'] = employeeId;
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      params['phoneNumber'] = phoneNumber;
    }
    if (resourceId != null && resourceId.isNotEmpty) {
      params['resourceId'] = resourceId;
    }
    if (params.isEmpty) return null;
    final body = <String, dynamic>{
      if (employeeId.isNotEmpty) ...<String, dynamic>{
        'method': 'employeeId',
        'value': employeeId,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phoneNumber': phoneNumber,
      } else if (phoneNumber != null &&
          phoneNumber.isNotEmpty) ...<String, dynamic>{
        'method': 'phone',
        'value': phoneNumber,
      } else ...<String, dynamic>{'method': 'resourceId', 'value': resourceId},
    };
    final data = await _postJson(
      '/api/public/attendance/identify',
      body,
      authenticated: false,
    );
    return _parsePublicAttendanceEmployee(data);
  }

  Future<PublicAttendanceEmployeeModel?> fetchAttendanceEmployeeByQr(
    String qrValue,
  ) async {
    final data = await _postJson(
      '/api/public/attendance/identify',
      <String, dynamic>{'method': 'qr', 'value': qrValue},
      authenticated: false,
    );
    return _parsePublicAttendanceEmployee(data);
  }

  PublicAttendanceEmployeeModel? _parsePublicAttendanceEmployee(
    Map<String, dynamic> data,
  ) {
    if (data['found'] != true) return null;
    final employee =
        data['employee'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(data['employee'] as Map)
            : <String, dynamic>{};
    final hint =
        employee['attendanceHint'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(employee['attendanceHint'] as Map)
            : null;
    return PublicAttendanceEmployeeModel(
      id: employee['id'] as String? ?? '',
      employeeCode: employee['employeeCode'] as String?,
      fullName: employee['fullName'] as String? ?? '',
      phoneNumber: employee['phoneNumber'] as String?,
      clientName: employee['clientName'] as String?,
      verificationToken: data['verificationToken'] as String?,
      attendanceHint:
          hint == null
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
    required String employeeDocId,
    required String dataUrl,
    required String siteId,
    String? attemptId,
    String? verificationToken,
    bool authenticated = true,
  }) async {
    final ownerKey = employeeDocId.trim();
    if (!RegExp(r'^[0-9A-Za-z_-]+$').hasMatch(ownerKey)) {
      throw Exception(
        'Attendance photo path must use employees/{id}/attendance.',
      );
    }
    if (siteId.isEmpty) {
      throw Exception('Attendance site id is required for photo upload.');
    }
    final attempt =
        (attemptId == null || attemptId.isEmpty)
            ? const Uuid().v4()
            : attemptId;
    final path = 'employees/$ownerKey/attendance/$attempt/photo.jpg';
    try {
      final tokenResponse = await _apiClient.dio.post<dynamic>(
        '/api/public/attendance/upload-token',
        data: <String, dynamic>{
          'employeeDocId': ownerKey,
          'siteId': siteId,
          'attemptId': attempt,
          if (verificationToken != null && verificationToken.isNotEmpty)
            'attendanceVerificationToken': verificationToken,
        },
        options:
            authenticated
                ? null
                : Options(extra: <String, dynamic>{kSkipApiAuth: true}),
      );
      final tokenData = _mapResponse(tokenResponse.data);
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
        options:
            authenticated
                ? null
                : Options(extra: <String, dynamic>{kSkipApiAuth: true}),
      );
      return _mapResponse(response.data);
    } catch (error) {
      if (_isOfflineDioError(error)) rethrow;
      throw Exception('Photo upload failed: ${_extractApiError(error)}');
    }
  }

  /// Uploads a report photo directly to Firebase Storage.
  ///
  /// The legacy `/api/field-officer/upload` REST endpoint was retired by the
  /// backend (HTTP 410); the webapp uploads report photos straight to
  /// Storage under `foReports/{folder}/{uid}/...` and submits the download
  /// URLs. The app mirrors that flow, honoring the active regional Firebase
  /// storage bucket.
  Future<Map<String, dynamic>> uploadReportPhoto({
    required String path,
    required String dataUrl,
  }) async {
    try {
      final bytes = Uint8List.fromList(_dataUrlToBytes(dataUrl));
      final storage = _regionService.activeStorage;
      final reference = storage.ref(path);
      await reference.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await reference.getDownloadURL();
      return <String, dynamic>{'url': url, 'path': path};
    } catch (error) {
      if (error is FirebaseException &&
          CissError.isRetryableNetworkError(error)) {
        rethrow;
      }
      if (error is FirebaseException &&
          (error.code == 'permission-denied' ||
              error.code == 'unauthenticated')) {
        throw Exception('Report photo upload failed: storage access denied');
      }
      throw Exception('Report photo upload failed: $error');
    }
  }

  /// Decodes a `data:<mime>;base64,<payload>` string back to raw bytes.
  List<int> _dataUrlToBytes(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    final payload = comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl;
    return base64Decode(payload);
  }

  Future<Map<String, dynamic>> submitAttendance(
    Map<String, dynamic> payload,
  ) async {
    final verificationToken = payload['attendanceVerificationToken'];
    return _postJson(
      '/api/attendance/submit',
      payload,
      authenticated:
          !(verificationToken is String && verificationToken.trim().isNotEmpty),
      // The server records which handset produced the punch so a shared login
      // or a swapped phone can be spotted on the record.
      identifyDevice: true,
    );
  }

  /// Server-authoritative geo + IP pre-check for check-in/out.
  ///
  /// The server derives the client IP from the request itself; [publicIp] is an
  /// optional hint only. The attendance submit endpoint re-enforces the same
  /// checks, so callers must treat an error here as fail-open rather than as
  /// permission to bypass enforcement.
  Future<AttendanceValidationResult> validateAttendance({
    required String employeeDocId,
    required String siteId,
    required double lat,
    required double lon,
    required String status,
    String? publicIp,
    String? dutyPointId,
  }) async {
    final data = await _postJson(_attendanceValidatePath, <String, dynamic>{
      'employeeDocId': employeeDocId,
      'siteId': siteId,
      'lat': lat,
      'lon': lon,
      'status': status,
      'dutyPointId': dutyPointId,
      'publicIp': publicIp,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
    });
    return AttendanceValidationResult.fromJson(data);
  }

  /// Starts or stops a break for the guard's open attendance session.
  ///
  /// The backend is authoritative for the resulting state, so the response
  /// (see `AttendanceSession.applyBreakResponse`) is returned to the caller.
  Future<Map<String, dynamic>> attendanceBreak({
    required String action,
    double? lat,
    double? lng,
    double? accuracy,
  }) async {
    return _postJson(_attendanceBreakPath, <String, dynamic>{
      'action': action,
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> startBreak({
    double? lat,
    double? lng,
    double? accuracy,
  }) {
    return attendanceBreak(
      action: 'start',
      lat: lat,
      lng: lng,
      accuracy: accuracy,
    );
  }

  Future<Map<String, dynamic>> stopBreak({
    double? lat,
    double? lng,
    double? accuracy,
  }) {
    return attendanceBreak(
      action: 'stop',
      lat: lat,
      lng: lng,
      accuracy: accuracy,
    );
  }

  Future<Map<String, dynamic>> fetchGuardTrackingStatus() {
    return _getJson('/api/guard/tracking/status');
  }

  Future<Map<String, dynamic>> fetchRemoteConfig() async {
    final response = await _getJson(_remoteConfigPath);
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : response;
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

  Future<Map<String, dynamic>> fetchQuiz(String assignmentId) async {
    return _getJson('/api/guard/training/quiz/$assignmentId');
  }

  Future<Map<String, dynamic>> submitQuiz({
    required String assignmentId,
    required String bankId,
    required String startedAt,
    required List<Map<String, dynamic>> answers,
  }) async {
    return _postJson(
      '/api/guard/training/quiz/$assignmentId/submit',
      <String, dynamic>{
        'bankId': bankId,
        'startedAt': startedAt,
        'answers': answers,
      },
    );
  }

  Future<GuardTrainingLeaderboard> fetchTrainingLeaderboard() async {
    final data = await _getJson('/api/guard/leaderboard');
    return GuardTrainingLeaderboard.fromJson(data);
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

  Future<List<int>> downloadPayslipPdf(String payslipId) async {
    final response = await _apiClient.dio.get<List<int>>(
      '/api/guard/payslips/${Uri.encodeComponent(payslipId)}/payslip',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? const <int>[];
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

  /// Field-officer view of guard patrol activity (patrol rounds + hourly
  /// night-photo checks). The webapp exposes this to field officers through
  /// the shared admin route with district-scoped authorization; returns
  /// `{summary, settings, activities}` where
  /// activities are `GuardPatrolActivityModel` rows.
  Future<Map<String, dynamic>> fetchFieldOfficerPatrolActivities() async {
    return _getJson('/api/admin/patrol-activities');
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

  Future<List<IncidentModel>> fetchFieldOfficerIncidents() async {
    final data = await _getJson('/api/field-officer/incidents');
    return (data['incidents'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(IncidentModel.fromJson)
        .toList();
  }

  // ── Field Officer endpoints ──────────────────────────────────────────

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
      totalSitesInScope: (data['totalSitesInScope'] as num?)?.toInt() ?? 0,
      attendanceSummary: FieldOfficerAttendanceSummary.fromJson(
        data['attendanceSummary'] as Map<String, dynamic>?,
      ),
      todayOverview: FieldOfficerTodayOverview.fromJson(
        data['todayOverview'] as Map<String, dynamic>?,
      ),
      todaySites:
          (data['todaySites'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(FieldOfficerTodaySiteBrief.fromJson)
              .toList(),
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

  String get dutyApiBaseUrl => _apiClient.dio.options.baseUrl;

  /// Duties retain structured HTTP errors for retry/CAS decisions and have no
  /// Firestore or stale-cache fallback.
  Future<Map<String, dynamic>> _dutyJson(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    Future<bool> Function()? identityGuard,
    bool identifyDevice = false,
  }) async {
    final result = await _apiClient.dio.request<dynamic>(
      path,
      data: body,
      queryParameters: query,
      options: Options(
        method: method,
        headers:
            identityGuard == null || identifyDevice
                ? <String, String>{
                  if (identityGuard == null) ...await _authHeaders(),
                  if (identifyDevice) ...await _deviceHeaders(),
                }
                : null,
        extra:
            identityGuard == null
                ? null
                : <String, dynamic>{kApiRequestIdentityGuard: identityGuard},
      ),
    );
    if (result.data is! Map) {
      throw const FormatException('Invalid duty response');
    }
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<List<GuardDuty>> fetchGuardDuties() async {
    final data = await _dutyJson('/api/guard/duties');
    return (data['duties'] as List? ?? [])
        .whereType<Map>()
        .map((e) => GuardDuty.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<WillingnessReceipt> setDutyWillingness({
    required String workOrderId,
    required WillingnessStatus response,
    required String clientRequestId,
    required int expectedVersion,
    String? expectedOwnerUid,
    String? expectedApiBaseUrl,
    Future<bool> Function()? isCurrentOperation,
  }) async {
    Future<bool> Function()? identityGuard;
    if (expectedOwnerUid != null && expectedApiBaseUrl != null) {
      final expectedOrigin = willingnessOrigin(expectedApiBaseUrl);
      identityGuard =
          () async =>
              currentUser?.uid == expectedOwnerUid &&
              willingnessOrigin(dutyApiBaseUrl) == expectedOrigin &&
              (isCurrentOperation == null || await isCurrentOperation());
      if (!await identityGuard()) {
        throw DioException(
          requestOptions: RequestOptions(
            path: '/api/guard/duties/$workOrderId/willingness',
          ),
          type: DioExceptionType.cancel,
          message: kApiRequestIdentityChanged,
        );
      }
    }
    return WillingnessReceipt.fromJson(
      await _dutyJson(
        '/api/guard/duties/${Uri.encodeComponent(workOrderId)}/willingness',
        method: 'POST',
        body: {
          'response': response.name,
          'clientRequestId': clientRequestId,
          'expectedVersion': expectedVersion,
        },
        identityGuard: identityGuard,
        identifyDevice: true,
      ),
    );
  }

  Future<WorkOrderWillingness> fetchWorkOrderWillingness(
    String id,
  ) async => WorkOrderWillingness.fromJson(
    await _dutyJson(
      '/api/field-officer/work-orders/${Uri.encodeComponent(id)}/willingness',
    ),
  );
  Future<List<GuardAssignment>> fetchGuardAssignments({
    String? from,
    String? to,
  }) async {
    final data = await _dutyJson(
      '/api/field-officer/assignments',
      query: {if (from != null) 'from': from, if (to != null) 'to': to},
    );
    return (data['assignments'] as List? ?? [])
        .whereType<Map>()
        .map((e) => GuardAssignment(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<GuardAssignment> createGuardAssignment(
    Map<String, dynamic> body,
  ) async {
    final data = await _dutyJson(
      '/api/field-officer/assignments',
      method: 'POST',
      body: body,
    );
    return GuardAssignment(
      Map<String, dynamic>.from(data['assignment'] as Map),
    );
  }

  Future<GuardAssignment> updateGuardAssignment(
    String id,
    Map<String, dynamic> body,
  ) async {
    final data = await _dutyJson(
      '/api/field-officer/assignments/${Uri.encodeComponent(id)}',
      method: 'PATCH',
      body: body,
    );
    return GuardAssignment(
      Map<String, dynamic>.from(data['assignment'] as Map),
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
      queryParameters:
          (district != null && district.trim().isNotEmpty)
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
    bool includeInactive = false,
  }) async {
    final queryParameters = <String, dynamic>{
      if (district != null && district.trim().isNotEmpty)
        'district': district.trim(),
      if (includeInactive) 'includeInactive': true,
    };
    final data = await _getJson(
      '/api/field-officer/guards',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
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
        .map(
          (g) => <String, dynamic>{
            'id': g['id']?.toString() ?? '',
            'name': g['name']?.toString() ?? g['fullName']?.toString() ?? '',
          },
        )
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

  Future<List<WorkOrderRevisionEventModel>> fetchWorkOrderRevisions() async {
    final data = await _getJson('/api/field-officer/work-order-revisions');
    return (data['events'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(WorkOrderRevisionEventModel.fromJson)
        .toList();
  }

  Future<void> acknowledgeWorkOrderRevision(String eventId) async {
    await _postJson(
      '/api/field-officer/work-order-revisions',
      <String, dynamic>{'eventId': eventId},
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
    final entries = _listValue(data, const <String>[
      'attendance',
      'records',
      'logs',
      'data',
    ]);

    return entries
        .whereType<Map<String, dynamic>>()
        .map(FieldOfficerAttendanceEntry.fromJson)
        .where((entry) => entry.hasRecordedPunch)
        .toList();
  }

  Future<List<FieldOfficerAttendanceEntry>>
  fetchFieldOfficerGuardAttendanceRange({
    required DateTime start,
    required DateTime end,
    String? district,
  }) async {
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);

    String fmt(DateTime day) =>
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

    // A single aggregated request replaces the previous N-day fan-out (which
    // launched up to 62 requests and caused connection resets on mobile).
    final data = await _getJson(
      '/api/field-officer/guard-attendance/range',
      queryParameters: <String, dynamic>{
        'start': fmt(first),
        'end': fmt(last),
        if (district != null && district.trim().isNotEmpty)
          'district': district.trim(),
      },
    );

    final entries = _listValue(data, const <String>[
      'attendance',
      'records',
      'logs',
    ]);

    return entries
        .whereType<Map<String, dynamic>>()
        .map(FieldOfficerAttendanceEntry.fromJson)
        .where((entry) => entry.hasRecordedPunch)
        .toList();
  }

  /// Attendance rows for one *business date*, including the previous calendar
  /// date.
  ///
  /// A 20:00 → 06:00 duty is filed under the day it started but its check-out
  /// is written on the next date, so asking for one date alone yields an
  /// unpaired punch and a guard who reads as off duty at midnight. The
  /// aggregated range endpoint answers this in a single request; a deployment
  /// without it falls back to one call per date, merged by row id so a punch
  /// returned by both is counted once.
  Future<List<FieldOfficerAttendanceEntry>> fetchGuardAttendanceForBusinessDate({
    required DateTime businessDate,
    String? district,
    int lookbackDays = 1,
  }) async {
    final day = DateTime(
      businessDate.year,
      businessDate.month,
      businessDate.day,
    );
    String key(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';

    try {
      return await fetchFieldOfficerGuardAttendanceRange(
        start: day.subtract(Duration(days: lookbackDays)),
        end: day,
        district: district,
      );
    } catch (error) {
      if (!_isRouteUnavailable(error)) rethrow;
    }

    final batches = <List<FieldOfficerAttendanceEntry>>[];
    for (var offset = lookbackDays; offset >= 0; offset--) {
      batches.add(
        await fetchFieldOfficerGuardAttendance(
          date: key(day.subtract(Duration(days: offset))),
          district: district,
        ),
      );
    }
    return mergeAttendanceRows(batches);
  }

  /// True when a failure means "this route is not on this deployment" rather
  /// than "this request failed", so the caller may fall back to an older route.
  static bool _isRouteUnavailable(Object error) {
    if (error is DioException) return error.response?.statusCode == 404;
    // `_getJson` rewrites an unexpected status into the parsed API message,
    // which renders a 404 as a "... not found" sentence. The guard is confined
    // to the fallback above, so a data-level miss only costs the extra request.
    return error.toString().toLowerCase().contains('not found');
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

  Future<Map<String, dynamic>> createVisitReportRevision(
    String reportId,
  ) async {
    return _postJson(
      '/api/admin/visit-reports/${Uri.encodeComponent(reportId)}/revisions',
      <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> createTrainingReportRevision(
    String reportId,
  ) async {
    return _postJson(
      '/api/admin/training-reports/${Uri.encodeComponent(reportId)}/revisions',
      <String, dynamic>{},
    );
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
    final casual =
        json['casual'] is Map<String, dynamic>
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

  Future<Map<String, dynamic>> enrollGuard(Map<String, dynamic> payload) async {
    return _postJson('/api/employees/enroll', payload);
  }

  /// Must match `AADHAAR_CONSENT_VERSION` in `(web) src/lib/aadhaar-policy.ts`.
  static const String aadhaarConsentVersion = 'aadhaar-esic-epf-v1';

  /// Uploads a missing enrolment document (Aadhaar / identity / address) for
  /// the signed-in guard. Mirrors the web `POST /api/guard/profile/documents`
  /// contract; files are sent as multipart form-data.
  ///
  /// - `category=aadhaar` requires `aadhaarNumber` + a `front` copy and sends
  ///   the consent flag/version automatically.
  /// - `category=identity|address` requires `documentType` + `documentNumber`
  ///   and a `front` copy, with an optional `back` copy.
  Future<void> uploadGuardDocument({
    required String category,
    String? documentType,
    String? documentNumber,
    String? aadhaarNumber,
    required DocumentUploadFile front,
    DocumentUploadFile? back,
  }) async {
    final form = FormData();
    form.fields.add(MapEntry('category', category));
    if (category == 'aadhaar') {
      form.fields.add(MapEntry('consentAccepted', 'true'));
      form.fields.add(MapEntry('consentVersion', aadhaarConsentVersion));
      form.fields.add(MapEntry('aadhaarNumber', aadhaarNumber ?? ''));
      form.files.add(MapEntry('front', await _toMultipartFile('front', front)));
    } else {
      form.fields.add(MapEntry('documentType', documentType ?? ''));
      form.fields.add(MapEntry('documentNumber', documentNumber ?? ''));
      form.files.add(MapEntry('front', await _toMultipartFile('front', front)));
      if (back != null) {
        form.files.add(MapEntry('back', await _toMultipartFile('back', back)));
      }
    }
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/api/guard/profile/documents',
        data: form,
        options: Options(headers: await _authHeaders()),
      );
      final data = response.data;
      if (data is! Map) {
        throw const FormatException('Unexpected response from server');
      }
    } on DioException catch (error) {
      throw Exception(_extractApiError(error));
    }
  }

  Future<MultipartFile> _toMultipartFile(
    String field,
    DocumentUploadFile file,
  ) async {
    return MultipartFile.fromFile(file.path, filename: file.name);
  }

  /// Requests an Aadhaar correction (ESIC/EPF) for the signed-in guard.
  // Payload contract: {'reason': reason}
  Future<Map<String, dynamic>> requestAadhaarCorrection(String reason) async {
    return _postJson('/api/guard/profile/aadhaar-correction', {
      'reason': reason,
    });
  }
}
