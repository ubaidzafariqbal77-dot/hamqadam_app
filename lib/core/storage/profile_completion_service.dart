import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/registration_sections.dart';
import '../../models/profile_model.dart';
import '../utils/app_logger.dart';

/// Tracks profile completion: the headline percentage, and which sections still
/// need data so "Complete your profile" can list them.
///
/// THE SERVER OWNS THE PERCENTAGE. `GET /profile` returns
/// `member.profile_completion_percentage`, recalculated by the backend's
/// ProfileCompletionService on every profile write, and set to 100 when
/// registration finishes. That value is what the website shows, so it is what
/// the app shows too.
///
/// This used to be the other way round: the percentage was derived purely from
/// a local SharedPreferences record of which signup steps the user filled, and
/// the reconcile pass that rebuilt it from the server only looked at five of
/// the fifteen sections. So a fully-completed profile came back as 5/15 ≈ 31%
/// after a logout — the account was still 100% complete server-side, the app
/// had simply forgotten. Worse, the profile header read the server value while
/// the completion card read the local one, so the same screen showed 100% and
/// 31% at once.
///
/// The local section map is still kept, for two things the percentage cannot
/// answer on its own: WHICH sections to offer in the completion hub, and what
/// the user explicitly skipped during signup. It is now reconciled against
/// every section the profile payload can speak to, so a fresh install recovers
/// the full picture from one `GET /profile`.
class ProfileCompletionService {
  ProfileCompletionService(this._prefs) {
    _restore();
  }

  static const String _storageKey = 'profile_sections_v2';

  final SharedPreferences _prefs;

  /// Sections the user filled in (observable so the graph updates live).
  final RxSet<int> done = <int>{}.obs;

  /// Sections the user explicitly skipped.
  final RxSet<int> skipped = <int>{}.obs;

  /// `member.profile_completion_percentage` as last reported by the server.
  ///
  /// Persisted so the graph renders the right number immediately on launch,
  /// before `GET /profile` comes back, instead of flashing a low local figure.
  final RxInt serverPercent = 0.obs;

  List<int> get sections => RegSections.profile;

  bool isDone(int step) => done.contains(step);
  bool isSkipped(int step) => skipped.contains(step) && !isDone(step);

  int get doneCount => sections.where(isDone).length;
  int get totalCount => sections.length;

  /// Locally derived percentage — the fallback for when the server has not
  /// reported one yet (offline first launch).
  int get _localPercent =>
      totalCount == 0 ? 0 : ((doneCount / totalCount) * 100).round();

  /// The percentage to show. Server value wins whenever we have one.
  int get percent {
    final int remote = serverPercent.value;
    return remote > 0 ? remote.clamp(0, 100) : _localPercent;
  }

  double get fraction => (percent / 100).clamp(0.0, 1.0);

  bool get isComplete => percent >= 100;

  /// Sections still waiting for data.
  ///
  /// Empty once the server reports 100%: at that point every section it can see
  /// is filled, and listing leftovers would contradict the headline number.
  List<int> get pendingSections => isComplete
      ? const <int>[]
      : sections.where((int s) => !isDone(s)).toList(growable: false);

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

  /// Adopts the server's percentage. Called from every place that learns it —
  /// `GET /profile`, and the registration status endpoint.
  void setServerPercent(int? value) {
    if (value == null || value <= 0) return;
    final int next = value.clamp(0, 100);
    if (serverPercent.value == next) return;
    serverPercent.value = next;
    // At 100 the server has confirmed there is nothing outstanding, so stop
    // showing sections as pending — otherwise the hub contradicts the header.
    if (next >= 100) {
      done
        ..clear()
        ..addAll(sections);
      skipped.clear();
    }
    _persist();
  }

  /// Records that partner preferences (section 18) exist. They live behind
  /// their own endpoint, so `GET /profile` cannot report them.
  void reconcilePartnerPreferences({required bool hasPreferences}) {
    if (!hasPreferences || done.contains(18)) return;
    markDone(18);
  }

  /// Fills the section map in from the server copy of the profile.
  ///
  /// Only ever marks sections DONE — never wipes one the user already
  /// completed, because the payload is a partial view (partner preferences and
  /// the account-only steps are not in it).
  void reconcile(ProfileModel profile) {
    setServerPercent(
      profile.member.profileCompletion > 0
          ? profile.member.profileCompletion
          : profile.registration.completionPercentage,
    );

    final MemberDetails m = profile.member;
    final Set<int> found = <int>{};

    void mark(int step, bool present) {
      if (present && !done.contains(step)) found.add(step);
    }

    bool text(String? s) => s != null && s.trim().isEmpty == false;

    /// True when a section carries any of the given keys with real data.
    bool any(ProfileSection section, List<String> keys) {
      final Map<String, dynamic> filled = section.filled;
      return keys.any(filled.containsKey);
    }

    // 1 — marriage plans & work intent, collected alongside "Account for".
    mark(
      1,
      m.onBehalfId != null ||
          any(profile.marriageExpectations, <String>[
            'marriage_timeline',
            'looking_for',
            'children_preference',
          ]) ||
          any(profile.career, <String>[
            'willing_to_work_after_marriage',
            'expects_spouse_to_work',
          ]),
    );

    // 3 — religion & language.
    mark(
      3,
      m.motherTongue != null ||
          m.knownLanguages.isNotEmpty ||
          any(profile.religionAndLanguage, <String>[
            'religion_id',
            'sect_main_id',
            'school_of_thought_id',
            'tradition_id',
            'mother_tongue',
            'languages_spoken_fluently',
          ]),
    );

    // 4 — location.
    mark(
      4,
      any(profile.location, <String>['country_id', 'state_id', 'city_id', 'area']),
    );

    // 6 — caste & community.
    mark(
      6,
      any(profile.caste, <String>[
        'caste_id',
        'sub_caste_id',
        'community_biradari',
        'family_value_id',
        'ethnicity',
      ]),
    );

    // 7 — marital status.
    mark(7, m.maritalStatusId != null);

    // 8 — education.
    mark(
      8,
      any(profile.education, <String>[
        'education_level_id',
        'degree_id',
        'degree',
        'field_of_study_id',
        'institution_id',
        'institution',
        'graduation_year',
      ]),
    );

    // 9 — physical.
    mark(
      9,
      any(profile.physical, <String>[
        'height',
        'weight',
        'body_type',
        'complexion',
        'blood_group',
        'diet',
      ]),
    );

    // 10 — career & income.
    mark(
      10,
      any(profile.career, <String>[
        'profession_category_id',
        'profession_id',
        'job_title',
        'organization',
        'years_of_experience',
        'employment_status',
        'annual_income',
        'annual_salary_range_id',
      ]),
    );

    // 12 — photos.
    mark(12, text(profile.user.photo) || profile.photos.profilePhotoUrl != null);

    // 13 — about yourself.
    mark(13, text(m.aboutMe));

    // 14 — identity verification: submitted counts as done for completion
    //      purposes. Whether it PASSED is a separate question, answered by the
    //      verification card — a member cannot make review go faster.
    mark(14, !profile.verification.notSubmitted);

    // 15 — interests & hobbies.
    mark(
      15,
      any(profile.lifestyleAndInterests, <String>[
        'hobbies',
        'interests_multi_select',
        'favorite_weekend_activities',
      ]),
    );

    // 16 — family information (parents and siblings).
    mark(
      16,
      any(profile.family, <String>[
        'father_name',
        'mother_name',
        'father_occupation',
        'mother_occupation',
        'siblings_brothers',
        'siblings_sisters',
        'married_siblings',
      ]),
    );

    // 17 — family details (household, values, location).
    mark(
      17,
      any(profile.family, <String>[
        'family_type',
        'family_values',
        'family_location',
        'family_bio',
        'family_expectations',
        'about_parents',
        'about_siblings',
        'guardian_name',
      ]),
    );

    if (found.isEmpty) return;
    done.addAll(found);
    skipped.removeAll(found);
    _persist();
  }

  Future<void> clear() async {
    done.clear();
    skipped.clear();
    serverPercent.value = 0;
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
          'server_percent': serverPercent.value,
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
      final int stored = decoded['server_percent'] is int
          ? decoded['server_percent'] as int
          : int.tryParse('${decoded['server_percent']}') ?? 0;
      if (stored > 0) serverPercent.value = stored.clamp(0, 100);
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
