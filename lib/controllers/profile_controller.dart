import 'package:get/get.dart';

import '../constants/app_lookups.dart';
import '../constants/income_options.dart';
import '../core/api/api_response.dart';
import '../core/storage/profile_completion_service.dart';
import '../exceptions/app_exceptions.dart';
import '../models/lookup_item_model.dart';
import '../models/privacy_settings_model.dart';
import '../models/profile_model.dart';
import '../models/public_profile_model.dart';
import '../repositories/profile_repository.dart';
import 'lookup_controller.dart';

/// Drives the Profile screen: fetches `GET /profile` and exposes the result as
/// an [ApiState] so the UI can render the mandated loading / success / empty /
/// error states. Also resolves the member's numeric ids (marital status,
/// gender, languages, on-behalf) into human labels via [LookupController].
class ProfileController extends GetxController {
  ProfileController(this._repo, this._lookup, this.completion);

  final ProfileRepository _repo;
  final LookupController _lookup;

  /// Drives the completion graph; reconciled with the server copy on every load
  /// so data added elsewhere still counts as a finished section.
  final ProfileCompletionService completion;

  final Rx<ApiState<ProfileModel>> state = const ApiState<ProfileModel>.initial().obs;

  ProfileModel? get profile => state.value.data;

  @override
  void onInit() {
    super.onInit();
    // Warm every list the profile resolves ids against (the bundled copy is
    // instant; a network refresh, if available, updates in place). Without this
    // the section cards would render blanks where `religion_id: 1` should read
    // "Islam".
    for (final String key in lookupKeysUsed) {
      _lookup.ensure(key);
    }
    load();
  }

  Future<void> load() async {
    state.value = const ApiState<ProfileModel>.loading();
    try {
      final ProfileModel data = await _repo.fetchProfile();
      completion.reconcile(data);
      state.value = ApiState<ProfileModel>.success(data);
    } on AppException catch (e) {
      state.value = ApiState<ProfileModel>.fromException(e);
    } catch (e) {
      state.value = ApiState<ProfileModel>.serverError(e.toString());
    }
  }

  Future<void> reload() => load();

  // ---- Privacy / visibility / deactivation ---------------------------------

  /// True while one of the mutating profile actions below is in flight, so the
  /// UI can disable its switches without flipping the whole screen to loading.
  final RxBool mutating = false.obs;
  final RxnString actionError = RxnString();

  /// Current privacy switches, derived from the loaded profile.
  ///
  /// NOTE: `do_not_disturb` and `invisible_mode` are accepted by the update
  /// endpoint but are NOT echoed by the read resource, so they always read
  /// false here. Keep the local value after a successful save rather than
  /// re-reading it.
  PrivacySettingsModel get privacySettings {
    final ProfilePrivacy? p = profile?.privacy;
    if (p == null) return const PrivacySettingsModel();
    return PrivacySettingsModel(
      showPhoto: p.showPhoto,
      showGallery: p.showGallery,
      showContact: p.showContact,
      showEmail: p.showEmail,
      showPhone: p.showPhone,
      showLocation: p.showLocation,
      allowProfileViewNotifications: p.allowProfileViewNotifications,
    );
  }

  /// `PATCH /profile/privacy`. Sends only what changed. Returns null on
  /// success, or a message to show.
  Future<String?> updatePrivacy(PrivacySettingsModel updated) async {
    final Map<String, dynamic> body = updated.changesFrom(privacySettings);
    if (body.isEmpty) return null;
    return _mutate(() async {
      await _repo.updatePrivacy(body);
      // The endpoint returns the privacy block only, so re-read the profile to
      // keep every derived view consistent.
      await load();
    });
  }

  /// `PATCH /profile/visibility` — hides or shows the profile in search and
  /// matches. Returns null on success, or a message to show.
  Future<String?> setHidden(bool hidden) => _mutate(() async {
    final ProfileModel updated = await _repo.updateVisibility(hideProfile: hidden);
    state.value = ApiState<ProfileModel>.success(updated);
  });

  /// `POST /profile/deactivate`.
  ///
  /// Removes the member from search and matching; reactivation needs support.
  /// Confirm with the member BEFORE calling this. Returns the server message on
  /// success so the caller can show it while signing out.
  Future<({String? error, String? message})> deactivate() async {
    mutating.value = true;
    actionError.value = null;
    try {
      final String message = await _repo.deactivate();
      return (error: null, message: message);
    } on AppException catch (e) {
      actionError.value = e.message;
      return (error: e.message, message: null);
    } catch (e) {
      actionError.value = e.toString();
      return (error: e.toString(), message: null);
    } finally {
      mutating.value = false;
    }
  }

  Future<String?> _mutate(Future<void> Function() action) async {
    if (mutating.value) return null;
    mutating.value = true;
    actionError.value = null;
    try {
      await action();
      return null;
    } on AppException catch (e) {
      actionError.value = e.message;
      return e.message;
    } catch (e) {
      actionError.value = e.toString();
      return e.toString();
    } finally {
      mutating.value = false;
    }
  }

  // ---- Other members -------------------------------------------------------

  /// `GET /profiles/{id}` — another member's profile.
  ///
  /// Carries a verification badge only; the AI internals are the owner's.
  Future<PublicProfileModel?> fetchPublicProfile(int id) async {
    try {
      return await _repo.fetchPublicProfile(id);
    } on AppException catch (e) {
      actionError.value = e.message;
      return null;
    }
  }

  /// `GET /profiles/{id}/compatibility`
  Future<CompatibilityModel?> fetchCompatibility(int id) async {
    try {
      return await _repo.fetchCompatibility(id);
    } on AppException catch (e) {
      actionError.value = e.message;
      return null;
    }
  }

  /// Replaces the cached profile after a successful edit (`PUT /profile`) so the
  /// Profile screen reflects the change without another round-trip.
  void applyUpdated(ProfileModel updated) {
    state.value = ApiState<ProfileModel>.success(updated);
  }

  // ---- Label resolution -----------------------------------------------------

  /// Field name → the lookup list that resolves its id.
  ///
  /// `GET /profile` hands back raw foreign keys (`religion_id: 1`) and the
  /// sections are rendered generically, so resolution is keyed by field name:
  /// a field the backend adds later reads as a name the moment it is listed
  /// here, and falls back to its raw text until then.
  static const Map<String, String> _lookupForField = <String, String>{
    'gender': LookupKeys.genders,
    'on_behalf_id': LookupKeys.onBehalf,
    'marital_status_id': LookupKeys.maritalStatuses,
    'mother_tongue': LookupKeys.languages,
    'known_languages': LookupKeys.languages,
    'languages_spoken_fluently': LookupKeys.languages,
    'religion_id': LookupKeys.religions,
    'sect_main_id': LookupKeys.sectMain,
    'school_of_thought_id': LookupKeys.schoolOfThought,
    'tradition_id': LookupKeys.traditions,
    'caste_id': LookupKeys.castes,
    'sub_caste_id': LookupKeys.subCastes,
    'country_id': LookupKeys.countries,
    'state_id': LookupKeys.states,
    'city_id': LookupKeys.cities,
    'area_id': LookupKeys.areas,
    'education_level_id': LookupKeys.educationLevels,
    'degree_id': LookupKeys.degrees,
    'field_of_study_id': LookupKeys.fieldsOfStudy,
    'institution_id': LookupKeys.institutions,
    'profession_category_id': LookupKeys.professionCategories,
    'profession_id': LookupKeys.professions,
    'diet': LookupKeys.diet,
    'employment_status': LookupKeys.employmentStatus,
    'education_status': LookupKeys.educationStatus,
    'live_with_family': LookupKeys.liveWithFamily,
    'family_values': LookupKeys.familyValues,
    'marriage_timeline': LookupKeys.marriageTimeline,
    'willing_to_work_after_marriage': LookupKeys.willingToWork,
    'expects_spouse_to_work': LookupKeys.expectsSpouseToWork,
    'hobbies': LookupKeys.hobbies,
    'interests': LookupKeys.hobbies,
    // App-supplied lists (the reference endpoint serves neither).
    'siblings_brothers': LookupKeys.siblings,
    'siblings_sisters': LookupKeys.siblings,
  };

  /// The distinct lists the profile needs warmed.
  static final List<String> lookupKeysUsed = _lookupForField.values.toSet().toList();

  /// Plumbing the profile never shows.
  static const Set<String> hiddenFields = <String>{
    'id',
    'member_id',
    'user_id',
    'created_at',
    'updated_at',
    'deleted_at',
  };

  /// Labels that would read badly if derived mechanically from the field name.
  static const Map<String, String> _fieldLabels = <String, String>{
    'about_me': 'About',
    'ai_generated_bio': 'AI bio',
    'cnic_number': 'CNIC number',
    'mother_tongue': 'Mother tongue',
    'on_behalf_id': 'Profile for',
    'sect_main_id': 'Sect',
    'school_of_thought_id': 'School of thought',
    'field_of_study_id': 'Field of study',
    'profession_category_id': 'Profession category',
    'annual_salary_range_id': 'Salary range',
    'years_of_experience': 'Experience (years)',
    'siblings_brothers': 'Brothers',
    'siblings_sisters': 'Sisters',
    'languages_spoken_fluently': 'Languages spoken',
    'hijab_beard_preference': 'Hijab / beard',
    'sub_caste_id': 'Sub-caste',
  };

  /// Human label for a raw field name (`religion_id` → `Religion`).
  static String fieldLabel(String field) {
    final String? special = _fieldLabels[field];
    if (special != null) return special;
    String s = field;
    if (s.endsWith('_id')) s = s.substring(0, s.length - 3);
    s = s.replaceAll('_', ' ').trim();
    if (s.isEmpty) return field;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Touch this inside an `Obx` to subscribe to the lookup store, so id → label
  /// text fills itself in the moment a list lands.
  int get lookupRevision => _lookup.states.length;

  /// One profile field ready to render: ids become names, booleans become
  /// Yes / No, dates and money are formatted.
  ///
  /// Null means "nothing worth showing", so a caller can treat every flavour of
  /// missing the same way.
  String? displayValue(String field, dynamic raw) {
    final List<String> parts = displayList(field, raw);
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// [displayValue] kept as separate items, so a list field (hobbies,
  /// languages) can render as chips instead of one long comma-joined line.
  List<String> displayList(String field, dynamic raw) {
    if (raw == null) return const <String>[];
    if (raw is List) {
      return raw
          .map((dynamic e) => _displayOne(field, e))
          .whereType<String>()
          .toList(growable: false);
    }
    if (raw is Map) {
      return raw.values
          .map((dynamic e) => _displayOne(field, e))
          .whereType<String>()
          .toList(growable: false);
    }
    final String? single = _displayOne(field, raw);
    return single == null ? const <String>[] : <String>[single];
  }

  String? _displayOne(String field, dynamic raw) {
    if (raw == null) return null;
    if (raw is bool) return raw ? 'Yes' : 'No';
    final String text = '$raw'.trim();
    if (text.isEmpty) return null;

    // Income is stored as a decimal, so it never equals a band's id exactly —
    // resolve it to the band that CONTAINS it instead of looking it up.
    if (field == 'annual_income') {
      final double? amount = double.tryParse(text);
      final String? band = IncomeBand.labelFor(amount);
      if (band != null) return band;
    }

    final String? lookupKey = _lookupForField[field];
    if (lookupKey != null) {
      final String? label = _labelIn(lookupKey, text);
      if (label != null) return label;
      // An id with no name yet (list still loading, or the server knows a row
      // this build does not) reads as nothing — "Religion: 1" is worse than a
      // field that simply fills in a moment later.
      if (int.tryParse(text) != null) return null;
    }
    if (_isDateField(field)) return _fmtDate(DateTime.tryParse(text)) ?? text;
    if (field == 'height') return _fmtHeight(text) ?? text;
    if (_isMoneyField(field)) return _fmtMoney(text) ?? text;
    return _tidyNumber(text);
  }

  /// Matches on [LookupItem.apiValue], so numeric ids and the string codes of
  /// the hardcoded lists (`immediate`, `yes`) both resolve.
  String? _labelIn(String lookupKey, String needle) {
    for (final LookupItem i in _lookup.itemsOf(lookupKey)) {
      if ('${i.apiValue}' == needle) return i.name;
    }
    return null;
  }

  static bool _isDateField(String field) =>
      field.contains('date') || field.contains('birthday') || field.endsWith('_at');

  static bool _isMoneyField(String field) =>
      field.contains('income') || field.contains('salary');

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String? _fmtDate(DateTime? d) =>
      d == null ? null : '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// The API stores height as feet-and-inches packed into one decimal
  /// (168 cm → 5.6, i.e. 5'6"), so the fractional digits are the inches.
  static String? _fmtHeight(String text) {
    final List<String> parts = text.split('.');
    final int? feet = int.tryParse(parts.first);
    if (feet == null || feet <= 0) return null;
    final int inches = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    if (inches > 11) return null;
    return "$feet' $inches\"";
  }

  static String? _fmtMoney(String text) {
    final double? v = double.tryParse(text);
    if (v == null) return null;
    final String whole = v.truncate().toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
      out.write(whole[i]);
    }
    return out.toString();
  }

  /// Drops the trailing `.0` the backend sends on whole numbers.
  static String _tidyNumber(String text) {
    final double? v = double.tryParse(text);
    if (v == null) return text;
    return v == v.truncateToDouble() ? v.truncate().toString() : text;
  }

  String? _nameFor(String key, int? id) {
    if (id == null) return null;
    for (final LookupItem i in _lookup.itemsOf(key)) {
      if (i.id == id) return i.name;
    }
    return null;
  }

  String? genderLabel(String? genderId) =>
      _nameFor(LookupKeys.genders, genderId == null ? null : int.tryParse(genderId));

  String? maritalLabel(int? id) => _nameFor(LookupKeys.maritalStatuses, id);

  String? onBehalfLabel(int? id) => _nameFor(LookupKeys.onBehalf, id);

  String? languageLabel(int? id) => _nameFor(LookupKeys.languages, id);

  List<String> languageLabels(List<int> ids) =>
      ids.map(languageLabel).whereType<String>().toList(growable: false);
}
