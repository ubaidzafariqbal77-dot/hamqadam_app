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
        // A TLS handshake failure is reported as a connection error by some
        // platforms, so it must be checked before falling back to "no network".
        if (_looksLikeTls(error)) return const TlsException();
        return const NetworkException();
      case DioExceptionType.badCertificate:
        return const TlsException();
      case DioExceptionType.unknown:
        if (_looksLikeTls(error)) return const TlsException();
        if (_looksLikeNoInternet(error)) return const NetworkException();
        return ApiException(_safeMessage(error));
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
    final String msg = _rawText(error);
    return msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable');
  }

  /// Detects a failed TLS handshake / rejected certificate.
  ///
  /// Dio only maps this to [DioExceptionType.badCertificate] on some platforms.
  /// On Android and iOS the handshake failure usually surfaces as
  /// [DioExceptionType.unknown] or [DioExceptionType.connectionError] carrying
  /// an `HandshakeException` / `CERTIFICATE_EXPIRED` / `CERTIFICATE_VERIFY_FAILED`.
  ///
  /// Without this, an expired server certificate reached the user as the bare
  /// string "null" (because `DioException.message` is null for handshake
  /// failures), which is exactly the symptom seen when the production TLS
  /// certificate expired.
  static bool _looksLikeTls(DioException error) {
    final String msg = _rawText(error);
    return msg.contains('handshakeexception') ||
        msg.contains('certificate') ||
        msg.contains('cert_') ||
        msg.contains('handshake') ||
        msg.contains('tls') ||
        msg.contains('ssl');
  }

  /// Best available text for an error that reached no classification.
  /// Never returns null or blank — a null message renders literally as
  /// "null" in the UI, which tells the user nothing.
  static String _safeMessage(DioException error) {
    for (final String candidate in <String>[error.message ?? '', error.error?.toString() ?? '']) {
      final String trimmed = candidate.trim();
      // Strip Dart runtime prefixes such as "Exception: " and reject the
      // literal "null" that `Object?.toString()` produces.
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') continue;
      return trimmed;
    }
    return 'Unexpected error. Please try again.';
  }

  /// Lower-cased concatenation of everything Dio knows about the failure.
  static String _rawText(DioException error) =>
      '${error.message ?? ''} ${error.error ?? ''}'.toLowerCase();
}
