import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';

class CissError {
  /// Returns true only for failures that are safe to retry later. Client
  /// validation and authorization failures must stay visible to the user
  /// instead of being persisted in the offline queue forever.
  static bool isRetryableNetworkError(Object error) {
    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      return code == 'unavailable' ||
          code == 'deadline-exceeded' ||
          code == 'network-request-failed' ||
          code.endsWith('/network-request-failed') ||
          code == 'retry-limit-exceeded' ||
          code.endsWith('/retry-limit-exceeded');
    }
    if (error is! DioException) return false;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return true;
      case DioExceptionType.badResponse:
        return (error.response?.statusCode ?? 0) >= 500;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return false;
    }
  }

  static String parse(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Network timeout. Please check your internet connection.';
        case DioExceptionType.connectionError:
          return 'No internet connection. Please turn on Wi-Fi or Mobile Data.';
        case DioExceptionType.badResponse:
          final status = error.response?.statusCode;
          final data = error.response?.data;

          if (status == 401) return 'Session expired. Please login again.';
          if (status == 403) {
            return 'Access denied. You do not have permission for this action.';
          }
          if (status == 404) return 'Requested information not found.';
          if (status == 500) {
            return 'Server error. Our team is looking into it.';
          }

          if (data is Map &&
              (data.containsKey('message') || data.containsKey('error'))) {
            final msg = (data['message'] ?? data['error']).toString();
            if (msg.toLowerCase().contains('invalid attendance')) {
              return 'Invalid attendance. Please ensure you are at the correct site.';
            }
            return msg;
          }
          return 'Something went wrong (Error $status).';
        default:
          return 'Unexpected network error. Please try again.';
      }
    }

    final str = error.toString().toLowerCase();
    if (str.contains('location permission')) {
      return 'Location permission denied. Please enable it in settings.';
    }
    if (str.contains('camera')) {
      return 'Camera access is required. Please check your permissions.';
    }
    if (error is StateError) {
      if (str.contains('not authenticated') ||
          str.contains('session expired') ||
          str.contains('no user')) {
        return 'Session expired. Please login again.';
      }
      return _fallbackMessage;
    }
    if (error is FormatException || error is TypeError) {
      return 'The server returned an invalid response.';
    }
    if (error is Exception) {
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      // Preserve short, human-readable backend messages, but never echo Dart
      // internals, Firebase codes or stack-frame-shaped text to the user.
      if (message.isNotEmpty &&
          message.length <= 180 &&
          !_looksLikeInternalError(message)) {
        return message;
      }
    }

    return _fallbackMessage;
  }

  static const String _fallbackMessage =
      'Something went wrong. Please try again.';

  static bool _looksLikeInternalError(String message) {
    final text = message.toLowerCase();
    return text.contains('type ') ||
        text.contains('is not a subtype') ||
        text.contains('null is not') ||
        text.contains('dart:') ||
        text.contains('stateerror') ||
        text.contains('formatexception') ||
        text.contains('[firebase') ||
        text.contains('stack trace') ||
        text.contains('#0 ') ||
        text.contains('exception:');
  }
}
