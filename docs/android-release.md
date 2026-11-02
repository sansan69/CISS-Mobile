# Android release (sideload channel)

The app is distributed as a signed APK through the in-app updater and the
GitHub release, not Google Play.

## Cut a release

1. Bump the version in `pubspec.yaml` (`version: X.Y.Z+N`). The release tag must
   equal `X.Y.Z`.
2. Commit, then tag and push:

   ```bash
   git tag vX.Y.Z
   git push origin HEAD
   git push origin vX.Y.Z
   ```

3. The `Build signed Android release` workflow runs `flutter analyze`,
   `flutter test`, builds the AAB and APK with `--split-debug-info`, verifies the
   signing certificate against `ANDROID_SIGNING_CERT_SHA256`, writes
   `SHA256SUMS.txt`, uploads artifacts, and publishes a GitHub release.
   All five signing secrets are already configured on the repo.
4. Start the workflow manually if the tag push was missed:

   ```bash
   gh workflow run build-apk.yml -f release_tag=vX.Y.Z
   ```

## Publish the update manifest

The app polls `https://cisskerala.site/api/public/app-update`, which serves
`public/downloads/ciss-workforce-android.json` from the CISS web repo. Derive it
from the artifact so the advertised hash cannot drift:

```bash
tooling/publish_update_manifest.py \
  --apk build/app/outputs/flutter-apk/app-release.apk \
  --downloads ../CISS/public/downloads \
  --notes "Release note one" "Release note two"
```

Then commit and deploy the CISS web app. Without this step the updater keeps
offering the previous build even though the GitHub release exists.

## Verify

```bash
curl -s https://cisskerala.site/api/public/app-update \
  | jq -r '.latestVersionName, .latestVersionCode, .sha256, .sizeBytes'
sha256sum build/app/outputs/flutter-apk/app-release.apk
```

Both hashes must match, and an installed previous build must show the update
dialog and install the new APK.

## Known follow-ups

- The updater ships one universal APK (all ABIs) to keep the manifest simple.
  Per-ABI artifacts would cut the download from ~87 MB to ~30 MB on metered
  connections.
- Play Store distribution is not wired up: no `supply`/Play upload step, no
  Play App Signing.
