# Meaningful Error Messages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace technical error strings (e.g., "DioException") with user-friendly, actionable messages across the Guard and Field Officer portals.

**Architecture:** 
- Centralize error mapping logic in a new `CissError` utility.
- Map Dio exceptions and specific backend response codes to meaningful Malayalam/English context-aware messages.
- Update UI helper functions (`guardErrorMessage`) to use this new utility.

**Tech Stack:** Dart, Flutter, Dio

---

### Task 1: Centralized Error Mapping Utility

**Files:**
- Create: `lib/core/network/ciss_error.dart`

- [ ] **Step 1: Create the `CissError` utility**
Implement a utility that parses `Object error` and returns a human-friendly string.

```dart
import 'package:dio/dio.dart';

class CissError {
  static String parse(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Network timeout. Please check your internet connection.';
        case DioExceptionType.connectionError:
          return 'No internet connection. Please turn on Wi-Fi or Mobile Data.';
        case DioExceptionType.badResponse:
          final status = error.response?.statusCode;
          final data = error.response?.data;
          
          if (status == 401) return 'Session expired. Please login again.';
          if (status == 403) return 'Access denied. You do not have permission for this action.';
          if (status == 404) return 'Requested information not found.';
          if (status == 500) return 'Server error. Our team is looking into it.';
          
          // Handle specific backend error messages if available
          if (data is Map && data.containsKey('message')) {
            final msg = data['message'].toString();
            if (msg.toLowerCase().contains('invalid attendance')) {
              return 'Invalid attendance. Please ensure you are at the correct site.';
            }
            return msg;
          }
          return 'Something went wrong (Error $status).';
        default:
          return 'Unexpected network error. Please try again.';
      }
    }
    
    final str = error.toString().toLowerCase();
    if (str.contains('location permission')) return 'Location permission denied. Please enable it in settings.';
    if (str.contains('camera')) return 'Camera access is required. Please check your permissions.';
    
    return error.toString().replaceFirst('Exception: ', '').trim();
  }
}
```

- [ ] **Step 2: Update `guardErrorMessage` in `lib/features/guard/presentation/widgets/guard_portal_widgets.dart`**
Replace the raw `toString()` logic with `CissError.parse(error)`.

- [ ] **Step 3: Commit**
```bash
git add lib/core/network/ciss_error.dart lib/features/guard/presentation/widgets/guard_portal_widgets.dart
git commit -m "feat: centralize user-friendly error mapping"
```

---

### Task 2: Update Field Officer Error UI

**Files:**
- Modify: `lib/features/field_officer/presentation/screens/field_officer_dashboard_screen.dart`
- Modify: `lib/features/field_officer/presentation/screens/field_officer_reports_screen.dart`
- Modify: `lib/features/field_officer/presentation/screens/field_officer_attendance_screen.dart`

- [ ] **Step 1: Update Dashboard error messages**
Replace `error.toString()` with `CissError.parse(error)` in the `when(error: ...)` blocks.

- [ ] **Step 2: Update Reports and Attendance screens**
Apply the same change to the `error` state displays.

- [ ] **Step 3: Commit**
```bash
git add lib/features/field_officer/presentation/screens/*.dart
git commit -m "feat: use meaningful error messages in field officer portal"
```

---

### Task 3: Update Auth and Guard Screens

**Files:**
- Modify: `lib/features/auth/presentation/role_login_screen.dart`
- Modify: `lib/features/guard/presentation/screens/guard_attendance_screen.dart`
- Modify: `lib/features/guard/presentation/screens/guard_incidents_screen.dart`

- [ ] **Step 1: Update Login error handling**
Ensure login failures show meaningful messages (e.g., "Check your credentials" instead of "401 Unauthorized").

- [ ] **Step 2: Update Guard Attendance error handling**
Ensure attendance submission errors use `CissError.parse`.

- [ ] **Step 3: Commit**
```bash
git add lib/features/auth/presentation/role_login_screen.dart lib/features/guard/presentation/screens/*.dart
git commit -m "feat: use meaningful error messages in guard portal and login"
```
