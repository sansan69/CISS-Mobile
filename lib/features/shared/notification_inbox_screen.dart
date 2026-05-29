import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/fcm/providers.dart';
import '../../../core/fcm/notification_service.dart';

class NotificationInboxScreen extends ConsumerWidget {
  const NotificationInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final notifsAsync = ref.watch(NotificationService.notificationsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: tokens.canvas,
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(notificationServiceProvider).markAllAsRead(),
            child: Text('Mark all read',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
      body: notifsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notifs) {
          if (notifs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded,
                      size: 64, color: tokens.inkMuted),
                  const SizedBox(height: 16),
                  Text('No notifications',
                      style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifs.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: tokens.border),
            itemBuilder: (_, i) {
              final n = notifs[i];
              final isRead = n['read'] == true;
              final createdAtRaw = n['createdAt'] as String?;
              final createdAt = createdAtRaw != null
                  ? DateTime.tryParse(createdAtRaw)
                  : null;
              final type = (n['type'] as String?) ?? 'broadcast';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _colorForType(type, tokens).withValues(alpha: 0.1),
                  child: Icon(_iconForType(type),
                      color: _colorForType(type, tokens), size: 20),
                ),
                title: Text(
                  n['title'] as String? ?? '',
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n['body'] as String? ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (createdAt != null)
                      Text(
                        _formatTime(createdAt),
                        style: TextStyle(
                            fontSize: 11, color: tokens.inkMuted),
                      ),
                  ],
                ),
                trailing: !isRead
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: tokens.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
                onTap: () {
                  if (!isRead) {
                    ref
                        .read(notificationServiceProvider)
                        .markAsRead(n['id'] as String);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Color _colorForType(String type, CissThemeTokens tokens) {
    return switch (type) {
      'work_order' => tokens.accent,
      'attendance_marked' => tokens.success,
      'leave_approved' => tokens.primary,
      'training_assigned' => tokens.warning,
      'broadcast' => tokens.primary,
      'report_review' => tokens.accent,
      _ => tokens.inkMuted,
    };
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'work_order' => Icons.assignment_rounded,
      'attendance_marked' => Icons.fact_check_rounded,
      'leave_approved' => Icons.event_available_rounded,
      'training_assigned' => Icons.school_rounded,
      'broadcast' => Icons.campaign_rounded,
      'report_review' => Icons.edit_note_rounded,
      _ => Icons.notifications_rounded,
    };
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('dd MMM').format(dt);
  }
}
