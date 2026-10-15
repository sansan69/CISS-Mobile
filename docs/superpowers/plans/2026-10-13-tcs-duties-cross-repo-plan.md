# TCS Classification, Willingness and Duty Assignment Implementation Plan

> **Current workflow (user update 2026-10-15):** Follow `AGENTS.md`. Continue the approved plan with GPT-6 Luna low for simple fixes or medium for moderate implementation. Routine planning uses Luna low; complex new plans use Astra. Default reviews use DeepSeek V4.1 Flash at high; complex reviews use separate GPT-6.1 Sol at medium. If DeepSeek is unavailable/unreliable, disclose and use the pre-authorized Luna medium/high review fallback. Use compact targeted handoffs and avoid rerunning unchanged passing checks. Historical model references in reports and steps are superseded by this workflow. Do not commit, push, merge, deploy, or change live data.


**Goal:** Deliver local web/backend and mobile changes for TCS classification, district exam willingness, and informational regular/relieving assignments, without changing attendance eligibility.

**Architecture:** Keep `workOrders` as the sole exam-demand and exam-roster authority. Add server-owned willingness records keyed by work order and employee document, and separate per-shift `guardAssignments` for ordinary scheduled duties; the guard API combines these sources into one safe feed. All writes derive identity and scope on the server, while mobile queues only willingness with account/region binding and explicit reconciliation.

**Tech Stack:** Existing Next.js 15/TypeScript/Firebase Admin/Vitest; Flutter/Riverpod/Dio/Hive/Firebase Messaging. Reuse existing notification inbox and token registration, district utilities, linked-profile authorization and site shift templates. No new application frameworks.

**Spec:** `docs/superpowers/specs/2026-10-13-ciss-mobile-2026-redesign-and-tcs-willingness-design.md`, §8 and relevant §6/§9. This plan resolves its stale open-default text using the user's explicit **Adhoc by default** choice and explicit authorization to include **mobile and local web/backend code changes**.

## Global Constraints

- Backend worktree: `/Users/mymac/.codex/worktrees/redesign-continuation/CISS`, based on `cad17132`; mobile: `/Users/mymac/.codex/worktrees/redesign-continuation/CISS-Mobile`. Preserve unrelated files and changes. Root agent coordinates the existing mobile foundation work before editing overlapping files.
- No commits, pushes, merges, deployments, live reads/writes, imports, production notifications, or credential copying. Local fixtures/mocks only. User authorization overrides skills' routine commit steps.
- New TCS enrollments are `adhoc`; only admin/superAdmin curate `permanent`. Legacy missing/invalid category is **unclassified**, never silently converted on read. Non-TCS records have no effective TCS category.
- Willingness is declare-only; any number of eligible guards may respond. It neither reserves nor caps capacity and never automatically assigns. The user explicitly chose **“Close responses when the duty day starts”**: willing/unavailable can change only before midnight at the start of the canonical duty date in `Asia/Kolkata`.
- Center means existing `sites` document. FO scope comes from the active linked profile, not stale claims. Admin/superAdmin may assign. Assignment is informational; never add assignment/willingness reads or checks to attendance authorization, GPS, QR, shift selection, or submission.
- Preserve navy/gold, bundled Inter, existing primitives, one primary action and maximum three above-fold content blocks. Guard remains personal and sparse; FO remains district-oriented.
- `workOrders.assignedGuards[].uid` is an **employee document ID**, despite the name. Firebase Auth UID is `employees.guardAuthUid`. Do not interchange them or use human `employeeId` (which contains slashes) as a document path.
- Local rules/index changes are deliverables, not deployed configuration. Root appends a local-only work-log/knowledge-base note per backend AGENTS after the complete task.

## Review Focus

1. A queued response from user A/region A must never replay as user B/region B; expired eligibility or cancelled work order must become a visible rejected response, not an endless retry (Task 5).
2. Site district changed after import, mixed-case district aliases, deleted/disabled FO profile and forged employee IDs must fail closed without leaking another district's roster (Tasks 2–3).
3. A timeout after a successful write, rapid offline willing→unavailable, concurrent supervisors and repeated notification dispatch must not roll back newer state or duplicate inbox events (Tasks 2–5).
4. Today near IST midnight, missing exam start time, overnight site shifts and a superseded exam row must produce an accurate cutoff/feed and not invent a shift (Tasks 2–3).
5. Guards with no assignment, a relieving assignment at another site, unknown category or declined willingness must retain the existing attendance flow unchanged (Tasks 3, 6–7).

## Grounded existing behavior and scope decisions

- `src/app/api/field-officer/work-orders/route.ts` reads upcoming active TCS orders, resolves district/site metadata from `sites` first, and verifies linked active FOs. The existing assignment PATCH in `src/app/api/admin/work-orders/[id]/route.ts` uses weaker claims fallback and row district; repair those gates when integrating willingness. Its existing same-date exam conflict policy and canonical roster behavior remain intact.
- Existing guard profile already returns gender. Mobile already has a preliminary `GuardDuty`, `/api/guard/duties` repository read, and willingness POST call; complete these rather than add competing interfaces.
- Public and staff enrollment both call `/api/employees/enroll`. Employee detail currently edits general fields directly in Firestore. Add a separate category control backed by a narrow admin route; do not rewrite the general editor.
- `src/lib/notifications.ts` is in-app-only. Actual FCM exists in `/api/admin/notifications/send`; token records use `fcmTokens/{uid}` for web and `{uid}_mobile` for mobile with a `uid` field. New duty delivery must use those tokens and the current inbox; do not use broad guard topics for personal assignments.
- `OfflineQueue` currently has no owner/origin and evicts its oldest item at 100; `SyncService` retries every error. Add isolated willingness behavior so it never evicts attendance or changes generic attendance retry semantics.
- Exam rows generally have a date, not a dependable start time/shift. Display **“Shift to be confirmed”** when absent. Cutoff is always the beginning of the duty date in `Asia/Kolkata`, regardless of any known exam shift start. API returns `respondBy`; a queued response arriving at or after it is rejected even if captured earlier. For duty date `2026-10-14`, accept through `2026-10-13T18:29:59.999Z` and reject at `2026-10-13T18:30:00.000Z`.
- Ordinary assignment shifts use site templates when configured. For a site without templates, FO/admin must enter a label and start/end times, including next-day end when overnight; the server validates them. Never silently assume day shift or mutate the site's configuration.

## Frozen cross-repository contract

### Classification

`tcsCategory: "adhoc" | "permanent" | null` in authenticated profile/list DTOs. Persist only the two valid strings on TCS employees. Public enrollment ignores or rejects a supplied permanent category and writes `adhoc` based on the **canonical resolved client**, not browser input. Staff enrollment has the same default; curation happens through `PATCH /api/admin/employees/{employeeDocId}/tcs-category` body `{tcsCategory}`. The route requires admin, existing TCS employee and enum validation, and records server audit fields. Unclassified guards see a neutral “Category not set” badge and cannot send willingness until classified; permanent/non-TCS guards can still read their assignments.

### Guard feed and willingness

`GET /api/guard/duties` → `{duties: GuardDutyDto[]}` with private/no-store caching. Feed defaults to today through 90 days ahead (IST), ordered by date then stable ID; return all scoped matches in that window without silently truncating. Load bounded date queries with internal paging where needed. Today’s already-started rows can remain read-only. Own cancelled assignments from today onward remain visible with cancellation status.

`GuardDutyDto`:

```ts
type GuardDutyDto = {
  id: string; kind: "assigned" | "exam"; date: string; // YYYY-MM-DD in IST
  siteId: string; siteName: string; clientName: string; district: string;
  shiftLabel: string | null; startsAt: string | null; endsAt: string | null;
  relieving: boolean; status: "assigned" | "open" | "cancelled";
  workOrderId: string | null; examName: string | null; examCode: string | null;
  maleGuardsRequired: number | null; femaleGuardsRequired: number | null;
  willingness: "willing" | "unavailable" | null;
  willingnessVersion: number; canRespond: boolean; respondBy: string | null;
  ineligibilityReason: string | null;
};
```

For open exams `id` is the canonical work-order ID and `kind=exam`. An own exam roster membership yields `kind=assigned`, stable `id="exam:"+workOrderId`, `workOrderId` set and no willingness action; do not duplicate that row as an open exam. Ordinary shifts use the assignment document ID with `kind=assigned`. Guard DTOs never expose other guards, phone numbers, import provenance, or payroll data.

`POST /api/guard/duties/{workOrderId}/willingness` body `{response, clientRequestId, expectedVersion}` → `{success:true, willingness:{response,version,respondedAt}, replayed:boolean}`. Response is only willing/unavailable; request ID is a UUID, expectedVersion a nonnegative integer. The server ignores no privileged fields: reject unknown fields so employee/district/time cannot be forged. Derive linked active guard, current employee client/category/district, active TCS work order and authoritative site in the transaction. Require effective category adhoc and same canonical district, current time before cutoff. Require neither available slots nor gender; willingness is an interest signal, while existing roster assignment validation keeps its established gender rules.

`dutyWillingness/{workOrderId}_{employeeDocId}`: `{workOrderId, guardId:employeeDocId, guardUid, employeeId, district, examCode, examName, dutyDate, response, version, respondedAt, source:"mobile"}`. Server-generated snapshot fields only. An operation receipt keyed by guard/workOrder/request ID stores payload fingerprint and resulting version atomically; exact replay returns the prior result without overwriting state, reuse with a different payload returns 409. A new mutation with stale expectedVersion returns `409 version_conflict` and current willingness. Repeating the current response with current version is a no-op. Only a true state change increments version and generates an event. Fresh authorization is still checked on replay.

`GET /api/field-officer/work-orders/{id}/willingness` (admin also permitted) → `{workOrderId,willingCount,unavailableCount,responses:[{employeeDocId,employeeId,name,gender,tcsCategory,response,respondedAt,version}]}`. Recheck current employee eligibility when tallying; deactivated/transferred/reclassified guards do not inflate active willingness. FO can fetch only the work order's current site district. Expose counts on existing FO/admin work-order list DTOs through the same helper. No new exam-pool entity or global willingness endpoint.

### Ordinary assignments

`GET /api/field-officer/assignments?from=YYYY-MM-DD&to=YYYY-MM-DD` → `{assignments:[...]}`, default same 90-day window, max requested span 90 days; active FO and admin only. `POST` to this route body `{employeeDocId,siteId,date,shiftCode?,shiftLabel?,startTime?,endTime?,crossesMidnight?,type,clientRequestId}`. Use one guard per request; multi-select UI submits separately and reports each result without claiming atomic bulk success. `PATCH /api/field-officer/assignments/{id}` body `{expectedVersion,clientRequestId,status?:"cancelled",siteId?,date?,shiftCode?,shiftLabel?,startTime?,endTime?,crossesMidnight?,type?}`. Guard identity is immutable; changing guard is explicit cancel + create. No deletion endpoint.

`guardAssignments/{id}` stores `{guardId:employeeDocId,guardUid,employeeId,guardName,district,clientName,siteId,siteName,date,shiftCode,shiftLabel,startsAt,endsAt,type:"regular"|"relieving",status:"assigned"|"cancelled",version,assignedBy,assignedAt,updatedBy,updatedAt}`. Use request receipts for idempotent create/update, optimistic version checks for edits and server audit fields. FO must own both previous/new site's current district and guard's district; admin bypasses district restriction but still validates active employee/site and data shape. Relieving changes this assignment only, never `employee.assignedSiteId` or attendance. Do not invent a same-client prohibition (the spec permits selecting client/site); client metadata always derives from selected site. Prevent an exact duplicate active employee/site/date/shift with a deterministic slot key/transaction. Do not introduce attendance conflict enforcement or reinterpret existing exam same-day policy.

Auth and validation errors use stable `{error,code}`: 401 invalid session; 403 wrong role/scope or ineligible category; 404 missing scoped object; 409 version conflict, closed/cancelled duty or duplicate active assignment; 400 invalid body. Unexpected infrastructure failure is 500, not 401. Clients distinguish retryable transport/429/5xx from terminal business responses.

## Task 1: Classification end-to-end with protected curation

**Files:** Create `CISS/src/lib/tcs-category.ts`, its `.test.ts`, `CISS/src/app/api/admin/employees/[id]/tcs-category/route.ts` and `route.test.ts`; modify `src/types/employee.ts`, `src/types/enrollment.ts`, `src/app/api/employees/enroll/route.ts`, its existing tests, `src/app/api/guard/profile/route.ts`, `src/lib/server/guard-profile-view.ts`, admin employee serializer, both enrollment pages and employee detail page. Mobile modifies `lib/core/models/guard_profile.dart`, guard Profile and FO guard directory/detail badge consumers after the foundation agent finishes.

**Interfaces:** Produce `parseTcsCategory(clientName: unknown, value: unknown): "adhoc"|"permanent"|null`; profile/list serializers consume it; enrollment derives adhoc after canonical client resolution.

- [x] Write failing tests: canonical TCS new enrollment stores adhoc, forged permanent cannot elevate, non-TCS creates no category, existing missing/invalid category stays null, admin curation succeeds, guard/FO/HR curation is denied, non-TCS curation rejected. Extend existing enrollment fixture rather than bypass its document/consent requirements.
- [x] Run `npm test -- src/lib/tcs-category.test.ts src/app/api/employees/enroll/route.test.ts 'src/app/api/admin/employees/[id]/tcs-category/route.test.ts'`; verify failures concern new behavior.
- [x] Implement helper, server defaults and narrow admin route; expose category in authenticated serializers. Add read-only “Adhoc — admin can update after enrollment” for TCS on public/staff forms; separate editable category control on admin detail. Avoid including category in general direct-Firestore edit payload.
- [x] Add rules validation for direct administrator category writes: absent or valid enum only, valid only on TCS; retain existing admin general edits and legacy records. Test that an unrelated edit on a legacy unclassified record remains permitted. UI must not grant HR or FO curation.
- [x] Run focused tests, mobile category parsing/badge tests and typecheck. Verify TCS qualification, LNG documents and existing enrollment defaults still pass.

## Task 2: Guard duty API, eligible willingness and scoped tallies

**Files:** Create `CISS/src/lib/server/duties/{scope,guard-feed,willingness}.ts`, respective tests; `src/types/duties.ts`; `src/app/api/guard/duties/route.ts`, `src/app/api/guard/duties/[id]/willingness/route.ts`, `src/app/api/field-officer/work-orders/[id]/willingness/route.ts`, respective route tests. Modify existing FO work-order read and admin work-order read serializers for counts. Add `src/lib/server/duties/requests.ts` + tests for receipts/CAS shared with Task 3.

**Interfaces:** Produce `resolveDutySupervisor(request): Promise<{uid,isAdmin,assignedDistricts}>`, `resolveDutySite(db,siteId): Promise<canonical site>`, `getGuardDuties(request): Promise<GuardDutyDto[]>`, `setDutyWillingness(request,id,input)` and `getWorkOrderWillingness(request,id)`. Use existing `requireGuard`/linked-profile/district/date utilities. `resolveDutySupervisor` must call `requireActiveFieldOfficerProfile` and never claim-only fallback.

- [x] Write route/service failing tests for linked own identity, permanent/non-TCS/unclassified rejection, canonical aliases, site district overriding stale order district, changed site scope, cancelled/superseded/draft/missing rows, malformed IDs, active status, guard PII isolation, today read-only feed and ordered complete 90-day window. Pin the exact UTC cutoff above, including a known afternoon exam shift that still closes at start-of-day and a late queued response captured before cutoff.
- [x] Add mutation tests: 50 willing guards against 2 required slots all succeed; willing→unavailable changes tally; duplicate request after another response does not roll it back; reused key with different payload fails; concurrent same-version writes allow one change; unknown body identity fields rejected. Test current ineligible responders excluded from counts.
- [x] Run `npm test -- src/lib/server/duties src/app/api/guard/duties 'src/app/api/field-officer/work-orders/[id]/willingness'` and confirm feature failures.
- [x] Implement DTO/service/route behavior above with server timestamps, bounded date queries and complete paging. No Firestore reads from browser/mobile for these new collections. Do not expand existing guard work-order read rules.
- [x] Add local deny-all client rules for `dutyWillingness`, operation receipts and duty event/outbox documents; backend Admin SDK is the sole access path. Add indexes used by actual implementation (at minimum willingness workOrderId+response if queried; guardId+dutyDate for own response window; assignment guardId+date and district+date in Task 3). Add schema/index assertions and a local emulator rules test if the environment supports it; document explicitly if emulator execution is unavailable.
- [x] Run focused tests and existing district/linked-profile/work-order tests. Confirm the new endpoint is wired before declaring mobile duties functional.

## Task 3: Informational shift assignment and existing exam-roster integration

**Files:** Create `CISS/src/lib/server/duties/assignments.ts` and tests, `src/app/api/field-officer/assignments/route.ts`, `src/app/api/field-officer/assignments/[id]/route.ts` with route tests. Modify `src/app/api/admin/work-orders/[id]/route.ts`, its tests, FO sites DTO (shift templates), Task 2 guard feed, and `firestore.rules`/`firestore.indexes.json`.

**Interfaces:** Produce `createGuardAssignment(request,input)` and `updateGuardAssignment(request,id,input)`, scoped list service and validated assignment DTO. Consume Task 2 supervisor/site/receipt helpers. Existing exam PATCH remains the only exam roster writer; willingness list selection feeds its current `assignedGuards` payload.

- [x] Write failing tests for scoped create/list/change/cancel; linked inactive/missing FO denies access despite claims; forged client/district/name rejected; alias district accepted; current site district wins; both old/new scope checked; exact duplicate request replays; concurrent edit gives 409; duplicate active slot rejected; cancel idempotent; overnight end follows start; invalid dates/time/shift rejected; no-template site requires explicit times.
- [x] Add guard feed tests showing own ordinary shifts, own exam roster membership once, relieving/cancelled labels and no other guard assignments. Verify a permanent or non-TCS guard still sees own assignments.
- [x] Run focused failures, then implement transaction-based writes and scoped list. Deny all browser/mobile direct reads/writes on `guardAssignments`; expose only validated API DTOs. Keep `workOrders.assignedGuards` authoritative for exam rosters, with no mirrored assignment collection rows.
- [x] Repair exam PATCH scope with Task 2 active supervisor/site helper and preserve existing assignment audit, roster matching and same-date conflict behavior. Same roster is a no-op; request ID receipts protect optional new clients while old clients remain compatible. Never require willingness before manually assigning an eligible guard.
- [x] Add regression tests proving attendance submission's preconditions and existing selected-site logic are unchanged with no assignment, cancelled assignment and different relieving site. Run existing attendance test suites, not only source-text assertions.
- [x] Run `npm test -- src/lib/server/duties src/app/api/field-officer/assignments 'src/app/api/admin/work-orders/[id]' src/lib/attendance` and typecheck.

## Task 4: Durable inbox events and best-effort targeted push

**Files:** Create `CISS/src/lib/server/duties/notifications.ts` and tests; modify Task 2–3 services, `src/types/notification.ts`, existing exam PATCH and `src/app/api/admin/work-orders/import/commit/route.ts` for affected roster changes/cancellations; use `src/app/api/mobile/notifications/route.ts` for bounded recipient-owned pending push retries. Mobile later updates `lib/core/fcm/notification_service.dart`.

**Interfaces:** `buildDutyNotificationWrites(event): writes` participates in the successful mutation transaction/batch; `dispatchDutyNotifications(eventIds): Promise<delivery summary>` runs after persistence. Event IDs are derived from operation/entity/version/recipient, never random on replay. Types: `duty_assigned`, `duty_changed`, `duty_cancelled`, `duty_willingness`; data includes `notifId`, `assignmentId` or `workOrderId` and route kind.

- [x] Write failing tests for inbox atomicity, one event per true change/recipient, correct Auth UID resolution, no-token success, FCM failure leaves inbox and pending status, retry does not recreate inbox or reset read state, role-scoped willingness audience, and cancelled/changed imported exam duties notifying retained affected guards once.
- [x] Implement per-recipient `notifications/{deterministicId}` inbox records with pending delivery metadata and server-only event ownership. Resolve current active FO profiles in the canonical district for willingness notifications; never expose guard details in broadcast topics. Query `fcmTokens` by UID and dedupe token strings.
- [x] Send via existing Firebase Admin messaging in chunks. Use a transactional short lease for concurrent dispatch, attempts/status for retry, and stable event ID plus Android tag/collapse identity. Do not delete token records on error; mark delivery outcome. Push delivery is at-least-once best effort, not an exactly-once guarantee.
- [x] Exact mutation replay retries pending delivery; recipient inbox polling retries a bounded set of that recipient's pending events after the inbox is readable. No new live cron or deployment. This gives recovery when the app next checks the inbox; document that a closed app after a server crash has no guaranteed immediate push retry.
- [x] Wire roster add/remove to assigned/cancelled and retained roster metadata changes to changed. Hook importer revision/cancellation event generation into its existing local write plan so persistence precedes FCM; do not send from preview or dry run. Test no notifications for unchanged import rows and replayed imports.
- [x] Run notification, importer, assignment and mobile inbox route regression tests. Mock all Firebase messaging calls; no delivery to real devices/accounts.

## Task 5: Mobile willingness persistence, ownership and reconciliation

**Files:** Modify `lib/core/models/duty_models.dart`, `lib/core/network/mobile_repository.dart`, `lib/core/offline/offline_request.dart`, `lib/core/offline/offline_queue.dart`, `lib/core/sync/sync_service.dart`; create `lib/features/guard/application/duty_willingness_controller.dart`; extend `test/duty_models_test.dart`, `test/sync_service_test.dart` and create `test/duty_willingness_queue_test.dart`.

**Interfaces:** Repository reads the Task 2 DTO and returns the mutation response rather than void. Add `queueWillingness({ownerUid,apiBaseUrl,workOrderId,response,expectedVersion,clientRequestId})`; metadata is stored locally, not added to HTTP JSON. Controller exposes `saved`, `pending`, `rejected` with reason/current server response. Existing OfflineRequest deserialization tolerates absent new metadata for older request types.

- [x] Write failing tests for durable restart, offline willing→unavailable coalescing, account/region mismatch, stale queue snapshot while a response is changed, one success removing only the acknowledged request, transport retry preserving request ID, 429/5xx retry, 401 retaining pending until valid same-owner session, and terminal 400/403/404/409 rejection displayed to user.
- [x] Run `flutter test test/duty_models_test.dart test/duty_willingness_queue_test.dart test/sync_service_test.dart` and inspect intended failures.
- [x] Implement willingness-specific enqueue/upsert keyed by owner+origin+workOrder; reject visible queue-capacity failure instead of dropping any attendance/request. Keep mutation processing ordered per duty. Never replay mismatched or unowned willingness rows; preserve them for the original identity and expose pending state only to that identity.
- [x] Every new user choice gets a new request UUID; retry keeps it. If predecessor was already accepted, update the pending successor's expectedVersion from that successful response before sending. If server returns version_conflict from another device, fetch current state, show rejection/choice to retry explicitly; do not silently overwrite another device's newer answer or trust client timestamps.
- [x] Remove terminal failures from the runnable queue into a persisted willingness result state; show “Response not sent” with reason and refresh. On success invalidate guard feed and synchronize current response. No haptic/presentation “saved” until server confirmation; pending has distinct copy. Preserve generic attendance/photo/tracking paths exactly.
- [x] Run focused tests plus all existing sync/auth lifecycle/attendance tests. Prove account switch and region switch cannot leak pending duty data or replay it to the wrong deployment.

## Task 6: Complete guard and supervisor surfaces

**Files:** Mobile `guard_duties_screen.dart`, `guard_dashboard_screen.dart`, `guard_profile_screen.dart`, FO `field_officer_work_orders_screen.dart`, guard directory/detail, `mobile_repository.dart`, `mobile_dashboard_models.dart`, `notification_service.dart`, router/module mapping as needed. Create small `duty_detail_sheet.dart`, `work_order_willingness_sheet.dart`, `assignment_editor_sheet.dart` near their consuming screens. Backend/web create `src/components/field-officers/{work-order-willingness,guard-assignment-form}.tsx`, integrate in `work-orders-panel.tsx` and `src/app/(app)/work-orders/page.tsx`; reuse existing site/guard selectors.

**Interfaces:** Consume only frozen APIs above. Reuse existing `workOrders` feature flag for Duties actions; no additional live settings mutation. A disabled workOrders flag disables willingness/assignment entry points consistently, but never attendance or profile.

- [x] Write mobile widget tests for eligible adhoc feed, missing category explanation, permanent own assignment, empty/loading/error/retry, cancelled/read-only duty, pending/rejected willingness, long site/exam text, large text, light/dark and flag off. Tests must use API fixtures, not production-looking invented data fallbacks.
- [x] Add FO tests: counts open scoped list; selecting willing guard calls existing exam roster PATCH; unwilling guards remain manually assignable under existing roster rules; regular/relieving create/edit/cancel form requires valid site/date/shift; partial multi-create reports each guard's result. Admin web uses the same APIs and surfaces.
- [x] Implement Guard Home's one upcoming duty/prompt and category badges. Duties detail labels required manpower as requirements, never “remaining slots”; express willingness/unavailable as a choice, with explicit “This does not confirm assignment.” Display missing exam shift honestly and canceled assignment clearly.
- [x] Implement FO willing list and assignment sheet; place secondary edit/cancel actions in detail/overflow. Preserve current exam roster controls and do not replace permanent assignment with a fake exam work order.
- [x] Route all assignment types to Guard Duties and willingness to the corresponding FO work order; handle foreground/background/cold-start and wrong active role safely. Use current tab constants, never stale numeric tab assumptions. Duplicate event IDs replace/suppress local duplicates.
- [x] Run focused widget/navigation/repository tests, then local mocked preview in light/dark with loading/error/empty/long text. Capture visual evidence without connecting the preview to production. Physical push/haptic behavior remains a reported device-verification limitation if no suitable device is available.

## Task 7: Dry-run classification scaffold and final cross-repo review

**Files:** Create `CISS/scripts/plan-tcs-categories.mjs`, fixture tests and `CISS/docs/tcs-category-backfill.md`; amend local feature documentation with verified commands and limitations. Do not modify original source datasets.

**Interfaces:** Offline-only CLI consumes explicitly supplied local JSON exports: employee records with document IDs and two source lists (biometric candidates, permanent deployment). Produces JSON/CSV proposals plus unmatched/ambiguous/conflicting records. No Firebase initialization, no credentials, no `--apply`; fail clearly if apply is requested. Exact unique employeeDocId or employeeId matching only; names/phones alone do not establish identity.

- [x] Write fixture tests for permanent source precedence over biometric candidate, unmatched identities, duplicate/conflicting source identities, non-TCS rejection, preserving existing curated categories and no implicit classification of everyone else. Existing category conflicts are review-required, not overwritten in proposals.
- [x] Implement dry-run scaffold and document required source schema, source date/provenance and the unresolved authority question: current biometric list may include permanent guards. Do not claim a production backfill or reviewed real-source diff; actual source selection/authority and later import authorization remain separate prerequisites.
- [x] Run scaffold on synthetic fixtures only and verify no network/write-capable Firebase import exists. No real biometric/payroll export is necessary to complete the local feature.
- [x] Run backend `npm test`, `npm run typecheck`, applicable existing lint (record pre-existing failures separately); mobile `flutter analyze`, `flutter test`. Run targeted existing enrollment, work-order importer/assignment, linked auth, notifications, district, attendance and sync regressions. Do not use a production build step that performs live data work.
- [x] A separate GPT-6.1 Sol reviewer reviews complete diffs in both isolated worktrees against this spec/contract, especially five Review Focus items. DeepSeek V4.1 Flash (or the user-authorized GPT-6 Luna fallback after failure/insufficient balance) implements fixes and the separate GPT-6.1 Sol reviewer reviews again until no actionable defects remain and required checks pass. GPT-6 Astra is reserved for new plans. Report any unavailable emulator/device verification rather than asserting it passed.
- [x] Verify `git diff --check`, final `git status --short` in both worktrees and unchanged original workspaces. Root adds the required non-sensitive work-log/KB local-only status. Deliver changed features, test evidence, exact worktree locations, and explicit undeployed/backfill limitations; do not commit or publish.

## Execution boundaries and data dependencies

The user already chose the model workflow and authorized both local repositories, adhoc defaults and the start-of-duty-day willingness cutoff. Root may proceed within that authorization without another routine permission prompt. Backend Tasks 1–4 establish the contract; mobile Task 5 can begin against its fixtures while backend proceeds; Task 6 integrates after both pass. Only one agent edits shared mobile repository/model/screen files at a time. Review each coherent task plus final cross-repo state. Baseline confirmed by root: backend 83 test files / 479 tests pass and typecheck passes; available Node is 26.7 while package engine requests 22, which must be recorded if it affects verification.

No fundamental product choice blocks local implementation. Real backfill is deliberately **not** completed: authoritative current biometric/permanent lists and review of actual proposed changes are still needed before any future live migration. FCM credentials/deployment/rules rollout and physical device verification are also outside this local-only authorization. These limitations must stay visible in the final report.

## Completion record — 2026-10-15

Approved local implementation and review gates are complete. See `docs/superpowers/reports/2026-10-15-redesign-continuation-verification.md` for evidence and limits. Final mobile review: `mobile-sol-round3-rereview.md`; final web review: `web-sol-round2-rereview.md` in the shared ledger. Model workflow follows the current AGENTS.md; historical role references above are superseded. Worktrees are preserved, uncommitted and undeployed.
