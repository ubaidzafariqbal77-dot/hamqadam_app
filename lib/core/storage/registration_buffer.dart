import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/app_constants.dart';
import '../utils/app_logger.dart';

/// In-memory + draft-backed store for the whole 18-step registration flow.
///
/// The document spreads the account-creation fields (name, email, phone,
/// password) across several steps, so the account cannot be created until the
/// Account Security step. Every screen therefore writes its fields here; the
/// account is created mid-flow and the remaining profile is submitted to the
/// backend step-endpoints at the end.
///
/// Sensitive values (password, identity documents, media paths) are kept in
/// memory only and are never written to SharedPreferences.
class RegistrationBuffer {
  RegistrationBuffer(this._prefs) {
    _restore();
  }

  final SharedPreferences _prefs;

  final Map<String, dynamic> _data = <String, dynamic>{};

  /// Keys that must never be persisted to disk.
  static const Set<String> _sensitive = <String>{
    'password',
    'password_confirmation',
    'cnic_number',
    'cnic_front',
    'cnic_back',
    'selfie',
    'profile_photo',
    'gallery',
  };

  Map<String, dynamic> get data => Map<String, dynamic>.unmodifiable(_data);

  bool get accountCreated => _data['__account_created'] == true;
  set accountCreated(bool v) {
    _data['__account_created'] = v;
    persist();
  }

  /// Furthest UI step the user reached (1-based). Used to resume.
  int get lastStep => (_data['__last_step'] as int?) ?? 1;
  set lastStep(int v) {
    _data['__last_step'] = v;
    persist();
  }

  /// Steps the user actually completed with data. Skipped steps are NOT here,
  /// so they never raise the completion percentage.
  Set<int> get completedSteps => _intSet('__completed');

  Set<int> _intSet(String key) {
    final dynamic raw = _data[key];
    if (raw is List) {
      return raw.map((dynamic e) => int.tryParse('$e') ?? 0).where((int e) => e > 0).toSet();
    }
    return <int>{};
  }

  void markCompleted(int step) {
    final Set<int> s = completedSteps..add(step);
    _data['__completed'] = s.toList()..sort();
    final Set<int> sk = skippedSteps..remove(step);
    _data['__skipped'] = sk.toList()..sort();
    persist();
  }

  void unmarkCompleted(int step) {
    final Set<int> s = completedSteps..remove(step);
    _data['__completed'] = s.toList()..sort();
    persist();
  }

  /// Steps the user explicitly skipped (kept so the profile-completion picture
  /// can tell "skipped" apart from "never reached").
  Set<int> get skippedSteps => _intSet('__skipped');

  void markSkipped(int step) {
    final Set<int> s = skippedSteps..add(step);
    _data['__skipped'] = s.toList()..sort();
    persist();
  }

  /// True once the signup flow finished — stops [RegistrationController.resume]
  /// from dropping the user back into registration while the buffered answers
  /// are deliberately kept for later section edits.
  bool get registrationDone => _data['__registration_done'] == true;
  set registrationDone(bool v) {
    _data['__registration_done'] = v;
    persist();
  }

  bool get isEmpty => _data.keys.where((String k) => !k.startsWith('__')).isEmpty;

  T? get<T>(String key) => _data[key] as T?;

  dynamic raw(String key) => _data[key];

  int? getInt(String key) {
    final dynamic v = _data[key];
    if (v is int) return v;
    return int.tryParse('${v ?? ''}');
  }

  String? getString(String key) {
    final dynamic v = _data[key];
    return v?.toString();
  }

  List<String> getStringList(String key) {
    final dynamic v = _data[key];
    if (v is List) return v.map((dynamic e) => e.toString()).toList();
    return <String>[];
  }

  /// Merges [values] into the buffer and persists the non-sensitive subset.
  void put(Map<String, dynamic> values) {
    _data.addAll(values);
    persist();
  }

  void putOne(String key, dynamic value) => put(<String, dynamic>{key: value});

  void persist() {
    try {
      final Map<String, dynamic> safe = <String, dynamic>{};
      _data.forEach((String k, dynamic v) {
        if (!_sensitive.contains(k)) safe[k] = v;
      });
      _prefs.setString(AppConstants.bufferDraftKey, jsonEncode(safe));
    } catch (e) {
      AppLogger.w('Registration buffer persist failed: $e');
    }
  }

  void _restore() {
    final String? raw = _prefs.getString(AppConstants.bufferDraftKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) _data.addAll(decoded);
    } catch (_) {
      // Corrupt draft — ignore.
    }
  }

  Future<void> clear() async {
    _data.clear();
    await _prefs.remove(AppConstants.bufferDraftKey);
  }
}
