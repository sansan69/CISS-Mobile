import 'package:dio/dio.dart';

class CissError {
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
          if (status == 403) return 'Access denied. You do not have permission for this action.';
          if (status == 404) return 'Requested information not found.';
          if (status == 408) return 'Request timed out. Please try again.';
          if (status == 429) return 'Too many requests. Please wait a moment and try again.';
          if (status == 500) return 'Server error. Our team is looking into it.';

          if (data is Map && data.containsKey('message')) {
            final msg = data['message'].toString();
            if (msg.toLowerCase().contains('invalid attendance')) {
              return 'Invalid attendance. Please ensure you are at the correct site.';
            }
            return msg;
          }
          return 'Something went wrong (Error $status).';
        case DioExceptionType.cancel:
          return 'Request was cancelled.';
        default:
          return 'Unexpected network error. Please try again.';
      }
    }

    final str = error.toString().toLowerCase();
    if (str.contains('location permission')) return 'Location permission denied. Please enable it in settings.';
    if (str.contains('camera')) return 'Camera access is required. Please check your permissions.';

    return error.toString().replaceFirst('Exception: ', '').trim();
  }
}
