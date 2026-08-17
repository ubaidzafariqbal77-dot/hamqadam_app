/// Typed exceptions for the networking layer. The API client converts every
/// low-level failure into one of these so controllers never see raw Dio errors.
library;

/// Base class for all app exceptions.
sealed class AppException implements Exception {
  const AppException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => '$runtimeType($statusCode): $message';
}

/// No connectivity / DNS failure before the request left the device.
class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection. Please check your network.']);
}

/// Connect/receive/send timeout.
class TimeoutException extends AppException {
  const TimeoutException([super.message = 'The request timed out. Please try again.']);
}

/// 401 — token missing/expired/invalid.
class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Your session has expired. Please sign in again.'])
    : super(statusCode: 401);
}

/// 422 (and similar) — Laravel field validation errors.
class ValidationException extends AppException {
  const ValidationException(super.message, {required this.errors, super.statusCode = 422});

  /// field name -> list of messages.
  final Map<String, List<String>> errors;

  /// First error message for [field], if any.
  String? firstFor(String field) {
    final List<String>? list = errors[field];
    return (list != null && list.isNotEmpty) ? list.first : null;
  }
}

/// 5xx — server side failure.
class ServerException extends AppException {
  // A super-parameter for `message` can't coexist with the explicit `super(...)`
  // call needed to pass the named `statusCode`, so keep them as normal params.
  // ignore: use_super_parameters
  const ServerException([
    String message = 'Something went wrong on our side. Please try again.',
    int statusCode = 500,
  ]) : super(message, statusCode: statusCode);
}

/// Any other API-level failure (4xx that is not 401/422, parsing issues, etc.).
class ApiException extends AppException {
  const ApiException(super.message, {super.statusCode, this.code});

  /// Machine-readable error code from the API envelope, when present.
  final String? code;
}

/// The request was cancelled (e.g. widget disposed) — usually swallowed.
class RequestCancelledException extends AppException {
  const RequestCancelledException([super.message = 'Request cancelled.']);
}
