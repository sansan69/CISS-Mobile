# CISS Mobile — 2026 Redesign, Role-Split Design Language, Motion/Haptics System & TCS Adhoc Willingness

**Date:** 2026-10-13
**Project:** CISS-Mobile (Flutter), plus webapp data-model work in `../CISS`
**Scope:** (1) app-wide UI/UX redesign to 2026 standards, (2) de-cluttering, (3) CISS branding, (4) a design language differentiated per role (Guard vs Field Officer), (5) a modern motion + haptics system, (6) TCS adhoc/permanent classification + guard willingness-to-attend.
**Supersedes/extends:** `docs/superpowers/specs/2026-07-05-ciss-mobile-redesign-design.md` (kept for history). `DESIGN.md` remains the token/visual source of truth unless this doc explicitly amends it.

---

## 1. Intent & Why

The app works but reads as a generic, dense admin tool rather than a field instrument for security staff. Guards and field officers (FOs) each need a *different* app: a guard needs to do one thing fast, outdoors, on a cheap phone, often offline; an FO needs to supervise a district — coverage, gaps, and the live map. Today both get the same cards, the same density, and the same screens.

The redesign's job is not decoration. It is to make the two jobs obvious at a glance, cut everything that isn't the job, and make the app feel like the 2026 Android standard it runs on.

**The concrete moments this must fix (from the user):**
- Guard marking attendance quickly.
- Guard checking his number of duties.
- Guard seeing upcoming duties in his region (TCS adhoc).
- Guard downloading a payslip.
- TCS adhoc guard seeing a recent upcoming exam duty and **expressing willingness to attend** through the app.
- (Field officer → guard) assigning a **permanent** guard's duty for a date/site **in-app** instead of WhatsApp, with a push notification and the duty detail in the guard's portal.

## 2. What Already Exists (do not rebuild)

Established and to be built on, not replaced:
- **Stack:** Flutter 3.47, Material 3, Riverpod 2, GoRouter 16, Dio, Hive (+ offline queue), Firebase (auth/firestore/messaging/storage/crashlytics), `flutter_background_service`, `flutter_map` (OSM), `mobile_scanner`, `local_auth`. minSdk 24. Bundled **Inter** (400/500/600/700). No `google_fonts` at runtime.
- **Design system:** `lib/app/theme/app_tokens.dart` (`CissThemeTokens` light/dark, `AppSpacing` 4/8/12/16/20/24/32, `AppRadius`, `AppShadows`, `AppTypography`), `lib/app/theme/app_theme.dart` (full M3 `ThemeData`), `lib/app/theme/theme_mode_controller.dart`.
- **Shared widgets (~22):** `modern_card`, `modern_hero`, `metric_card`, `surface_card`, `glass_card`, `status_chip`, `section_header`, `screen_scaffold`, `floating_nav_bar`, `state_block`, `sync_status_badge`, `offline_badge`, `compliance_tag`, `time_counter_chip`, `document_list_tile`, `success_overlay`, `biometric_setup_sheet`, `brand_banner`, `portal_primitives`, `security_settings_card`, `camera_capture_screen`, `theme_mode_selector`.
- **Brand colors:** Brand Navy `#014C85`, Navy Deep `#013A6B`, Brand Gold `#BD9C55`; status green/amber/red + soft tints. `DESIGN.md` already bans purple/gradient/emoji/Pure-black/3-equal-column tiles.
- **Haptics:** `lib/core/haptics.dart` exists but is Android-only and semantically broken (see §7).
- **Roles/presentation:** `features/guard` (14 screens), `features/field_officer` (14), `features/auth`, `features/region`, `features/attendance_qr`, `features/attendance_public`. Shells: `guard_shell.dart`, `field_officer_shell.dart`.
- **Webapp (source of record for data):** `../CISS` (Next.js/Firestore) already ships **TCS exam work orders** modelled per `site × date × exam` (`docs/superpowers/specs/2026-04-19-tcs-exam-work-orders-design.md`, `src/lib/work-orders/tcs-exam-parser.ts`). Mobile consumes work orders via `WorkOrderModel`.

## 3. Goals / Non-Goals / Anti-Goals

**Goals**
1. A 2026-standard visual + interaction system built on **Material 3 Expressive** principles, adapted to Flutter and to the existing navy/gold brand.
2. Measurably less clutter: fewer simultaneous elements per screen, one job per screen, summary→detail, progressive disclosure.
3. A documented **role design language**: Guard and FO share foundations but differ in composition, density, tone, and default screen.
4. Coherent CISS branding at every surface (header, icon, splash, empty/loading/error, tone).
5. A real **motion system** and a real **haptics system** (cross-platform, semantic, co-designed).
6. Ship the **TCS adhoc/permanent** classification and the **guard willingness-to-attend** flow.

**Non-Goals**
- Rewriting the backend or the web admin. Web changes are limited to what the feature needs (§8).
- Admin/client/HR mobile surfaces (remain web-only, per current `DESIGN.md`).
- Retheming the brand. Navy+gold stays; we refine its use, we don't replace it.
- New state-management or navigation libraries.

**Anti-Goals (this is a failure even if it "works")**
- More decoration: gradients, glows, glass everywhere, confetti, emoji-as-icons.
- Two roles that still look identical.
- Motion that plays on scroll/loops, or haptics that buzz on everything.
- A "redesign" that only restyles and doesn't reduce what's on screen.

## 4. The 2026 Bar (research-grounded)

From official Android/Flutter sources (Reddit/forums blocked automated fetch; see §11):
- **Material 3 Expressive** is the current Android evolution: **motion tokens with spring + shape-morphing**, an **expanded shape library**, dynamic color with a **third accent**, **variable fonts**, and expressive components (button groups, floating toolbar). Google reports expressive variants won ~100% on preference and up to ~170% on aesthetics vs baseline. It defines an **expression ladder**: foundational → excellent → transformative (target excellent+).
- **Flutter 3.47** is current; animation approach is implicit/explicit/**physics-based (spring)**, `Hero` for shared elements, staggered lists; packages in the ecosystem include `simple_animations`, `Animated-Text-Kit`, `lottie-flutter`.
- **Android haptics guidance:** favor *clear/rich* over *buzzy*; prefer `HapticFeedbackConstants`; strength correlates with importance **and** frequency; **co-design haptic + visual + audio**; keyclicks 10–20 ms; avoid legacy one-shot vibrations; always provide fallback.

## 5. Design Direction — De-clutter + 2026 Look (shared)

**De-clutter is structural, not cosmetic.** Rules for every screen:
1. **One job per screen, one primary action.** Any screen with two "primary-looking" buttons is a defect. Secondary/destructive actions go to an overflow menu, a bottom sheet, or a detail route.
2. **Above-the-fold budget:** at most **3 content blocks** before scroll (a hero/summary, one action cluster, one list). Everything else moves below or behind a sheet/route.
3. **Summary → detail.** Dashboards become *summaries* (the 3 numbers that matter + one action), with drill-down routes. Kill on-dashboard data dumps.
4. **Progressive disclosure.** Filters, day-timelines, telemetry, audit fields, and long forms open in `showModalBottomSheet`/dedicated routes, not inline.
5. **Kill equal-weight tile grids.** Already banned in `DESIGN.md`; enforce with priority rows + status chips.
6. **Typography carries hierarchy** (Inter weights), not more boxes. Reduce card count; use dividers for dense lists.
7. **Density target:** raise whitespace and lower simultaneous element count per screen; keep "Daily App Balanced" but audit each screen against a per-screen element budget.

**2026 visual language (adapted from M3 Expressive):**
- **Shape:** adopt a stated shape scale and use shape as meaning (state change, hierarchy), not decoration. Document as: actions = pill, cards = 22, inputs = 12, sheets = 24 top. Add a *single* shape-morph moment on the primary CTA per hero screen.
- **Color:** keep one accent (Brand Navy). Add a disciplined **third accent usage** only if it earns a role (e.g., a Guard "on-duty" state distinct from generic success); otherwise navy + status only. No gradients without a brand reason.
- **Type:** Inter stays (field legibility + offline). Use weight/width as expression; ensure tabular numerals for counts/times/money.
- **Components:** adopt M3 expressive-style components where Flutter supports them (segmented buttons, FAB menu, button groups, floating toolbar for contextual actions on the map/detail screens).

**Interpretation note (my reading, flag if wrong):** "too cluttered" means too many *things* per screen, not too much *information in the system*. So we relocate information behind drill-downs rather than delete it.

## 6. Role Design Language (Guard vs Field Officer)

Shared foundations (tokens, components, motion, haptics, branding) — **different composition rules, density, tone, and home**. Written as two "profiles":

### 6.1 Guard profile
- **Job:** "What do I do now?" Personal, single-task, thumb-first, offline-first, outdoors (high contrast, big targets, glanceable).
- **Default screen:** Home = *today* — prominent **Mark Attendance** primary action, and then either an **assigned-duty** card (permanent guards, §8.5) or an **adhoc exam-duty / willingness** prompt (adhoc guards, §8.3), plus a compact row: duties count, latest payslip.
- **Density:** lowest. Big primary actions. Minimal charts. Encouraging, plain-language tone.
- **Nav (proposed, confirm):** Home · Duties · Attendance · Profile. (Today there is no guard "Duties" screen — this is new.)
- **Offline posture:** every core action (attendance, willingness) works offline and syncs.

### 6.2 Field Officer profile
- **Job:** "Is my district covered and where are my people?" Supervisory, map-first, organized-dense, multi-task.
- **Default screen:** Home = district summary (coverage %, guards on duty, sites without attendance, duties today) + **Live Map** entry + pending reports, with a clear action cluster.
- **Density:** medium (organized, grouped), more summaries/tables, but still one primary action per screen.
- **Nav:** Home · Duties (work orders) · Guards · More (Live Map, reports, tools).
- **Distinctness requirement:** an FO screen must be recognisable as FO at a glance (denser summary rows, map affordances, district scope header) vs a Guard screen (single big action, personal framing).

### 6.3 How distinctness is enforced
- A `RoleDesignProfile` (composition tokens: block budget, header style, action-cluster style, tone strings) selected by role, analogous to `CissThemeTokens`. Same primitives, different assembly.

## 7. Motion & Haptics Systems

### 7.1 Motion
- **Decide in order:** frequency gate first (100+/day → platform default, nothing custom; tens/day → <150 ms near-imperceptible; occasional → standard; rare → delight). When unsure, delete the animation.
- **Name the purpose** (feedback / spatial continuity / state change / prevent-cut / explanation / delight) or don't build it.
- **Gesture-driven = spring** (start from live value, hand off velocity, project momentum, rubber-band). Non-gesture = timing <300 ms, strong ease-out; press feedback on press-in 100–150 ms (scale 0.97 buttons/cards; highlight rows; opacity bar buttons). Entrances fade + `scale(0.95)`; exits faster.
- **Adopt M3 Expressive motion:** a small token set (`duration`+`easing`/spring) so all motion is consistent; **shape morph** on the one hero CTA; Hero transitions for list→detail (e.g., guard → guard detail on FO side); **no slide between tabs**.
- **Performance:** animate `transform`/`opacity` only; no `entering` on recycled rows; verify 60 fps on release on the slowest device. Respect Reduce Motion (collapse spatial motion to cross-fade).
- **Implementation:** built-in Flutter animation + springs; add a package (`simple_animations` or a small internal spring helper) only if it removes real boilerplate. No heavy deps.

### 7.2 Haptics (replace the current file)
New `lib/core/haptics.dart` with a **semantic vocabulary**, correct on both platforms:
- Events: `selection()` (step/toggle), `light()`, `medium()`, `heavy()`, `tick()` (picker/step), `confirm()/success()`, `reject()/error()`, `warning()`, `impactFor(action)`.
- **Android:** base on `HapticFeedbackConstants` (`VIRTUAL_KEY`, `CLOCK_TICK`, `CONFIRM`, `REJECT`, `LONG_PRESS`, `SEGMENT_TICK`…) rather than raw impact levels; use `VibrationEffect`/`Composition` primitives only for the few genuinely *rich* moments, always with a constant fallback.
- **iOS:** `HapticFeedback.*` (maps to Taptic) — remove the current `if (!_isAndroid) return;`.
- **Rules:** one haptic per user action, on the same frame as the visual; never on scroll or in loops; strength scales with importance *and* frequency; respects the OS haptic setting (constants honor it; raw `vibrate` does not — prefer constants).
- **Co-design:** every haptic ships paired with its visual/motion; document the table (event → haptic → motion) so it stays consistent.

## 8. New Feature — TCS Adhoc/Permanent + Guard Willingness

### 8.1 Problem
Enrollment (`cisskerala.site`, webapp `../CISS`) does not capture whether a guard under the **TCS** client is **adhoc** or **permanent**. The team cannot segment them. Existing biometric data (Google Drive) can label current guards; a monthly permanent-deployment sheet identifies the permanent ones. Currently working permanent guards are <30.

### 8.2 Classification model (recommended)
- Add a TCS-scoped attribute on the employee/guard record: `tcsCategory: "permanent" | "adhoc"` (only meaningful for TCS). Default and backfill rules below.
- Surface it in enrollment (web), employee detail (web), admin marking (web), and as a **badge** on the mobile guard screens (and in FO guard lists).
- **Backfill (past):** one-off import/migration script that sets `tcsCategory` for existing guards using the Drive biometric list (adhoc) cross-checked with the monthly permanent-deployment sheet (permanent). Include a dry-run diff + review before write; unresolved rows flagged, not guessed.

**OPEN DECISION (needs the user):** the user's text says both "keep all ... under TCS as **permanent**" and "admin should be able to mark him as **permanent**," which is self-contradictory. My recommended default pending their decision:
- **Option A (recommended):** new TCS enrollments default to **permanent**, and admin can mark **adhoc**. Rationale: permanent is the smaller, more deliberate set (<30), so "default permanent + exceptions marked adhoc" keeps the majority unlabelled-wrong risk low only if most enrollees are actually permanent — which contradicts "working permanent guards are <30." **This option is only right if most *new* TCS enrollees are permanent.**
- **Option B:** new TCS enrollments default to **adhoc**, admin marks **permanent**. Safer given adhoc is the majority; the small permanent set is explicitly curated. *(I lean B unless the user confirms new enrollees are mostly permanent.)*
Confirmation of A vs B is required before building §8.2.

### 8.3 Willingness-to-attend flow (mobile)
- **Demand side already exists:** TCS exam work orders are per `site × date × exam` with `maleGuardsRequired`/`femaleGuardsRequired` and district. Reuse it; do not invent a parallel model.
- **Guard view:** a **Duties** surface shows upcoming exam duties in the guard's district/region, each with date, site, exam name, shift, and slots. An adhoc guard can **Express willingness** (or mark unavailable) per duty.
- **Data model (mobile/new):** `dutyWillingness/{workOrderId}_{guardId}` → `{ workOrderId, guardId, employeeId, district, examCode, examName, dutyDate, response: "willing"|"unavailable", respondedAt, source: "mobile" }`. Offline-queued like attendance.
- **Supervisor view:** FO/admin sees, per work order, a count and list of willing guards, filtered by district; this feeds assignment (assignment stays per exam row per the web spec — no shared pool). A guard's willingness raises an **in-app message/notification to the field officer**; the FO then assigns that guard for the adhoc duty from his portal. Willingness **informs** the FO; it does not reserve a slot or gate anything.
- **Guard home:** if a matching upcoming duty exists, show a single non-nagging prompt ("You have 2 upcoming TCS exam duties in your district — are you available?").

**OPEN DECISION:** is willingness a **declare-only** signal (admin assigns manually) or does it feed **auto-suggested assignment**? Default: declare-only for v1 (simpler, auditable); auto-suggest later.

### 8.4 Backend/API dependency & build order (found during review)
Guards have **no duty endpoint today** — work orders are served FO-scoped only (`/api/field-officer/work-orders`), and `GuardProfileModel` has no category field. So §8 is **not mobile-only**. Assumed build order (confirm):
1. **Web/API first:** add `tcsCategory` to the employee record + enrollment capture; add a **guard-scoped** upcoming-duties read (canonical district-scoped); add the `dutyWillingness` collection + write/read endpoints + Firestore rules/indexes; add the FO/admin "willing count per work order" read.
2. **Mobile second:** duty feed, willingness action (offline-queued), category badge, eligibility gating.

**Matching key (my call):** match guards to duties by **canonical district** (webapp already canonicalizes via `src/lib/districts` / `tcs-site-resolver`), not free-text `guard.district` and not the regional Firebase "region" selector. Confirm this reading of "his region."

### 8.5 Duty assignment (informational; replaces WhatsApp)
Duties are assigned **per shift** — a guard, a **client/site**, a **date**, and a **shift**. Today this happens over WhatsApp; bring it in-app.

- **FO → assign:** pick a guard (or several), a **client/site**, a **date**, and a **shift**; mark it **regular** (his own center) or **relieving** (cover at another site). Scoped to the FO's district.
- **Guard → see:** a **push notification** (FCM) on assign/change/cancel, and the duty in his portal as a **future reference** (date, client/site, shift, `Relieving` badge). A relieving assignment overrides his home site for that shift only.
- **Assignment is informational only — for both parties' knowledge.** It is not an authorization step and never blocks any action.
- **Attendance is never gated by assignment (hard rule).** At some sites guards work as per their convenience and have **no** assignment at all; marking attendance during a shift must work with or without an assignment, and a mismatch (assigned site vs actual site, or no assignment) must never prevent check-in.
- **Data model (proposed):** `guardAssignments/{assignmentId}` → `{ guardId, employeeId, district, clientName, siteId, siteName, date, shiftLabel, type: "regular"|"relieving", status: "assigned"|"cancelled", assignedBy, assignedAt, notifiedAt }`. Reuse the existing **site** entity as the "center".
- **Backend dependency:** assignment endpoints + Firestore rules/indexes + notification trigger, same repo-first build order as §8.4.

**OPEN DECISIONS:** (1) "Center" = the existing **site** entity? *(Recommended: yes.)* (2) Who may assign — **FO (district-scoped) + admin**? *(Recommended: yes.)* (3) Does a relieving assignment need the guard to **accept**, or is it informational? *(Recommended: assign directly; optional accept for relieving.)*

## 9. Screen Plan (targets, not pixels)

For each screen: the one job, above-the-fold budget, and where secondary content moves.

**Guard**
- Home → today (attendance CTA + next duty + duties count + payslip + willingness prompt).
- **Duties (new)** → upcoming adhoc exam duties (with willingness) **and** assigned shifts (future reference); detail sheet per duty. Bringing attendance is independent and never requires a duty to exist.
- Attendance → mark flow; history/logs behind a tab or route.
- Payslips → list → detail; download is the primary action.
- Profile, Training (+ detail/quiz/leaderboard), Evaluations, Leave, Incidents, Patrol, Aadhaar correction, Document upload → apply §5; move long forms/progress to detail routes.
- **FO**
- Home → district summary + Live Map entry + pending reports.
- Duties (work orders) → grouped by date with exam rows/chips (aligns with web spec); plus an **Assign duty** action (per shift; regular/relieving) and a **willing-guards** list per work order.
- Guards → directory; guard detail keeps live map/telemetry/day-timeline but moves telemetry behind progressive disclosure.
- Live Map, Reports (visit/training), Tools, Patrol activity, Training assignments.
- **Shared/Auth:** login hub, role login, permission onboarding, PIN/biometric setup — apply branding + motion/haptics, keep flows.

## 10. Left to the Builder / Open Decisions

**Theirs (only the user can decide) — brought in review order, most important first:**
1. **Cross-repo scope & ownership.** Is §8 a **two-repo feature** (webapp `../CISS` + mobile) and if so, do we own the web/API + Firestore work, or is that another team's? *Changes whether this is a mobile-only plan or a two-repo plan with a hard blocking dependency and build order.*
2. **§8.2 adhoc/permanent default (A vs B).** New TCS enrollments default **permanent** (A) or **adhoc** (B)? *Changes the enrollment flow, the backfill logic, and which set is curated.*
3. **Willingness lifecycle.** Can a guard change/withdraw a response? Is there a cutoff before the duty date? Do "willing" responses **reserve/reserve-cap** against `maleGuardsRequired`/`femaleGuardsRequired` (first-come) or are they just a **tally** for admins? *Changes the data model and whether the FO count is an oversubscribed list or a real capacity signal.*
4. **Backfill authority.** Confirm the Drive biometric list is **adhoc-only** (and current) and the monthly deployment sheet is **permanent**; who signs off the dry-run before the irreversible write? *A wrong assumption silently mislabels production guards.*
5. **Mobile role scope** for the first pass: Guard + FO only, or also the **region** officer?
6. **Nav changes**, especially the **new guard "Duties" tab** and the willingness entry point on Guard Home.
7. **Duty assignment (§8.5):** confirmed **informational** (no accept/decline gate; never blocks attendance). Still confirm: "center" = the existing **site** entity, and whether admin may also assign (recommended: yes).

**Builder's calls (settled here so planning can proceed):**
- Guards match to duties by **canonical district** (§8.4); "region" = the guard's administrative district.
- `tcsCategory` and `gender` are added to the mobile profile model + API (dependency on the web change).
- Willingness v1 is **declare-only** (no auto-assign).
- Motion: keep Flutter built-ins + springs; add `simple_animations` only if it removes real boilerplate.
- Shape-morph is scoped to the one primary CTA per hero screen.

**Open for planning (not blocking the design):** exact per-screen element budgets; which expanded components to adopt; the concrete haptic event→effect table; custody of the Drive files for the backfill.


## 11. Research Caveat

Standards above are grounded in official Android (`developer.android.com` M3 Expressive + haptics) and Flutter (`docs.flutter.dev`) material, plus Flutter community repos (`Solido/awesome-flutter`, `fluttergems/awesome-open-source-flutter-apps`). Reddit and several design forums blocked automated fetching; if community sentiment is required, provide specific threads or an alternate source and they will be folded in.

## 12. Verification

- `flutter analyze` = 0 errors/warnings (per `GEMINI.md`); `flutter test` green.
- Every redesigned screen: verified in simulator in **light + dark**, with long content, empty, loading, error states; safe areas/Dynamic Island/home indicator; Dynamic Type; 44 px targets; contrast.
- Motion: **full-flow screen recording** watched once for feel, once frame-by-frame; no dropped frames / wrong-theme flashes; Reduce Motion respected; 60 fps on release on the slowest supported device.
- Haptics: event→haptic table implemented consistently; verified on a device with a good actuator and one with a weak/no actuator (fallback).
- De-clutter: per-screen element budget met; no screen with two primary CTAs.
- Feature: classification backfill dry-run reviewed; willingness works offline and reconciles; FO/admin see willing counts per work order.
</content>
