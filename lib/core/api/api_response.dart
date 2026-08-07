import '../../exceptions/app_exceptions.dart';

/// The full set of states every API-backed piece of UI must support.
enum ApiStatus {
  initial,
  loading,
  success,
  empty,
  validationError,
  serverError,
  noInternet,
  unauthorized,
}

/// Immutable state holder for a single API-driven operation.
///
/// Controllers expose an `Rx<ApiState<T>>` (or plain field) and the UI reacts
/// to [status]. This keeps the eight mandated states explicit everywhere.
class ApiState<T> {
  const ApiState._(
    this.status, {
    this.data,
    this.message,
    this.fieldErrors = const <String, List<String>>{},
  });

  final ApiStatus status;
  final T? data;
  final String? message;
  final Map<String, List<String>> fieldErrors;

  const ApiState.initial() : this._(ApiStatus.initial);
  const ApiState.loading() : this._(ApiStatus.loading);

  const ApiState.success(T value, {String? message})
    : this._(ApiStatus.success, data: value, message: message);

  const ApiState.empty({String? message}) : this._(ApiStatus.empty, message: message);

  const ApiState.validationError(Map<String, List<String>> errors, {String? message})
    : this._(ApiStatus.validationError, fieldErrors: errors, message: message);

  const ApiState.serverError([String? message]) : this._(ApiStatus.serverError, message: message);

  const ApiState.noInternet([String? message]) : this._(ApiStatus.noInternet, message: message);

  const ApiState.unauthorized([String? message]) : this._(ApiStatus.unauthorized, message: message);

  bool get isLoading => status == ApiStatus.loading;
  bool get isSuccess => status == ApiStatus.success;
  bool get isInitial => status == ApiStatus.initial;
  bool get isError =>
      status == ApiStatus.serverError ||
      status == ApiStatus.validationError ||
      status == ApiStatus.noInternet ||
      status == ApiStatus.unauthorized;

  /// Builds the matching state from a thrown [AppException].
  factory ApiState.fromException(AppException e) {
    return switch (e) {
      NetworkException() => ApiState<T>.noInternet(e.message),
      TimeoutException() => ApiState<T>.serverError(e.message),
      UnauthorizedException() => ApiState<T>.unauthorized(e.message),
      ValidationException(:final Map<String, List<String>> errors) => ApiState<T>.validationError(
        errors,
        message: e.message,
      ),
      ServerException() => ApiState<T>.serverError(e.message),
      ApiException() => ApiState<T>.serverError(e.message),
      RequestCancelledException() => ApiState<T>.initial(),
    };
  }

  ApiState<T> copyWith({ApiStatus? status, T? data, String? message}) {
    return ApiState<T>._(
      status ?? this.status,
      data: data ?? this.data,
      message: message ?? this.message,
      fieldErrors: fieldErrors,
    );
  }
}
