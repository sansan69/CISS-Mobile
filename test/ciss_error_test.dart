import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/network/ciss_error.dart';

void main() {
  group('CissError.parse never leaks Dart internals', () {
    test('maps TypeError and FormatException to a safe message', () {
      expect(
        CissError.parse(TypeError()),
        'The server returned an invalid response.',
      );
      expect(
        CissError.parse(const FormatException('bad json')),
        'The server returned an invalid response.',
      );
    });

    test('maps StateError internals to a safe message', () {
      expect(
        CissError.parse(StateError('Not authenticated')),
        'Session expired. Please login again.',
      );
      expect(
        CissError.parse(StateError('type Null is not a subtype of String')),
        'Something went wrong. Please try again.',
      );
    });

    test('keeps short, human-readable backend messages', () {
      expect(
        CissError.parse(Exception('Invalid OTP')),
        'Invalid OTP',
      );
    });

    test('rejects stack frames and Firebase codes', () {
      final message = CissError.parse(
        Exception('Exception: [firebase_auth/user-not-found] #0 foo'),
      );
      expect(message, 'Something went wrong. Please try again.');
    });

    test('maps Dio failures to known copy', () {
      final request = RequestOptions(path: '/api/test');
      expect(
        CissError.parse(
          DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          ),
        ),
        'No internet connection. Please turn on Wi-Fi or Mobile Data.',
      );
      expect(
        CissError.parse(
          DioException(
            requestOptions: request,
            type: DioExceptionType.badResponse,
            response: Response<void>(
              requestOptions: request,
              statusCode: 401,
            ),
          ),
        ),
        'Session expired. Please login again.',
      );
    });
  });
}
