import 'dart:async';

import 'package:dio/dio.dart';

import 'api_config.dart';

class ApiClient {
  ApiClient({
    required this.authTokenProvider,
    this.authTokenRefreshProvider,
    String? baseUrl,
    this.onModuleDisabled,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: baseUrl ?? ApiConfig.baseUrl,
           connectTimeout: const Duration(seconds: 30),
           receiveTimeout: const Duration(seconds: 40),
           headers: const <String, String>{'Content-Type': 'application/json'},
         ),
       ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (
          RequestOptions options,
          RequestInterceptorHandler handler,
        ) async {
          if (options.extra[kSkipApiAuth] != true) {
            final token = await authTokenProvider();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          // 401 — stale token: force-refresh and retry once. The marker
          // prevents a permanently rejected token from recursing through
          // this interceptor indefinitely.
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra[_authRetryMarker] != true) {
            try {
              final token =
                  await (authTokenRefreshProvider ?? authTokenProvider)();
              if (token == null || token.isEmpty) {
                handler.next(error);
                return;
              }

              final retryOptions = error.requestOptions;
              retryOptions.extra[_authRetryMarker] = true;
              retryOptions.headers['Authorization'] = 'Bearer $token';
              final response = await dio.fetch<dynamic>(retryOptions);
              handler.resolve(response);
              return;
            } catch (_) {
              // Token refresh or retry failed — fall through to the
              // original error so callers can handle it normally.
            }
          }
          // 403 — a module may have been disabled server-side: re-fetch
          // settings so the UI can hard-hide the affected module. Best
          // effort and fire-and-forget; never delays or alters the error.
          if (error.response?.statusCode == 403) {
            final callback = onModuleDisabled;
            if (callback != null) {
              unawaited(callback().catchError((Object _) {}));
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
  final Future<String?> Function() authTokenProvider;
  final Future<String?> Function()? authTokenRefreshProvider;

  /// Invoked (fire-and-forget) when a request fails with HTTP 403, giving the
  /// app a chance to refresh server-driven module settings.
  final Future<void> Function()? onModuleDisabled;
}

const String _authRetryMarker = 'ciss_auth_retry';

/// Request marker used by public attendance flows so a logged-in user from a
/// different account cannot accidentally authenticate an anonymous submission.
const String kSkipApiAuth = 'ciss_skip_auth';
