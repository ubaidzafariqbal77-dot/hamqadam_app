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
    this.identityVerified = false,
    this.verifiedAt,
    this.compatibilityPercentage,
    this.lastActiveAt,
    this.createdAt,
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
  final bool identityVerified;
  final DateTime? verifiedAt;
  final int? compatibilityPercentage;
  final DateTime? lastActiveAt;
  final DateTime? createdAt;

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
        : <String, dynamic>{};

    return SearchProfileModel(
      id: _asInt(json['id']),
      code: json['code']?.toString(),
      name: json['name']?.toString(),
      photo: json['photo']?.toString(),
      membership: _asIntOrNull(json['membership']),
      approved: _asBool(json['approved']),
      age: _asIntOrNull(json['age']),
      gender: json['gender']?.toString(),
      maritalStatusId: _asIntOrNull(json['marital_status_id']),
      height: json['height']?.toString(),
      religionId: _asIntOrNull(json['religion_id']),
      casteId: _asIntOrNull(json['caste_id']),
      cityId: _asIntOrNull(json['city_id']),
      stateId: _asIntOrNull(json['state_id']),
      countryId: _asIntOrNull(json['country_id']),
      compatibilityPercentage: _asIntOrNull(json['compatibility_percentage']),
      identityVerified: _asBool(verification['identity_verified']),
      verifiedAt: _asDate(verification['verified_at']),
      lastActiveAt: _asDate(json['last_active_at']),
      createdAt: _asDate(json['created_at']),
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
    if (gender != null && gender!.isNotEmpty) count++;
    if (maritalStatusId != null) count++;
    if (religionId != null) count++;
    if (casteId != null) count++;
    if (countryId != null) count++;
    if (stateId != null) count++;
    if (cityId != null) count++;
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
    if (searchQuery != null && searchQuery!.trim().isNotEmpty) {
      params['search'] = searchQuery!.trim();
    }

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
