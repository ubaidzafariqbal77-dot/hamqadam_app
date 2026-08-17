import 'package:dio/dio.dart';

import '../../exceptions/app_exceptions.dart';
import '../../models/api_error_model.dart';
import '../utils/app_logger.dart';

/// Converts any [DioException] / bad HTTP response into a typed [AppException].
class ApiErrorParser {
  const ApiErrorParser._();

  static AppException parse(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutException();
      case DioExceptionType.cancel:
        return const RequestCancelledException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badCertificate:
        return const ApiException('Secure connection failed.');
      case DioExceptionType.unknown:
        if (_looksLikeNoInternet(error)) return const NetworkException();
        return ApiException(error.message ?? 'Unexpected error.');
      case DioExceptionType.badResponse:
        return _fromResponse(error.response);
    }
  }

  static AppException _fromResponse(Response<dynamic>? response) {
    final int status = response?.statusCode ?? 0;
    final ApiErrorModel model = _extractModel(response);

    if (status == 401) return UnauthorizedException(model.message);
    if (status == 422 || (status == 400 && model.hasFieldErrors)) {
      return ValidationException(model.message, errors: model.errors, statusCode: status);
    }
    if (status >= 500) {
      // A 5xx body can be a raw stack trace / SQL statement (Laravel with debug
      // on). Log it for developers, but never put it in front of a user.
      AppLogger.w('Server error $status: ${model.message}');
      return ServerException(_serverMessage, status);
    }
    return ApiException(model.message, statusCode: status, code: model.code);
  }

  /// What the user sees for any 5xx.
  static const String _serverMessage =
      'Something went wrong on our side. Please try again in a moment.';

  static ApiErrorModel _extractModel(Response<dynamic>? response) {
    final dynamic data = response?.data;
    if (data is Map<String, dynamic>) {
      return ApiErrorModel.fromJson(data);
    }
    return ApiErrorModel(message: 'Request failed (${response?.statusCode ?? 'no response'}).');
  }

  static bool _looksLikeNoInternet(DioException error) {
    final String msg = (error.error?.toString() ?? error.message ?? '').toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable');
  }
}
