import '../models/lookup_item_model.dart';

/// Presentation-only option lists for the registration flow.
///
/// Everything the API owns now comes from `dropdown-reference-data` (dynamic
/// lists, see [LookupKeys]) or from [ApiOptions] (the documented hardcoded
/// values). What is left here is UI convenience data that never reaches the
/// backend as an id: the height picker, the interest chips, and the free-text
/// suggestion lists.
class RegOptions {
  const RegOptions._();

  // Step 9 — Height options. label shown to user, value is centimetres (sent
  // to the API as a float).
  static List<LookupItem> get heights {
    final List<LookupItem> out = <LookupItem>[];
    // 4'6" (137 cm) to 6'6" (198 cm).
    for (int inches = 54; inches <= 78; inches++) {
      final int ft = inches ~/ 12;
      final int inch = inches % 12;
      final int cm = (inches * 2.54).round();
      out.add(LookupItem(id: cm, name: "$ft' $inch\"  ($cm cm)"));
    }
    return out;
  }

  // Step 15 — Interests & hobbies (mirrors the design references). Each entry
  // is "emoji label" so chips render with an emoji like the mockups.
  static const Map<String, List<String>> interestCategories = <String, List<String>>{
    'Arts & Culture': <String>[
      '🎭 Acting',
      '🍿 Anime',
      '🖼️ Art galleries',
      '🎲 Board games',
      '✍️ Creative writing',
      '🎨 Design',
      '🪚 DIY',
      '👗 Fashion',
      '🎥 Film & Cinema',
      '🎼 Live music',
      '🏛️ Museums',
      '📷 Photography',
      '🌍 Learning languages',
    ],
    'Sport': <String>[
      '🏈 American football',
      '🏸 Badminton',
      '🏏 Cricket',
      '🏀 Basketball',
      '🥊 Boxing',
      '🚴 Cycling',
      '💃 Dancing',
      '⛳ Golf',
      '🏋️ Gym',
      '🏇 Horse Riding',
      '🏊 Swimming',
      '🎾 Tennis',
      '🧘 Yoga',
    ],
    'Food & Drink': <String>[
      '🧁 Baking',
      '🧋 Bubble tea',
      '🍫 Chocolate',
      '☕ Coffee',
      '👨‍🍳 Cooking',
      '🍽️ Eating out',
      '🥗 Healthy eating',
      '🍔 Junk food',
      '🍕 Pizza',
      '🍣 Sushi',
      '🌱 Vegetarian',
    ],
    'Fitness & Wellness': <String>[
      '🏃 Running',
      '🥾 Hiking',
      '🧘‍♀️ Meditation',
      '🚶 Walking',
      '🤸 Calisthenics',
      '🥤 Nutrition',
    ],
    'Going Out': <String>[
      '🎬 Movies',
      '🛍️ Shopping',
      '🌳 Nature',
      '✈️ Travel',
      '🏖️ Beaches',
      '🎡 Theme parks',
    ],
  };

  static const int maxInterests = 15;

  // Step 16 — Parent occupations. Free-text is allowed, so this is a convenience
  // list of common answers. 'Died' (late parent) is included as an explicit
  // option per product requirement.
  static const List<String> parentOccupations = <String>[
    'Died',
    'Businessman',
    'Business Owner',
    'Government Employee',
    'Government Officer',
    'Private Job',
    'Self-Employed',
    'Doctor',
    'Engineer',
    'Teacher',
    'Professor / Lecturer',
    'Lawyer',
    'Accountant',
    'Banker',
    'Army / Defence',
    'Police',
    'Farmer / Agriculture',
    'Shopkeeper',
    'Trader',
    'Driver',
    'Labourer / Worker',
    'Skilled Worker',
    'Homemaker / Housewife',
    'Retired',
    'Overseas / Abroad',
    'Not Working',
    'Other',
  ];

  // Age options (18–99) for preference range pickers.
  static List<String> get ages =>
      List<String>.generate(82, (int i) => (i + 18).toString());

  // Step 18 — Preferred education / profession (simple pick lists + Any).
  static const List<String> partnerEducation = <String>[
    'Any',
    'Matric or above',
    'Intermediate or above',
    'Bachelors or above',
    'Masters or above',
  ];

  static const List<String> partnerProfession = <String>[
    'Any',
    'Government',
    'Private',
    'Business / Self-Employed',
    'Defence',
    'Professional (Doctor/Engineer/Lawyer)',
  ];

  static const List<String> partnerDiet = <String>['Any', 'Vegetarian', 'Non-Vegetarian'];

  static const List<String> profileManagedBy = <String>[
    'Self',
    'Parents',
    'Sibling',
    'Relative',
    'Guardian',
  ];

  /// Strips the leading emoji from an interest chip label, e.g.
  /// "🎨 Design" -> "Design".
  static String plain(String emojiLabel) {
    final int space = emojiLabel.indexOf(' ');
    if (space <= 0) return emojiLabel;
    return emojiLabel.substring(space + 1).trim();
  }
}
