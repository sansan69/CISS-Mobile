# Web deployment (cisskerala.site/app)

The web build is the same Flutter app compiled for the browser. It is published
under `https://cisskerala.site/app/` so it shares the API origin. No CORS work is
needed for the API as long as the app stays on that origin.

## Build

```bash
tooling/build_web.sh                      # build only
tooling/build_web.sh ../CISS/public/app   # build and copy into the Next.js app
```

`tooling/build_web.sh` runs `flutter analyze` and `flutter test` first and then
builds with `--base-href=/app/`. `CISS_WEB_API_BASE_URL` can point the bundle at
a different API host; leave it unset for the same-origin deployment.

## What the Next.js host must do

1. Serve the bundle contents at `/app/*` (the CISS app ships them from
   `public/app/`).
2. Send a Flutter-compatible Content-Security-Policy for `/app/*`. The site-wide
   policy uses a per-response nonce, which Flutter's static `index.html` cannot
   carry, so those files need a path-scoped policy:

   ```
   default-src 'self';
   script-src 'self' 'wasm-unsafe-eval';
   style-src 'self' 'unsafe-inline';
   img-src 'self' data: blob:;
   font-src 'self' data:;
   connect-src 'self' https: wss:;
   media-src 'self' blob: https:;
   worker-src 'self' blob:;
   manifest-src 'self';
   object-src 'none';
   base-uri 'self';
   frame-ancestors 'none'
   ```

   `wasm-unsafe-eval` is required by the CanvasKit renderer.
3. Serve `.wasm` as `application/wasm` and let `flutter_service_worker.js` be
   revalidated (`Cache-Control: no-cache`) so updated builds activate.

## Runtime differences from Android

| Capability | Web behaviour |
|---|---|
| Background location tracking | Not available. Attendance location is captured in the foreground per submission. |
| Biometrics (`local_auth`) | Reported as "no sensor"; PIN login is used. |
| Push notifications | Disabled (no FCM service worker). The in-app notification inbox still polls the API. |
| Camera | Uses the browser file picker / camera capture via `image_picker`. |
| Photo display & upload | Bytes are held in memory for the tab; uploads send base64 data URLs as on mobile. |
| Offline queue / drafts | Hive over IndexedDB, encrypted with the same key path as mobile. |
| Payslip download | Saved through the browser download manager. |
| In-app APK updater | Not applicable; `app_update_service` is Android-only. |

## Security notes

- `flutter_secure_storage` on web stores an AES key in IndexedDB, so the origin
  must stay HTTPS-only (it does, with HSTS).
- The bundle must never be served from a different path than its `--base-href`,
  or the service worker will cache mismatched assets.
- Keep the `/app` scope out of the Next.js CSP nonce path; see item 2 above.
