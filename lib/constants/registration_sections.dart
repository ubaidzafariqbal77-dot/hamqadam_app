import 'api_options.dart';

/// Which registration steps must be filled, which ones may be skipped, and
/// which ones make up the profile-completion picture.
///
/// The API marks exactly three steps skippable — Interests & Hobbies, Family
/// Information and Family Details (API steps 14/15/16, screens 15/16/17). Every
/// other step is mandatory before the registration counts as complete and the
/// Basic Free package is applied, so the flow no longer offers a skip on them.
class RegSections {
  const RegSections._();

  /// True when [step] (a UI step) may be skipped during signup.
  static bool canSkip(int step) => RegSteps.isOptional(step);

  /// Steps the API requires before registration completes.
  static Set<int> get mandatory => <int>{
    for (int step = 1; step <= RegSteps.total; step++)
      if (!canSkip(step)) step,
  };

  /// Sections counted by the completion graph, in display order. The pure
  /// account steps (2 name/dob, 5 contact, 11 password) are left out: they are
  /// always filled, so counting them would only inflate the percentage.
  static const List<int> profile = <int>[
    1, // marriage plans & work intent (collected with "Account for")
    3, // religion & language
    4, // location
    6, // caste
    7, // marital status
    8, // education
    9, // physical
    10, // career & income
    12, // photos
    13, // about yourself
    14, // identity verification
    15, // interests
    16, // family information
    17, // family details
    18, // partner preferences
  ];

  static bool isProfileSection(int step) => profile.contains(step);

  static int get totalProfileSections => profile.length;
}
