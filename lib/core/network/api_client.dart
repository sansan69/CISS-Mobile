import 'package:dio/dio.dart';

import 'api_config.dart';

class ApiClient {
  ApiClient({required this.authTokenProvider})
    : dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
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
      ),
    );
  }

  final Dio dio;
  final Future<String?> Function() authTokenProvider;
}
