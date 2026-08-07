/// Which registration steps must be filled, which ones may be skipped, and
/// which ones make up the profile-completion picture.
///
/// The 18-step signup flow spreads the account-creation fields across steps 1
/// (who the profile is for + gender), 2 (name + date of birth), 5 (email +
/// phone) and 11 (password) — the account cannot exist without them, so those
/// four are the only mandatory steps. Everything else can be skipped during
/// signup and completed later from "Complete your profile".
class RegSections {
  const RegSections._();

  /// Steps required to create the account — never skippable.
  static const Set<int> mandatory = <int>{1, 2, 5, 11};

  /// True when [step] may be skipped during signup.
  static bool canSkip(int step) => !mandatory.contains(step);

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
