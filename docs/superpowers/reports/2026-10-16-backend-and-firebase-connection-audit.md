# Backend and Firebase connection audit

**Date:** 16 October 2026. **Scope:** every Firebase and HTTP dependency the mobile app uses, checked against the live project (`ciss-workforce`) and the deployed backend (`https://cisskerala.site`).

**Method.** Firebase: the Firebase MCP read the active project, its registered apps and the *deployed* Firestore rules; the deployed rules are byte-identical to `firestore.rules` in the sibling web/backend checkout, so that file is the source of truth. HTTP: every `/api/...` literal in `lib/**` (56 paths, interpolations replaced with a probe value) was requested once with GET and, where a route is write-only, once with POST and an empty body. A 401/405/400 means the route exists and refused an unauthenticated request; 404 means the route is absent. Trailing-slash variants answer 308 to the canonical path, so they were ruled out as an artefact.

## 1. Firebase wiring — correct

| Check | Result |
| --- | --- |
| Project | `ciss-workforce` (active) matches `lib/firebase_options.dart` |
| Android app | `1:1041149201339:android:7b26e030f9400f1f5b929e`, namespace `co.in.ciss.ciss_mobile` = `applicationId` in `android/app/build.gradle.kts` |
| `google-services.json` | contains our package and app id |
| iOS | bundle `co.in.ciss.cissMobile` present in the project |
| Storage bucket | `ciss-workforce.firebasestorage.app` matches the option file and the file `storage_bucket` |
| Deployed Firestore rules | identical to the repo file |
| Indexes for the app's queries | present for `guardLocations` (`status`; `status+district`; `status+district+clientName`; `status+clientName`) and `notifications` (`recipientUid+createdAt`) |
| Region bootstrap | `/api/public/regions` returns Kerala only (`apiUrl` = the deployed origin), `/api/public/region-config/KL` 200, `/api/public/attendance` 200 |

The app's other Firebase paths are rule-compatible: `fcmTokens/{uid}_mobile` writes only the allow-listed keys under an id matching `uid + '_.*'`; the fallback `notifications` read is provably scoped by `recipientUid == uid` and its update touches only `read`/`readAt`; attendance photos go through server routes (`/api/public/attendance/upload-token` then `/api/public/attendance/upload`), so Storage rules do not gate them; field-officer report photos write to `foReports/{folder}/{uid}/...`, which the Storage rule allows for a field officer.

## 2. Firestore reads that the rules refuse

Firestore evaluates a *list* rule against the query, not against the documents returned, so a rule that references `resource.data` can only authorise a query that names the value itself.

### 2.1 Live locations — fixed in the app

`guardLocations` authorises a field officer with `resource.data.district in token.assignedDistricts`. `LiveLocationService.streamActiveLocations()` queried `where status == 'In'` with no district, so the read was refused outright: the field-officer live map and the live dots on the attendance feed had nothing to show. The sibling web dashboard already scopes the same query by district (`src/components/dashboard/live-guards-section.tsx`), which is the intended contract.

Fixed: `streamActiveLocations`/`fetchActiveLocations` now take the officer's districts, use `==` for one district and `in` for several (capped at Firestore's 30), and log the attempted scope when a read is refused. Both call sites pass `authSession.assignedDistricts`. Covered by `test/live_location_scope_test.dart`.

### 2.2 Guard day-timeline breadcrumbs — needs a backend decision

`guardLocations/{id}/locationHistory` has the same shape of rule
(`resource.data.district in token.assignedDistricts`), and the officer's timeline reads a date range with an `orderBy`, which can never be authorised from a field on the history document. Two ways to close it; neither is applied yet, because both are production changes to the shared project:

**Option A — rules (recommended).** Read the district from the parent document, which makes the condition document-independent and therefore provable for a list query:

```javascript
function officerOwnsGuardLocation(employeeId) {
  return isFieldOfficer() &&
    request.auth.token.assignedDistricts != null &&
    get(/databases/$(database)/documents/guardLocations/$(employeeId))
      .data.district in request.auth.token.assignedDistricts;
}

match /guardLocations/{employeeId} {
  match /locationHistory/{historyId} {
    allow read: if readStateMatches() && (isAdmin() || isHR() || isAccounts() || isCompliance() ||
      officerOwnsGuardLocation(employeeId) ||
      (isClientUser() && clientUserClientName() != null &&
        resource.data.clientName == clientUserClientName()));
  }
}
```

Cost: one extra document read per request. No client change, no new index, and the client branch keeps working.

**Option B — client filter plus an index.** Add `where('district','==',district)` to `_loadHistory` (the screen already loads the parent document, which carries `district`) and add `locationHistory (district ASC, recordedAt ASC)` to `firestore.indexes.json`. This needs an index deploy instead of a rules deploy.

Until one lands, the timeline now distinguishes the two cases in the UI: a refused read shows "Movement history could not be loaded" instead of claiming the guard recorded no movement.

## 3. Mobile endpoints the deployed backend does not implement

404 on the live backend for every method, with no trailing-slash variant:

| Endpoint | Called by | Model parsed |
| --- | --- | --- |
| `GET /api/guard/duties` | guard Duties tab (`fetchGuardDuties`) | `{duties: [...GuardDuty]}` |
| `POST /api/guard/duties/{workOrderId}/willingness` | guard duty response, incl. the offline willingness queue | `{success, willingness, version, respondedAt, replayed}` |
| `POST /api/field-officer/work-orders/{id}/willingness` | FO work-order willingness sheet (a primary FO destination) | same receipt |
| `GET /api/field-officer/assignments` (+ `/{id}`) | FO assignments screen, opened from the work orders screen | `{assignments: [...GuardAssignment]}` |
| `GET /api/guard/leaderboard` | guard training leaderboard | *exists in the backend repo, not deployed* — deployment lag, not missing code |

Field contract the mobile already parses for a duty (`lib/core/models/duty_models.dart`): `id, kind, status, workOrderId, siteId, siteName, clientName, district, date, startsAt, endsAt, respondBy, shiftLabel, examName, examCode, canRespond, willingnessVersion, willingness, maleGuardsRequired, femaleGuardsRequired, willingCount, unavailableCount, ineligibilityReason`. The willingness body the app sends is `{response, clientRequestId, expectedVersion}`.

A 404 is not treated as retryable (`CissError.isRetryableNetworkError` rejects 4xx), so a queued willingness response is kept and reported as "Response not sent: …" rather than retried forever.

**Not implemented here on purpose.** These routes live in the sibling web/backend project, are part of the cross-repo duties stream, and take effect only after a deployment; the mobile half is already correct and waiting.

## 4. Re-running this audit

```bash
# every API path the mobile calls, probed against the deployed backend
python3 - <<'PY' > /tmp/mobile_paths.txt
import re, glob
paths=set()
for f in glob.glob('lib/**/*.dart', recursive=True):
    s=open(f).read()
    for m in re.finditer(r"'/api/[^'\n]*'", s):
        raw=re.sub(r"\$\{[^}]*\}", "probe1", m.group(0)[1:-1])
        paths.add(raw.split('?')[0].rstrip('/'))
for p in sorted(paths): print(p)
PY
while read -r p; do
  echo "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://cisskerala.site$p") $p"
done < /tmp/mobile_paths.txt | sort
```

401/405/400/200 are healthy; 404 is a missing route.
