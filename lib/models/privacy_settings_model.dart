/// Privacy & visibility settings submitted in step 12 (`PATCH /profile/privacy`).
///
/// NOTE: the exact field contract is not enumerated in the public API docs, so
/// these are the conventional visibility controls. Adjust field names here if
/// the backend expects different keys — the UI/controller need not change.
class PrivacySettingsModel {
  const PrivacySettingsModel({
    required this.profileVisibility,
    required this.photoVisibility,
    required this.showContact,
    required this.showGallery,
    required this.allowMessages,
    required this.allowProposals,
    required this.verifiedOnly,
    required this.notifyNewMatches,
    required this.notifyMessages,
  });

  final String profileVisibility; // public | members | verified
  final String photoVisibility; // public | members | verified
  final bool showContact;
  final bool showGallery;
  final bool allowMessages;
  final bool allowProposals;
  final bool verifiedOnly;
  final bool notifyNewMatches;
  final bool notifyMessages;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'profile_visibility': profileVisibility,
    'photo_visibility': photoVisibility,
    'show_contact': showContact,
    'show_gallery': showGallery,
    'allow_messages': allowMessages,
    'allow_proposals': allowProposals,
    'verified_only': verifiedOnly,
    'notify_new_matches': notifyNewMatches,
    'notify_messages': notifyMessages,
  };

  static const List<String> visibilityOptions = <String>['public', 'members', 'verified'];
}
