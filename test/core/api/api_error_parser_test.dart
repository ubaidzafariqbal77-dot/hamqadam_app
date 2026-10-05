import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/core/api/api_error_parser.dart';
import 'package:hamqadam/exceptions/app_exceptions.dart';

/// Regression coverage for the production incident where the server TLS
/// certificate expired and every login in the app failed with a bare "null".
DioException _handshakeFailure(DioExceptionType type) {
  return DioException(
    requestOptions: RequestOptions(path: '/api/v1/auth/login/email'),
    type: type,
    error: const HandshakeException('HandshakeException CERTIFICATE_EXPIRED: certificate has expired'),
  );
}

void main() {
  group('ApiErrorParser TLS handling', () {
    test('expired certificate as badCertificate -> TlsException', () {
      final AppException result = ApiErrorParser.parse(
        _handshakeFailure(DioExceptionType.badCertificate),
      );
      expect(result, isA<TlsException>());
    });

    test('expired certificate as unknown -> TlsException (iOS/Android path)', () {
      final AppException result = ApiErrorParser.parse(
        _handshakeFailure(DioExceptionType.unknown),
      );
      expect(result, isA<TlsException>());
    });

    test('expired certificate as connectionError -> TlsException, not NetworkException', () {
      final AppException result = ApiErrorParser.parse(
        _handshakeFailure(DioExceptionType.connectionError),
      );
      expect(result, isA<TlsException>());
    });

    test('TLS message is never null or blank', () {
      final AppException result = ApiErrorParser.parse(
        _handshakeFailure(DioExceptionType.unknown),
      );
      expect(result.message.trim(), isNotEmpty);
      expect(result.message.trim().toLowerCase(), isNot('null'));
    });
  });

  group('ApiErrorParser never surfaces a null message', () {
    test('unknown error with no message and no cause -> useful fallback', () {
      final AppException result = ApiErrorParser.parse(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.unknown,
        ),
      );
      expect(result.message.trim().toLowerCase(), isNot('null'));
      expect(result.message.trim(), isNotEmpty);
    });

    test('literal null cause is not echoed back to the user', () {
      final AppException result = ApiErrorParser.parse(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.unknown,
          error: null,
        ),
      );
      expect(result.message.trim().toLowerCase(), isNot('null'));
    });
  });

  group('ApiErrorParser still classifies normal failures correctly', () {
    test('no internet -> NetworkException', () {
      final AppException result = ApiErrorParser.parse(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.unknown,
          error: const SocketException('Failed host lookup'),
        ),
      );
      expect(result, isA<NetworkException>());
    });

    test('401 -> UnauthorizedException', () {
      final AppException result = ApiErrorParser.parse(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 401,
            data: <String, dynamic>{'message': 'Invalid email or password.'},
          ),
        ),
      );
      expect(result, isA<UnauthorizedException>());
      expect(result.message, 'Invalid email or password.');
    });

    test('500 -> ServerException with a safe message (no stack trace leak)', () {
      final AppException result = ApiErrorParser.parse(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 500,
            data: <String, dynamic>{'message': 'SQLSTATE[42S02] at /var/www/app.php:88'},
          ),
        ),
      );
      expect(result, isA<ServerException>());
      expect(result.message, isNot(contains('SQLSTATE')));
    });

    test('timeout -> TimeoutException', () {
      final AppException result = ApiErrorParser.parse(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      expect(result, isA<TimeoutException>());
    });
  });
}