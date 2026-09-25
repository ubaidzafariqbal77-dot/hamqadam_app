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

  /// Logs a push/realtime milestone **in every build mode**, release included.
  ///
  /// The one deliberate exception to "only print in debug". Everything about
  /// whether a closed app can be reached is device-specific — which grants the
  /// member gave, whether FCM issued a token, whether the server accepted it —
  /// and none of it reproduces on a developer's machine. Testers run release
  /// builds, where every other line in this class compiles to nothing, so the
  /// evidence for "no notifications on my phone" did not exist and the problem
  /// was diagnosed by guesswork for weeks.
  ///
  /// Kept deliberately narrow: push lifecycle only, one stable tag to filter
  /// on, and never a whole token — [tokenPreview] is what callers pass.
  ///
  ///     adb logcat -s flutter | grep HQ-PUSH
  static void push(String message) {
    // ignore: avoid_print
    print('HQ-PUSH $message');
  }

  /// Opt-in, build-time only: print whole FCM tokens.
  ///
  ///     flutter build apk --release --dart-define=HQ_LOG_FULL_TOKEN=true
  ///
  /// A registration token is a capability — anyone holding it can push to that
  /// device — so it is never written to the system log by default, where every
  /// app with log access could read it. This exists so a tester's phone can be
  /// pushed to directly when diagnosing "nothing arrives on my device", which
  /// otherwise needs a debuggable build the call path cannot be tested on.
  static const bool _logFullToken = bool.fromEnvironment('HQ_LOG_FULL_TOKEN');

  /// The first few characters of a token, for correlating a device with a
  /// server-side log line without writing a credential to the system log.
  static String tokenPreview(String? token) {
    if (token == null || token.isEmpty) return '<none>';
    if (_logFullToken) return token;
    return token.length <= 12 ? '<short>' : '${token.substring(0, 12)}…';
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
