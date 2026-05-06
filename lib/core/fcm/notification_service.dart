import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
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

class NotificationService {
  NotificationService(this._ref);

  final Ref _ref;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Stream of notifications for UI badges
  static final unreadCountProvider = StreamProvider<int>((ref) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  });

  // Stream of all notifications for inbox
  static final notificationsProvider =
      StreamProvider<List<Map<String, dynamic>>>((ref) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  });

  Future<void> init() async {
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

      _fcm.onTokenRefresh.listen((String newToken) async {
        await _ref.read(mobileRepositoryProvider).updateFcmToken(newToken);
      });

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Foreground messages — show local notification
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Background/open messages
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageClick);

      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageClick(initialMessage);
      }
    }
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
    } catch (_) {}
  }

  // ── FCM notification tap ─────────────────────────────────────────────

  void _handleMessageClick(RemoteMessage message) {
    _navigateFromData(message.data);
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return;

    // Try to mark notification as read if notifId is present
    final notifId = data['notifId'] as String?;
    if (notifId != null) {
      FirebaseFirestore.instance
          .collection('notifications')
          .doc(notifId)
          .update({'read': true, 'readAt': FieldValue.serverTimestamp()});
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
        _navigateGuard(0);
        break;
      default:
        break;
    }
  }

  void _navigateGuard(int tabIndex) {
    _ref.read(guardTabIndexProvider.notifier).state = tabIndex;
    rootNavigatorKey.currentContext?.go('/');
  }

  void _navigateFieldOfficer(int tabIndex) {
    _ref.read(fieldOfficerTabIndexProvider.notifier).state = tabIndex;
    rootNavigatorKey.currentContext?.go('/');
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Mark a notification as read
  static Future<void> markAsRead(String notifId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notifId)
        .update({'read': true, 'readAt': FieldValue.serverTimestamp()});
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    final batch = FirebaseFirestore.instance.batch();
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Trigger a system notification (called from attendance screen, etc.)
  static Future<void> triggerSystemNotification({
    required String type,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.messageId}');
}
