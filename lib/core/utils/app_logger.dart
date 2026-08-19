import 'package:flutter/foundation.dart';

/// Lightweight logger that only prints in debug mode and redacts sensitive
/// values (tokens, passwords, identity documents, private media).
class AppLogger {
  const AppLogger._();

  static const Set<String> _sensitiveKeys = <String>{
    'password',
    'password_confirmation',
    'token',
    'access_token',
    'authorization',
    'cnic_number',
    'cnic_front',
    'cnic_back',
    'selfie',
    // The complete-registration payload calls it `selfie_verification`, and the
    // extra photos travel as an array of base64 strings — both are media, both
    // must be redacted.
    'selfie_verification',
    'otp',
    'code',
    'profile_photo',
    'additional_photos',
    'cover_photo',
    'video_introduction',
    'voice_introduction',
    'private_gallery',
  };

  static void d(String message) {
    if (kDebugMode) debugPrint('💬 $message');
  }

  static void i(String message) {
    if (kDebugMode) debugPrint('ℹ️  $message');
  }

  static void w(String message) {
    if (kDebugMode) debugPrint('⚠️  $message');
  }

  static void e(String message, [Object? error, StackTrace? st]) {
    if (kDebugMode) {
      debugPrint('⛔ $message${error != null ? ' | $error' : ''}');
      if (st != null) debugPrint(st.toString());
    }
  }

  /// Longest body ever written to the console. `dropdown-reference-data` alone
  /// is ~2.4 MB across ~48 000 rows; deep-copying it for redaction and pushing
  /// it through [debugPrint]'s rate limiter stalls the app for many seconds, so
  /// bodies are summarised past this size instead of being printed in full.
  static const int _maxBodyChars = 4096;

  /// Deepest level [_redact] walks into. Below it, collections are summarised.
  static const int _maxDepth = 6;

  /// Redacts sensitive keys before logging a request/response body.
  ///
  /// Truncated rather than complete: a log line is a debugging aid, and paying
  /// megabytes of string building for one is what made the registration
  /// dropdowns feel slow.
  static void body(String label, Object? data) {
    if (!kDebugMode) return;
    final String text = _stringify(_redact(data, 0));
    if (text.length <= _maxBodyChars) {
      debugPrint('📦 $label: $text');
    } else {
      debugPrint(
        '📦 $label: ${text.substring(0, _maxBodyChars)}… '
        '[truncated, ${text.length} chars total]',
      );
    }
  }

  /// Cheap `toString` that never throws on an unencodable value.
  static String _stringify(Object? data) {
    try {
      return data.toString();
    } catch (_) {
      return '<unprintable ${data.runtimeType}>';
    }
  }

  static Object? _redact(Object? data, int depth) {
    if (data is Map) {
      if (depth >= _maxDepth) return '{…${data.length} keys}';
      return data.map((dynamic k, dynamic v) {
        final String key = k.toString().toLowerCase();
        if (_sensitiveKeys.contains(key)) return MapEntry<String, Object?>(k.toString(), '***');
        return MapEntry<String, Object?>(k.toString(), _redact(v, depth + 1));
      });
    }
    if (data is List) {
      if (depth >= _maxDepth) return '[…${data.length} items]';
      // Long lists (city/state reference data) are summarised: a handful of rows
      // is enough to debug the shape, and copying all of them is not free.
      if (data.length > 20) {
        return <Object?>[
          for (final Object? row in data.take(5)) _redact(row, depth + 1),
          '…${data.length - 5} more',
        ];
      }
      return data.map((Object? v) => _redact(v, depth + 1)).toList();
    }
    return data;
  }
}
