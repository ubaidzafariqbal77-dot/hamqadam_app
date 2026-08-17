// Named constructor params can't be private, so `prefer_initializing_formals`
// does not apply to this file's ApiClient constructor.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:dio/dio.dart';

import '../../constants/app_constants.dart';
import '../../exceptions/app_exceptions.dart';
import '../network/network_info.dart';
import '../storage/secure_storage_service.dart';
import '../utils/app_logger.dart';
import 'api_error_parser.dart';

/// Normalised successful envelope returned to repositories.
class ApiEnvelope {
  const ApiEnvelope({required this.success, required this.message, required this.data});

  final bool success;
  final String message;
  final dynamic data;

  Map<String, dynamic> get dataMap =>
      data is Map<String, dynamic> ? data as Map<String, dynamic> : <String, dynamic>{};

  List<dynamic> get dataList => data is List ? data as List<dynamic> : <dynamic>[];
}

/// Single reusable HTTP client for the whole app.
class ApiClient {
  // Named params can't be private, so initializing formals don't apply here.
  ApiClient({required SecureStorageService storage, required NetworkInfo networkInfo, Dio? dio})
    : _storage = storage,
      _networkInfo = networkInfo,
      _dio = dio ?? Dio() {
    _configure();
  }

  /// `RequestOptions.extra` flag that suppresses the Authorization header.
  static const String _skipAuthKey = 'skip_auth';
  static const Map<String, dynamic> _skipAuthExtra = <String, dynamic>{_skipAuthKey: true};

  final SecureStorageService _storage;
  final NetworkInfo _networkInfo;
  final Dio _dio;

  /// Invoked exactly once per 401 wave so the app can clear the session and
  /// route to login without redirect loops.
  FutureOr<void> Function()? onUnauthorized;
  bool _handlingUnauthorized = false;

  Dio get raw => _dio;

  void _configure() {
    _dio.options
      ..baseUrl = ApiConfig.baseUrl
      ..connectTimeout = ApiConfig.connectTimeout
      ..receiveTimeout = ApiConfig.receiveTimeout
      ..sendTimeout = ApiConfig.sendTimeout
      ..responseType = ResponseType.json
      ..headers = <String, dynamic>{'Accept': 'application/json'}
      // We handle non-2xx ourselves via the error parser.
      ..validateStatus = (int? code) => code != null && code >= 200 && code < 300;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          final String? token = _storage.cachedToken;
          // Public endpoints (registration step 1, login, …) must never carry a
          // stale token: it would 401 and tear the session down mid-signup.
          final bool skipAuth = options.extra[_skipAuthKey] == true;
          if (!skipAuth && token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          AppLogger.i('➡️ ${options.method} ${options.uri}');
          AppLogger.body('request', options.data);
          handler.next(options);
        },
        onResponse: (Response<dynamic> response, ResponseInterceptorHandler handler) {
          AppLogger.i('⬅️ ${response.statusCode} ${response.requestOptions.uri}');
          AppLogger.body('response', response.data);
          handler.next(response);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          AppLogger.w('✖️ ${error.response?.statusCode} ${error.requestOptions.uri}');
          // Log the server error body (validation messages / field errors) so
          // 4xx/5xx failures are debuggable. Sensitive keys stay redacted.
          if (error.response?.data != null) {
            AppLogger.body('error-response', error.response?.data);
          }
          if (error.response?.statusCode == 401) {
            await _fireUnauthorized();
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<void> _fireUnauthorized() async {
    // A 401 on a request that carried no token (e.g. the dropdown reference
    // data warmed up before registration step 1) means "sign in first", not
    // "your session died" — there is nothing to clear and nowhere to redirect.
    final String? token = _storage.cachedToken;
    if (token == null || token.isEmpty) return;
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    try {
      await onUnauthorized?.call();
    } finally {
      // Small window so a burst of parallel 401s only triggers one logout.
      Future<void>.delayed(const Duration(seconds: 2), () {
        _handlingUnauthorized = false;
      });
    }
  }

  // ---- Public verbs ---------------------------------------------------------

  Future<ApiEnvelope> get(String path, {Map<String, dynamic>? query, CancelToken? cancelToken}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query, cancelToken: cancelToken));

  /// [authenticated] = false sends the request without the bearer token (used
  /// by the public endpoints such as registration step 1).
  Future<ApiEnvelope> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    bool authenticated = true,
    void Function(int sent, int total)? onProgress,
  }) => _send(
    () => _dio.post<dynamic>(
      path,
      data: body,
      queryParameters: query,
      cancelToken: cancelToken,
      onSendProgress: onProgress,
      options: authenticated ? null : Options(extra: _skipAuthExtra),
    ),
  );

  Future<ApiEnvelope> put(String path, {Object? body, CancelToken? cancelToken}) =>
      _send(() => _dio.put<dynamic>(path, data: body, cancelToken: cancelToken));

  Future<ApiEnvelope> patch(String path, {Object? body, CancelToken? cancelToken}) =>
      _send(() => _dio.patch<dynamic>(path, data: body, cancelToken: cancelToken));

  Future<ApiEnvelope> delete(String path, {Object? body, CancelToken? cancelToken}) =>
      _send(() => _dio.delete<dynamic>(path, data: body, cancelToken: cancelToken));

  /// Multipart upload. [fields] are simple values; [files] map field -> path.
  /// [arrayFiles] map field -> list of paths (sent as `field[]`).
  ///
  /// [authenticated] = false sends the request without the bearer token (used by
  /// the public `POST /auth/register/complete`).
  Future<ApiEnvelope> multipart(
    String path, {
    Map<String, dynamic> fields = const <String, dynamic>{},
    Map<String, String?> files = const <String, String?>{},
    Map<String, List<String>> arrayFiles = const <String, List<String>>{},
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
    bool authenticated = true,
  }) async {
    final FormData form = FormData();
    fields.forEach((String key, dynamic value) {
      if (value == null) return;
      if (value is List) {
        for (final dynamic v in value) {
          form.fields.add(MapEntry<String, String>('$key[]', v.toString()));
        }
      } else {
        form.fields.add(MapEntry<String, String>(key, value.toString()));
      }
    });
    for (final MapEntry<String, String?> e in files.entries) {
      final String? filePath = e.value;
      if (filePath == null || filePath.isEmpty) continue;
      form.files.add(
        MapEntry<String, MultipartFile>(e.key, await MultipartFile.fromFile(filePath)),
      );
    }
    for (final MapEntry<String, List<String>> e in arrayFiles.entries) {
      for (final String p in e.value) {
        if (p.isEmpty) continue;
        form.files.add(
          MapEntry<String, MultipartFile>('${e.key}[]', await MultipartFile.fromFile(p)),
        );
      }
    }
    return _send(
      () => _dio.post<dynamic>(
        path,
        data: form,
        cancelToken: cancelToken,
        onSendProgress: onProgress,
        options: authenticated ? null : Options(extra: _skipAuthExtra),
      ),
    );
  }

  // ---- Core ----------------------------------------------------------------

  Future<ApiEnvelope> _send(Future<Response<dynamic>> Function() run) async {
    if (!await _networkInfo.isConnected) {
      throw const NetworkException();
    }
    try {
      final Response<dynamic> response = await run();
      return _envelope(response.data);
    } on DioException catch (e) {
      throw ApiErrorParser.parse(e);
    }
  }

  ApiEnvelope _envelope(dynamic body) {
    if (body is Map<String, dynamic>) {
      return ApiEnvelope(
        success: body['success'] == true,
        message: (body['message'] ?? '').toString(),
        data: body['data'],
      );
    }
    // Non-standard body — wrap so callers still get something usable.
    return ApiEnvelope(success: true, message: '', data: body);
  }
}
