import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/storage_keys.dart';
import '../../models/user_model.dart';
import '../utils/app_logger.dart';

/// Stores the **current logged-in user** locally in SharedPreferences (the full
/// user JSON returned by the API). The auth token stays in secure storage; this
/// holds only the non-sensitive profile so any screen can read it quickly.
///
/// Usage from anywhere:
///   `final user = Get.find<CurrentUserService>().user;`     (UserModel?)
///   `final raw  = Get.find<CurrentUserService>().rawJson;`  (full Map)
class CurrentUserService {
  CurrentUserService(this._prefs) {
    load(); // warm the in-memory cache at startup
  }

  final SharedPreferences _prefs;

  UserModel? _cached;
  Map<String, dynamic>? _cachedRaw;

  /// Cached parsed user (null when signed out).
  UserModel? get user => _cached;

  /// Full raw user map (includes nested `member`, membership, etc.).
  Map<String, dynamic>? get rawJson => _cachedRaw;

  bool get hasUser => _cached != null;

  /// Persist the complete user JSON.
  Future<void> save(Map<String, dynamic> json) async {
    _cachedRaw = json;
    _cached = UserModel.fromJson(json);
    try {
      await _prefs.setString(StorageKeys.currentUser, jsonEncode(json));
    } catch (e) {
      AppLogger.w('CurrentUser save failed: $e');
    }
  }

  /// Load from disk into the cache and return it.
  UserModel? load() {
    final String? raw = _prefs.getString(StorageKeys.currentUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _cachedRaw = decoded;
        _cached = UserModel.fromJson(decoded);
        return _cached;
      }
    } catch (_) {}
    return null;
  }

  Future<void> clear() async {
    _cached = null;
    _cachedRaw = null;
    await _prefs.remove(StorageKeys.currentUser);
  }
}
