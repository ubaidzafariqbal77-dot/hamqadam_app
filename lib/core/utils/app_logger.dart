import 'dart:convert';

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
    'otp',
    'profile_photo',
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

  /// Redacts sensitive keys before logging a request/response body.
  static void body(String label, Object? data) {
    if (!kDebugMode) return;
    debugPrint('📦 $label: ${_redact(data)}');
  }

  static Object? _redact(Object? data) {
    if (data is Map) {
      return data.map((dynamic k, dynamic v) {
        final String key = k.toString().toLowerCase();
        if (_sensitiveKeys.contains(key)) return MapEntry<String, Object?>(k.toString(), '***');
        return MapEntry<String, Object?>(k.toString(), _redact(v));
      });
    }
    if (data is List) return data.map(_redact).toList();
    try {
      // Ensure it is representable; fall back to string.
      jsonEncode(data);
      return data;
    } catch (_) {
      return data.toString();
    }
  }
}
