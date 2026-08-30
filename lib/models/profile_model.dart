import '../constants/app_constants.dart';
import 'ai_verification_model.dart';

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
    this.religionAndLanguage = const ProfileSection.empty(),
    this.caste = const ProfileSection.empty(),
    this.location = const ProfileSection.empty(),
    this.education = const ProfileSection.empty(),
    this.career = const ProfileSection.empty(),
    this.physical = const ProfileSection.empty(),
    this.lifestyleAndInterests = const ProfileSection.empty(),
    this.family = const ProfileSection.empty(),
    this.marriageExpectations = const ProfileSection.empty(),
    this.photos = const ProfilePhotos(),
    this.verification = const ProfileVerification(),
    this.registration = const ProfileRegistration(),
  });

  final ProfileUser user;
  final MemberDetails member;
  final ProfilePrivacy privacy;

  /*
   * Registration writes its 18 steps across several database tables, so
   * `GET /profile` returns them as named groups alongside `user` / `member`.
   * Each group is kept as a [ProfileSection] rather than a hand-written class
   * per group: the backend keeps adding fields, and a typed class per section
   * would silently drop anything new until the app was rebuilt.
   */
  final ProfileSection religionAndLanguage; // step 3
  final ProfileSection caste; // step 6
  final ProfileSection location; // step 4
  final ProfileSection education; // step 8
  final ProfileSection career; // step 10
  final ProfileSection physical; // step 9
  final ProfileSection lifestyleAndInterests; // step 14
  final ProfileSection family; // steps 15-16
  final ProfileSection marriageExpectations; // step 17
  final ProfilePhotos photos; // step 11
  final ProfileVerification verification; // step 13 + the AI check
  final ProfileRegistration registration;

  /// Every group in display order, for a "profile details" screen that should
  /// not need editing when the backend adds a field.
  List<({String key, String title, ProfileSection section})> get sections =>
      <({String key, String title, ProfileSection section})>[
        (key: 'religion_and_language', title: 'Religion & Language', section: religionAndLanguage),
        (key: 'caste', title: 'Caste & Community', section: caste),
        (key: 'location', title: 'Location', section: location),
        (key: 'education', title: 'Education', section: education),
        (key: 'career', title: 'Career & Income', section: career),
        (key: 'physical', title: 'Physical', section: physical),
        (
          key: 'lifestyle_and_interests',
          title: 'Lifestyle & Interests',
          section: lifestyleAndInterests,
        ),
        (key: 'family', title: 'Family', section: family),
        (
          key: 'marriage_expectations',
          title: 'Marriage Expectations',
          section: marriageExpectations,
        ),
      ];

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      user: ProfileUser.fromJson(_asMap(json['user'])),
      member: MemberDetails.fromJson(_asMap(json['member'])),
      privacy: ProfilePrivacy.fromJson(_asMap(json['privacy'])),
      religionAndLanguage: ProfileSection.fromJson(_asMap(json['religion_and_language'])),
      caste: ProfileSection.fromJson(_asMap(json['caste'])),
      location: ProfileSection.fromJson(_asMap(json['location'])),
      education: ProfileSection.fromJson(_asMap(json['education'])),
      career: ProfileSection.fromJson(_asMap(json['career'])),
      physical: ProfileSection.fromJson(_asMap(json['physical'])),
      lifestyleAndInterests: ProfileSection.fromJson(_asMap(json['lifestyle_and_interests'])),
      family: ProfileSection.fromJson(_asMap(json['family'])),
      marriageExpectations: ProfileSection.fromJson(_asMap(json['marriage_expectations'])),
      photos: ProfilePhotos.fromJson(_asMap(json['photos'])),
      verification: ProfileVerification.fromJson(_asMap(json['verification'])),
      registration: ProfileRegistration.fromJson(_asMap(json['registration'])),
    );
  }
}

/// One named group of the profile, held as raw key/value pairs.
///
/// Deliberately untyped. These groups exist so the app can *render* whatever
/// registration collected; hard-coding a field list here would mean every new
/// backend field is invisible until the app ships again.
class ProfileSection {
  const ProfileSection(this.values);
  const ProfileSection.empty() : values = const <String, dynamic>{};

  final Map<String, dynamic> values;

  factory ProfileSection.fromJson(Map<String, dynamic> json) => ProfileSection(json);

  bool get isEmpty => filled.isEmpty;
  int get filledCount => filled.length;
  int get totalCount => values.length;

  /// Only the entries worth showing — nulls, empty strings and empty lists are
  /// noise on a profile screen.
  Map<String, dynamic> get filled {
    final Map<String, dynamic> out = <String, dynamic>{};
    values.forEach((String key, dynamic value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (value is List && value.isEmpty) return;
      if (value is Map && value.isEmpty) return;
      out[key] = value;
    });
    return out;
  }

  dynamic operator [](String key) => values[key];

  String? string(String key) {
    final dynamic v = values[key];
    if (v == null) return null;
    final String s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  int? integer(String key) => _asIntOrNull(values[key]);
  double? number(String key) => _asDoubleOrNull(values[key]);
  bool? boolean(String key) => values[key] == null ? null : _asBool(values[key]);

  List<String> list(String key) {
    final dynamic v = values[key];
    if (v is List) {
      return v
          .map((dynamic e) => '$e'.trim())
          .where((String e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  /// "father_occupation" -> "Father occupation", for rendering unknown keys.
  static String humanise(String key) {
    final String spaced = key.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) return key;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

/// Profile and gallery imagery (registration step 11).
class ProfilePhotos {
  const ProfilePhotos({this.profilePhoto, this.coverPhoto, this.gallery = const <String>[]});

  final String? profilePhoto;
  final String? coverPhoto;
  final List<String> gallery;

  /// The API already returns absolute URLs here, but run them through
  /// [ApiConfig.mediaUrl] anyway so a relative path from an older build still
  /// resolves.
  String? get profilePhotoUrl => ApiConfig.mediaUrl(profilePhoto);
  String? get coverPhotoUrl => ApiConfig.mediaUrl(coverPhoto);
  List<String> get galleryUrls =>
      gallery.map(ApiConfig.mediaUrl).whereType<String>().toList(growable: false);

  bool get hasGallery => galleryUrls.isNotEmpty;

  factory ProfilePhotos.fromJson(Map<String, dynamic> json) {
    return ProfilePhotos(
      profilePhoto: json['profile_photo']?.toString(),
      coverPhoto: json['cover_photo']?.toString(),
      gallery: (json['gallery'] is List ? json['gallery'] as List<dynamic> : <dynamic>[])
          .map((dynamic e) => '$e')
          .where((String e) => e.isNotEmpty)
          .toList(growable: false),
    );
  }
}

/// Identity verification: the document status plus the AI check that runs
/// against the CNIC and selfie submitted at registration step 13.
class ProfileVerification {
  const ProfileVerification({
    this.status,
    this.ai = const AiVerificationModel(status: 'not_started'),
  });

  /// unverified | draft | submitted | verified — the document workflow.
  final String? status;

  /// Never null: a profile with no attempt yet reads as `not_started`, which is
  /// what the UI wants to show anyway.
  final AiVerificationModel ai;

  /// A moderator approved the documents. On the backend this is the only thing
  /// that writes `verification_status = 'verified'` (VerificationService::approve).
  bool get documentsVerified => status == 'verified';

  /// Documents are submitted and sitting with a human reviewer.
  bool get inManualReview => status == 'submitted' || status == 'under_review';

  /// Documents were reviewed and turned down.
  bool get documentsRejected => status == 'rejected';

  /// Nothing has been submitted yet.
  bool get notSubmitted => status == null || status == 'unverified' || status == 'draft';

  /// What the profile badge should show.
  ///
  /// ONLY a moderator approval counts. The AI check is a pre-screen that runs
  /// automatically the moment documents land, so treating it as the answer put
  /// a "verified" badge on every account whose photos merely looked plausible —
  /// while `verification_status` was still `submitted` and no human had looked.
  /// That contradiction is what the client reported; keep the two separate.
  bool get identityVerified => documentsVerified;

  /// The AI pre-screen passed but manual review has not signed off yet. Worth
  /// telling the member, because it means their part is done and the wait is
  /// ours.
  bool get aiClearedAwaitingReview => !documentsVerified && !documentsRejected && ai.isApproved;

  factory ProfileVerification.fromJson(Map<String, dynamic> json) {
    return ProfileVerification(
      status: json['status']?.toString(),
      ai: json['ai'] is Map<String, dynamic>
          ? AiVerificationModel.fromProfileBlock(json['ai'] as Map<String, dynamic>)
          : const AiVerificationModel(status: 'not_started'),
    );
  }
}

/// Registration progress as the server sees it.
class ProfileRegistration {
  const ProfileRegistration({this.completionPercentage = 0, this.steps = const <String>[]});

  final int completionPercentage;

  /// Completed step keys, as recorded on the member row.
  final List<String> steps;

  factory ProfileRegistration.fromJson(Map<String, dynamic> json) {
    return ProfileRegistration(
      completionPercentage: _asInt(json['completion_percentage']),
      steps: (json['steps'] is List ? json['steps'] as List<dynamic> : <dynamic>[])
          .map((dynamic e) => '$e')
          .where((String e) => e.isNotEmpty)
          .toList(growable: false),
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
    final String joined = <String?>[
      firstName,
      lastName,
    ].where((String? s) => (s ?? '').trim().isNotEmpty).join(' ').trim();
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

Map<String, dynamic> _asMap(dynamic v) => v is Map<String, dynamic> ? v : <String, dynamic>{};

int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

double? _asDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

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
    return v.map(_asIntOrNull).whereType<int>().toList(growable: false);
  }
  return const <int>[];
}
