/// Privacy and visibility switches: `PATCH /profile/privacy`, and the `privacy`
/// block inside `GET /profile`.
///
/// The field names here are the server's, verified against
/// ProfilePrivacyResource and UpdatePrivacyRequest. An earlier version of this
/// model invented its own names (`profile_visibility`, `allow_messages`,
/// `verified_only`, …). Because every rule on that endpoint is `sometimes`,
/// unknown keys were accepted and ignored — the request returned 200 and
/// changed nothing, which is the worst kind of bug to chase. Do not rename
/// these without checking the backend.
class PrivacySettingsModel {
  const PrivacySettingsModel({
    this.showPhoto = true,
    this.showGallery = true,
    this.showContact = false,
    this.showEmail = false,
    this.showPhone = false,
    this.showLocation = true,
    this.allowProfileViewNotifications = true,
    this.doNotDisturb = false,
    this.invisibleMode = false,
  });

  final bool showPhoto;
  final bool showGallery;
  final bool showContact;
  final bool showEmail;
  final bool showPhone;
  final bool showLocation;
  final bool allowProfileViewNotifications;

  /// Write-only on the server today: accepted by the update endpoint but not
  /// echoed by the read resource, so a fetched model always reads `false`.
  /// Keep the local value after a successful save rather than trusting the
  /// response for these two.
  final bool doNotDisturb;

  /// Hides the member from matches entirely (the match query excludes anyone
  /// with invisible_mode set). Same write-only caveat as [doNotDisturb].
  final bool invisibleMode;

  factory PrivacySettingsModel.fromJson(Map<String, dynamic> json) {
    return PrivacySettingsModel(
      showPhoto: _asBool(json['show_photo'], fallback: true),
      showGallery: _asBool(json['show_gallery'], fallback: true),
      showContact: _asBool(json['show_contact']),
      showEmail: _asBool(json['show_email']),
      showPhone: _asBool(json['show_phone']),
      showLocation: _asBool(json['show_location'], fallback: true),
      allowProfileViewNotifications: _asBool(
        json['allow_profile_view_notifications'],
        fallback: true,
      ),
      doNotDisturb: _asBool(json['do_not_disturb']),
      invisibleMode: _asBool(json['invisible_mode']),
    );
  }

  /// Full body. Prefer [changesFrom] for edits so a save only sends what moved.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'show_photo': showPhoto,
    'show_gallery': showGallery,
    'show_contact': showContact,
    'show_email': showEmail,
    'show_phone': showPhone,
    'show_location': showLocation,
    'allow_profile_view_notifications': allowProfileViewNotifications,
    'do_not_disturb': doNotDisturb,
    'invisible_mode': invisibleMode,
  };

  /// Only the switches that differ from [original]. Every rule is `sometimes`,
  /// so a minimal body is both cheaper and safer than resending everything.
  Map<String, dynamic> changesFrom(PrivacySettingsModel original) {
    final Map<String, dynamic> mine = toJson();
    final Map<String, dynamic> theirs = original.toJson();
    final Map<String, dynamic> diff = <String, dynamic>{};
    mine.forEach((String key, dynamic value) {
      if (theirs[key] != value) diff[key] = value;
    });
    return diff;
  }

  PrivacySettingsModel copyWith({
    bool? showPhoto,
    bool? showGallery,
    bool? showContact,
    bool? showEmail,
    bool? showPhone,
    bool? showLocation,
    bool? allowProfileViewNotifications,
    bool? doNotDisturb,
    bool? invisibleMode,
  }) {
    return PrivacySettingsModel(
      showPhoto: showPhoto ?? this.showPhoto,
      showGallery: showGallery ?? this.showGallery,
      showContact: showContact ?? this.showContact,
      showEmail: showEmail ?? this.showEmail,
      showPhone: showPhone ?? this.showPhone,
      showLocation: showLocation ?? this.showLocation,
      allowProfileViewNotifications:
          allowProfileViewNotifications ?? this.allowProfileViewNotifications,
      doNotDisturb: doNotDisturb ?? this.doNotDisturb,
      invisibleMode: invisibleMode ?? this.invisibleMode,
    );
  }
}

bool _asBool(dynamic v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final String s = '$v'.toLowerCase();
  if (s == 'true' || s == '1' || s == 'yes') return true;
  if (s == 'false' || s == '0' || s == 'no') return false;
  return fallback;
}
