# Backend and Firebase connection audit

**Original label:** 16 October 2026. **Deployment correction verified:** 15 October 2026, 23:00 IST. **Scope:** every Firebase and HTTP dependency the mobile app uses, checked against the live project (`ciss-workforce`) and the deployed backend (`https://cisskerala.site`).

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

## 2. Firestore read issues and current resolution

Firestore evaluates a *list* rule against the query, not against the documents returned, so a rule that references `resource.data` can only authorise a query that names the value itself.

### 2.1 Live locations — fixed in the app

`guardLocations` authorises a field officer with `resource.data.district in token.assignedDistricts`. `LiveLocationService.streamActiveLocations()` queried `where status == 'In'` with no district, so the read was refused outright: the field-officer live map and the live dots on the attendance feed had nothing to show. The sibling web dashboard already scopes the same query by district (`src/components/dashboard/live-guards-section.tsx`), which is the intended contract.

Fixed: `streamActiveLocations`/`fetchActiveLocations` now take the officer's districts, use `==` for one district and `in` for several (capped at Firestore's 30), and log the attempted scope when a read is refused. Both call sites pass `authSession.assignedDistricts`. Covered by `test/live_location_scope_test.dart`.

### 2.2 Guard day-timeline breadcrumbs — rules fix deployed

The deployed rules now use `officerOwnsGuardLocation(employeeId)`, which resolves the district from the parent `guardLocations` document. Fresh read-only comparison found deployed Firestore and Storage rules equal to the reviewed sibling worktree at `1ce4b100`. All 137 declared composite indexes match the deployed index signatures, and all 137 are `READY`.

The earlier statement that neither breadcrumb fix had been applied is superseded. Seven guard-location emulator checks pass, including parent lookup and district-scoped live-location reads. An end-to-end breadcrumb **list** query remains unverified because the local emulator hangs on subcollection list requests even with rules bypassed; a static assertion protects the helper's use. An authenticated production list/phone walkthrough is still needed.

## 3. Mobile endpoints — deployed route inventory corrected

The earlier missing-route list is superseded by the deployment at web/backend commit `1ce4b100`. Fresh unauthenticated GET probes of all 56 literal mobile API paths returned 34 × 401, 20 × 405, 1 × 400 and 1 × 200, with no 404, 5xx or network errors. Guard duties, willingness, field-officer assignments and leaderboard are present. A write-only route answering 405 to GET confirms route presence, not successful authenticated behavior.

Evidence: `/tmp/ciss-astra-audit-api-probes.json`. This check does not submit attendance, change willingness, assign guards, or verify authenticated production responses. The separate `/api/client/attendance` endpoint still returns HTTP 500 for a missing bearer token; that pre-existing auth-error mapping issue is recorded in the full-stack audit.

See `2026-10-15-astra-full-stack-audit.md` for the new cross-contract and concurrency findings. Deployment availability alone does not close those defects.

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
