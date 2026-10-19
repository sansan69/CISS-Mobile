# Baseline continuation — 18 October 2026

Work is in the linked redesign-continuation mobile and CISS worktrees. Changes
are uncommitted and have not been deployed; no device installation or live data
write was performed.

## Implemented

- One handset capture timestamp for new signed-in guard punches and per-sample
  tracking batch outcomes. Retryable samples stay buffered, permanent rejections
  retire, legacy count-only responses remain compatible.
- Generic attendance/report outbox: monotonic sequence migration, stable
  attendance replay identity, durable last ack/failure, exponential jittered
  deadlines without waiting inside a flush, periodic 30-second flush, FIFO causal
  ordering, retained permanent rejects and no silent eviction after repeated
  failures/capacity. Uploaded photo paths are persisted before submission and use
  the same capture attempt ID. Malformed legacy entries are retained, skipped
  and isolated from bootstrap.
- Willingness: sequence, captured/acknowledgment time, persisted retry deadline
  and jittered backoff. Latest local choices still coalesce; account/origin guards
  and server version checks remain authoritative, including duty-day closure.
- Sync health in guard Profile and officer More: pending/rejected attendance and
  report count, oldest pending, last ack/failure, manual flush. Duty response
  history continues to expose its own pending/conflict states.
- Attestation abstraction plus explicit Noop; configured freeRASP advisory flags
  on guard, public and QR punches; backend stores those fields and requests review
  for risk flags or handset changes. No handset risk flag is a trusted verdict.
- Reference-counted screen_protector wrapper for payslips, documents and employee
  detail pages, including overlapping sensitive routes.
- Scoped opaque directory cursors with stable document-ID order for paged callers;
  legacy full-list callers retain newest-enrollment ordering. Bounded query scans,
  duplicate merge, malformed/scope-mismatched cursor validation; lazy mobile rows,
  guarded next-page fetch, loaded-page search, retry and old-server fallback.
- Firebase Analytics attendance/duty/sync events and nonfatal failure reporting
  using reason codes without names, employee IDs, coordinates, photos or tokens.
- Employee access audit after authorization in web profile reads and a new scoped
  mobile audit endpoint. Mobile profile navigation requires its audit receipt.
  Audit TTL declaration is local only; see sibling privacy-retention documentation.
- Policy card reachable from both roles, with approved HTTPS links configurable
  by build defines and explicit office-contact fallback.
- Play-specific update path, conditional install-package permission removal,
  manual signed CI build/staged publishing/symbol upload path. Existing sideload
  update path retained. See docs/release/google-play.md.
- Web guard leave page and More navigation; date/reason validation, stable create
  replay ID, authenticated ownership, transactional pending-only cancellation.

## Rulings

- Keep cross-device willingness CAS rejection instead of overwriting a newer
  server response. Cost: a conflict requires refresh and an explicit new choice.
- Keep existing sideload releases supported while introducing the Play path.
  Cost: both distribution paths need regression coverage.
- Guard history is already bounded to one calendar month, usually about two
  punches/day. Additional pagination is unwarranted now; directory pagination is
  implemented. Revisit if real monthly volume makes that response large.
- No Play Integrity verdict is fabricated before a trusted backend verifier and
  Play configuration exist. Noop status remains visible in the attendance data.
- The audit retention default is an engineering proposal, not a legal retention
  determination; office approval is required before deploying its TTL policy.

## Verification and external dependencies

Focused mobile and backend tests have passed during implementation. Final full
suite, analyzer, typecheck, native compilation and review results are recorded
in the completion entry below.

Still external: actual signing/Play credentials; approved policy URLs and vendor
report email/certificate; production Play Integrity verifier; approval and deploy
of the new audit TTL; device TalkBack/screenshot/store-update and offline/overnight
walkthroughs. Automated 320dp/1.8 text and semantic contrast tests cover the new
status/policy surfaces in English, Hindi and Malayalam. These do not replace
TalkBack or an on-device check. Deploy the new web endpoints before distributing
the mobile build, because employee opening now requires a durable access audit.

## Completion evidence

- `flutter analyze`: clean, no issues.
- `flutter test --reporter expanded`: **559 passed**.
- Sibling web `tsc --noEmit -p tsconfig.typecheck.json`: passed.
- Sibling web Vitest: **739 passed, 35 skipped** (emulator-dependent).
- Android debug compilation: Play and sideload modes both passed. Play merged
  manifests omit REQUEST_INSTALL_PACKAGES; sideload manifests retain it.
- Play workflow YAML and each shell step passed local syntax validation. This is
  not a signed CI run or a store publication; those need configured credentials.
- `git diff --check`: clean in both worktrees.
- GPT-6.1 Sol reviewed the complex cross-stack change. Actionable findings fixed:
  mandatory Play-update bypass; corrupt legacy-row migration abort; missing audit
  TTL declaration; and public/QR funnel ordering around upload/durable enqueue.
  Targeted re-reviews found no further actionable defects in those fixes.
- DeepSeek visual route returned 401 `api_key_expired`. Per the pre-authorized
  fallback, GPT-6 Luna medium reviewed synthetic screenshots of the directory and
  enlarged sync/policy surfaces in both themes. The initial square icons were a
  test-probe font omission; loading the production MaterialIcons font in the
  probe resolved it. Final static review found no actionable visual defects.
- No Pixel/emulator install, TalkBack walkthrough, signed release, live Firebase
  change, Vercel deployment, commit or push was performed.

The production gates listed above remain outstanding; this report does not
claim that store distribution or legal/privacy rollout is complete.
