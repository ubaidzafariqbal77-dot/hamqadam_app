import '../constants/app_constants.dart';

/// Metadata returned with a public profile view (package validity, limits).
class ProfileViewMeta {
  const ProfileViewMeta({
    this.consumed = false,
    this.alreadyViewed = false,
    this.remainingProfileViewerCount = 0,
    this.packageValidity,
    this.isActive = false,
  });

  final bool consumed;
  final bool alreadyViewed;
  final int remainingProfileViewerCount;
  final String? packageValidity;
  final bool isActive;

  factory ProfileViewMeta.fromJson(Map<String, dynamic> json) {
    return ProfileViewMeta(
      consumed: json['consumed'] as bool? ?? false,
      alreadyViewed: json['already_viewed'] as bool? ?? false,
      remainingProfileViewerCount: json['remaining_profile_viewer_view'] as int? ?? 0,
      packageValidity: json['package_validity']?.toString(),
      isActive: json['is_active'] as bool? ?? false,
    );
  }
}

/// Another member's profile, from `GET /profiles/{id}` and every search /
/// match / proposal listing (they all share the backend's SearchProfileResource).
class PublicProfileModel {
  const PublicProfileModel({
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
    this.compatibilityPercentage,
    this.identityVerified = false,
    this.verifiedAt,
    this.lastActiveAt,
    this.createdAt,
    this.meta,
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

  /// Present when the viewer has a stored match score against this member.
  final int? compatibilityPercentage;

  /// True when EITHER path succeeded: a moderator approved the documents, or
  /// the AI model returned APPROVE.
  final bool identityVerified;

  /// Only populated for the AI path. The moderator path keeps its timestamp on
  /// the verification request, which the listing does not join — so a
  /// moderator-verified member can read verified with a null date. Show the
  /// badge from [identityVerified], never from this being non-null.
  final DateTime? verifiedAt;

  final DateTime? lastActiveAt;
  final DateTime? createdAt;
  final ProfileViewMeta? meta;

  String get displayName => (name ?? '').trim().isEmpty ? 'HamQadam Member' : name!.trim();
  String get initial => displayName.isNotEmpty ? displayName[0].toUpperCase() : 'H';
  String? get photoUrl => ApiConfig.mediaUrl(photo);

  factory PublicProfileModel.fromJson(Map<String, dynamic> rawJson, {Map<String, dynamic>? metaJson}) {
    final Map<String, dynamic> json = rawJson['profile'] is Map<String, dynamic>
        ? rawJson['profile'] as Map<String, dynamic>
        : rawJson;

    final Map<String, dynamic> verification = json['verification'] is Map<String, dynamic>
        ? json['verification'] as Map<String, dynamic>
        : <String, dynamic>{};

    final dynamic rawMeta = metaJson ??
        (rawJson['profile_view'] is Map
            ? rawJson['profile_view']
            : (rawJson['meta'] is Map
                ? rawJson['meta']['profile_view'] ?? rawJson['meta']
                : null));
    final ProfileViewMeta? parsedMeta = rawMeta is Map<String, dynamic> ? ProfileViewMeta.fromJson(rawMeta) : null;

    return PublicProfileModel(
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
      meta: parsedMeta,
    );
  }
}

/// `GET /profiles/{id}/compatibility`.
class CompatibilityModel {
  const CompatibilityModel({
    required this.profileId,
    this.percentage = 0,
    this.explanation,
    this.reasons = const <String>[],
    this.breakdown = const <String, dynamic>{},
    this.calculatedAt,
    this.source,
  });

  final int profileId;
  final int percentage;
  final String? explanation;
  final List<String> reasons;

  /// Per-dimension scores. Shape is set by the scoring service and changes as
  /// dimensions are added, so it stays raw.
  final Map<String, dynamic> breakdown;

  final DateTime? calculatedAt;

  /// `stored` when read from a precomputed match row, `live_rule_based` when
  /// scored on the fly — worth surfacing, because a live score has not had the
  /// collaborative-filtering boosts applied.
  final String? source;

  factory CompatibilityModel.fromJson(Map<String, dynamic> json) {
    return CompatibilityModel(
      profileId: _asInt(json['profile_id']),
      percentage: _asInt(json['compatibility_percentage']),
      explanation: json['compatibility_explanation']?.toString(),
      reasons:
          (json['compatibility_reasons'] is List
                  ? json['compatibility_reasons'] as List<dynamic>
                  : <dynamic>[])
              .map((dynamic e) => '$e'.trim())
              .where((String e) => e.isNotEmpty)
              .toList(growable: false),
      breakdown: json['score_breakdown'] is Map<String, dynamic>
          ? json['score_breakdown'] as Map<String, dynamic>
          : <String, dynamic>{},
      calculatedAt: _asDate(json['calculated_at']),
      source: json['source']?.toString(),
    );
  }
}

// ---- Parsing helpers -------------------------------------------------------

int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

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
