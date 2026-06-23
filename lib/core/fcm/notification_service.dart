import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../features/field_officer/field_officer_tab_provider.dart';
import '../../features/guard/guard_tab_provider.dart';
import '../network/providers.dart';
import '../models/app_role.dart';
import '../../features/auth/application/auth_controller.dart';

class NotificationService {
  NotificationService(this._ref);

  final Ref _ref;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final Set<String> _subscribedTopics = <String>{};
  Timer? _sessionRetryTimer;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _messageOpenedAppSub;

  void dispose() {
    _sessionRetryTimer?.cancel();
    _sessionRetryTimer = null;
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundMessageSub?.cancel();
    _foregroundMessageSub = null;
    _messageOpenedAppSub?.cancel();
    _messageOpenedAppSub = null;
  }

  void _ensureSessionRetryLoop() {
    _sessionRetryTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        final session = _ref.read(authSessionProvider).value;
        if (session != null) {
          unawaited(refreshTopicSubscription());
          _sessionRetryTimer?.cancel();
          _sessionRetryTimer = null;
        }
      },
    );
  }

  static Stream<T> _poll<T>(
    Future<T> Function() load, {
    Duration interval = const Duration(seconds: 30),
  }) async* {
    yield await load();
    yield* Stream.periodic(interval).asyncMap((_) => load());
  }

  static final _notificationsSnapshotProvider =
      StreamProvider<List<Map<String, dynamic>>>((ref) {
        final repo = ref.watch(mobileRepositoryProvider);
        return _poll(repo.fetchNotifications);
      });

  static final unreadCountProvider = StreamProvider<int>((ref) {
    final repo = ref.watch(mobileRepositoryProvider);
    return _poll(repo.fetchUnreadNotificationCount);
  });

  static final notificationsProvider =
      Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
        return ref.watch(_notificationsSnapshotProvider);
      });

  Future<void> init() async {
    _ensureSessionRetryLoop();

    // ── Local notification setup ───────────────────────────────────────
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // ── FCM setup ──────────────────────────────────────────────────────
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await _fcm.getToken();
      if (token != null) {
        await _ref.read(mobileRepositoryProvider).updateFcmToken(token);
      }

      _tokenRefreshSub = _fcm.onTokenRefresh.listen((String newToken) async {
        await _ref.read(mobileRepositoryProvider).updateFcmToken(newToken);
      });

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Foreground messages — show local notification
      _foregroundMessageSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Background/open messages
      _messageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageClick);

      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageClick(initialMessage);
      }

      // Subscribe to role-based topic for broadcasts
      await _subscribeToRoleTopic();
    }
  }

  /// Subscribe to the appropriate FCM topic based on the user's role.
  /// Called after auth session is resolved.
  Future<void> _subscribeToRoleTopic() async {
    try {
      final session = _ref.read(authSessionProvider).value;
      if (session == null) {
        await clearTopicSubscriptions();
        return;
      }

      final desiredTopics = <String>{
        if (session.role == AppRole.guard) 'guards',
        if (session.role == AppRole.fieldOfficer) 'field_officers',
        if (session.role == AppRole.guard &&
            (session.district ?? '').trim().isNotEmpty)
          _buildDistrictTopic('guard', session.district!.trim()),
        if (session.role == AppRole.fieldOfficer)
          ...session.assignedDistricts
              .where((district) => district.trim().isNotEmpty)
              .map((district) => _buildDistrictTopic('fieldOfficer', district)),
      };

      final topicsToUnsubscribe = _subscribedTopics.difference(desiredTopics);
      final topicsToSubscribe = desiredTopics.difference(_subscribedTopics);

      for (final topic in topicsToUnsubscribe) {
        await _fcm.unsubscribeFromTopic(topic);
      }
      for (final topic in topicsToSubscribe) {
        await _fcm.subscribeToTopic(topic);
      }

      _subscribedTopics
        ..clear()
        ..addAll(desiredTopics);
      _sessionRetryTimer?.cancel();
      _sessionRetryTimer = null;
    } catch (e) {
      debugPrint('FCM topic subscription error: $e');
    }
  }

  /// Re-subscribe to topic when role changes (e.g. after login).
  Future<void> refreshTopicSubscription() => _subscribeToRoleTopic();

  Future<void> clearTopicSubscriptions() async {
    _sessionRetryTimer?.cancel();
    _sessionRetryTimer = null;
    for (final topic in _subscribedTopics) {
      await _fcm.unsubscribeFromTopic(topic);
    }
    _subscribedTopics.clear();
  }

  // ── Foreground: show local notification ──────────────────────────────

  void _onForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'CISS Workforce';
    final body = message.notification?.body ?? '';

    _localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ciss_general',
          'CISS Notifications',
          channelDescription: 'General notifications from CISS Workforce',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  // ── Local notification tap ───────────────────────────────────────────

  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _navigateFromData(data);
    } catch (e) {
      debugPrint('Local notification payload parse error: $e');
    }
  }

  // ── FCM notification tap ─────────────────────────────────────────────

  void _handleMessageClick(RemoteMessage message) {
    _navigateFromData(message.data);
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return;

    final notifId = data['notifId'] as String?;
    if (notifId != null) {
      unawaited(markAsRead(notifId));
    }

    switch (type) {
      case 'attendance_reminder':
      case 'duty_assigned':
      case 'attendance_marked':
        _navigateGuard(1);
        break;
      case 'leave_status':
        _navigateGuard(2);
        break;
      case 'new_training':
      case 'training_assigned':
        _navigateGuard(3);
        break;
      case 'work_order':
        _navigateFieldOfficer(1);
        break;
      case 'report_review':
        _navigateFieldOfficer(2);
        break;
      case 'broadcast':
        _navigateHomeForCurrentRole();
        break;
      default:
        break;
    }
  }

  String _buildDistrictTopic(String role, String district) {
    final slug = district
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final prefix = role == 'guard' ? 'guards' : 'field_officers';
    return '${prefix}_district_$slug';
  }

  void _navigateGuard(int tabIndex) {
    _ref.read(guardTabIndexProvider.notifier).state = tabIndex;
    rootNavigatorKey.currentContext?.go('/');
  }

  void _navigateFieldOfficer(int tabIndex) {
    _ref.read(fieldOfficerTabIndexProvider.notifier).state = tabIndex;
    rootNavigatorKey.currentContext?.go('/');
  }

  void _navigateHomeForCurrentRole() {
    final session = _ref.read(authSessionProvider).value;
    if (session?.role == AppRole.fieldOfficer) {
      _navigateFieldOfficer(0);
      return;
    }
    _navigateGuard(0);
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  Future<void> markAsRead(String notifId) async {
    await _ref.read(mobileRepositoryProvider).markNotificationAsRead(notifId);
    _ref.invalidate(_notificationsSnapshotProvider);
    _ref.invalidate(unreadCountProvider);
  }

  Future<void> markAllAsRead() async {
    await _ref.read(mobileRepositoryProvider).markAllNotificationsAsRead();
    _ref.invalidate(_notificationsSnapshotProvider);
    _ref.invalidate(unreadCountProvider);
  }

  Future<void> triggerSystemNotification({
    required String type,
    required String title,
    required String body,
    required String role,
    String? district,
    Map<String, String>? data,
  }) async {
    await _ref.read(mobileRepositoryProvider).createSystemNotification(
          type: type,
          title: title,
          body: body,
          role: role,
          district: district,
          data: data,
        );
    _ref.invalidate(_notificationsSnapshotProvider);
    _ref.invalidate(unreadCountProvider);
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.messageId}');
}
