/// Partner preferences, captured at registration step 17 and editable from the
/// app: `GET/PUT/DELETE /partner-preferences`.
///
/// These are not cosmetic — the backend filters the candidate pool with them
/// (age, marital status, religion, caste, preferred location). A candidate is
/// only excluded when their value is KNOWN and outside the preference, so an
/// empty preference widens the pool rather than emptying it.
///
/// MIND THE ASYMMETRY. The read payload nests and renames; the write payload is
/// flat and uses the column names:
///
///   read  `age: {min, max}`      write `preferred_age_min` / `preferred_age_max`
///   read  `height: {min, max}`   write `height_min` / `height_max`
///   read  `income: {min, max}`   write `income_min` / `income_max`
///   read  `country_id`           write `preferred_country_id`
///   read  `state_id` / `city_id` write `preferred_state_id` / `preferred_city_id`
///
/// [toUpdateJson] does that translation. Never post [toJson]-shaped data.
class PartnerPreferenceModel {
  const PartnerPreferenceModel({
    this.id,
    this.general,
    this.ageMin,
    this.ageMax,
    this.heightPreferred,
    this.heightMin,
    this.heightMax,
    this.weight,
    this.education,
    this.profession,
    this.incomeMin,
    this.incomeMax,
    this.religionId,
    this.casteId,
    this.subCasteId,
    this.maritalStatusId,
    this.childrenAcceptable,
    this.childrenPreference,
    this.countryId,
    this.stateId,
    this.cityId,
    this.residenceCountryId,
    this.languageId,
    this.preferredLanguageIds = const <int>[],
    this.lifestyle,
    this.diet,
    this.prayer,
    this.religiousPractice,
    this.smokingAcceptable,
    this.drinkingAcceptable,
    this.bodyType,
    this.personalValue,
    this.familyValueId,
    this.complexion,
    this.dealBreakers = const <String>[],
    this.updatedAt,
  });

  final int? id;

  /// Free-text summary the member wrote ("Practicing, educated, family-oriented").
  final String? general;

  final int? ageMin;
  final int? ageMax;

  /// Stored in METRES on this side (e.g. 1.50–1.75). The member's own height is
  /// recorded in feet in places, which is why height is scored rather than used
  /// as a hard filter server-side — do not compare the two directly.
  final double? heightPreferred;
  final double? heightMin;
  final double? heightMax;

  final double? weight;
  final String? education;
  final String? profession;
  final double? incomeMin;
  final double? incomeMax;

  final int? religionId;
  final int? casteId;
  final int? subCasteId;
  final int? maritalStatusId;
  final String? childrenAcceptable;
  final String? childrenPreference;

  final int? countryId;
  final int? stateId;
  final int? cityId;
  final int? residenceCountryId;

  final int? languageId;
  final List<int> preferredLanguageIds;

  final String? lifestyle;
  final String? diet;
  final String? prayer;
  final String? religiousPractice;
  final String? smokingAcceptable;
  final String? drinkingAcceptable;
  final String? bodyType;
  final String? personalValue;
  final int? familyValueId;
  final String? complexion;

  /// Free-text deal breakers. The backend also matches these as text against
  /// candidate bios, so wording matters.
  final List<String> dealBreakers;

  final DateTime? updatedAt;

  /// True when nothing has been set — the UI should invite the member to fill
  /// them in rather than showing an empty summary.
  bool get isEmpty =>
      ageMin == null &&
      ageMax == null &&
      religionId == null &&
      casteId == null &&
      maritalStatusId == null &&
      countryId == null &&
      (general ?? '').isEmpty &&
      dealBreakers.isEmpty;

  /// Which preferences actually narrow the match pool server-side. Useful for
  /// telling the member why they see who they see.
  List<String> get activeFilters => <String>[
    if (ageMin != null || ageMax != null) 'Age',
    if (maritalStatusId != null) 'Marital status',
    if (religionId != null) 'Religion',
    if (casteId != null) 'Caste',
    if (countryId != null || stateId != null || cityId != null) 'Location',
  ];

  String get ageRangeLabel {
    if (ageMin == null && ageMax == null) return 'Any age';
    if (ageMin != null && ageMax != null) return '$ageMin – $ageMax years';
    return ageMin != null ? '$ageMin+ years' : 'Up to $ageMax years';
  }

  String get heightRangeLabel {
    if (heightMin == null && heightMax == null) return 'Any height';
    String fmt(double? v) => v == null ? '?' : v.toStringAsFixed(2);
    if (heightMin != null && heightMax != null) {
      return '${fmt(heightMin)} – ${fmt(heightMax)} m';
    }
    return heightMin != null ? '${fmt(heightMin)} m and above' : 'Up to ${fmt(heightMax)} m';
  }

  factory PartnerPreferenceModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> age = _asMap(json['age']);
    final Map<String, dynamic> height = _asMap(json['height']);
    final Map<String, dynamic> income = _asMap(json['income']);

    return PartnerPreferenceModel(
      id: _asIntOrNull(json['id']),
      general: json['general']?.toString(),
      ageMin: _asIntOrNull(age['min']),
      ageMax: _asIntOrNull(age['max']),
      heightPreferred: _asDouble(height['preferred']),
      heightMin: _asDouble(height['min']),
      heightMax: _asDouble(height['max']),
      weight: _asDouble(json['weight']),
      education: json['education']?.toString(),
      profession: json['profession']?.toString(),
      incomeMin: _asDouble(income['min']),
      incomeMax: _asDouble(income['max']),
      religionId: _asIntOrNull(json['religion_id']),
      casteId: _asIntOrNull(json['caste_id']),
      subCasteId: _asIntOrNull(json['sub_caste_id']),
      maritalStatusId: _asIntOrNull(json['marital_status_id']),
      childrenAcceptable: json['children_acceptable']?.toString(),
      childrenPreference: json['children_preference']?.toString(),
      countryId: _asIntOrNull(json['country_id']),
      stateId: _asIntOrNull(json['state_id']),
      cityId: _asIntOrNull(json['city_id']),
      residenceCountryId: _asIntOrNull(json['residence_country_id']),
      languageId: _asIntOrNull(json['language_id']),
      preferredLanguageIds: _asIntList(json['preferred_language_ids']),
      lifestyle: json['lifestyle']?.toString(),
      diet: json['diet']?.toString(),
      prayer: json['prayer']?.toString(),
      religiousPractice: json['religious_practice']?.toString(),
      smokingAcceptable: json['smoking_acceptable']?.toString(),
      drinkingAcceptable: json['drinking_acceptable']?.toString(),
      bodyType: json['body_type']?.toString(),
      personalValue: json['personal_value']?.toString(),
      familyValueId: _asIntOrNull(json['family_value_id']),
      complexion: json['complexion']?.toString(),
      dealBreakers: _asStringList(json['deal_breakers']),
      updatedAt: _asDate(json['updated_at']),
    );
  }

  factory PartnerPreferenceModel.empty() => const PartnerPreferenceModel();

  /// Body for `PUT /partner-preferences`.
  ///
  /// Every rule on the server is `sometimes`, so only non-null values are sent:
  /// a partial update never blanks a preference the member did not touch. To
  /// clear one deliberately, pass it through [explicitNulls].
  Map<String, dynamic> toUpdateJson({Set<String> explicitNulls = const <String>{}}) {
    final Map<String, dynamic> body = <String, dynamic>{
      'general': general,
      'preferred_age_min': ageMin,
      'preferred_age_max': ageMax,
      'height': heightPreferred,
      'height_min': heightMin,
      'height_max': heightMax,
      'weight': weight,
      'education': education,
      'profession': profession,
      'income_min': incomeMin,
      'income_max': incomeMax,
      'religion_id': religionId,
      'caste_id': casteId,
      'sub_caste_id': subCasteId,
      'marital_status_id': maritalStatusId,
      'children_acceptable': childrenAcceptable,
      'children_preference': childrenPreference,
      'preferred_country_id': countryId,
      'preferred_state_id': stateId,
      'preferred_city_id': cityId,
      'residence_country_id': residenceCountryId,
      'language_id': languageId,
      'preferred_language_ids': preferredLanguageIds.isEmpty ? null : preferredLanguageIds,
      'lifestyle': lifestyle,
      'diet': diet,
      'prayer': prayer,
      'religious_practice': religiousPractice,
      'smoking_acceptable': smokingAcceptable,
      'drinking_acceptable': drinkingAcceptable,
      'body_type': bodyType,
      'personal_value': personalValue,
      'family_value_id': familyValueId,
      'complexion': complexion,
      'deal_breakers': dealBreakers.isEmpty ? null : dealBreakers,
    };

    body.removeWhere((String key, dynamic value) => value == null && !explicitNulls.contains(key));
    return body;
  }

  PartnerPreferenceModel copyWith({
    String? general,
    int? ageMin,
    int? ageMax,
    double? heightMin,
    double? heightMax,
    double? incomeMin,
    double? incomeMax,
    int? religionId,
    int? casteId,
    int? subCasteId,
    int? maritalStatusId,
    int? countryId,
    int? stateId,
    int? cityId,
    int? languageId,
    List<int>? preferredLanguageIds,
    String? education,
    String? profession,
    String? diet,
    String? childrenPreference,
    List<String>? dealBreakers,
  }) {
    return PartnerPreferenceModel(
      id: id,
      general: general ?? this.general,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
      heightPreferred: heightPreferred,
      heightMin: heightMin ?? this.heightMin,
      heightMax: heightMax ?? this.heightMax,
      weight: weight,
      education: education ?? this.education,
      profession: profession ?? this.profession,
      incomeMin: incomeMin ?? this.incomeMin,
      incomeMax: incomeMax ?? this.incomeMax,
      religionId: religionId ?? this.religionId,
      casteId: casteId ?? this.casteId,
      subCasteId: subCasteId ?? this.subCasteId,
      maritalStatusId: maritalStatusId ?? this.maritalStatusId,
      childrenAcceptable: childrenAcceptable,
      childrenPreference: childrenPreference ?? this.childrenPreference,
      countryId: countryId ?? this.countryId,
      stateId: stateId ?? this.stateId,
      cityId: cityId ?? this.cityId,
      residenceCountryId: residenceCountryId,
      languageId: languageId ?? this.languageId,
      preferredLanguageIds: preferredLanguageIds ?? this.preferredLanguageIds,
      lifestyle: lifestyle,
      diet: diet ?? this.diet,
      prayer: prayer,
      religiousPractice: religiousPractice,
      smokingAcceptable: smokingAcceptable,
      drinkingAcceptable: drinkingAcceptable,
      bodyType: bodyType,
      personalValue: personalValue,
      familyValueId: familyValueId,
      complexion: complexion,
      dealBreakers: dealBreakers ?? this.dealBreakers,
      updatedAt: updatedAt,
    );
  }
}

// ---- Parsing helpers -------------------------------------------------------

Map<String, dynamic> _asMap(dynamic v) => v is Map<String, dynamic> ? v : <String, dynamic>{};

int? _asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse('$v');
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse('$v');
}

List<int> _asIntList(dynamic v) {
  if (v is List) {
    return v.map(_asIntOrNull).whereType<int>().toList(growable: false);
  }
  return const <int>[];
}

List<String> _asStringList(dynamic v) {
  if (v is List) {
    return v
        .map((dynamic e) => '$e'.trim())
        .where((String e) => e.isNotEmpty)
        .toList(growable: false);
  }
  final String s = (v ?? '').toString().trim();
  return s.isEmpty ? const <String>[] : <String>[s];
}
