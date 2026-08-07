import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/registration_sections.dart';
import '../../models/profile_model.dart';
import '../utils/app_logger.dart';

/// Remembers, for every profile section, whether the user actually filled it or
/// skipped it during signup.
///
/// This is what drives the profile-completion graph: a skipped section stays
/// pending until the user fills it in from "Complete your profile", at which
/// point the percentage moves up. The state is persisted (one JSON slot in
/// SharedPreferences) so it survives restarts, and is reconciled with the data
/// `GET /profile` reports so a fresh install does not start from zero.
class ProfileCompletionService {
  ProfileCompletionService(this._prefs) {
    _restore();
  }

  static const String _storageKey = 'profile_sections_v1';

  final SharedPreferences _prefs;

  /// Sections the user filled in (observable so the graph updates live).
  final RxSet<int> done = <int>{}.obs;

  /// Sections the user explicitly skipped.
  final RxSet<int> skipped = <int>{}.obs;

  List<int> get sections => RegSections.profile;

  bool isDone(int step) => done.contains(step);
  bool isSkipped(int step) => skipped.contains(step) && !isDone(step);

  int get doneCount => sections.where(isDone).length;
  int get totalCount => sections.length;

  double get fraction => totalCount == 0 ? 0 : (doneCount / totalCount).clamp(0.0, 1.0);
  int get percent => (fraction * 100).round();
  bool get isComplete => doneCount >= totalCount;

  /// Sections still waiting for data (skipped ones plus anything never filled).
  List<int> get pendingSections =>
      sections.where((int s) => !isDone(s)).toList(growable: false);

  int get pendingCount => pendingSections.length;

  // ---- Mutations ------------------------------------------------------------

  void markDone(int step) {
    if (!RegSections.isProfileSection(step)) return;
    skipped.remove(step);
    done.add(step);
    _persist();
  }

  void markSkipped(int step) {
    if (!RegSections.isProfileSection(step)) return;
    done.remove(step);
    skipped.add(step);
    _persist();
  }

  /// Records the outcome of the signup flow: everything the user completed is
  /// done, every other section is left pending (skipped).
  void seedFromRegistration(Set<int> completed) {
    done
      ..clear()
      ..addAll(completed.where(RegSections.isProfileSection));
    skipped
      ..clear()
      ..addAll(sections.where((int s) => !done.contains(s)));
    _persist();
  }

  /// Fills gaps from the server copy of the profile (used after `GET /profile`),
  /// so data entered on another device still counts. Only ever marks sections
  /// as done — never wipes a section the user already completed.
  void reconcile(ProfileModel profile) {
    final MemberDetails m = profile.member;
    final Set<int> found = <int>{};

    void mark(int step, bool present) {
      if (present && !done.contains(step)) found.add(step);
    }

    bool filled(String? s) => s != null && s.trim().isNotEmpty;

    mark(3, m.motherTongue != null || m.knownLanguages.isNotEmpty);
    mark(7, m.maritalStatusId != null);
    mark(12, filled(profile.user.photo));
    mark(13, filled(m.aboutMe));
    mark(14, filled(m.verificationStatus) && m.verificationStatus!.toLowerCase() != 'unverified');

    if (found.isEmpty) return;
    done.addAll(found);
    skipped.removeAll(found);
    _persist();
  }

  Future<void> clear() async {
    done.clear();
    skipped.clear();
    await _prefs.remove(_storageKey);
  }

  // ---- Persistence ----------------------------------------------------------

  void _persist() {
    try {
      _prefs.setString(
        _storageKey,
        jsonEncode(<String, dynamic>{
          'done': done.toList()..sort(),
          'skipped': skipped.toList()..sort(),
        }),
      );
    } catch (e) {
      AppLogger.w('Profile completion persist failed: $e');
    }
  }

  void _restore() {
    final String? raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      done.addAll(_ints(decoded['done']));
      skipped.addAll(_ints(decoded['skipped']));
    } catch (_) {
      // Corrupt record — start from an empty picture.
    }
  }

  static Iterable<int> _ints(dynamic v) {
    if (v is! List) return const <int>[];
    return v
        .map((dynamic e) => e is int ? e : int.tryParse('$e'))
        .whereType<int>()
        .where(RegSections.isProfileSection);
  }
}
