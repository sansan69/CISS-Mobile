# MobileRepository Analysis

**File:** `/Users/mymac/Documents/CISS-Mobile/lib/core/network/mobile_repository.dart`
**Lines:** 1266 (23–1265 class body, 1 import, 1 trailing)

**Role:** Central data access layer for the mobile app. Wraps Dio HTTP calls and Firestore fallbacks behind ~60 public + ~20 private methods.

---

## 1. Code Duplication

### 1.1 Near-identical HTTP helpers (`_getJson` / `_postJson` / `_patchJson`)

Lines 152–220. All three share the same structure:
- Wrap a Dio call (`.get`/`.post`/`.patch`)
- Check `data is! Map` and throw same generic message
- Return `Map<String, dynamic>.from(data)`
- Catch: `_isOfflineDioError` → rethrow; otherwise `Exception(_extractApiError(error))`

The method is the **only** difference. This is a textbook candidate for a single `_request(String method, ...)` that branches on the verb, or a helper that accepts a Dio method function.

### 1.2 Sign-in method template (x3)

| Method | Lines | API | Role check |
|--------|-------|-----|------------|
| `signInGuard` | 642–671 | `dio.post` | `session.role != AppRole.guard` |
| `signInFieldOfficer` | 673–693 | `signInWithEmailAndPassword` | `session.role != AppRole.fieldOfficer` |
| `signInAdminOrClient` | 695–716 | `signInWithEmailAndPassword` | session is null OR neither admin/client |

All three: try API → `resolveCurrentSession()` → if wrong role → `signOut()` + `StateError` → catch and throw `Exception(_extractApiError(...))`. The `signOut` + re-auth guard is a single extracted helper.

### 1.3 List-parsing boilerplate (12+ occurrences)

Pattern repeated verbatim across methods like `fetchTrainingAssignments`, `fetchEvaluations`, `fetchPayslips`, `fetchGuardIncidents`, `fetchFieldOfficerWorkOrders`, `fetchVisitReports`, `fetchTrainingReports`, `fetchAttendanceHistory`, etc.:

```dart
final data = await _getJson('/api/...');
final items = data['<key>'] as List<dynamic>? ?? const <dynamic>[];
return items
    .whereType<Map<String, dynamic>>()
    .map(SomeModel.fromJson)
    .toList();
```

Minor variance: some use `.map((item) => ...)` with an inline conversion (e.g., `fetchFieldOfficerGuards`), some delegate to `.fromJson`. The cast-check-map-toList pipeline is repeated ~200 lines total.

### 1.4 Client endpoint trio (984–1013)
`fetchClientGuards`, `fetchClientAttendance`, `fetchClientWorkOrders` — three methods differing only in path suffix and response key name (`guards`/`attendance`/`workOrders`).

### 1.5 Admin endpoint trio (1021–1046)
`fetchAdminGuards`, `fetchAdminAttendance`, `fetchAdminWorkOrders` — same structure with hardcoded limits (300/250/250).

### 1.6 Fallback pattern (x5)
`updateFcmToken`, `fetchNotifications`, `fetchUnreadNotificationCount`, `markNotificationAsRead`, `markAllNotificationsAsRead` all follow: try API → catch → try Firestore-direct → catch. The notification variants have a no-op nested try/catch (see 2.1).

---

## 2. Error Handling Issues

### 2.1 Redundant nested try/catch in notification methods

**Lines 73–103** (`fetchNotifications` and `fetchUnreadNotificationCount`):
```dart
try {
  return _fetchNotificationsDirectly();
} catch (_) {
  rethrow;  // <-- pure no-op; the outer try/catch would propagate anyway
}
```
The inner `catch (_) { rethrow; }` does nothing — the error propagates straight through. Remove the inner try for clarity, or add a meaningful fallback.

### 2.2 Original error type destroyed

`_getJson` / `_postJson` / `_patchJson` (lines 152–220) catch all errors and rethrow as `Exception(_extractApiError(error))`. This **strips the original type**. A caller who wants to handle `DioException` (e.g., for connectivity-specific retry) or `StateError` (auth failure) cannot distinguish them from parsing errors. The only exception: `_isOfflineDioError` errors are rethrown as-is (before the wrap).

### 2.3 500+ treated as "offline/queueable" but never retried

`_isOfflineDioError` (line 234–235) returns `true` for `badResponse` with status ≥ 500. The comment says "queue for retry rather than dropping the data" — but **no queue or retry mechanism exists**. These errors simply propagate like any other. The classification has no behavioral effect.

### 2.4 `DioExceptionType.unknown` treated as offline

**Line 244:** `DioExceptionType.unknown` is a catch-all — it includes SSL errors, response parse failures, or any unexpected error. Treating ALL of them as "offline" can silently route permanent failures into the same path as transient connectivity issues.

### 2.5 Direct Dio callers skip error classification

`resetGuardPin`, `checkGuardPinStatus`, `setupGuardPin`, `signInGuard`, `uploadAttendancePhoto`, `uploadReportPhoto` call `_apiClient.dio.post` directly (not `_postJson`). Their catch blocks use `_extractApiError` but **never call `_isOfflineDioError`**. Offline errors on these endpoints get wrapped in a generic `Exception` instead of propagating as `DioException`.

### 2.6 `createSystemNotification` has no error handling

**Lines 133–150.** Unlike every other public method, this one has zero try/catch. If `_postJson` throws, the raw `Exception` propagates to the caller unmodified. (May be intentional, but breaks the file's convention.)

### 2.7 `_authHeaders()` produces a poor user-facing message on failure

**Lines 247–253.** When `token` is null, it throws `StateError('Not authenticated')`. `_extractApiError` doesn't handle `StateError`, so it falls through to `error.toString().replaceFirst('Exception: ', '')`, yielding `"Bad state: Not authenticated"`. A `FirebaseAuthException` with code `'not-authenticated'` would give a friendlier message.

### 2.8 `uploadAttendancePhoto` and `uploadReportPhoto` have no error handling at all

**Lines 835–878.** If `_apiClient.dio.post` throws, the raw `DioException` propagates to the caller. Unlike every other direct-Dio method, there's no try/catch around these calls.

### 2.9 `_extractApiError` overly broad fallback

**Line 437:** `error.toString().replaceFirst('Exception: ', '')`. This handles `FirebaseAuthException` and `DioException` explicitly, but any other error type (e.g., `SocketException`, `TimeoutException`, `FormatException`, `TypeError`) gets its full `toString()` output with the type prefix intact.

### 2.10 `_markNotificationAsReadDirectly` silently skips on ownership mismatch

**Line 493:** If `data['recipientUid'] != user.uid`, returns `false` — the caller gets a silent false, no indication of *why* it failed (wrong user, doesn't exist, or server error). Contrast with `_markAllNotificationsAsReadDirectly` which returns `true` even when it skips already-read notifications.

---

## 3. Inconsistent Patterns

### 3.1 Mixed use of helpers vs direct Dio

~20 methods use `_getJson`/`_postJson`/`_patchJson` (response validation + consistent error handling). 7 methods use `_apiClient.dio.*` directly and miss response format validation and/or error classification:
- `resetGuardPin`, `checkGuardPinStatus`, `setupGuardPin`, `signInGuard` — no auth headers (public endpoints, intentional) but also no response `Map` check.
- `uploadAttendancePhoto` — no auth, no error handling.
- `uploadReportPhoto` — has auth headers (line 875), no error handling.

### 3.2 `postGeneric` is a naked public alias

**Lines 173–178.** This is the only public method that directly exposes the raw JSON helper. All other public methods wrap it in domain meaning. Either callers should also have domain methods, or this should be removed in favor of direct `_postJson` usage.

### 3.3 Two different notification "mark read" fallback behaviors

| Method | Ownership/read check | Return on skip |
|--------|---------------------|----------------|
| `_markNotificationAsReadDirectly` | Checks `recipientUid != user.uid` → returns false | `false` |
| `_markAllNotificationsAsReadDirectly` | Checks `doc.data()['read'] == true` → skips | `true` (batch may be empty) |

`_markNotificationAsReadDirectly` returns `false` on mismatch, causing `markNotificationAsRead` to `rethrow`. But `_markAllNotificationsAsReadDirectly` always returns `true` even if it skipped every document because they were already read. Callers get different signals for the same category of operation.

### 3.4 Error message casing

`_extractFirebaseAuthError` returns user-facing messages (e.g., "Invalid email or password."). `_extractApiError` for `DioException` returns the server's `error`/`message` field verbatim which may have arbitrary casing. No normalization applied.

### 3.5 Guard PIN identity detection could misclassify

`_guardIdentityPayload` (lines 589–599) uses `RegExp(r'^\d{8,15}$')` to decide if input is a phone number vs employee ID. Any employee ID that happens to be 8–15 digits is misclassified as a phone number. Whether this matters depends on whether employee IDs can contain only digits.

---

## 4. Missing Timeout / Retry

### 4.1 No per-call timeouts anywhere

Every Dio call relies on the `_apiClient` default timeout. No call sets `sendTimeout`, `receiveTimeout`, or `connectTimeout` on `Options`. For potentially slow operations (photo upload, large lists, `Future.wait` combining two calls), a hung server hangs the UI.

### 4.2 No retry mechanism

`_isOfflineDioError` labels 500+ and connection errors as "queueable for retry" (comments on lines 231–232, 236). But **no retry logic exists anywhere** in this class. The classification is aspirational code — it never materializes into actual retry behavior.

### 4.3 Firestore fallbacks have no timeout

`_fetchNotificationsDirectly` (line 474), `_markNotificationAsReadDirectly` (line 491), `_markAllNotificationsAsReadDirectly` (line 515) call Firestore `.get()` / `.commit()` with no timeout wrapper. A stalled Firestore connection blocks indefinitely.

### 4.4 `fetchFieldOfficerReportHistory` has no timeout on `Future.wait`

**Line 1233:** `Future.wait<dynamic>([...])`. If either request hangs (e.g., a backend that never responds), the entire method hangs. No `Future.any` with a timeout, no per-request timeout.

---

## 5. Bugs and Logic Errors

### 5.1 Token is force-refreshed on every request

**Line 36:** `_auth.currentUser?.getIdToken(false)`. The `false` parameter means "force refresh" — Firebase must fetch a fresh token from the server each time, bypassing its local cache. Every authenticated API call incurs a network round-trip just for the token, not just for the data. Should be `true` (prefer cache) or omitted (defaults to `true`).

### 5.2 `fetchNotifications` / `fetchUnreadNotificationCount` fallback rethrow achieves nothing

Per 2.1 above — the nested `catch (_) { rethrow; }` is a no-op. Same semantic as no catch at all. The inner try block provides no meaningful fallback over the outer one.

### 5.3 `_buildSessionFromClaims` missing explicit catch-all

Lines 286–348: Returns for `AppRole.guard`, `AppRole.client`, `AppRole.admin` — then line 334 returns a generic session for any other role (presumably `fieldOfficer`). This works, but if a new role is added to the enum and not handled, it silently uses the generic template (which includes `assignedDistricts` and `stateCode` fields not set for other roles). No compiler warning because there's no `default` or `else`.

### 5.4 `setupGuardPin` destroys the original error

**Lines 621–640:** Calls `_apiClient.dio.post` directly and wraps any error in `Exception(_extractApiError(error))`. No `_isOfflineDioError` check — offline errors get bundled into the generic message instead of being distinguishable.

### 5.5 `fetchGuardDashboard` redundant casts

Lines 743–763: Each `attendanceStats` field access casts `data['attendanceStats']` to `Map<String, dynamic>` twice — once in the `is num` guard and again in the truth expression. The same `Map` is re-cast on every access (6 casts for 3 fields). A local variable like `final stats = data['attendanceStats'] as Map<String, dynamic>?;` would be cleaner and slightly faster.

### 5.6 `fetchFieldOfficerGuardAttendance` silently accepts unknown response shapes

**Lines 1191–1194:** Checks four possible keys (`attendance`, `records`, `logs`, `data`). If the backend changes the response key to something else, this method silently returns an empty list with no warning. No log, no error.

### 5.7 `_resolveGuardSessionFromProfile` silently fails on API error

**Lines 384–403:** `fetchGuardProfile()` can throw. The catch swallows it with a `debugPrint` and returns `null`. This means a transient profile fetch failure causes `resolveCurrentSession` to silently skip the guard-session path, potentially building a session from claims instead with less complete data.

### 5.8 `_parseLeaveBalance` only considers casual leave

**Lines 1245–1260:** Only reads `casual.balance` (or falls back to `earned.balance` if casual is missing). If both are present, `earned` is completely ignored. The comment on line 1249 documents this as intentional ("We only need one summary card"), but semantically the return type `LeaveBalanceModel` implies total leave, not casual-only.

---

## Summary

| Category | Count | Most impactful |
|----------|-------|----------------|
| Duplication | ~6 patterns | HTTP helpers (DRY); list-parsing boilerplate |
| Error handling | ~10 issues | Stripped error types; redundant catch; missing classification in direct-Dio callers; no error handling on upload methods |
| Inconsistencies | ~5 items | Mixed helper vs direct-Dio; fallback behavioral asymmetry; `postGeneric` leak |
| Missing timeout/retry | ~4 gaps | No retry despite "queueable" classification; no per-call timeouts; Firestore + `Future.wait` unprotected |
| Bugs | ~8 items | Force-refreshed tokens on every call (performance bug); redundant catch no-ops; silent fallback on profile fetch |
