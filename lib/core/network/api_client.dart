import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'api_config.dart';

class ApiClient {
  ApiClient({
    required this.authTokenProvider,
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
        onRequest:
            (RequestOptions options, RequestInterceptorHandler handler) async {
              final token = await authTokenProvider();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              handler.next(options);
            },
        onError:
            (DioException error, ErrorInterceptorHandler handler) async {
              // 401 — stale token: force-refresh and retry once
              if (error.response?.statusCode == 401) {
                try {
                  await FirebaseAuth.instance.currentUser?.getIdToken(true);
                  // Retry the original request with the refreshed token
                  final token = await authTokenProvider();
                  final retryOptions = error.requestOptions;
                  if (token != null && token.isNotEmpty) {
                    retryOptions.headers['Authorization'] = 'Bearer $token';
                  }
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

  /// Invoked (fire-and-forget) when a request fails with HTTP 403, giving the
  /// app a chance to refresh server-driven module settings.
  final Future<void> Function()? onModuleDisabled;
}
