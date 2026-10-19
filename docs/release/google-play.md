# Google Play release path

The default new managed distribution is Google Play. Existing signed sideload
builds remain supported, and an ordinary local build continues to use that path.
Play builds use `--dart-define=CISS_DISTRIBUTION=play`; the same define reaches
Gradle, which removes REQUEST_INSTALL_PACKAGES. They use Google's update API and
never download or install an APK from the sideload update endpoint. Mandatory
updates are based on the installed version falling below the server's
`minSupportedVersion`, so a Play outage cannot let an unsupported app continue.
An up-to-date app is never trapped by a generic `forceUpdate` flag, and an
unavailable Play check does not create an optional prompt. Store errors remain
distinct from Play reporting the app as current.

`.github/workflows/android-play.yml` is manual, defaults to build-only, and uses
the `google-play` environment. Configure required reviewers for that environment
before enabling production publishing. Internal testing is the default track;
production is a staged rollout (default 5%, allowed 1% to less than 100%).
Promote or halt the release in Play Console after checking crash/ANR and sync
failure metrics. A Play application must already exist and initial store setup,
background location disclosure/review, and Data Safety declarations must be done.

Required secrets:

- ANDROID_KEYSTORE_BASE64, ANDROID_STORE_PASSWORD, ANDROID_KEY_PASSWORD,
  ANDROID_KEY_ALIAS, ANDROID_SIGNING_CERT_SHA256 (upload signing certificate).
- RASP_SIGNING_CERT_BASE64: SHA-256 digest encoded as base64 for the **Play app
  signing** certificate; this may differ from the upload key.
- RASP_WATCHER_EMAIL: approved recipient for the vendor's security reports.
- For publishing: PLAY_SERVICE_ACCOUNT_JSON. Use a scoped service account.
- Optional for automatic Crashlytics symbol upload:
  FIREBASE_SERVICE_ACCOUNT_JSON and FIREBASE_ANDROID_APP_ID. If absent, the
  workflow artifact retains the symbols for manual upload.

Required repository/environment variables: CISS_PRIVACY_URL, CISS_TERMS_URL,
CISS_PSARA_URL (approved HTTPS documents). These are passed as Dart defines.
No legal text or company policy has been invented. Sideload builds can receive
the same defines manually; without them their policy card explains how to
contact the office.

The workflow checks version-independent signing identity, policy URL shape,
rollout bounds, analyzer/tests and absence of sideload permission, then archives
the AAB, Dart symbols and native mapping. Publishing uploads Flutter symbols to
Crashlytics when its service-account and Android app ID secrets are configured,
and uploads native mapping to Play before releasing. If Crashlytics credentials
are absent, symbols stay in the workflow artifact for manual upload. Signed
sideload releases also retain Dart symbols and R8 mapping in the workflow and
GitHub release artifacts. Preserve these artifacts for every release. Build
numbers must increase; Play rejects reused codes.

Play Integrity is intentionally not asserted: `AttestationSource` defaults to
Noop and emits `not_configured`. A trusted verifier endpoint and Play API/cloud
configuration are prerequisites to replacing it. freeRASP runs advisory-only
with `killOnBypass=false`; failure/unconfigured detection never refuses punches.

Local checks do not establish store publishing, signed release installation,
TalkBack behaviour, or a production integrity verdict. Production signing keys
are absent locally. No publish operation was run during implementation.
