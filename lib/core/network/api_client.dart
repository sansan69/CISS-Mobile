import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'api_config.dart';

class ApiClient {
  ApiClient({required this.authTokenProvider, String? baseUrl})
    : dio = Dio(
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
              handler.next(error);
            },
      ),
    );
  }

  final Dio dio;
  final Future<String?> Function() authTokenProvider;
}
