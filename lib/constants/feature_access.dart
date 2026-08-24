/// Which features a member may use at each stage of identity verification.
///
/// ## Why this file exists
///
/// The API does not gate anything on `verification_status`. Every `/api/v1`
/// route is protected by `auth:sanctum` and nothing else, so a member whose
/// documents are still in manual review can call the interest, chat and
/// proposal endpoints exactly like a verified one. There was no definition
/// anywhere of what "in review" is allowed to do — which is the gap this file
/// closes for the app.
///
/// ## Important: this is UX, not enforcement
///
/// Gating in the client stops the honest member from walking into a wall; it
/// does NOT stop a crafted request. The same matrix has to be applied
/// server-side (a middleware on the interest / chat / proposal route groups)
/// before it can be relied on as a rule. Until that lands, treat this as the
/// agreed policy the app presents, and keep the two in step.
///
/// ## The matrix
///
/// | Feature              | Not submitted | Manual review | Verified | Rejected |
/// |----------------------|:-------------:|:-------------:|:--------:|:--------:|
/// | Browse & search      |       ✅       |       ✅       |    ✅     |    ✅     |
/// | View full profile    |       ❌       |       ✅       |    ✅     |    ❌     |
/// | View contact details |       ❌       |       ❌       |    ✅     |    ❌     |
/// | Send interest        |       ❌       |       ❌       |    ✅     |    ❌     |
/// | Respond to interest  |       ❌       |       ✅       |    ✅     |    ❌     |
/// | Chat / messaging     |       ❌       |       ❌       |    ✅     |    ❌     |
/// | Send proposal        |       ❌       |       ❌       |    ✅     |    ❌     |
/// | Edit own profile     |       ✅       |       ✅       |    ✅     |    ✅     |
/// | Partner preferences  |       ✅       |       ✅       |    ✅     |    ✅     |
/// | Upload photos        |       ✅       |       ✅       |    ✅     |    ✅     |
/// | Buy a package        |       ✅       |       ✅       |    ✅     |    ✅     |
/// | Submit verification  |       ✅       |       ❌       |    ❌     |    ✅     |
///
/// The shape of it: anything that only affects the member's OWN account stays
/// open throughout, so they can keep working on their profile while they wait.
/// Anything that reaches another member is held back until a human has approved
/// the identity — with two deliberate exceptions during review, so a member is
/// not left staring at a blank app for 24–48 hours: they can open a full
/// profile, and they can answer an interest someone else sent them.
library;

import '../models/profile_model.dart';

/// A gated capability.
enum AppFeature {
  browseProfiles,
  viewFullProfile,
  viewContactDetails,
  sendInterest,
  respondToInterest,
  chat,
  sendProposal,
  editProfile,
  partnerPreferences,
  uploadPhotos,
  buyPackage,
  submitVerification;

  /// Wording used in the "locked" message.
  String get label => switch (this) {
    AppFeature.browseProfiles => 'Browsing profiles',
    AppFeature.viewFullProfile => 'Viewing full profiles',
    AppFeature.viewContactDetails => 'Contact details',
    AppFeature.sendInterest => 'Sending interest',
    AppFeature.respondToInterest => 'Responding to interest',
    AppFeature.chat => 'Messaging',
    AppFeature.sendProposal => 'Sending proposals',
    AppFeature.editProfile => 'Editing your profile',
    AppFeature.partnerPreferences => 'Partner preferences',
    AppFeature.uploadPhotos => 'Uploading photos',
    AppFeature.buyPackage => 'Buying a package',
    AppFeature.submitVerification => 'Submitting verification',
  };
}

/// The four states the matrix is keyed on.
enum VerificationGate {
  /// No documents sent yet.
  notSubmitted,

  /// Documents sent, waiting on a moderator.
  inManualReview,

  /// A moderator approved them.
  verified,

  /// A moderator turned them down.
  rejected;

  String get label => switch (this) {
    VerificationGate.notSubmitted => 'Not verified',
    VerificationGate.inManualReview => 'In manual review',
    VerificationGate.verified => 'Verified',
    VerificationGate.rejected => 'Verification rejected',
  };

  /// Reads the gate off a loaded profile.
  ///
  /// Note it keys on the DOCUMENT workflow only. The AI pre-screen never opens
  /// a gate on its own — see [ProfileVerification.identityVerified].
  static VerificationGate of(ProfileVerification v) {
    if (v.documentsVerified) return VerificationGate.verified;
    if (v.documentsRejected) return VerificationGate.rejected;
    if (v.inManualReview) return VerificationGate.inManualReview;
    return VerificationGate.notSubmitted;
  }
}

/// The matrix itself, and the reasons shown when something is closed.
class FeatureAccess {
  const FeatureAccess(this.gate);

  final VerificationGate gate;

  factory FeatureAccess.of(ProfileVerification v) =>
      FeatureAccess(VerificationGate.of(v));

  /// Features available in every state — they only touch the member's own
  /// account, so there is no one to protect by withholding them.
  static const Set<AppFeature> _alwaysOpen = <AppFeature>{
    AppFeature.browseProfiles,
    AppFeature.editProfile,
    AppFeature.partnerPreferences,
    AppFeature.uploadPhotos,
    AppFeature.buyPackage,
  };

  /// Additional features unlocked while documents sit with a reviewer.
  static const Set<AppFeature> _openDuringReview = <AppFeature>{
    AppFeature.viewFullProfile,
    AppFeature.respondToInterest,
  };

  bool can(AppFeature feature) {
    if (_alwaysOpen.contains(feature)) return true;

    if (feature == AppFeature.submitVerification) {
      // Only one open request at a time; the API answers 409 otherwise.
      return gate == VerificationGate.notSubmitted ||
          gate == VerificationGate.rejected;
    }

    return switch (gate) {
      VerificationGate.verified => true,
      VerificationGate.inManualReview => _openDuringReview.contains(feature),
      VerificationGate.notSubmitted || VerificationGate.rejected => false,
    };
  }

  bool cannot(AppFeature feature) => !can(feature);

  /// Why [feature] is unavailable, or null when it is available. Written to be
  /// shown directly to the member.
  String? reasonFor(AppFeature feature) {
    if (can(feature)) return null;

    if (feature == AppFeature.submitVerification) {
      return gate == VerificationGate.inManualReview
          ? 'Your documents are already in review. You will be notified once a '
                'decision is made.'
          : 'Your identity is already verified.';
    }

    return switch (gate) {
      VerificationGate.notSubmitted =>
        '${feature.label} unlocks once your identity is verified. '
            'Submit your CNIC and a selfie to get started.',
      VerificationGate.inManualReview =>
        '${feature.label} unlocks once our team approves your documents. '
            'Review usually takes 24–48 hours.',
      VerificationGate.rejected =>
        'Your verification was rejected, so ${feature.label.toLowerCase()} is '
            'unavailable. Please submit your documents again.',
      VerificationGate.verified => null,
    };
  }

  /// Everything currently locked — for a "what you get when verified" list.
  List<AppFeature> get lockedFeatures =>
      AppFeature.values.where(cannot).toList(growable: false);
}
