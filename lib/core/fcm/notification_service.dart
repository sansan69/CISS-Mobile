import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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

  Future<void> init() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('User granted permission');
      }

      final token = await _fcm.getToken();
      if (token != null) {
        await _ref.read(mobileRepositoryProvider).updateFcmToken(token);
      }

      // Handle token refreshes
      _fcm.onTokenRefresh.listen((String newToken) async {
        await _ref.read(mobileRepositoryProvider).updateFcmToken(newToken);
      });

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Got a message whilst in the foreground!');
          print('Message data: ${message.data}');
        }
        // In foreground, we might show a snackbar or local notification
      });

      // Handle message clicks when app is in background but opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageClick);

      // Check if the app was opened from a terminated state via a notification
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageClick(initialMessage);
      }
    }
  }

  void _handleMessageClick(RemoteMessage message) {
    if (kDebugMode) {
      print('Notification clicked: ${message.data}');
    }

    final type = message.data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'attendance_reminder':
      case 'duty_assigned':
        _navigateGuard(1); // Attendance tab
        break;
      case 'leave_status':
        _navigateGuard(2); // Leave tab
        break;
      case 'new_training':
        _navigateGuard(3); // Training tab
        break;
      case 'work_order':
        _navigateFieldOfficer(1); // Work Orders tab
        break;
      case 'report_review':
        _navigateFieldOfficer(2); // Reports tab
        break;
      default:
        // Default to dashboard
        break;
    }
  }

  void _navigateGuard(int tabIndex) {
    _ref.read(guardTabIndexProvider.notifier).state = tabIndex;
    rootNavigatorKey.currentContext?.go('/guard');
  }

  void _navigateFieldOfficer(int tabIndex) {
    _ref.read(fieldOfficerTabIndexProvider.notifier).state = tabIndex;
    rootNavigatorKey.currentContext?.go('/field-officer');
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling a background message: ${message.messageId}');
  }
}
