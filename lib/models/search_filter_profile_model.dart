import '../constants/app_constants.dart';

/// Single member profile returned in `GET /search/profiles` listings.
class SearchProfileModel {
  const SearchProfileModel({
    required this.id,
    this.code,
    this.name,
    this.photo,
    this.membership,
    this.approved = false,
    this.age,
    this.gender,
    this.maritalStatusId,
    this.height,
    this.religionId,
    this.casteId,
    this.cityId,
    this.stateId,
    this.countryId,
    this.sectMainId,
    this.schoolOfThoughtId,
    this.educationLevelId,
    this.degreeId,
    this.professionId,
    this.familyValues,
    this.additionalPhotoCount = 0,
    this.identityVerified = false,
    this.verifiedAt,
    this.compatibilityPercentage,
    this.lastActiveAt,
    this.createdAt,
    this.interestScore,
    this.sharedInterests = const <String>[],
  });

  final int id;
  final String? code;
  final String? name;
  final String? photo;
  final int? membership;
  final bool approved;
  final int? age;
  final String? gender;
  final int? maritalStatusId;
  final String? height;
  final int? religionId;
  final int? casteId;
  final int? cityId;
  final int? stateId;
  final int? countryId;

  /// Sect / denomination for the card's "Muslim · Sunni" chips.
  final int? sectMainId;
  final int? schoolOfThoughtId;

  /// Education + career facts for the listing card ("Master's / Designer").
  final int? educationLevelId;
  final int? degreeId;
  final int? professionId;

  /// The card's "Family Oriented" line (the member's own family-values pick).
  final String? familyValues;

  /// Extra gallery photos behind the card image's count badge (front photo
  /// excluded — 0 hides the badge).
  final int additionalPhotoCount;
  final bool identityVerified;
  final DateTime? verifiedAt;
  final int? compatibilityPercentage;
  final DateTime? lastActiveAt;
  final DateTime? createdAt;

  /// Interest-Based Recommendations only (`GET /matches/interest-based`): how
  /// much of the viewer's own interests this member shares, 0-100.
  final int? interestScore;

  /// The words behind [interestScore] ("reading", "travel", …) so a card can
  /// say WHY it was recommended instead of showing a bare number.
  final List<String> sharedInterests;

  String get displayName => (name ?? '').trim().isEmpty ? 'HamQadam Member' : name!.trim();
  String get initial => displayName.isNotEmpty ? displayName[0].toUpperCase() : 'H';
  String? get photoUrl => ApiConfig.mediaUrl(photo);
  bool get hasPhoto => photo != null && photo!.trim().isNotEmpty;
  bool get isVerified => identityVerified;

  String get ageLabel => age != null ? '$age yrs' : '';

  String? get heightFormatted {
    if (height == null || height!.isEmpty) return null;
    final List<String> parts = height!.split('.');
    final int? feet = int.tryParse(parts.first);
    if (feet == null || feet <= 0) return null;
    final int inches = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    if (inches > 11) return null;
    return "$feet' $inches\"";
  }

  factory SearchProfileModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> verification = json['verification'] is Map<String, dynamic>
        ? json['verification'] as Map<String, dynamic>
        : const <String, dynamic>{};

    // `GET /matches` items are ProfileMatch rows, not profiles: the real
    // candidate id rides in `matched_user_id` (`id` is the row's own primary
    // key) and the human fields live in a nested `profile` object. Parsing
    // only the flat search shape made every match card carry a row id — so
    // tapping one opened the WRONG member's detail sheet and a compatibility
    // score that belonged to whoever happened to hold that id.
    final Map<String, dynamic> nested = json['profile'] is Map<String, dynamic>
        ? json['profile'] as Map<String, dynamic>
        : const <String, dynamic>{};

    dynamic field(String key) => json[key] ?? nested[key];

    return SearchProfileModel(
      id: _asInt(json['matched_user_id'] ?? json['id']),
      code: field('code')?.toString(),
      name: field('name')?.toString(),
      photo: field('photo')?.toString(),
      membership: _asIntOrNull(json['membership']),
      approved: _asBool(json['approved'] ?? nested['verified']),
      age: _asIntOrNull(field('age')),
      gender: field('gender')?.toString(),
      maritalStatusId: _asIntOrNull(json['marital_status_id']),
      height: field('height')?.toString(),
      religionId: _asIntOrNull(field('religion_id')),
      casteId: _asIntOrNull(json['caste_id']),
      cityId: _asIntOrNull(json['city_id']),
      stateId: _asIntOrNull(json['state_id']),
      countryId: _asIntOrNull(json['country_id']),
      sectMainId: _asIntOrNull(field('sect_main_id')),
      schoolOfThoughtId: _asIntOrNull(field('school_of_thought_id')),
      educationLevelId: _asIntOrNull(field('education_level_id')),
      degreeId: _asIntOrNull(field('degree_id')),
      professionId: _asIntOrNull(field('profession_id')),
      familyValues: field('family_values')?.toString(),
      additionalPhotoCount:
          _asIntOrNull(field('additional_photo_count')) ?? 0,
      compatibilityPercentage: _asIntOrNull(json['compatibility_percentage']),
      identityVerified: verification.isNotEmpty
          ? _asBool(verification['identity_verified'])
          : _asBool(nested['verified']),
      verifiedAt: _asDate(verification['verified_at']),
      lastActiveAt: _asDate(json['last_active_at']),
      createdAt: _asDate(json['created_at']),
      interestScore: _asIntOrNull(json['interest_score']),
      sharedInterests: (json['shared_interests'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => '$e')
          .where((String e) => e.isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'code': code,
    'name': name,
    'photo': photo,
    'membership': membership,
    'approved': approved,
    'age': age,
    'gender': gender,
    'marital_status_id': maritalStatusId,
    'height': height,
    'religion_id': religionId,
    'caste_id': casteId,
    'city_id': cityId,
    'state_id': stateId,
    'country_id': countryId,
    'compatibility_percentage': compatibilityPercentage,
    'verification': <String, dynamic>{
      'identity_verified': identityVerified,
      'verified_at': verifiedAt?.toIso8601String(),
    },
    'last_active_at': lastActiveAt?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
  };
}

/// Paginated response from `GET /search/profiles`.
class SearchProfilesPage {
  const SearchProfilesPage({
    this.profiles = const <SearchProfileModel>[],
    this.currentPage = 1,
    this.lastPage = 1,
    this.perPage = 20,
    this.total = 0,
  });

  final List<SearchProfileModel> profiles;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
  bool get isEmpty => profiles.isEmpty;
  bool get isNotEmpty => profiles.isNotEmpty;

  factory SearchProfilesPage.fromJson(Map<String, dynamic> json) {
    final dynamic rawData = json['data'];
    final List<SearchProfileModel> list = <SearchProfileModel>[];
    if (rawData is List) {
      for (final dynamic item in rawData) {
        if (item is Map<String, dynamic>) {
          list.add(SearchProfileModel.fromJson(item));
        }
      }
    }

    final Map<String, dynamic> meta = json['meta'] is Map<String, dynamic>
        ? json['meta'] as Map<String, dynamic>
        : <String, dynamic>{};

    return SearchProfilesPage(
      profiles: list,
      currentPage: _asInt(meta['current_page'], fallback: 1),
      lastPage: _asInt(meta['last_page'], fallback: 1),
      perPage: _asInt(meta['per_page'], fallback: 20),
      total: _asInt(meta['total'], fallback: list.length),
    );
  }

  factory SearchProfilesPage.fromEnvelopeData({
    required dynamic data,
    Map<String, dynamic>? meta,
  }) {
    final List<SearchProfileModel> list = <SearchProfileModel>[];
    if (data is List) {
      for (final dynamic item in data) {
        if (item is Map<String, dynamic>) {
          list.add(SearchProfileModel.fromJson(item));
        }
      }
    }
    final Map<String, dynamic> metaMap = meta ?? <String, dynamic>{};
    return SearchProfilesPage(
      profiles: list,
      currentPage: _asInt(metaMap['current_page'], fallback: 1),
      lastPage: _asInt(metaMap['last_page'], fallback: 1),
      perPage: _asInt(metaMap['per_page'], fallback: 20),
      total: _asInt(metaMap['total'], fallback: list.length),
    );
  }

  /// Appends the next page to the existing list for pagination.
  SearchProfilesPage merge(SearchProfilesPage next) => SearchProfilesPage(
    profiles: <SearchProfileModel>[...profiles, ...next.profiles],
    currentPage: next.currentPage,
    lastPage: next.lastPage,
    perPage: next.perPage,
    total: next.total,
  );
}

/// Filter parameters for `GET /search/profiles`.
class SearchFilterModel {
  const SearchFilterModel({
    this.ageMin,
    this.ageMax,
    this.verifiedOnly = false,
    this.photoOnly = false,
    this.compatibilityMin,
    this.nearby = false,
    this.sort,
    this.gender,
    this.maritalStatusId,
    this.religionId,
    this.casteId,
    this.countryId,
    this.stateId,
    this.cityId,
    this.searchQuery,
    this.partnerPreferenceFilter = false,
    this.excludeViewed = false,
    this.newProfiles = false,
    this.mutualMatch = false,
    this.onlineNow = false,
    this.recentlyActive = false,
    this.newThisWeek = false,
    this.international = false,
    this.heightMin,
    this.heightMax,
    this.incomeMin,
    this.incomeMax,
    this.subCasteId,
    this.sectId,
    this.education,
    this.profession,
    this.lifestyle,
    this.languageId,
  });

  final int? ageMin;
  final int? ageMax;
  final bool verifiedOnly;
  final bool photoOnly;
  final int? compatibilityMin;
  final bool nearby;
  final String? sort;
  final String? gender;
  final int? maritalStatusId;
  final int? religionId;
  final int? casteId;
  final int? countryId;
  final int? stateId;
  final int? cityId;
  final String? searchQuery;
  final bool partnerPreferenceFilter;

  /// Hide members this account has already opened. The API owns the list (its
  /// own `profile-views`), so the flag is the whole implementation here.
  final bool excludeViewed;

  /// Only members who joined recently (`new_profiles` → 14 days,
  /// `new_this_week` → 7).
  final bool newProfiles;

  /// Only members whose interest with this account was accepted both ways.
  final bool mutualMatch;

  /// Only members active in the last few minutes.
  final bool onlineNow;

  /// Ordered by recent activity rather than just filtering to active members.
  final bool recentlyActive;

  /// Tighter than [newProfiles]: joined within the last 7 days.
  final bool newThisWeek;

  /// Include members who live outside the member's own country.
  final bool international;

  /// Height window in the server's own unit (inches).
  final num? heightMin;
  final num? heightMax;

  /// Annual income window, in the server's own unit.
  final num? incomeMin;
  final num? incomeMax;

  /// Narrows [casteId] to one sub-caste.
  final int? subCasteId;

  /// Sect within the member's religion.
  final int? sectId;

  /// Free-text education / profession / lifestyle matches, plus a language id.
  final String? education;
  final String? profession;
  final String? lifestyle;
  final int? languageId;

  /// Counts the active filter criteria (excluding search text and page).
  int get activeFilterCount {
    int count = 0;
    if (ageMin != null && ageMin! > 18) count++;
    if (ageMax != null && ageMax! < 70) count++;
    if (verifiedOnly) count++;
    if (photoOnly) count++;
    if (compatibilityMin != null && compatibilityMin! > 0) count++;
    if (nearby) count++;
    if (sort != null && sort!.isNotEmpty && sort != 'default') count++;
    // `gender` is not counted: Discover pins it to the opposite gender on
    // every search, so counting it would light the "filters active" badge
    // permanently and make "Reset" look broken — it can never go back to zero.
    if (maritalStatusId != null) count++;
    if (religionId != null) count++;
    if (casteId != null) count++;
    if (countryId != null) count++;
    if (stateId != null) count++;
    if (cityId != null) count++;
    if (excludeViewed) count++;
    if (newProfiles) count++;
    if (mutualMatch) count++;
    if (onlineNow) count++;
    if (recentlyActive) count++;
    if (newThisWeek) count++;
    if (international) count++;
    if (heightMin != null || heightMax != null) count++;
    if (incomeMin != null || incomeMax != null) count++;
    if (subCasteId != null) count++;
    if (sectId != null) count++;
    if (education != null && education!.trim().isNotEmpty) count++;
    if (profession != null && profession!.trim().isNotEmpty) count++;
    if (lifestyle != null && lifestyle!.trim().isNotEmpty) count++;
    if (languageId != null) count++;
    return count;
  }

  bool get hasFilters => activeFilterCount > 0 || (searchQuery != null && searchQuery!.trim().isNotEmpty);

  /// Converts this filter model into query parameters for the API call.
  Map<String, dynamic> toQueryParams({int page = 1, int perPage = 20}) {
    final Map<String, dynamic> params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };

    if (ageMin != null) params['age_min'] = ageMin;
    if (ageMax != null) params['age_max'] = ageMax;
    if (verifiedOnly) params['verified_only'] = 1;
    if (photoOnly) params['photo_only'] = 1;
    if (compatibilityMin != null) params['compatibility_min'] = compatibilityMin;
    if (nearby) params['nearby'] = 1;
    if (sort != null && sort!.isNotEmpty && sort != 'default') params['sort'] = sort;
    if (gender != null && gender!.isNotEmpty) params['gender'] = gender;
    if (maritalStatusId != null) params['marital_status_id'] = maritalStatusId;
    if (religionId != null) params['religion_id'] = religionId;
    if (casteId != null) params['caste_id'] = casteId;
    if (countryId != null) params['country_id'] = countryId;
    if (stateId != null) params['state_id'] = stateId;
    if (cityId != null) params['city_id'] = cityId;
    if (excludeViewed) params['exclude_viewed'] = 1;
    if (newProfiles) params['new_profiles'] = 1;
    if (mutualMatch) params['mutual_match'] = 1;
    if (onlineNow) params['online_now'] = 1;
    if (recentlyActive) params['recently_active'] = 1;
    if (newThisWeek) params['new_this_week'] = 1;
    if (international) params['international'] = 1;
    if (heightMin != null) params['height_min'] = heightMin;
    if (heightMax != null) params['height_max'] = heightMax;
    if (incomeMin != null) params['income_min'] = incomeMin;
    if (incomeMax != null) params['income_max'] = incomeMax;
    if (subCasteId != null) params['sub_caste_id'] = subCasteId;
    if (sectId != null) params['sect_id'] = sectId;
    if (education != null && education!.trim().isNotEmpty) {
      params['education'] = education!.trim();
    }
    if (profession != null && profession!.trim().isNotEmpty) {
      params['profession'] = profession!.trim();
    }
    if (lifestyle != null && lifestyle!.trim().isNotEmpty) {
      params['lifestyle'] = lifestyle!.trim();
    }
    if (languageId != null) params['language_id'] = languageId;
    if (searchQuery != null && searchQuery!.trim().isNotEmpty) {
      params['search'] = searchQuery!.trim();
    }
    // The backend applies the saved partner-preference scope only when this is
    // truthy (filter_var BOOLEAN). It used to send 'false' here when the
    // member switched the filter ON — an inverted flag that made the toggle a
    // no-op. Absent (default) and false mean the same thing, so only the ON
    // case needs to send anything.
    if (partnerPreferenceFilter) params['partner_preference'] = 'true';

    return params;
  }

  SearchFilterModel copyWith({
    int? ageMin,
    int? ageMax,
    bool? verifiedOnly,
    bool? photoOnly,
    int? compatibilityMin,
    bool? nearby,
    String? sort,
    String? gender,
    int? maritalStatusId,
    int? religionId,
    int? casteId,
    int? countryId,
    int? stateId,
    int? cityId,
    String? searchQuery,
    bool? partnerPreferenceFilter,
    bool? excludeViewed,
    bool? newProfiles,
    bool? mutualMatch,
    bool? onlineNow,
    bool? recentlyActive,
    bool? newThisWeek,
    bool? international,
    num? heightMin,
    num? heightMax,
    num? incomeMin,
    num? incomeMax,
    int? subCasteId,
    int? sectId,
    String? education,
    String? profession,
    String? lifestyle,
    int? languageId,
    bool clearAgeMin = false,
    bool clearAgeMax = false,
    bool clearCompatibilityMin = false,
    bool clearSort = false,
    bool clearGender = false,
    bool clearMaritalStatus = false,
    bool clearReligion = false,
    bool clearCaste = false,
    bool clearCountry = false,
    bool clearState = false,
    bool clearCity = false,
    bool clearSearch = false,
    bool clearHeightMin = false,
    bool clearHeightMax = false,
    bool clearIncomeMin = false,
    bool clearIncomeMax = false,
    bool clearSubCaste = false,
    bool clearSect = false,
    bool clearEducation = false,
    bool clearProfession = false,
    bool clearLifestyle = false,
    bool clearLanguage = false,
  }) {
    return SearchFilterModel(
      ageMin: clearAgeMin ? null : (ageMin ?? this.ageMin),
      ageMax: clearAgeMax ? null : (ageMax ?? this.ageMax),
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      photoOnly: photoOnly ?? this.photoOnly,
      compatibilityMin: clearCompatibilityMin ? null : (compatibilityMin ?? this.compatibilityMin),
      nearby: nearby ?? this.nearby,
      sort: clearSort ? null : (sort ?? this.sort),
      gender: clearGender ? null : (gender ?? this.gender),
      maritalStatusId: clearMaritalStatus ? null : (maritalStatusId ?? this.maritalStatusId),
      religionId: clearReligion ? null : (religionId ?? this.religionId),
      casteId: clearCaste ? null : (casteId ?? this.casteId),
      countryId: clearCountry ? null : (countryId ?? this.countryId),
      stateId: clearState ? null : (stateId ?? this.stateId),
      cityId: clearCity ? null : (cityId ?? this.cityId),
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      partnerPreferenceFilter: partnerPreferenceFilter ?? this.partnerPreferenceFilter,
      excludeViewed: excludeViewed ?? this.excludeViewed,
      newProfiles: newProfiles ?? this.newProfiles,
      mutualMatch: mutualMatch ?? this.mutualMatch,
      onlineNow: onlineNow ?? this.onlineNow,
      recentlyActive: recentlyActive ?? this.recentlyActive,
      newThisWeek: newThisWeek ?? this.newThisWeek,
      international: international ?? this.international,
      heightMin: clearHeightMin ? null : (heightMin ?? this.heightMin),
      heightMax: clearHeightMax ? null : (heightMax ?? this.heightMax),
      incomeMin: clearIncomeMin ? null : (incomeMin ?? this.incomeMin),
      incomeMax: clearIncomeMax ? null : (incomeMax ?? this.incomeMax),
      subCasteId: clearSubCaste ? null : (subCasteId ?? this.subCasteId),
      sectId: clearSect ? null : (sectId ?? this.sectId),
      education: clearEducation ? null : (education ?? this.education),
      profession: clearProfession ? null : (profession ?? this.profession),
      lifestyle: clearLifestyle ? null : (lifestyle ?? this.lifestyle),
      languageId: clearLanguage ? null : (languageId ?? this.languageId),
    );
  }

  /// Empty initial filter.
  factory SearchFilterModel.empty() => const SearchFilterModel();
}

// ---- Parsing helpers -------------------------------------------------------

int _asInt(dynamic v, {int fallback = 0}) => v is int ? v : int.tryParse('$v') ?? fallback;

int? _asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse('$v');
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final String s = '$v'.toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse('$v');
}
