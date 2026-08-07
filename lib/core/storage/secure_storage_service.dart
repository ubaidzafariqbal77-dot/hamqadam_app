import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../constants/storage_keys.dart';

/// Secure, encrypted storage for the Sanctum token and basic user info.
///
/// Tokens are NEVER placed in SharedPreferences. Reads are cached in memory
/// after first load so the token interceptor stays synchronous-friendly.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
          );

  final FlutterSecureStorage _storage;

  String? _cachedToken;
  bool _tokenLoaded = false;

  /// Loads the token into memory once at startup.
  Future<String?> init() async {
    _cachedToken = await _storage.read(key: StorageKeys.authToken);
    _tokenLoaded = true;
    return _cachedToken;
  }

  String? get cachedToken => _cachedToken;
  bool get hasToken => (_cachedToken ?? '').isNotEmpty;

  Future<String?> readToken() async {
    if (_tokenLoaded) return _cachedToken;
    return init();
  }

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    _tokenLoaded = true;
    await _storage.write(key: StorageKeys.authToken, value: token);
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(key: StorageKeys.authUser, value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> readUser() async {
    final String? raw = await _storage.read(key: StorageKeys.authUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Clears the session (token + user) — draft data is untouched.
  Future<void> clearSession() async {
    _cachedToken = null;
    _tokenLoaded = true;
    await _storage.delete(key: StorageKeys.authToken);
    await _storage.delete(key: StorageKeys.authUser);
  }
}
