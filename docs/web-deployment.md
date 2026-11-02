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
builds with `--base-href=/app/` and `--no-web-resources-cdn`. `CISS_WEB_API_BASE_URL`
can point the bundle at a different API host; leave it unset for the same-origin
deployment.

## Middleware branch (verified)

`src/middleware.ts` must skip the nonce policy for `/app` and return the policy
above instead:

```ts
const FLUTTER_APP_PREFIX = "/app";

function flutterContentSecurityPolicy() {
  return [
    "default-src 'self'",
    "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' https://www.gstatic.com",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob:",
    "font-src 'self' data:",
    "connect-src 'self' https: wss:",
    "media-src 'self' blob: https:",
    "worker-src 'self' blob:",
    "manifest-src 'self'",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
    ...(process.env.NODE_ENV === "production"
      ? ["upgrade-insecure-requests"]
      : []),
  ].join("; ");
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  if (pathname === FLUTTER_APP_PREFIX ||
      pathname.startsWith(`${FLUTTER_APP_PREFIX}/`)) {
    const response = NextResponse.next();
    response.headers.set("Content-Security-Policy", flutterContentSecurityPolicy());
    return response;
  }

  // …existing nonce policy and host lock…
}
```

## What the Next.js host must do

1. Serve the bundle contents at `/app/*` (the CISS app ships them from
   `public/app/`), plus a rewrite for the bare path:

   ```ts
   // next.config.ts
   async rewrites() {
     return [{ source: "/app", destination: "/app/index.html" }];
   }
   ```

2. Send a Flutter-compatible Content-Security-Policy for `/app/*`. The site-wide
   policy uses a per-response nonce, which Flutter's static `index.html` cannot
   carry, so those files need a path-scoped policy. This is the policy that was
   verified against the real bundle:

   ```
   default-src 'self';
   script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' https://www.gstatic.com;
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

   Why each relaxation is required:
   - `'unsafe-inline'` — `firebase_core_web` injects inline bootstrap scripts
     that lazily import the Firebase product bundles.
   - `'wasm-unsafe-eval'` — CanvasKit compiles WebAssembly.
   - `https://www.gstatic.com` — FlutterFire's web SDK imports
     `firebase-app.js`, `firebase-auth.js`, `firebase-firestore.js`,
     `firebase-storage.js` and `firebase-messaging.js` from that host.

   With the policy above the app boots, initialises Firebase, loads the region
   list from the API, activates the region and reaches the login hub with no
   console or CSP errors.

3. Serve `.wasm` as `application/wasm` and let `flutter_service_worker.js` be
   revalidated (`Cache-Control: no-cache`) so updated builds activate:

   ```ts
   // next.config.ts headers()
   {
     source: "/app/:path*.wasm",
     headers: [
       { key: "Content-Type", value: "application/wasm" },
       { key: "Cache-Control", value: "public, max-age=31536000, immutable" },
     ],
   },
   {
     source: "/app/flutter_service_worker.js",
     headers: [{ key: "Cache-Control", value: "no-cache, no-store, must-revalidate" }],
   },
   ```

4. Build with `--no-web-resources-cdn` (already in `tooling/build_web.sh`) so
   CanvasKit ships from `/app/canvaskit/` instead of a third-party CDN.

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
