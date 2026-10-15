# CISS-AMS 5.0.4 reverse engineering — 15 October 2026

Target: `/Users/mymac/Downloads/CISS-AMS_5.0.4_APKPure.xapk` (40 MB, package `com.users.ciss_flutter`, "CISS-AMS" 5.0.4 / versionCode 6, minSdk 24, targetSdk 36).

## Tooling actually used

REA is installed (skill v42, CLI 6.5.0) but not registered for Codex, so its MCP tools were unavailable in this session — `npx -y rea-agents@6.5.0 doctor --client codex --json` reports `registration:codex ... config_drift` and a missing JADX provider (`REA_JADX_MCP_JAR` unset). Registering needs `rea setup --client codex --yes` plus a Codex restart, which the user has to trigger. The CLI worked, and only its engine-free commands apply to a Flutter package: **REA Evidence** below comes from `identify-flutter-build`, `inspect-dart-aot`, `inspect-artifact` and `decode-android-resources` (raw JSON in `.superpowers/sdd/2026-10-15-ciss-ams-rea/`). Manifest details confirmed with apktool were cross-checked against REA's decoded-resources Evidence; anything from ordinary tools is labelled as such.

## What the artifact is

- Flutter app, arm64-v8a. `identify-flutter-build` Evidence `ev_2e97be3d…`: `libapp.so` 9,503,664 bytes, sha256 `b31954e4…`, Dart snapshot hash `78da37fed6bf1489361a312568249f3f`; `libflutter.so` 11,317,712 bytes with engine build id `d73e2148…`, built by clang 19.0.1 (Android r530567e).
- `inspect-dart-aot` (Evidence in `dart-aot.json`) exposes 500 package URIs, 212 dart URIs and 2,000 class-like tokens. The application package is **`fieldmanager_hrms_flutter`** — a white-labelled commercial HRMS/field-manager product, not a bespoke codebase. 73 screen references, 25 model groups, 6 services, 3 stores, 3 API files, 5 locale files.
- Modules visible in the Dart graph: `ATMs/assigned_atms_model`, `ATMs/check_list_questions_model`, `Cart/cart_model`, `Client/client_model(+skip_take)`, `Document/document_request_model`, `Document/document_type_model`, `Expense/expense_type_model`, `Form/form_model`, `Form/form_request_model`, `Loan/loan_request_model`, `Order/order_model`, `Order/order_count_model`, `Order/product_model`, `Order/product_category_model`, `PaymentCollection/payment_collection_model`, `Settings/app_settings_model`, `Settings/module_settings_model`, `Task/task_model`, `Visit/visit_model`, `Visit/VisitCountModel`, `chat_response`, `user_model`, `api_response_model`.
- Services: `api/api_service.dart`, `api/network_utils.dart`, `api/pdf_api.dart`, `service/LocationService.dart`, `service/AppStore.dart`, `service/SharedHelper.dart`, `service/module_service.dart`, `service/network_utils.dart`, `service/offline_sync_service.dart`, `service/permission_service.dart`, `db/database_context.dart`, `db_models/tracking_model.dart`, `db_services/tracking_service.dart`, `utils/map_helper.dart`, `locale/language_{en,hi,ar,fr}.dart` + `languages.dart`, `screens/language_screen.dart`, `screens/more_screen.dart`, `screens/splash_screen.dart`.

### How each component works

| Component | Mechanism (evidence) |
| --- | --- |
| Multi-language UI | `locale/language_en|hi|ar|fr.dart` maps + `screens/language_screen.dart` picker; not Android resource strings (the 115 decoded `strings.xml` entries are androidx/Material scaffolding only, plus a stray `app_name = App Killer Manager` from the battery plugin). |
| Continuous tracking | Four location stacks declared together (ordinary-tool manifest read, cross-checked with REA decoded resources): `flutter_background_service.BackgroundService` (type location, `stopWithTask=false`) with `WatchdogReceiver` + `BootReceiver` for `BOOT_COMPLETED`/`QUICKBOOT_POWERON`/`MY_PACKAGE_REPLACED`; `com.icapps.background_location_tracker.service.LocationUpdatesService`; `com.baseflow.geolocator.GeolocatorLocationService`; `com.lyokone.location.FlutterLocationService`. Plus `ACCESS_BACKGROUND_LOCATION`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`, and the `disable_battery_optimization` package. |
| Motion/activity awareness | `flutter_activity_recognition` receiver + job service with `ACTIVITY_RECOGNITION` (+ Play services variant). |
| Local persistence and replay | sqflite-style `db/database_context.dart` with `db_models/tracking_model.dart` and `db_services/tracking_service.dart`, driven by `service/offline_sync_service.dart`. |
| Reporting | `api/pdf_api.dart` + native PDFium (`libjniPdfium`, `libmodpdfium`, `libmodft2`) with `share_plus` file provider for handing documents to clients. |
| Scanning | ML Kit barcode (`play-services-mlkit-barcode-scanning`, `libbarhopper_v3`) — used for QR/tag capture. |
| Maps | Native Google Maps (`com.google.android.geo.API_KEY`, `play-services-maps`, maps-utils attribution) rather than a tile overlay. |
| Notifications | FCM with a dedicated `high_importance_channel` default channel and Firebase Analytics/datatransport present. |
| Media | `cached_network_image` for remote images, `image_picker`/`file_picker` providers, `badges`, `dotted_border`, `connectivity_plus`, `battery_plus`, `device_info_plus`, `archive`, `crypto`, `ffi`/`libdartjni`. |
| Distribution | Play-style split delivery (`com.android.vending.splits.required`, stamp `STAMP_TYPE_DISTRIBUTION_APK`), `android:extractNativeLibs="false"`, `targetSdk 36`, `profileinstaller` baseline profiles, `taskAffinity=""` on the launcher activity, no self-update APK gate. |

## What this app is missing relative to it (and was implemented)

1. Interface localization — implemented (en/hi/ml + persisted picker). Note AMS also ships Arabic and French, which this workforce does not need.
2. Battery-optimisation awareness for tracking — implemented as a user-initiated Tracking health card (location, battery, notifications, service state) with repairs; the restricted `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` grant is deliberately *not* declared because this repo's contract test forbids it.
3. Cached remote images — implemented.
4. Notification badges — implemented on both portals.
5. On-device PDF export — implemented for the muster roll.

## Not adopted, with reasons

Dynamic form/checklist engine, expense/loan/order/payment-collection modules (not part of guard or TCS duty operations), chat, and the four concurrent location stacks (two are redundant; ours uses one foreground service plus activity recognition). Play distribution, Play Integrity and RASP from the earlier gap report remain open items.
