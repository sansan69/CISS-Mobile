# Platform & Release Audit — CISS-Mobile

**Scope/method.** Static review of the Android and iOS platform layer, the in-app APK updater, Firebase/FCM wiring, CI/CD, dependency posture and release hygiene of `CISS-Mobile` (branch `wip/redesign-1.0.21`, HEAD `edfec10`, pubspec `1.0.22+22`), plus first-hand build verification. Evidence was gathered by reading `android/`, `ios/`, `lib/core/update/`, `lib/core/fcm/`, `.github/workflows/` and `pubspec.*`; by building `flutter build apk --release` and `flutter build appbundle --release` and inspecting the resulting artifacts with `aapt2`, `apksigner` and `unzip`; by running `flutter analyze`, `flutter pub outdated` and an OSV.dev batch query for every locked package; and by fetching the live update manifest from `https://cisskerala.site/api/public/app-update` (GET only, read-only) and verifying the published APK it points to. No product file, config or git state was modified. Commands run and raw results are reproduced inline under *Evidence*; every claim is tagged **[verified]** (observed directly in files, build output or HTTP responses) or **[inferred]** (reasoned from those observations). Baseline facts supplied by the Lead (155 Dart files / 45,973 lines, 167 tests pass, `dart analyze` 3 unused-import warnings, targetSdk 34) were consistent with what was observed.

## Findings

| ID | Severity | Title | Evidence | Confidence |
|---|---|---|---|---|
| P-01 | **High** | iOS target is non-shippable: no usage descriptions, background modes, entitlements or Podfile | `ios/Runner/Info.plist:4-48`, `ios/` (no `Podfile`), `ios/Runner.xcodeproj/project.pbxproj:353,375` | verified (static) |
| P-02 | **High** | `targetSdk = 34` cannot be uploaded to Google Play (API 36 required since 2026-08-31) | `android/app/build.gradle.kts:44`, built APK badging | verified config / policy inferred |
| P-03 | **High** | Only signed-release pipeline is red and was bypassed for 5 releases; live updater serves stale 1.0.21 | `.github/workflows/build-apk.yml:82`, `pubspec.yaml:19`, `git tag`, live `/api/public/app-update` | verified |
| P-04 | Medium | In-app updater trusts the update JSON end-to-end: no host allowlist, hash from same response, unverified browser fallback | `lib/core/update/app_update_service.dart:109-127`, `lib/core/update/app_update_gate.dart:85-94` | verified code / impact inferred |
| P-05 | Medium | Update download is not size-bounded, hashes an 86 MB file in RAM, and the disk-full path is dead code | `lib/core/update/apk_downloader.dart:55,65,100-107`, `app_update_gate.dart:299-305` | verified |
| P-06 | Medium | Fat universal APK (86.7 MB) is the self-update artifact although split APKs were shipped up to 1.0.16 | build output, `apk_downloader.dart:65`, GitHub release assets | verified |
| P-07 | Medium | Cleartext HTTP explicitly permitted for `*.cisskerala.site` (API + update host) | `android/app/src/main/res/xml/network_security_config.xml:3-5`, `AndroidManifest.xml:45` | verified config / risk latent |
| P-08 | Medium | `allowBackup="false"` alone does not stop Android 12+ D2D transfer; no `dataExtractionRules`/`fullBackupContent` | `AndroidManifest.xml:41`, `lib/main.dart:56-58` | verified config / behaviour inferred |
| P-09 | Medium | R8 runs, but no `proguard-rules.pro`, no mapping upload, no Crashlytics Gradle plugin, Dart code unobfuscated | `android/app/build.gradle.kts:60-66,73-78`, `build/app/outputs/mapping/release/mapping.txt`, `main.dart:74-77` | verified |
| P-10 | Low | Two plugin broadcast receivers exported without permission guard can poke the tracking service | `~/.pub-cache/.../flutter_background_service_android-6.3.1/android/src/main/AndroidManifest.xml:17-33` | verified |
| P-11 | Low | Sensitive permissions (`RECORD_AUDIO`, storage, boot) arrive silently from plugins into the release manifest | `aapt2` badging of `app-release.apk`, `AndroidManifest.xml:4-38` | verified |
| P-12 | Low | Dependency/toolchain staleness: Flutter 3.29.0 pinned, 35 deps behind, `hive` unmaintained since 2022, duplicate federated dep | `pubspec.yaml:19,58,64`, `.github/workflows/build-apk.yml:42`, `flutter pub outdated` | verified |
| P-13 | Info | Repo/release hygiene: `.gitignore` misses `android/build/`, 69 emulator screenshots and `mobile.env` in a **public** repo, notification icon/channel defaults | `.gitignore:33`, `git status`, `github api repos/sansan69/CISS-Mobile`, `notification_service.dart:86-88,209-231` | verified |

---

## P-01 — iOS target is non-shippable

**Severity:** High · **Confidence:** verified (static); iOS build itself not verifiable on this machine (see *Not verified*).

**Impact.** The product is described as Android+iOS, but as committed the iOS target cannot pass App Store review and would fault at the first permission request. `Info.plist` contains no `NS*UsageDescription` keys at all, so any call into `geolocator`, `camera`, `image_picker`, `local_auth` or `flutter_local_notifications` on iOS terminates the process (`TCC`/`permission_handler` will return `denied` or throw), and App Store Connect rejects the build with ITMS-90683 (missing purpose strings). There is also no `UIBackgroundModes: location` — background tracking, the core function of the app, silently dies when the app is backgrounded. No `aps-environment` entitlement exists, so APNs/FCM cannot obtain a token, and no `CFBundleURLTypes`/associated-domains are declared (no deep-link surface at all). Deployment target is iOS 13.0 with `CODE_SIGN_STYLE = Automatic` and no `DEVELOPMENT_TEAM`, so even a signed archive cannot be produced reproducibly from the repo.

**Evidence.**
- `ios/Runner/Info.plist:4-48` — the entire key set is `CFBundle*`, `LSRequiresIPhoneOS`, `UILaunchStoryboardName`, `UIMainStoryboardFile`, `UISupportedInterfaceOrientations(~ipad)`, `CADisableMinimumFrameDurationOnPhone`, `UIApplicationSupportsIndirectInputEvents`. Absent: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`, `NSMicrophoneUsageDescription`, `NSFaceIDUsageDescription`, `NSMotionUsageDescription`, `UIBackgroundModes`, `NSAppTransportSecurity`, `CFBundleURLTypes`, `FirebaseAppDelegateProxyEnabled`.
- `ios/` contains no `Podfile` and no `Podfile.lock`; `ios/.gitignore:13` ignores `**/Pods/`. With 20+ federated iOS plugins in `pubspec.yaml`, plugin versions are therefore unpinned and iOS dependency resolution is not reproducible.
- No `*.entitlements` file exists anywhere in `ios/` (`ls ios/Runner/*.entitlements` → no match), so there is no push, associated-domains or keychain-sharing entitlement and the `GoogleService-Info.plist` present at `ios/Runner/GoogleService-Info.plist` (bundle `co.in.ciss.cissMobile`) cannot deliver FCM.
- `ios/Runner.xcodeproj/project.pbxproj:353,479,530` — `IPHONEOS_DEPLOYMENT_TARGET = 13.0`; `:375,554,576` — `PRODUCT_BUNDLE_IDENTIFIER = co.in.ciss.cissMobile`; `:339,459,516` — `CODE_SIGN_IDENTITY[sdk=iphoneos*] = "iPhone Developer"` (legacy identity name, no team).
- `ios/Runner/AppDelegate.swift:1-13` is the bare template (`GeneratedPluginRegistrant.register` + `super.application`), which is sufficient for Firebase only with method swizzling enabled; no `UNUserNotificationCenter` delegate is set.
- Cosmetic/branding skew: `CFBundleDisplayName` is `Ciss Mobile` (`Info.plist:8`) versus `CISS Workforce` on Android (`AndroidManifest.xml:42`).
- Orientation skew: `Info.plist:31-36` allows landscape on iPhone while `lib/main.dart:45` locks `portraitUp`; Android's manifest relies on the same runtime lock only (`AndroidManifest.xml:72`).

**Remediation.** Add to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>CISS Workforce uses your location during duty to record attendance and patrol checkpoints.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>CISS Workforce records your location while you are on duty, including when the app is in the background, so supervisors can verify site coverage.</string>
<key>NSCameraUsageDescription</key>
<string>Used to capture attendance selfies and incident photos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to attach photos to incident and attendance reports.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Used to save report attachments you create.</string>
<key>NSFaceIDUsageDescription</key>
<string>Face ID unlocks CISS Workforce instead of re-entering your password.</string>
<key>NSMotionUsageDescription</key>
<string>Used to distinguish still / walking / in-vehicle duty states for tracking accuracy.</string>
<key>UIBackgroundModes</key>
<array><string>location</string><string>fetch</string><string>remote-notification</string></array>
```

Then: commit a `ios/Podfile` with `platform :ios, '13.0'` (or raise to 15.0 and bump `IPHONEOS_DEPLOYMENT_TARGET`), run `pod install`, commit `ios/Podfile.lock`; add `ios/Runner/Runner.entitlements` with `aps-environment` and wire it via `CODE_SIGN_ENTITLEMENTS`; enable the Push Notifications and Background Modes capabilities in the Xcode project; set `DEVELOPMENT_TEAM`. Keep ATS at its secure default (do **not** add `NSAllowsArbitraryLoads`) since the API is HTTPS-only.

**Verification.** `grep -c "UsageDescription" ios/Runner/Info.plist` returns ≥ 7; `plutil -lint ios/Runner/Info.plist` passes; `xcodebuild -showBuildSettings -workspace ios/Runner.xcworkspace -scheme Runner | grep -E "PRODUCT_BUNDLE_IDENTIFIER|DEVELOPMENT_TEAM|CODE_SIGN_ENTITLEMENTS"` shows a team and the entitlements path; a debug run on a device opens the system location prompt instead of crashing; `pod install` produces a committed `Podfile.lock`.

---

## P-02 — `targetSdk = 34` cannot be uploaded to Google Play

**Severity:** High · **Confidence:** config verified; Google Play requirement inferred from published policy pages.

**Impact.** Google Play requires new apps **and app updates** to target Android 16 (API 36) for anything submitted after 2026-08-31 ([Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878), [developer.android.com target-sdk](https://developer.android.com/google/play/requirements/target-sdk)); a short extension window has been offered to 2026-11-01 in some regions. As of this audit (2026-10-22) `targetSdk = 34` means every AAB produced by this repo is rejected at upload, so the Play channel is closed and the team has been forced onto sideload distribution — which is exactly what P-03 documents. Separately, running with `targetSdk 34` on Android 15/16 devices forfeits platform-enforced hardening (e.g. stricter foreground-service and notification behaviour, mandatory edge-to-edge) and shows the "built for an older version of Android" compatibility warning.

**Evidence.**
- `android/app/build.gradle.kts:44` — `targetSdk = 34`; `:28` `compileSdk = 36`; `:43` `minSdk = 24`.
- Built artifact confirms the pair is actually compiled in: `aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk` → `targetSdkVersion:'34'`, `minSdkVersion:'24'`, `compileSdkVersion='36'`, `versionCode='22' versionName='1.0.22'`.
- `Memory.md:30` records that `targetSdk = 34` was pinned deliberately ("W-P1-16"), i.e. this is a conscious legacy decision that has now expired.
- No `Play`/`supply` publishing step exists in `.github/workflows/build-apk.yml`, so nothing in automation would have caught the policy deadline.

**Remediation.** Set `targetSdk = 36` in `android/app/build.gradle.kts:44` and re-verify the two behaviours that actually change between 34 and 36 for this app: (a) foreground-service launch restrictions — the `location` FGS must only be started while an activity is visible (`lib/core/location/background_tracking_service.dart:41-49` already uses `autoStart: false`, and `lib/main.dart:103-105` gates init on notification permission, so this is likely fine); (b) edge-to-edge enforcement — `lib/main.dart:44` already sets `SystemUiMode.edgeToEdge`, but `android/app/src/main/res/values/styles.xml` should use `Theme.AppCompat.Light.NoActionBar` with `android:windowOptOutEdgeToEdgeEnforcement` removed. Do not raise `minSdk` (24 is fine and keeps the fleet's cheap hardware). Add a `targetSdkVersion >= 36` assertion to CI so this cannot silently regress:

```yaml
- name: Enforce Play target API policy
  run: |
    sdk="$(grep -oE 'targetSdk *= *[0-9]+' android/app/build.gradle.kts | grep -oE '[0-9]+')"
    [ "$sdk" -ge 36 ] || { echo "targetSdk $sdk < 36: Play upload will be rejected"; exit 1; }
```

**Verification.** `flutter build appbundle --release` then `bundletool dump manifest --bundle build/app/outputs/bundle/release/app-release.aab | grep targetSdk` shows 36; `aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk | grep targetSdk` shows 36; a full regression pass of background tracking on an API 34 and an API 36 device (start duty tracking, lock screen, verify samples continue) plus a notification-permission-denied run (must not crash).

---

## P-03 — The only signed-release pipeline is red and has been bypassed for five releases

**Severity:** High · **Confidence:** verified.

**Impact.** Two independent facts combine into a release-integrity problem. (1) The workflow's gate `flutter analyze` **fails today**, so the one pipeline that builds a signed, certificate-checked artifact cannot complete. (2) The last tag and the last GitHub release are `v1.0.17` (2026-07-30) while the tree is at `1.0.22+22`, so versions 1.0.18–1.0.22 were built and distributed outside CI — without the certificate pin (`ANDROID_SIGNING_CERT_SHA256`), without `SHA256SUMS.txt`, without the AAB artifact and without provenance. The live update channel confirms the effect: `/api/public/app-update` still advertises **1.0.21**, released 2026-08-10, and its APK is not a GitHub release artifact at all. Users therefore receive builds whose source commit cannot be tied to the distributed binary, and the version-advertised state lags the code by one release.

**Evidence.**
- `flutter analyze` (run in the repo): `3 issues found.` — `warning • Unused import: 'package:flutter/foundation.dart' • lib/features/auth/application/auth_controller.dart:3:8`, `warning • Unused import: '../../../shared/widgets/brand_banner.dart' • lib/features/auth/presentation/permission_onboarding_screen.dart:9:8`, `warning • Unused import: 'package:ciss_mobile/core/haptics/haptic_event.dart' • test/de_clutter_primitives_test.dart:6:8`; **`EXIT=1`**. `.github/workflows/build-apk.yml:82` runs `- run: flutter analyze`, so the job aborts before the build steps at `:85-88`.
- `.github/workflows/build-apk.yml:46-67` enforces `pubspec.yaml` version == release tag and all five signing secrets; `:69-79` materialises the keystore from `ANDROID_KEYSTORE_BASE64`; `:90-116` verifies the signing certificate SHA-256 against the pinned secret and writes `SHA256SUMS.txt`. These controls only run for `v*` tags (`:10-12`).
- `git tag` / `git ls-remote --tags origin`: newest tag is `v1.0.17` (2026-07-30). `github.com/api/repos/sansan69/CISS-Mobile/releases` (public): newest release `v1.0.17` 2026-07-30 with assets `app-release.aab`, `app-release.apk`, `SHA256SUMS.txt`, `signing-certificate.txt`. `git log --oneline v1.0.17..HEAD` = 33 commits.
- Live `GET https://cisskerala.site/api/public/app-update` (HTTP 200, Vercel, `strict-transport-security: max-age=63072000`) returns: `latestVersionName:"1.0.21"`, `latestVersionCode:21`, `minimumSupportedVersionCode:13`, `apkUrl:"https://cisskerala.site/downloads/ciss-workforce-1.0.21.apk"`, `sha256:"9819487575e173384507a9133b36eda5919e2a5ab35603d0d262ccc2817a304f"`, `sizeBytes:85945160`, `releaseDate:"2026-08-10"`.
- Positive control re-verified end-to-end: downloading that APK yields exactly `85945160` bytes with SHA-256 `9819487575e173384507a9133b36eda5919e2a5ab35603d0d262ccc2817a304f` (matches the manifest), `versionCode='21' versionName='1.0.21'`, and signer certificate SHA-256 `e5ee3fd603d258abe3bcf0364589dc13c2e8afcc3c063d33edbb68cf1b5c29aa` — identical to the certificate produced by a local release build (§Build results), so the published binary is at least from the same signing key. **[verified]**
- Production key custody **[inferred]**: because the local keystore's certificate equals the published APK's certificate, `android/app/ciss-release.keystore` is the production key, held on a developer machine, with the store/key passwords in plaintext in `android/key.properties` (present locally, correctly git-ignored — `git log --all -- android/key.properties android/app/ciss-release.keystore` is empty, so neither has ever been committed).

**Remediation.** (a) Make the gate green by deleting the three unused imports, or downgrade the CI step to `flutter analyze --no-fatal-infos --no-fatal-warnings` only if the team consciously accepts warnings — the three imports are trivial to remove, so fix them. (b) Re-establish tagged releases: tag `v1.0.22` on the commit that ships 1.0.22, let the workflow produce the AAB/APK/SHA256SUMS/certificate, and only then update the backend's update manifest from the generated `SHA256SUMS.txt` — never by hand. (c) Move to Play App Signing so the upload key is not the app signing key, and inject the keystore only through CI secrets; keep the local keystore offline as a rotation backup. (d) Add a release-manifest automation step so the endpoint cannot drift:

```yaml
- name: Publish update manifest
  run: |
    ver=$(awk -F'[ +]' '/^version:/ {print $2}' pubspec.yaml)
    code=$(awk -F'[ +]' '/^version:/ {print $3}' pubspec.yaml)
    sha=$(grep -F 'app-release.apk' build/SHA256SUMS.txt | cut -d' ' -f1)
    size=$(stat -c%s build/app/outputs/flutter-apk/app-release.apk)
    jq -n --arg v "$ver" --argjson c "$code" --arg s "$sha" --argjson sz "$size" \
      '{platform:"android",packageName:"co.in.ciss.ciss_mobile",latestVersionName:$v,latestVersionCode:$c,sha256:$s,sizeBytes:$sz,apkUrl:("https://cisskerala.site/downloads/ciss-workforce-"+$v+".apk"),mandatory:false}' \
      > build/app-update.json   # uploaded by the same job, then deployed to the API host
```

**Verification.** `flutter analyze; echo $?` returns 0; `git tag -l 'v1.0.2*'` lists `v1.0.22`; the workflow run for `v1.0.22` is green and its artifact contains `signing-certificate.txt` whose digest equals `ANDROID_SIGNING_CERT_SHA256`; after deploying the manifest, `curl -s https://cisskerala.site/api/public/app-update | jq -r '.latestVersionCode,.sha256'` matches the tag's `SHA256SUMS.txt`; a device on 1.0.21 sees the update dialog and installs 1.0.22.

---

## P-04 — The in-app updater trusts the update document end-to-end

**Severity:** Medium · **Confidence:** code verified; exploitability inferred (mitigated by Android's install-time signature check).

**Impact.** `AndroidUpdateInfo.apkUrl` and `AndroidUpdateInfo.sha256` are both read from the same unauthenticated JSON document fetched from `activeApiUrl` (`app_update_service.dart:109-127`). The SHA-256 comparison in `apk_downloader.dart:103` therefore proves only that the file matches *the server's own claim* — it is an integrity/transport check, not an authenticity check. Nothing constrains `apkUrl` to `https`, to `cisskerala.site`, or to the `/downloads/` path, and nothing checks the downloaded APK's package name or signing certificate before handing it to the package installer. The residual exploit is bounded by Android's own rule that an update must be signed by the installed app's key, so code substitution over the existing package is blocked — but an attacker positioned to control the update document (compromised API, poisoned region config, or a downgrade of `activeApiUrl` to plaintext) can still force every device to fetch and prompt-install an arbitrary 86 MB APK, i.e. coercion, wasted metered data, and confusing "App not installed" failures. The browser fallback is weaker still: `_browserFallback` hands `Uri.tryParse(update.apkUrl)` straight to `launchUrl(..., LaunchMode.externalApplication)` with **no** hash or host validation, so anything the server names is opened in the browser.

**Evidence.**
- `lib/core/update/app_update_service.dart:39` — `apkUrl: (json['apkUrl'] as String?) ?? (json['apkPath'] as String?) ?? ''`; `:40` — `sha256: (json['sha256'] as String?) ?? ''`; `:109-110` — `final baseUrl = _regionService.activeApiUrl...; Uri.parse('$baseUrl/api/public/app-update')`; `:122-128` — parses the JSON and compares only `latestVersionCode > currentBuild`.
- `lib/core/region/region_service.dart:375-386` — `activeApiUrl` returns a **server-provided** `RegionInfo.apiUrl` for non-KL regions, so the update host itself is remote-controlled.
- `lib/core/update/apk_downloader.dart:69-76` — plain `_dio.get(apkUrl, ...)` with no scheme/host check; `:103` — `actualHash.toLowerCase() != expectedSha256.toLowerCase()`.
- `lib/core/update/app_update_gate.dart:85-94` — `_browserFallback` parses and launches the URL without validation; called on install-permission refusal (`:372,378,394`).
- `android/app/src/main/kotlin/co/in/ciss/ciss_mobile/ApkInstallerPlugin.kt:77-106` — copies `sourcePath` verbatim into `cacheDir/android_updates/ciss-update-install.apk` and fires `ACTION_VIEW`; no `PackageManager` inspection of the candidate APK.
- `AndroidManifest.xml:38` declares `REQUEST_INSTALL_PACKAGES`, which is what makes this path possible.

**Remediation.** Validate before download and before install:

```dart
// app_update_service.dart — after parsing, before returning an update
static const _allowedHosts = {'cisskerala.site', 'www.cisskerala.site'};
bool _isTrustedApkUrl(String raw) {
  final uri = Uri.tryParse(raw);
  return uri != null &&
      uri.scheme == 'https' &&
      _allowedHosts.contains(uri.host) &&
      uri.path.startsWith('/downloads/') &&
      !uri.hasQuery &&
      !uri.hasFragment;
}
// then: if (!_isTrustedApkUrl(update.apkUrl) || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(update.sha256)) return null;
```

Additionally: (a) reject non-`https`/non-allowlisted URLs in `_browserFallback` (same predicate) and prefer `LaunchMode.inAppBrowserView` or a `canLaunchUrl` + scheme allowlist; (b) before `installUpdate`, verify the file with `PackageManager.getPackageArchiveInfo(path, GET_SIGNING_CERTIFICATES)` — matching `packageName == context.packageName` and the signer digest of the installed app — and abort otherwise; (c) long term, publish the update manifest with a signature (Ed25519 over `{versionCode, apkUrl, sha256}`) verified against a pinned public key, so a compromised API host cannot redirect the channel. For Play-distributed builds, replace this entire mechanism with `in_app_update` (Play Core) and drop `REQUEST_INSTALL_PACKAGES`, both because Play's Device & Network Abuse policy scrutinises self-installation and because the current flow duplicates a channel Play already signs.

**Verification.** Unit-test the predicate with cases: `http://cisskerala.site/x.apk` → reject, `https://evil.example/x.apk` → reject, `https://cisskerala.site/downloads/ciss-workforce-1.0.22.apk` → accept, malformed sha → reject. Instrumentation test: point the client at a local fake manifest whose `apkUrl` is off-host and assert no network request leaves the device. Manual: tamper the downloaded APK's last byte and confirm `ApkHashMismatchError` still aborts before any installer intent.

---

## P-05 — Update download is unbounded and the disk-full path is dead code

**Severity:** Medium · **Confidence:** verified.

**Impact.** For the target fleet (low-end Android, 2–3 GB RAM, metered data) the updater has three concrete failure modes. (1) `file.readAsBytes()` loads the whole 85–87 MB APK into the Dart heap to compute SHA-256, on top of the `sha256.convert` copy — a transient spike of ~170–260 MB that can OOM-kill the app mid-update on a device already holding a Flutter engine and a camera session. (2) `expectedSizeBytes` is used only for the progress percentage; nothing aborts a response that is larger than advertised, so a hostile or broken server can stream until the disk fills. (3) `ApkDiskFullError` is defined and caught (`app_update_gate.dart:299-305`) but **never thrown** anywhere in `apk_downloader.dart` — there is no free-space check at all, so a full disk surfaces as an opaque `Download failed: …` at best, or a silently truncated file that then fails the hash check. Timeouts are also one-sided: `receiveTimeout: 120s` bounds inter-chunk gaps, not total duration, and there is no `connectTimeout`/`sendTimeout`.

**Evidence.**
- `lib/core/update/apk_downloader.dart:55` — `required int expectedSizeBytes` used only at `:87-92` for the percentage; `:82-94` — the stream loop writes chunks with no running total cap.
- `lib/core/update/apk_downloader.dart:100-101` — `final fileBytes = await file.readAsBytes(); final actualHash = sha256.convert(fileBytes).toString();`.
- `lib/core/update/apk_downloader.dart:23-31` — `ApkDiskFullError` declared with a helper `_mb`; `grep -n "ApkDiskFullError"` shows no `throw` site (only the class and the `catch` in the gate at `:299`).
- `lib/core/update/apk_downloader.dart:46` — `Dio()` constructed with defaults (no timeouts); `:71-75` — only `responseType` and `receiveTimeout` overridden.
- Artifact size measured locally: `86,709,865` bytes (§Build results); the live manifest advertises `85,945,160` bytes for 1.0.21.

**Remediation.** Stream the digest and enforce the cap:

```dart
final output = AccumulatorSink<Digest>();
final hasher = sha256.startChunkedConversion(output);
final free = await _freeBytesFor(cacheDir);          // package:disk_space_plus or statvfs
if (expectedSizeBytes > 0 && free < expectedSizeBytes * 1.2) {
  throw ApkDiskFullError(expectedSizeBytes, free);
}
int received = 0;
await for (final chunk in response.data!.stream) {
  received += chunk.length;
  if (expectedSizeBytes > 0 && received > expectedSizeBytes) {
    throw ApkNetworkError('Server sent more bytes than advertised'); // aborts, cleans up in catch
  }
  hasher.add(chunk);
  sink.add(chunk);
}
hasher.close();
final actualHash = output.events.single.toString();
```

Also pass `Options(connectTimeout: const Duration(seconds: 15), sendTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 60))` and prefer `downloadOptions`/`Range` resume for an 86 MB payload.

**Verification.** Unit test with a fake `Dio` (`ResponseBody` stream) that emits `expectedSizeBytes + 1` bytes and asserts `ApkNetworkError` plus deletion of the partial file; unit test with a temp dir and an injected free-space value of 10 MB asserting `ApkDiskFullError`. On a 2 GB-RAM device, watch `adb shell dumpsys meminfo co.in.ciss.ciss_mobile` during a real update — peak PSS should no longer jump by ~170 MB and the installer intent must still fire.

---

## P-06 — The self-update artifact is a 86.7 MB fat APK

**Severity:** Medium · **Confidence:** verified.

**Impact.** `flutter build apk --release` produces a universal APK containing four ABIs (`arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`) totalling 86.7 MB, while the AAB is 45.3 MB. That fat APK is what the updater downloads (`ApkDownloader` fetches `apkUrl` as-is) and what the backend serves (live manifest `sizeBytes: 85,945,160` for 1.0.21). A field guard on ₹100/month mobile data spends ~86 MB per update, and the download is re-attempted from scratch on any failure (no resume, see P-05). Emulator ABIs account for roughly 15 MB of pure waste on real devices. Earlier releases shipped per-ABI APKs (`ciss-mobile-arm64-v8a-v1.0.16.apk` / `ciss-mobile-armeabi-v7a-v1.0.16.apk` on GitHub), so this is a regression introduced with `v1.0.17`.

**Evidence.** `unzip -l build/app/outputs/flutter-apk/app-release.apk` → 631 files, 86,709,865 bytes total; `lib/arm64-v8a/libapp.so` 9,307,040 + `libflutter.so` 11,057,104 + `libbarhopper_v3.so` 4,946,720; matching blocks for `armeabi-v7a`, `x86`, `x86_64`. `build/app/outputs/bundle/release/app-release.aab` = 45,311,894 bytes. GitHub releases list for v1.0.15/1.0.16 shows per-ABI asset names; v1.0.17 shows a single `app-release.apk`.

**Remediation.** Publish per-ABI artifacts and teach the updater to pick one, or move to Play (which splits the AAB itself):

```bash
flutter build apk --release --split-per-abi     # app-arm64-v8a-release.apk (~28-32 MB), -armeabi-v7a, -x86_64
flutter build apk --release --target-platform android-arm64   # single ABI, simplest for a fleet that is all arm64
```

and extend the manifest with per-ABI URLs+hashes:

```json
{"apkUrl":{"arm64-v8a":"https://cisskerala.site/downloads/ciss-workforce-1.0.22-arm64.apk"},
 "sha256":{"arm64-v8a":"…"}, "sizeBytes":{"arm64-v8a":31234567}}
```

selecting by `Abi.current()` on the Dart side (with a universal `apkUrl` kept as fallback). Also enable `--obfuscate --split-debug-info=build/symbols` alongside this to keep the AOT snapshot small and unreadable (see P-09).

**Verification.** `flutter build apk --release --split-per-abi && ls -lh build/app/outputs/flutter-apk/` shows an arm64 artifact well under 40 MB; install the arm64 APK on a device (`adb install -r`) and confirm cold start; update from 1.0.21 to the new artifact on a device and observe the download size in the dialog matching the per-ABI byte count.

---

## P-07 — Cleartext HTTP is explicitly permitted for the API and update host

**Severity:** Medium · **Confidence:** config verified; current exploitability latent (no `http://` URL exists in Dart today).

**Impact.** `network_security_config.xml` carves out `cisskerala.site` **with `includeSubdomains="true"`** from the platform's cleartext ban. `targetSdk 34` means `usesCleartextTraffic` defaults to `false`, so this file is the single place that re-opens plaintext for the app's most sensitive host — the same origin that serves the auth API, the region configs and the APK downloads. Today every Dart URL is `https://` (`grep -rn "http://" lib --include=*.dart` → no matches), so this is a latent downgrade rather than an active hole; but any future `http://` literal, any server-side redirect, any SDK that probes an `http://` variant, or a `RegionInfo.apiUrl` supplied over a tampered response would be silently accepted and MITM-able — and for `/downloads/*.apk` the only remaining guard is the SHA-256 from the same untrusted document (P-04).

**Evidence.** `android/app/src/main/res/xml/network_security_config.xml:3-5` — `<domain-config cleartextTrafficPermitted="true"><domain includeSubdomains="true">cisskerala.site</domain></domain-config>`; no `<base-config>`. Wired in at `AndroidManifest.xml:45` (`android:networkSecurityConfig="@xml/network_security_config"`). The merged release manifest carries no `android:usesCleartextTraffic` attribute (verified in `aapt2 dump xmltree`), i.e. the default `false` plus this one exception. The live host serves HSTS (`strict-transport-security: max-age=63072000`), which the platform's cleartext policy does not consult for a *native* client, so HSTS cannot compensate here.

**Remediation.** Replace the file with a deny-by-default policy that still pins nothing risky:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false" />
    <!-- Cleartext deliberately NOT permitted for cisskerala.site: the API and
         the APK download host are HTTPS-only (HSTS max-age=63072000). -->
</network-security-config>
```

If a temporary debug-only exception is genuinely needed, put it in `android/app/src/debug/res/xml/network_security_config.xml` so it never reaches release artifacts. Optionally add `<domain-config><domain>cisskerala.site</domain><pin-set expiration="...">` for certificate pinning **only** if the team can operate pin rotation — a bad pin is worse than no pin.

**Verification.** Rebuild, then `aapt2 dump xmltree --file res/xml/network_security_config.xml build/app/outputs/flutter-apk/app-release.apk` shows `cleartextTrafficPermitted=false` (or no exception); add a test that constructs `Uri.parse(baseUrl)` for every configured regional `apiUrl` and asserts `scheme == 'https'`; smoke-test login, attendance and an update check on a device behind a proxy that blocks :80 to prove nothing falls back to cleartext.

---

## P-08 — Backup exclusion is incomplete on Android 12+

**Severity:** Medium · **Confidence:** config verified; the D2D behaviour is documented platform behaviour.

**Impact.** `android:allowBackup="false"` is set (correctly), but for apps running on Android 12+ it disables only cloud (Google Drive) backup, **not** device-to-device transfer — Android's own 12.0 behaviour-change notes state that `allowBackup="false"` "disables Google Drive backups but does not disable D2D transfer", and `android:dataExtractionRules` / `android:fullBackupContent` are the supported controls. Because neither is declared, app-private data participates in migration: the Hive `draft` box, which `lib/main.dart:56-58` explicitly opens **unencrypted** ("Non-encrypted for high-frequency drafts"), plus `shared_prefs` and the app-lock/tracking-session stores, can be copied to a new device. Notifications and shared key material are what make this more than cosmetic: `flutter_secure_storage` keys live in the Android Keystore, which does *not* migrate, so migrated ciphertext is unreadable — but the plaintext drafts (potentially customer names, incident narrative, site notes) arrive intact and bypass any assumption that biometric-gated data stays on the enrolled device.

**Evidence.** `android/app/src/main/AndroidManifest.xml:41` — `android:allowBackup="false"`; the `<application>` tag (`:40-45`) has no `android:dataExtractionRules` and no `android:fullBackupContent`. `lib/main.dart:54-58` — `Hive.openBox<Map>(OfflineQueue.boxName, encryptionCipher: cipher)` (encrypted) versus `Hive.openBox<Map>(DraftService.boxName)` with the comment "Non-encrypted for high-frequency drafts". Merged release manifest confirms `allowBackup=false` and the absence of any extraction-rules attribute (`aapt2 dump xmltree` on `AndroidManifest.xml`).

**Remediation.** Declare explicit rules for both channels and wire them in:

```xml
<!-- android/app/src/main/res/xml/data_extraction_rules.xml -->
<data-extraction-rules>
    <cloud-backup><exclude domain="root" /><exclude domain="file" /><exclude domain="database" /><exclude domain="sharedpref" /><exclude domain="external" /></cloud-backup>
    <device-transfer><exclude domain="root" /><exclude domain="file" /><exclude domain="database" /><exclude domain="sharedpref" /><exclude domain="external" /></device-transfer>
</data-extraction-rules>
```

```xml
<application android:allowBackup="false"
             android:fullBackupContent="false"
             android:dataExtractionRules="@xml/data_extraction_rules" ... >
```

Keep `allowBackup="false"` (it covers Android 11 and below). Independently, treat the draft box as sensitive: encrypt it with the same offline-queue cipher (`lib/main.dart:55`) — the "high-frequency" argument is a performance trade-off that a field device does not need (drafts are written on human timescales).

**Verification.** `aapt2 dump xmltree --file AndroidManifest.xml build/app/outputs/flutter-apk/app-release.apk | grep dataExtractionRules` shows the attribute; on an Android 14 device run `adb shell cmd device_config`-independent check by performing a D2D transfer (or `adb backup` on API ≤ 31) and confirm `draft.hive` is absent from the new device; unit test that a newly written draft cannot be read from a box opened without the cipher.

---

## P-09 — R8 runs, but its output and the Dart symbols are not retained, and nothing deobfuscates crashes

**Severity:** Medium · **Confidence:** verified.

**Impact.** Two gaps that both look like "release hardening" and both bite in production. (1) Flutter's Gradle plugin turns on `minifyEnabled(true)` and `shrinkResources(true)` for release (confirmed by the R8 outputs in the build), but `android/app/` ships **no** `proguard-rules.pro`, so the only keep rules are AAPT-generated ones plus Flutter's `flutter_proguard_rules.pro`. Any reflection-based library added later can be shrunk away and fail only in release builds. (2) Nothing symbolises crashes: the workflow uploads only the AAB/APK/`SHA256SUMS.txt`/`signing-certificate.txt` (`build-apk.yml:118-127`), the 55.9 MB `mapping.txt` is discarded with the runner, `com.google.firebase.crashlytics` is not applied in `android/app/build.gradle.kts:3-8`, and Dart is compiled without `--obfuscate`/`--split-debug-info`. Net effect: R8-mangled native frames in Crashlytics are unreadable (no mapping), while the Dart logic in `libapp.so` retains full symbol names and is straightforward to lift with `strings`/`ghidra` — relevant for an app that holds session tokens, PINs and location history.

**Evidence.** `build/app/outputs/mapping/release/` contains `mapping.txt` (55,950,229 B), `configuration.txt` (56,377 B), `seeds.txt`, `usage.txt`, `resources.txt` after `flutter build apk --release` — proof R8 and the resource shrinker ran. Cause: `flutter.groovy:342-345` (`minifyEnabled(true)`, `shrinkResources(isBuiltAsApp(project))`, `proguardFiles(..., "proguard-rules.pro")`). `ls android/app/proguard-rules.pro` → does not exist. `android/app/build.gradle.kts:3-8` — plugins are `com.android.application`, `com.google.gms.google-services`, `kotlin-android`, `dev.flutter.flutter-gradle-plugin` (no crashlytics plugin). `.github/workflows/build-apk.yml:85-88` builds `appbundle` + `apk` with no `--obfuscate`/`--split-debug-info`; `:118-127` uploads only `app-release.aab`, `app-release.apk`, `SHA256SUMS.txt`, `signing-certificate.txt`.

**Remediation.** Add `android/app/proguard-rules.pro` (initially just documenting intent, so additions have somewhere to go), apply the Crashlytics Gradle plugin so mapping is uploaded on every build, and obfuscate Dart with retained symbols:

```kotlin
// android/app/build.gradle.kts plugins { … id("com.google.firebase.crashlytics") }
```

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols --extra-gen-snapshot-options=--no-strip
```

and add `build/symbols/**`, `build/app/outputs/mapping/**` to the uploaded artifacts (`actions/upload-artifact@v4` in the same job), plus a release note telling support how to `flutter symbolize -i <stack> -d build/symbols/`.

**Verification.** `ls build/app/outputs/mapping/release/mapping.txt` exists **and** the CI artifact contains it after a tag build; Crashlytics shows a symbolicated Kotlin frame (deliberately throw from `MainActivity.onCreate`); `unzip -p app-release.apk lib/arm64-v8a/libapp.so | strings | grep -c "PackageInfo\|AppUpdateGate"` counts near zero after `--obfuscate` (it is non-zero today); `flutter symbolize -i <obfuscated stack>` recovers `file:line`.

---

## P-10 — Two exported plugin receivers can poke the tracking service

**Severity:** Low · **Confidence:** verified.

**Impact.** `flutter_background_service_android` declares `WatchdogReceiver` with `android:exported="true"` and **no permission and no intent filter**, and `BootReceiver` with `exported="true"` for `BOOT_COMPLETED` / `QUICKBOOT_POWERON`. `WatchdogReceiver` is meant to be triggered by the app's own `AlarmManager` `PendingIntent`, but an exported, unprotected receiver can be targeted by an explicit broadcast from any installed app, restarting the foreground tracking service at will (battery/data drain, spurious "CISS Active Duty" notification, and a plausible way to defeat the deliberate `canInitTracking` permission gate in `lib/main.dart:103-105`). `QUICKBOOT_POWERON` is a vendor-specific, **unprotected** action, so it can be spoofed on devices that register for it. Nothing here is remotely exploitable, and no other component is over-exposed: the only exported activity is `MainActivity` (required for the launcher) and there are no `intent-filter` deep links, no `autoVerify` App Links, and no exported services of our own.

**Evidence.** `~/.pub-cache/hosted/pub.dev/flutter_background_service_android-6.3.1/android/src/main/AndroidManifest.xml:12,17-33` — `android:exported="true"` on the receiver block, `BOOT_COMPLETED` + `QUICKBOOT_POWERON` filters, no `android:permission`. Merged release manifest (`build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml`) lists exactly four exported receivers, of which the two Firebase ones are protected by `com.google.android.c2dm.permission.SEND` and `androidx.profileinstaller` by `android.permission.DUMP` — so only the two background-service receivers are unguarded. `android/app/src/main/AndroidManifest.xml:48-52` already shows the correct override technique for this plugin (`tools:replace="android:exported"`), which is what makes the fix cheap.

**Remediation.** Override the library declaration in the app manifest:

```xml
<receiver
    android:name="id.flutter.flutter_background_service.WatchdogReceiver"
    android:exported="false"
    tools:replace="android:exported" />
<receiver
    android:name="id.flutter.flutter_background_service.BootReceiver"
    android:exported="true"
    android:permission="android.permission.RECEIVE_BOOT_COMPLETED"
    tools:replace="android:exported" />
```

(`BootReceiver` must stay exported to receive the system broadcast; the `RECEIVE_BOOT_COMPLETED` permission guard is only meaningful for the non-protected `QUICKBOOT_POWERON` action. If auto-start after reboot is not a required behaviour, set `exported="false"` on it too.) Report the missing guard upstream.

**Verification.** `aapt2 dump xmltree --file AndroidManifest.xml build/app/outputs/flutter-apk/app-release.apk | grep -A2 WatchdogReceiver` shows `exported=false`; `adb shell am broadcast -n co.in.ciss.ciss_mobile/id.flutter.flutter_background_service.WatchdogReceiver` from a device console returns `Permission Denial`/does not start the service; reboot the device and confirm tracking auto-start still behaves as the product intends.

---

## P-11 — Sensitive permissions arrive silently from plugins

**Severity:** Low · **Confidence:** verified.

**Impact.** The hand-written manifest declares 15 permissions, but the release APK asks for 20. The extras — `android.permission.RECORD_AUDIO`, `android.permission.READ_EXTERNAL_STORAGE`, `android.permission.WRITE_EXTERNAL_STORAGE (maxSdkVersion 28)`, `android.permission.RECEIVE_BOOT_COMPLETED` — are merged in by plugins. `RECORD_AUDIO` is the problematic one: the app records video nowhere (photos only), yet the manifest requests the microphone, which (a) shows a "microphone" entry in the store listing and the install sheet for a guard-tracking app, (b) drags the app into Play's sensitive-permissions/prominent-disclosure review, and (c) is a trust problem when the app also tracks location continuously. It comes from `camera_android_camerax`, which requests audio for video capture that this app never configures. Storage permissions from `image_picker_android` are largely vestigial on API 29+ (scoped storage), while the manifest's own `READ_EXTERNAL_STORAGE` has no `maxSdkVersion` cap.

**Evidence.** `aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk` lists, beyond `android/app/src/main/AndroidManifest.xml:4-38`: `RECORD_AUDIO`, `WRITE_EXTERNAL_STORAGE maxSdkVersion='28'`, `READ_EXTERNAL_STORAGE`, `RECEIVE_BOOT_COMPLETED`, `com.google.android.c2dm.permission.RECEIVE`, `com.google.android.providers.gsf.permission.READ_GSERVICES`, `co.in.ciss.ciss_mobile.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` — 20 `uses-permission` lines in total.

**Remediation.** Remove what the product does not use, at merge time, so a future plugin bump cannot re-add them:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" tools:node="remove" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
                 android:maxSdkVersion="32" tools:node="replace" />
```

If camera video recording is ever needed, re-add `RECORD_AUDIO` deliberately together with an in-app disclosure and a Play declaration. Also add `android:maxSdkVersion="32"` to the read-storage permission.

**Verification.** `aapt2 dump badging … | grep -c uses-permission` drops to ≤ 18 and `grep RECORD_AUDIO` returns nothing; install on a fresh device and confirm the install sheet no longer lists microphone access; run the camera/attendance-photo and image-picker flows end-to-end to prove nothing regressed.

---

## P-12 — Dependency and toolchain staleness

**Severity:** Low · **Confidence:** verified (with the OSV result stated as of this audit date).

**Impact.** The toolchain is frozen at Flutter 3.29.0 (engine built 2025-02-10, Dart 3.7.0) — roughly 20 months stale at the time of audit, both locally and in CI, so engine-level fixes shipped since then are absent and `--obfuscate`/API-36 support are pinned to that release's capabilities. `flutter pub outdated` reports 35 direct/locked dependencies constrained below a resolvable version, with several whole generations behind: `firebase_core 3.15.2 → 5.0.0`, `firebase_auth 5.7.0 → 7.0.0`, `firebase_messaging 15.2.10 → 17.0.0`, `flutter_riverpod 2.6.1 → 3.x`, `go_router 16.3.0 → 18.1.1`, `file_picker 8.3.7 → 13.1.0`, `mobile_scanner 6.0.11 → 7.4.2`, `flutter_local_notifications 18.0.1 → 22.3.2`, `share_plus 10.1.4 → 13.3.1`. Firebase majors in particular carry platform-minimum changes that will force `minSdk`/iOS-target decisions, so deferring them compounds. Two packages are effectively abandoned: `hive` (stable 2.2.3; newest publish is `4.0.0-dev.2` from 2023-08-25) and `hive_flutter` (newest publish `2.0.0-dev`, 2022-10-15) — both sit under the app's offline queue and settings stores, and the maintained successor is `hive_ce`. `flutter_activity_recognition 4.0.0` (2024-09-06) backs the `ACTIVITY_RECOGNITION` heartbeat and is likewise a single-maintainer plugin. `pubspec.yaml` also declares `flutter_background_service_android: ^6.3.1` directly even though it is pulled in transitively by `flutter_background_service: ^5.1.0` — an unnecessary federated pin that can create version-solve conflicts. Positively, a **CVE sweep found nothing**: an OSV.dev `v1/query` for all **204** locked pub.dev packages at their exact resolved versions returned zero advisories (source: `https://api.osv.dev/v1/query`, ecosystem `Pub`, queried 2026-10-22), and `flutter pub outdated` marks only `build_resolvers` and `build_runner_core` as discontinued (test-only, transitive).

**Evidence.** `flutter --version` → `Flutter 3.29.0 • channel stable … revision 35c388afb5 (1 year, 8 months ago) • 2025-02-10`; `dart --version` → `3.7.0`; `pubspec.yaml:22` → `sdk: ^3.7.0`; `.github/workflows/build-apk.yml:42` → `flutter-version: "3.29.0"`; `.metadata:7` records `revision: "f6ff1529fd6d8af5f706051d9251ac9231c83407"` — a **different** Flutter revision than the one pinned for builds, i.e. the project was last migrated with a newer SDK than CI builds with. `flutter pub outdated` output (direct deps table and the closing lines "32 upgradable dependencies are locked… 35 dependencies are constrained to versions that are older"). `pubspec.yaml:49-50` `hive: ^2.2.3` / `hive_flutter: ^1.1.0`; `pubspec.yaml:58,64` both `flutter_background_service` and `flutter_background_service_android`. pub.dev API last-published dates as quoted. OSV batch result: no advisories for any of the 204 packages.

**Remediation.** (a) Move the pin forward in a single deliberate step: `flutter upgrade` locally, set `.github/workflows/build-apk.yml:42` to the same version, and regenerate `.metadata` (`flutter create --platforms=android,ios .`); do not leave `.metadata` pointing at a third revision. (b) Upgrade in this order — patch/minor first (`dio 5.11.1`, `battery_plus 7.1.2`, `connectivity_plus 7.3.2`, `flutter_secure_storage 10.3.4`, `permission_handler 13.0.2`), then the Firebase generation as one atomic change with a device regression pass on FCM token registration, Crashlytics and Storage, then `riverpod 3`/`go_router 18` as a code-migration task. (c) Replace `hive`/`hive_flutter` with `hive_ce` (or migrate to `shared_preferences`+`json` for the small stores), and delete the direct `flutter_background_service_android` pin. (d) Add a scheduled job that runs `flutter pub outdated --json` and the same OSV sweep weekly, failing only on advisories and on `(latest - current) > 1 major` for security-relevant packages.

**Verification.** `flutter pub outdated` shows zero *direct* dependencies behind by more than one minor; the OSV sweep remains empty after the upgrade; `flutter test` still reports 167 passing tests; a device smoke test covers login, biometric unlock, attendance photo, FCM notification, offline-queue replay, and the update dialog.

---

## P-13 — Repo and release hygiene

**Severity:** Info · **Confidence:** verified.

**Impact.** Small items that make the release trail harder to audit and that look sloppy in a **public** repository (`api.github.com/repos/sansan69/CISS-Mobile` → `"private": false`, `"visibility": "public"`). (1) `.gitignore:33` ignores only the root `/build/`, so `android/build/` (148 KB of Gradle problem reports) shows up as untracked and would be committed by a `git add -A`. (2) 69 files under `tooling/` are tracked, overwhelmingly emulator screenshots (`tooling/fo_guards.png`, `tooling/shell_final2.png`, …). I inspected `tooling/fo_guards.png`: it shows guard names, employee IDs (`CISS-1042`), client name (`Kerala State Bank`), districts and phone numbers (`+91 98470 12345`). Those specific numbers and IDs are sequential and almost certainly seeded test data — but the pattern is exactly how real PII ends up in a public repo, and the directory is 12 MB — about two thirds of the repository's 17.7 MiB pack size. (3) `mobile.env` is tracked and contains `NEXT_PUBLIC_SUPER_ADMIN_EMAIL=admin@cisskerala.app` alongside the Firebase web API key. Firebase client keys and the web API key are public by design (they also appear in `lib/firebase_options.dart:22-56` and `android/app/google-services.json`), so this is disclosure of an admin e-mail address for phishing, not a secret leak — but the file is also unused: nothing in `lib/` reads `CISS_API_BASE_URL` (`lib/core/region/region_service.dart:131` hardcodes `https://cisskerala.site`, `lib/firebase_options.dart` hardcodes the keys), so `--dart-define-from-file=mobile.env` documented in `README.md:16` has no effect. (4) Notification polish: `lib/core/fcm/notification_service.dart:86-88` initialises with `AndroidInitializationSettings('@mipmap/ic_launcher')`, i.e. a full-colour launcher icon as the status-bar small icon (renders as a white blob on API 21+), and no `com.google.firebase.messaging.default_notification_icon` / `default_notification_channel_id` meta-data is declared, so background FCM notifications use plugin defaults. `AppUpdateService` also ignores the `platform`/`packageName` fields the live endpoint already returns, which would have made P-04's validation nearly free.

**Evidence.** `git status --porcelain` → `?? android/build/`; `git check-ignore -v android/build` → no match while `build` matches `.gitignore:33`. `git ls-files tooling | wc -l` → 69. `curl -s https://api.github.com/repos/sansan69/CISS-Mobile` → `private:false, visibility:public`. `mobile.env:13`; `README.md:16,26-32`; `lib/core/region/region_service.dart:131` `static const String _baseUrl = 'https://cisskerala.site';`. `notification_service.dart:86-88,209-231`; live endpoint returns `"platform":"android","packageName":"co.in.ciss.ciss_mobile"` which `app_update_service.dart:32-49` never reads.

**Remediation.** Add `/android/build/` (and `**/android/build/`) to `.gitignore`; `git rm -r --cached tooling/` and keep screenshots outside version control (or in a `docs/screenshots/` folder with synthetic-only data and a README stating that); either delete `mobile.env` from tracking (it does nothing) or wire it through `--dart-define` for real and drop the hardcoded fallbacks; add a proper white-on-transparent notification icon plus the FCM default-channel meta-data:

```xml
<meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="ciss_general" />
<meta-data android:name="com.google.firebase.messaging.default_notification_icon" android:resource="@drawable/ic_stat_ciss" />
```

and validate `platform`/`packageName` from the update document as part of P-04's fix.

**Verification.** `git check-ignore -v android/build` matches; `git status --porcelain` is clean of build dirs; `git ls-files tooling | wc -l` = 0; a background FCM push shows a monochrome status-bar icon and lands in the "CISS Notifications" channel.

---

## Positive controls observed

Worth recording so they are not regressed: release builds hard-fail without signing material (`android/app/build.gradle.kts:16-24`) and never silently fall back to debug signing; CI pins the release certificate digest and publishes `SHA256SUMS.txt` (`.github/workflows/build-apk.yml:90-116`); the published 1.0.21 APK's SHA-256 and size match the live manifest exactly and it is signed with the same production certificate as a local build; the keystore and `key.properties` have never been committed (`git log --all` is empty for both, `.gitignore:46-47` covers them); `allowBackup="false"` is present; the `FileProvider` is correctly `exported="false"` with `grantUriPermissions` and a narrow `cache-path` (`AndroidManifest.xml:55-64`, `res/xml/file_paths.xml:4`); no deep links / App Links are exposed; `android:exported="false"` is applied to the background service via `tools:replace`; `MainActivity` is a `FlutterFragmentActivity` (`MainActivity.kt:10`) with `Theme.AppCompat.Light.NoActionBar` themes (`res/values/styles.xml:4,15`) so `local_auth`'s biometric prompt does not crash; the tracking notification channel is created in both `Application` and `Activity` before `startForeground()` (`CissMobileApplication.kt:17-30`, `MainActivity.kt:16-29`); `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` is deliberately **not** declared and the generic settings screen is used instead (`DeviceCompatPlugin.kt:78-95`); `extractNativeLibs=false`; the offline queue uses an encrypted Hive box (`lib/main.dart:52-55`); and no pub package in the lockfile has a known advisory.

## Build results (verbatim)

| Step | Command | Outcome |
|---|---|---|
| Release APK | `flutter build apk --release` | **success**, Gradle `assembleRelease` 124.1 s, `✓ Built build/app/outputs/flutter-apk/app-release.apk (86.7MB)` — 86,709,865 B, SHA-256 `726408ac684e70183b706aa1e5b4eb8870d0d27bfbdc384afc88d06f3a594e2a`, 631 entries, 4 ABIs |
| Release bundle | `flutter build appbundle --release` | **success**, 6.7 s, `app-release.aab` 45,311,894 B |
| R8/shrinking | inspection | **on** — `build/app/outputs/mapping/release/` contains `mapping.txt` 55,950,229 B, `configuration.txt`, `seeds.txt`, `usage.txt`, `resources.txt`; no `android/app/proguard-rules.pro` exists |
| Signing | `apksigner verify --verbose --print-certs` | Verifies; **v2 only** (v1 `false`, v3 `false`) — acceptable for `minSdk 24`; 1 signer, `CN=CISS Workforce, OU=Mobile, O=CISS, L=Thiruvananthapuram, ST=Kerala, C=IN`, RSA 2048 / `SHA384withRSA`, cert SHA-256 `e5ee3fd6…29aa`, valid 2026-05-05 → 2053-09-20; matches the iOS/Android keystore alias `ciss-release` |
| Manifest facts | `aapt2 dump badging` / `xmltree` | `package co.in.ciss.ciss_mobile`, `versionCode 22`, `versionName 1.0.22`, `minSdk 24`, `targetSdk 34`, `compileSdk 36`, 20 permissions, `allowBackup=false`, `extractNativeLibs=false`, `networkSecurityConfig` set, no `usesCleartextTraffic`, no `dataExtractionRules`, 4 exported receivers |
| Analyzer gate | `flutter analyze` | **FAIL** — exit 1, 3 `unused_import` warnings (`auth_controller.dart:3`, `permission_onboarding_screen.dart:9`, `test/de_clutter_primitives_test.dart:6`) |
| Build warnings | captured in Gradle output | `Warning: SDK processing. This version only understands SDK XML versions up to 3 but an SDK XML file of version 4 was encountered` (AGP 8.11.1 vs installed cmdline-tools 36.1.0); `warning: [options] source value 8 is obsolete … target value 8 is obsolete` from three plugin modules (JDK 25 default toolchain, Gradle 8.14, AGP 8.11.1, Kotlin 2.2.20) |
| iOS | `flutter build ios --no-codesign` | **not verifiable here** — exits with `Application not configured for iOS` (Flutter throws when `xcodebuild -showBuildSettings` cannot yield `PRODUCT_BUNDLE_IDENTIFIER`); root cause is environmental: `xcode-select -p` → `/Library/Developer/CommandLineTools` and `xcodebuild` reports "requires Xcode"; `pod` is not installed either. No IPA/simulator artifact was produced and no iOS-specific behaviour was exercised. |

## Release readiness verdict

**Android: not ready for Play, marginally serviceable for sideload — and the current release process cannot be trusted to produce the artifact you serve.** Two of the three blockers are one-line config changes (`targetSdk 34 → 36`, three unused imports), but the third — five consecutive releases (1.0.18–1.0.22) shipped outside the only signed pipeline, with the live update endpoint still advertising 1.0.21 — means that "what is on users' phones" currently has no verifiable link to a tagged commit. The Android binary itself is structurally sound: it builds reproducibly in 124 s, is signed with the expected production certificate, has shrinking enabled, no cleartext in Dart, an encrypted offline queue and no advisory-flagged dependencies. Fix P-02, P-03 and P-04 first (they are the ones that gate a defensible release); P-05/P-06 materially reduce field pain on metered, low-RAM devices; P-07/P-08 are cheap defence-in-depth. **iOS: not shippable at all** — no usage descriptions, no background location mode, no push entitlement, no Podfile; treat "Android+iOS" as aspirational until P-01 is done and an archive has actually been produced.

## Not verified / limitations

- **iOS build, signing, runtime and App Store Connect behaviour** — Xcode is not installed on this machine (`xcodebuild` → "requires Xcode", active developer dir is `/Library/Developer/CommandLineTools`) and CocoaPods (`pod`) is absent, so `flutter build ios --no-codesign` could not run; every iOS claim in P-01 is file-level static evidence, not build or device evidence. The iOS deployment target's compatibility with the current Firebase iOS SDK was not checked by `pod install`.
- **Emulator/device behaviour** — per scope, no emulator or device was started; runtime behaviour (notification rendering, installer intent on API 34, D2D transfer, FGS restart after boot, biometric prompt) is asserted from code and platform documentation, not observed.
- **Android 16 (API 36) behaviour changes** relevant to this app could not be exercised; P-02's remediation steps are based on documented behaviour changes.
- **The backend serving `/downloads/*.apk`** — only the manifest document and the 1.0.21 APK were fetched; I did not confirm that the host would not serve a different file at the next request, that `/downloads/` rejects non-APK content, or that region-config `apiUrl` values are all HTTPS (P-04/P-07 mitigation depends on those server-side properties).
- **`ANDROID_SIGNING_CERT_SHA256`** and the other four CI secrets could not be compared against the local certificate (secrets are write-only in GitHub Actions); the local↔published certificate match was verified directly instead.
- **Play Console status** — whether the app already has a Play listing, whether `REQUEST_INSTALL_PACKAGES` has been reviewed, and whether a target-API extension to 2026-11-01 was requested are all unknown from the repo.
- **Definition-of-done for the fleet's device matrix** — `minSdk 24` support, `.flutter-plugins-dependencies` platform coverage, and `x86`/`x86_64` artifacts being shipped to real users were not exercised on hardware.
- Line numbers are 1-based against the files as read at HEAD `edfec10` (`wip/redesign-1.0.21`); `wip` working-tree modifications to `lib/` (router, haptics, repository, guard dashboard) do not touch any file cited above, except that `flutter analyze`'s third warning is in the untracked `test/de_clutter_primitives_test.dart`.
