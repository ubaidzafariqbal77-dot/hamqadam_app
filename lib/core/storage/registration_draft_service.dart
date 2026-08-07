import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/storage_keys.dart';
import '../utils/app_logger.dart';

/// Persists **non-sensitive** per-step draft data in SharedPreferences so an
/// accidental app close does not lose progress.
///
/// Never store passwords, tokens or identity documents here. The step
/// controllers strip those before calling [saveStep].
class RegistrationDraftService {
  RegistrationDraftService(this._prefs);

  final SharedPreferences _prefs;

  String _key(String stepKey) => '${StorageKeys.registrationDraftPrefix}$stepKey';

  Future<void> saveStep(String stepKey, Map<String, dynamic> data) async {
    try {
      await _prefs.setString(_key(stepKey), jsonEncode(data));
    } catch (e) {
      AppLogger.w('Draft save failed for $stepKey: $e');
    }
  }

  Map<String, dynamic>? loadStep(String stepKey) {
    final String? raw = _prefs.getString(_key(stepKey));
    if (raw == null || raw.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearStep(String stepKey) => _prefs.remove(_key(stepKey));

  Future<void> clearAll(List<String> stepKeys) async {
    for (final String k in stepKeys) {
      await _prefs.remove(_key(k));
    }
    await _prefs.remove(StorageKeys.lastKnownNextStep);
  }

  Future<void> setNextStep(String stepKey) =>
      _prefs.setString(StorageKeys.lastKnownNextStep, stepKey);

  String? get lastKnownNextStep => _prefs.getString(StorageKeys.lastKnownNextStep);
}
