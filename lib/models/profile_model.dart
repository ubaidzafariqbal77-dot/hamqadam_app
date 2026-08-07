import '../constants/app_constants.dart';

/// Full profile payload returned by `GET /api/v1/profile`.
///
/// The endpoint wraps everything under `data`, which splits into three logical
/// groups: the account [user], the matrimonial [member] details and the
/// [privacy] visibility switches. Unknown/extra keys are ignored gracefully so
/// the model keeps working when the backend adds fields.
class ProfileModel {
  const ProfileModel({
    required this.user,
    required this.member,
    required this.privacy,
  });

  final ProfileUser user;
  final MemberDetails member;
  final ProfilePrivacy privacy;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      user: ProfileUser.fromJson(_asMap(json['user'])),
      member: MemberDetails.fromJson(_asMap(json['member'])),
      privacy: ProfilePrivacy.fromJson(_asMap(json['privacy'])),
    );
  }
}

/// Account-level fields (identity + moderation flags).
class ProfileUser {
  const ProfileUser({
    required this.id,
    this.code,
    this.firstName,
    this.lastName,
    this.name,
    this.email,
    this.phone,
    this.photo,
    this.approved = false,
    this.blocked = false,
    this.deactivated = false,
  });

  final int id;
  final String? code;
  final String? firstName;
  final String? lastName;
  final String? name;
  final String? email;
  final String? phone;
  final String? photo;
  final bool approved;
  final bool blocked;
  final bool deactivated;

  /// Best available display name.
  String get displayName {
    final String joined =
        <String?>[firstName, lastName].where((String? s) => (s ?? '').trim().isNotEmpty).join(' ').trim();
    if (joined.isNotEmpty) return joined;
    if ((name ?? '').trim().isNotEmpty) return name!.trim();
    return 'HamQadam Member';
  }

  /// First letter for the avatar fallback.
  String get initial => displayName.isNotEmpty ? displayName[0].toUpperCase() : 'H';

  /// Absolute URL for the profile photo, or null when unset.
  String? get photoUrl => ApiConfig.mediaUrl(photo);

  factory ProfileUser.fromJson(Map<String, dynamic> json) {
    return ProfileUser(
      id: _asInt(json['id']),
      code: json['code']?.toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      photo: json['photo']?.toString(),
      approved: _asBool(json['approved']),
      blocked: _asBool(json['blocked']),
      deactivated: _asBool(json['deactivated']),
    );
  }
}

/// Matrimonial member details.
class MemberDetails {
  const MemberDetails({
    this.gender,
    this.dateOfBirth,
    this.aboutMe,
    this.aiGeneratedBio,
    this.videoIntroduction,
    this.voiceIntroduction,
    this.maritalStatusId,
    this.children,
    this.onBehalfId,
    this.annualSalaryRangeId,
    this.motherTongue,
    this.knownLanguages = const <int>[],
    this.travelPreferences,
    this.futureGoals,
    this.hideProfile = false,
    this.verificationStatus,
    this.profileCompletion = 0,
  });

  /// Raw gender id as a string ("1" male, "2" female) — matches the `genders`
  /// lookup ids.
  final String? gender;
  final DateTime? dateOfBirth;
  final String? aboutMe;
  final String? aiGeneratedBio;
  final String? videoIntroduction;
  final String? voiceIntroduction;
  final int? maritalStatusId;
  final int? children;
  final int? onBehalfId;
  final int? annualSalaryRangeId;
  final int? motherTongue;
  final List<int> knownLanguages;
  final String? travelPreferences;
  final String? futureGoals;
  final bool hideProfile;
  final String? verificationStatus;
  final int profileCompletion;

  bool get isVerified => (verificationStatus ?? '').toLowerCase() == 'verified';

  int? get genderId => gender == null ? null : int.tryParse(gender!);

  /// Age in whole years derived from [dateOfBirth].
  int? get age {
    final DateTime? dob = dateOfBirth;
    if (dob == null) return null;
    final DateTime now = DateTime.now();
    int years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      years -= 1;
    }
    return years < 0 ? null : years;
  }

  String? get videoIntroUrl => ApiConfig.mediaUrl(videoIntroduction);
  String? get voiceIntroUrl => ApiConfig.mediaUrl(voiceIntroduction);

  factory MemberDetails.fromJson(Map<String, dynamic> json) {
    return MemberDetails(
      gender: json['gender']?.toString(),
      dateOfBirth: _asDate(json['date_of_birth']),
      aboutMe: json['about_me']?.toString(),
      aiGeneratedBio: json['ai_generated_bio']?.toString(),
      videoIntroduction: json['video_introduction']?.toString(),
      voiceIntroduction: json['voice_introduction']?.toString(),
      maritalStatusId: _asIntOrNull(json['marital_status_id']),
      children: _asIntOrNull(json['children']),
      onBehalfId: _asIntOrNull(json['on_behalf_id']),
      annualSalaryRangeId: _asIntOrNull(json['annual_salary_range_id']),
      motherTongue: _asIntOrNull(json['mother_tongue']),
      knownLanguages: _asIntList(json['known_languages']),
      travelPreferences: json['travel_preferences']?.toString(),
      futureGoals: json['future_goals']?.toString(),
      hideProfile: _asBool(json['hide_profile']),
      verificationStatus: json['verification_status']?.toString(),
      profileCompletion: _asInt(json['profile_completion_percentage']),
    );
  }
}

/// Visibility / privacy switches.
class ProfilePrivacy {
  const ProfilePrivacy({
    this.showPhoto = false,
    this.showGallery = false,
    this.showContact = false,
    this.showEmail = false,
    this.showPhone = false,
    this.showLocation = false,
    this.allowProfileViewNotifications = false,
  });

  final bool showPhoto;
  final bool showGallery;
  final bool showContact;
  final bool showEmail;
  final bool showPhone;
  final bool showLocation;
  final bool allowProfileViewNotifications;

  factory ProfilePrivacy.fromJson(Map<String, dynamic> json) {
    return ProfilePrivacy(
      showPhoto: _asBool(json['show_photo']),
      showGallery: _asBool(json['show_gallery']),
      showContact: _asBool(json['show_contact']),
      showEmail: _asBool(json['show_email']),
      showPhone: _asBool(json['show_phone']),
      showLocation: _asBool(json['show_location']),
      allowProfileViewNotifications: _asBool(json['allow_profile_view_notifications']),
    );
  }
}

// ---- Parsing helpers (tolerant of string / int / bool shapes) --------------

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map<String, dynamic> ? v : <String, dynamic>{};

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

List<int> _asIntList(dynamic v) {
  if (v is List) {
    return v
        .map(_asIntOrNull)
        .whereType<int>()
        .toList(growable: false);
  }
  return const <int>[];
}
