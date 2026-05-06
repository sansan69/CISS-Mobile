# Push Notification & Broadcast System — Design Spec

**Date:** 2026-05-06
**Status:** Implement Now

## Overview

End-to-end push notification system with admin broadcast panel.

## Notification Types

| Type | Trigger | Recipients | Data |
|---|---|---|---|
| `work_order` | New work order assigned | Guards on that WO | WO ID, site, date |
| `attendance_marked` | Guard marks IN/OUT | Field Officer (district) | Guard name, site, status |
| `leave_approved` | Admin approves leave | Guard | Leave dates |
| `training_assigned` | New training assigned | Guard | Training ID, title |
| `broadcast` | Admin sends from panel | Selected audience | Title, body, link |
| `report_review` | FO submits visit/training report | Admin | Report type, site |

## Architecture

```
Admin Panel (Next.js) ──POST──▶ /api/admin/notifications/send
                                      │
                                      ▼
                              Firebase Admin SDK
                              ┌──────────────────┐
                              │ 1. Save to        │
                              │ Firestore         │
                              │ notifications/    │
                              │ 2. Send via FCM   │
                              └──────┬───────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    ▼                ▼                ▼
              Guard Device    FO Device        Admin Browser
              (FCM push)     (FCM push)      (Firestore stream)
              ↓ show local   ↓ show local    ↓ real-time update
              notification   notification    in notification bell
```

## Files to Create/Modify

### Next.js Web App
| File | Change |
|---|---|
| `src/app/api/admin/notifications/send/route.ts` | New: send notification API |
| `src/app/(app)/admin/notifications/page.tsx` | New: broadcast panel |
| `src/types/notification.ts` | New: Notification type |

### Flutter Mobile App  
| File | Change |
|---|---|
| `lib/core/fcm/notification_service.dart` | Enhance: foreground display, inbox support |
| `lib/features/shared/notification_inbox_screen.dart` | New: notification history |
| `lib/features/guard/presentation/guard_shell.dart` | Add notification bell badge |
| `lib/features/field_officer/presentation/field_officer_shell.dart` | Add notification bell badge |
| `lib/features/guard/presentation/screens/guard_attendance_screen.dart` | Trigger attendance notification |
| `lib/features/attendance_qr/qr_attendance_flow.dart` | Trigger attendance notification |
| `pubspec.yaml` | +`flutter_local_notifications` |
