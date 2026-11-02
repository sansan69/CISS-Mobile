// Browser-only helpers.
//
// The conditional export keeps `package:web` out of mobile and desktop builds:
// native targets compile the stub, which throws.
export 'browser_download_stub.dart'
    if (dart.library.js_interop) 'browser_download_web.dart';
