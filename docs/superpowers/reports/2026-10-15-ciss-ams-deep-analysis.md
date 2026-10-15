# CISS-AMS 5.0.4 — deep REA analysis (MCP pass)

Target: `/Users/mymac/Downloads/CISS-AMS_5.0.4_APKPure.xapk`, root sha256 `d0b6967a3f69aae0b9b972c65fe93113d31b1c63bb81ad9ba1c85f5ad510aa73`. REA MCP server `rea-agents` 6.5.0, skill v42, provider set at the time of the run: artifact-graph, apktool, flutter, artifact (SQLite/Go/Rust/PE), managed, browser/Electron, adb — with **Hopper** available and **Ghidra/IDA/JADX/JEB/Binwalk/WABT/Wakaru/pwntools missing**.

## Evidence ledger (this pass)

| Observation | Evidence |
| --- | --- |
| XAPK inventory: 23 entries, 23 nodes, 22 edges, 0 integrity contradictions, `source_complete=true` | `ev_82c57149106d6ba5052d57ce1e86c4b9b25d6e2bbd08535e96bc5f0c6c780087` (summary view `ev_1f92876f…`), inventory `ev_25cc2482a13a06e267abd52c1065d9d77c2b288fef6e73006b9132e42747ed38` |
| Extraction of all 22 splits/files, containment verified, cleanup verified | `ev_65514e31b1d108d29699499167d4c6adb5870be1498495fe99a7c3996cea5162` |
| Decoded manifest + 115 android resource strings (apktool 3.0.3), 636 files decoded | `ev_ac9733831d0d6be22af0702f4b1998cb23aef9b31b48930da19af65920d80009` |
| Flutter build identity: snapshot hash `78da37fed6bf1489361a312568249f3f`, libapp.so 9,503,664 B, engine build id `d73e2148…`, clang 19.0.1 | `ev_59e64bb4dd88e88ab3dc44e1cfaa9b416426e49a7767928c3b259b6876f5b744` |
| Dart AOT snapshot: kind 3 (Dart 2.14 FullAOT layout), four sections with offsets/sizes, string-pool lower bounds (≥1000 package URIs, 212 dart URIs, ≥4000 class-like tokens among 26,633 printable runs) | `ev_719ae7f50e3b3aac7f67a33dcc28636694fb26fcdc840611db438e55e46f2897` (summary `ev_40cd896f…`) |
| Base APK graph: 540 nodes, 599 occurrences, 598 edges, 0 integrity contradictions | `ev_feffb6548c5f2e8c793cd0d8e8d208aa32f0b0edcb6bc5d077471fde18e85087` (summary `ev_c8631646…`), inventory `ev_e619962a06b5941bfc650d21a666757592d606f9b096f79d730f71143ae61e99` |
| Exact asset occurrences, hash-verified: `assets/flutter_assets/AssetManifest.bin` (6,671 B), `FontManifest.json` (953 B), `images/3d/salary.png` (14,486 B) | `ev_3baf6e947717c415802047acc7d317f10728b3f1a1fe8958f1f82cce934aa6a9` |
| Exact asset occurrences, hash-verified: `assets/animations/checkin.json` (841,791 B), `assets/animations/offline_server.json` (53,131 B), `assets/animations/location_permission.json` (20,751 B) | `ev_f21701444a4fe0239eb23853efe6c9e5541f3107734df3bb0ec7d496f87ba979` |

Findings from the extracted trees (asset listing, `*.properties`, `kotlin-tooling-metadata.json`) are ordinary-tool observations on REA-extracted files, not REA Evidence; they are marked below.

## Snapshot layout (`inspect_dart_aot`)

| Section | Offset | Size | Header |
| --- | --- | --- | --- |
| `_kDartVmSnapshotData` | 832 | 18,384 | magic valid, kind 3, header 16,844 |
| `_kDartIsolateSnapshotData` | 19,264 | 3,693,456 | magic valid, kind 3, header 3,048,158 |
| `_kDartVmSnapshotInstructions` | 3,735,552 | 92,704 | — |
| `_kDartIsolateSnapshotInstructions` | 3,828,288 | 5,628,912 | — |

The producer states plainly that string-pool entries are byte-pattern observations, that typed class/function recovery needs an SDK-specific parser, and that counts are lower bounds (500 of ≥1000 package URIs, 2000 of ≥4000 class-like tokens were returned). Everything below that depends on the pool therefore stays a lower bound.

## Component map

The application package is `fieldmanager_hrms_flutter` — a white-labelled commercial field-manager HRMS. Directory evidence: `screens/` (73 references), `models/` (25 groups), `service/`, `store/`, `api/`, `db/`, `db_models/`, `db_services/`, `locale/`, `utils/`, `Widgets/`, `dialog/`.

| Layer | What it does | Evidence type |
| --- | --- | --- |
| Feature modules | ATMs (assigned ATMs + checklist questions), Cart/Order/Product/Category, Client (+ skip/take paging), Document requests and types, Expense types, dynamic Form (+ form requests), Loan requests, Payment collection, Tasks, Visits (+ counts), chat, users, app/module settings | REA string pool |
| Reporting | `api/pdf_api.dart` plus native PDFium (`libjniPdfium`, `libmodpdfium`, `libmodft2`) and a `share_plus` file provider | string pool + manifest + ordinary-tool lib listing |
| Tracking | `service/LocationService.dart`, `db_models/tracking_model.dart`, `db_services/tracking_service.dart`, `db/database_context.dart`, `service/offline_sync_service.dart`; four location stacks declared (flutter_background_service with watchdog + boot receiver, background_location_tracker, geolocator, lyokone location) | string pool + manifest |
| Motion awareness | `flutter_activity_recognition` receiver/job service with `ACTIVITY_RECOGNITION` | manifest |
| Device cooperation | `ACCESS_BACKGROUND_LOCATION`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`, `disable_battery_optimization`, plus a `dialog_huawei_notification` string telling the user to mark the app as a "Protected App" and an `oppo.permission.OPPO_COMPONENT_SAFE` permission | manifest + resources |
| Localization | `locale/language_{en,hi,ar,fr}.dart` + `languages.dart` + `screens/language_screen.dart`; no app strings in Android resources | string pool + resources |
| Push/messaging | FCM with `high_importance_channel`, Firebase Installations/datatransport, Firebase Analytics (`firebase-measurement-connector`, CCT backend) | manifest + ordinary-tool `*.properties` |
| Icons/UI kit | Material Icons, LineAwesome (`nb_utils`), Iconsax, Font Awesome 7 (brands/regular/solid), CupertinoIcons | ordinary-tool `FontManifest.json` |
| Illustration/animation language | 3D-style PNG set (`images/3d/*`: salary, chart, money, visit, checklist, customers, route markers…), ten Lottie files (`assets/animations/checkin.json` 841 KB, `activity`, `success`, `failed`, `offline_server` 53 KB, `no_requests`, `location_permission` 21 KB, `screen_tap`, `phone_number_verification`, `sun`), GIFs and SVGs | REA inventory (hash-verified paths) + `AssetManifest.bin` strings |
| Build/runtime | Kotlin 2.2.0, Gradle 8.12, Java 17, `isHmppEnabled: true` (Huawei push capability enabled in the Kotlin settings, though no HMS service is declared in the manifest), `targetSdk 36`, `extractNativeLibs=false`, profileinstaller baseline profiles, Play split delivery | ordinary-tool metadata + manifest |

## What is worth adopting here, ranked

1. **Vendor-specific background-survival guidance.** Their `dialog_huawei_notification` string ("…need to be set as 'Protected App' in settings…") plus the Oppo permission show they treat OEM task-killers as a first-class problem. Our Tracking health card already reports the generic state; adding per-vendor autostart/battery deep links (Xiaomi, Realme/Oppo, Vivo, Huawei, Samsung) is the single highest-value parity item for an Indian guard fleet.
2. **Lottie state illustrations.** Ten purpose-built animations cover check-in, success, failure, offline, no-requests, and location-permission states. Our empty/error surfaces are static; adopting Lottie (or the animation set's structure) gives the same “the app is doing something” feedback during sync and permission flows.
3. **Firebase Analytics.** Their build carries Analytics/datatransport; ours carries Crashlytics only. Attendance completion, duty acceptance and sync failures are exactly the funnel that benefits.
4. **Native Google Maps with a curated marker set** versus our OSM tile overlay, which already failed with HTTP 400 in widget tests and depends on a public tile policy. This one is a product/cost decision (API key + Play services), not an automatic port.
5. **Baseline profiles** (`profileinstaller`) for faster cold start — cheap to add and measurable.

## What not to copy

A plaintext Google Maps API key in the manifest (`AIzaSy…`), `allowBackup` left at its default (PII in an unencrypted backup), legacy `WRITE_EXTERNAL_STORAGE`, four overlapping location stacks, and an "App Killer Manager" plugin string still merged into `strings.xml`. Also note their Android layer is still unanalysed on my side: `inspect_android_package`, `inspect_android_class` and `trace_android_references` are unavailable until `REA_JADX_MCP_JAR` points at a `jadx-headless-mcp 0.7.1` jar, so all Dalvik/Kotlin conclusions here stop at the manifest.

## Reproduce

```bash
npx -y rea-agents@6.5.0 mcp   # already registered for Codex
# in-session: open_binary the XAPK, then inspect_artifact / extract_artifact,
# identify_flutter_build + inspect_dart_aot on config.arm64_v8a.apk,
# decode_android_resources on com.users.ciss_flutter.apk
```

## Second pass — tools installed, Android layer unlocked

Prerequisites installed on this host, then re-verified with `rea doctor --json` (`healthy: true`; `ghidra`, `jadx`, `hopper` and the platform/architecture/installation/headless/JAVA checks all healthy; only `ghidra-native_decompiler` is `config_drift` because the official Ghidra 12.1.4 archive ships decompiler binaries for `linux_x86_64` and `win_x86_64` only, so no pseudocode on macOS/arm64):

| Tool | Where | Notes |
| --- | --- | --- |
| `jadx-headless-mcp` 0.7.1 fat jar | `/Users/mymac/.rea/tools/jadx-headless-mcp-0.7.1-all.jar` | sha256 `6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75`, verified identical to the upstream release digest ([1013503897/jadx-headless-mcp](https://github.com/1013503897/jadx-headless-mcp) v0.7.1) |
| Ghidra 12.1.4 PUBLIC | `/Users/mymac/.rea/tools/ghidra_12.1.4_PUBLIC` | 543 MB release zip, extracted |
| wabt 1.0.42 | `/opt/homebrew/opt/wabt/bin` | matches REA's required version |
| jadx 1.5.6 CLI | Homebrew | same jadx-core line as the MCP jar |
| OpenJDK 21 (arm64) | `/opt/homebrew/opt/openjdk@21` | the machine's default `java` is an x86_64 Temurin 25 that cannot run here; JAVA_HOME is now pinned for REA |

Homebrew also pulled `ca-certificates` (2026-09-25) and `openssl@4` as wabt dependencies and unlinked the previous `openssl@3` keg — a host-level side effect worth knowing about.

The tool paths are now wired into `[mcp_servers.rea.env]` in `~/.codex/config.toml` (`GHIDRA_INSTALL_DIR`, `REA_JADX_MCP_JAR`, `REA_WABT_BIN_DIRECTORY`, `JAVA_HOME`), with a backup at `~/.codex/config.toml.bak-20261015`. The running MCP server still holds its start-time environment, so a Codex restart is required before the in-session Android and Ghidra tools appear; this pass used the REA CLI, which reads the current shell environment.

### Definitive native plugin inventory

`inspect-android-package` (JADX 0.7.1, source revision `5844800a…`): **5,199 classes**, 598 resources, minSdk 24, targetSdk 36, 22 permissions, signature verification `not_performed`. App-owned classes are only `com.users.ciss_flutter.MainActivity` and `…R` — **every feature lives in the Dart snapshot**, so the sibling app has no hidden native feature logic.

`inspect-android-method` on `io.flutter.plugins.GeneratedPluginRegistrant.registerWith` gives the ground-truth plugin list, which supersedes my earlier `.properties` inference:

`background_location_tracker`, `battery_plus`, `connectivity_plus`, `device_info_plus`, `disable_battery_optimization`, `file_picker`, `firebase_core`, `firebase_messaging`, `flutter_activity_recognition`, `flutter_background_service_android`, `flutter_local_notifications`, `flutter_pdfview`, `flutter_plugin_android_lifecycle`, `flutter_udid`, `fluttertoast`, `geocoding_android`, `geolocator_android`, `google_maps_flutter_android`, `image_picker_android`, `jni`, `jni_flutter`, `local_auth_android`, `location`, `maps_launcher`, `mobile_scanner`, `nb_utils`, `package_info_plus`, `permission_handler_android`, `share_plus`, `shared_preferences_android`, `sqflite_android`, `url_launcher_android`, `vibration`, `webview_flutter_android`.

New relative to the earlier pass: **flutter_udid** (stable device identity), **geocoding**, **maps_launcher** (hand off to the Google Maps app), **jni/jni_flutter** (Dart→Java FFI rather than method channels), **flutter_local_notifications**, **flutter_pdfview**, **sqflite** + **shared_preferences** (local stores alongside the tracking DB), **webview_flutter**, **vibration**, **mobile_scanner** and **nb_utils** (the UI kit whose LineAwesome font appears in the asset inventory).

### Native layer of the Flutter engine payloads (Hopper)

`analyze` on `lib/arm64-v8a/libapp.so` (9,503,664 bytes, sha256 `b31954e4…`) with the Hopper provider: **17,857 procedures**, 3 segments, and only **2 typed strings**. That is expected and not a gap in the tooling: Hopper's string inventory covers native typed objects, while this binary is a Dart AOT snapshot whose data lives in the isolate pool that `inspect_dart_aot` already projected. `libflutter.so` (11,317,712 bytes, build id `d73e2148…`), `libmodpdfium.so`, `libbarhopper_v3.so` (ML Kit barcode), `libmodft2.so`, `libmodpng.so`, `libjniPdfium.so`, `libdartjni.so`, `libimage_processing_util_jni.so`, `libsurface_util_jni.so` and `libc++_shared.so` complete the native set. Recovering Dart *semantics* (classes, functions, field names) from the snapshot needs a Dart-specific parser such as blutter; REA does not ship one, so that remains an explicit unknown rather than something I inferred.

### Ghidra: installed but not bindable on this host

Ghidra 12.1.4 PUBLIC is installed and `rea doctor` reports `ghidra`, `ghidra-platform`, `ghidra-architecture`, `ghidra-installation`, `ghidra-version`, `ghidra-headless` and `ghidra-java` healthy, with `GHIDRA_INSTALL_DIR` and `JAVA_HOME` (arm64 OpenJDK 21) pinned. Binding it still fails with `provider_unavailable / executable_missing`: REA requires the host-native decompiler binary `Ghidra/Features/Decompiler/os/mac_arm_64/decompile`, and the official 12.1.4 archive ships `linux_x86_64` and `win_x86_64` only. Options, in order of effort: run REA on a Linux host for Ghidra-backed analysis, build Ghidra's decompiler from source for darwin/arm64, or keep using Hopper (which is what this pass did).

## Third pass — MCP after the toolchain restart

The Codex restart picked up `[mcp_servers.rea.env]`, so the Android provider is now live in-session. Because macOS purges `TMPDIR` between sessions, the artifact was re-extracted to a stable path (`/Users/mymac/.rea/targets/ciss-ams/`); the base APK digest is unchanged at `b0b7ceab…`, so this Evidence is directly comparable with the earlier passes.

| Observation | Evidence |
| --- | --- |
| Package identity via JADX 0.7.1: 5,199 classes, 598 resources, 22 permissions, minSdk 24 / targetSdk 36, signature verification `not_performed` | `ev_2fb7a12c7f3c9b9c7c3b371a635182110bde9734543cca94dcf8171995408464` (summary `ev_27c9ed372000f1358ae9d6b8a6a6adaef7f9b1ecea30dbdf849fee98dd1e345a`) |
| `BackgroundService` member inventory: 17 fields, 16 methods, 1 inner class | `ev_a58447ab938a086423e6bc685b48dda0701d2b1955eb7e792a113d233e106cfc` |
| Class search `flutter_background_service`: 8 classes | `ev_dcf25a11d96e742da57cf478ac21825f087ef7c611996119d95bf64efcaeffa0` |
| Class search `Integrity`: **zero matches**, coverage `complete` | `ev_12fc5eb1d7c5db976c3b78c42d3244e1b8156670c93035a3c88015ef9b1729e9` |
| `MainActivity` inventory and incoming references: 1 member (constructor), **0 references** | `ev_5a346060b4ebe0bfdb3bee9f481114fe8e5e1c2100c4a89cb3425e9af3f96ee7` |
| `BackgroundService.onStartCommand` decompiled (Java, no smali fallback) | `ev_1f0d4aa47c58405225f0598316f227f0b08adf22782218c277dd7c9bd4e6c30f` |

### How their tracking service actually stays alive

```java
@Override // android.app.Service
public int onStartCommand(Intent intent, int i, int i6) {
    this.config.setManuallyStopped(false);
    WatchdogReceiver.enqueue(this);
    runService();
    return 2;   // START_STICKY
}
```

START_STICKY plus re-enqueueing the watchdog on every start, backed by the declared `BootReceiver` (BOOT_COMPLETED / QUICKBOOT_POWERON / MY_PACKAGE_REPLACED), a `PowerManager.WakeLock` held through `getLock`/`LOCK_NAME`, a foreground notification channel whose title and body are updated at runtime (`notificationChannelId/Title/Content/Id`, `updateNotificationInfo`, `createNotificationChannel`), a `Pipe` listener for isolate↔service messaging, and `ForegroundTypeMapper` translating the Dart-declared type into `foregroundServiceType`. Our app runs the same plugin, so this is the mechanism we already inherit — worth knowing, not worth re-implementing.

### Two conclusions this pass settled

- **No hidden native logic.** `MainActivity` has no members beyond its constructor and no static referencing nodes, and the only app-owned classes in the whole dex are `MainActivity` and `R`. Every feature is Dart; the native side is stock Flutter plus 34 plugins. Plugin packages survive the app's minification intact (keep rules preserve `id.flutter.flutter_background_service.*` etc.), which is what made this ground-truth plugin list readable at all.
- **No Play Integrity or RASP in their build either.** A name search over the complete 5,199-class inventory returns zero matches for `Integrity`. Bounded honestly: a tamper-detection SDK renamed by the app's R8 pass would not match a name search, so this proves absence of a *recognisably named* attestation SDK, not absence of any tamper check. Our earlier gap list therefore stands for both apps, not just ours.

### Adoptable from their plugin set

Three plugins they ship that we do not, each with a concrete use in our app: **geocoding** (turn a punch's coordinates into a human address for site notes and client-facing muster rolls), **maps_launcher** (one-tap hand-off to Google Maps navigation from a duty or attendance entry, which matters on night shifts), and **flutter_udid** (stable device identity, the cheapest first step toward binding an attendance session to one device). **webview_flutter** is the fourth if we ever want in-app policy or document reading instead of pushing out to a browser. We already match them on local notifications, barcode scanning, camera capture, background service, activity recognition, biometrics and connectivity.
