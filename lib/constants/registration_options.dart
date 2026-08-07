import '../models/lookup_item_model.dart';

/// Option lists specific to the 18-step registration flow described in the
/// product document. These are the ONLY fields the flow collects — nothing
/// extra is asked of the user. Where the backend needs an id, the list uses
/// [LookupItem] with the same ids as [BundledLookups]; free-choice fields use
/// plain string lists.
class RegOptions {
  const RegOptions._();

  // Step 1 — Account For (on_behalf). Ids match BundledLookups.onBehalf.
  static const List<LookupItem> accountFor = <LookupItem>[
    LookupItem(id: 1, name: 'Myself'),
    LookupItem(id: 2, name: 'My Son'),
    LookupItem(id: 3, name: 'My Daughter'),
    LookupItem(id: 4, name: 'My Brother'),
    LookupItem(id: 5, name: 'My Sister'),
    LookupItem(id: 7, name: 'My Friend'),
    LookupItem(id: 6, name: 'My Relative'),
  ];

  /// on_behalf ids that need an explicit gender question (Myself/Friend/Relative).
  static const Set<int> needsExplicitGender = <int>{1, 7, 6};

  /// on_behalf ids that imply a male / female profile.
  static const Set<int> impliesMale = <int>{2, 4}; // Son, Brother
  static const Set<int> impliesFemale = <int>{3, 5}; // Daughter, Sister

  static const List<LookupItem> gender = <LookupItem>[
    LookupItem(id: 1, name: 'Male'),
    LookupItem(id: 2, name: 'Female'),
  ];

  // Step 1 — Marriage timeline (doc wording).
  static const List<String> marriageTimeline = <String>[
    'Immediate',
    'Within 3 Months',
    'Within 6 Months',
    '1 Year',
  ];

  // Step 1 — Work-after-marriage answers (doc wording).
  static const List<String> workIntent = <String>[
    'Yes',
    'No',
    'Depends on Mutual Understanding',
  ];

  // Step 7 — Marital status (doc wording). Ids align with BundledLookups.
  static const List<LookupItem> maritalStatus = <LookupItem>[
    LookupItem(id: 1, name: 'Never Married'),
    LookupItem(id: 2, name: 'Divorced'),
    LookupItem(id: 3, name: 'Widow / Widower'),
    LookupItem(id: 5, name: 'Awaiting Divorce'),
  ];

  // Step 8 — Highest education.
  static const List<String> educationLevel = <String>[
    'Matric',
    'Intermediate',
    'Diploma',
    'Bachelors',
    'Masters',
    'MPhil',
    'PhD',
  ];

  // Step 8 — Colleges & universities. Not exhaustive: the field allows a custom
  // entry, so a user whose institution is missing can simply type it in.
  static const List<String> institutions = <String>[
    'University of the Punjab (PU)',
    'Quaid-i-Azam University (QAU)',
    'University of Karachi (KU)',
    'University of Peshawar',
    'University of Balochistan',
    'University of Sindh (Jamshoro)',
    'University of Agriculture, Faisalabad',
    'University of Engineering & Technology, Lahore (UET)',
    'National University of Sciences & Technology (NUST)',
    'Ghulam Ishaq Khan Institute (GIKI)',
    'Lahore University of Management Sciences (LUMS)',
    'Institute of Business Administration (IBA), Karachi',
    'FAST National University (NUCES)',
    'COMSATS University Islamabad',
    'International Islamic University, Islamabad (IIUI)',
    'Air University',
    'Bahria University',
    'Iqra University',
    'Riphah International University',
    'University of Management & Technology (UMT)',
    'University of Central Punjab (UCP)',
    'University of Lahore (UOL)',
    'Superior University',
    'Government College University, Lahore (GCU)',
    'Government College University, Faisalabad',
    'University of Health Sciences, Lahore (UHS)',
    'King Edward Medical University (KEMU)',
    'Allama Iqbal Medical College',
    'Dow University of Health Sciences (DUHS)',
    'Aga Khan University (AKU)',
    'NED University of Engineering & Technology',
    'Mehran University of Engineering & Technology',
    'University of Gujrat (UOG)',
    'Bahauddin Zakariya University (BZU), Multan',
    'Islamia University of Bahawalpur (IUB)',
    'University of Sargodha',
    'University of Malakand',
    'Abdul Wali Khan University, Mardan',
    'Virtual University of Pakistan',
    'Allama Iqbal Open University (AIOU)',
    'PMAS Arid Agriculture University, Rawalpindi',
    'Institute of Space Technology (IST)',
    'Pakistan Institute of Engineering & Applied Sciences (PIEAS)',
    'Foundation University',
    'Preston University',
    'Hamdard University',
    'Ziauddin University',
    'Other',
  ];

  // Step 9 — Diet (doc: Vegetarian / Non-Vegetarian).
  static const List<String> diet = <String>['Vegetarian', 'Non-Vegetarian'];

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

 // ============================================================
// STEP 10 — WORK CATEGORY
// ============================================================

static const List<String> workCategory = <String>[
  'Government',
  'Private',
  'Civil / Professional Services',
  'Defence',
  'Medical / Healthcare',
  'Education',
  'Information Technology',
  'Finance / Banking',
  'Legal',
  'Business / Entrepreneurship',
  'Self-Employed',
  'Freelancer / Remote Work',
  'Media / Entertainment',
  'Engineering',
  'Sales / Marketing',
  'Skilled Trade / Technical',
  'Agriculture / Farming',
  'NGO / Non-Profit',
  'Retired',
  'Student',
  'Unemployed',
  'Homemaker',
  'Other',
];


// ============================================================
// PROFESSIONS BY WORK CATEGORY
// ============================================================

static const Map<String, List<String>> professionsByCategory =
    <String, List<String>>{

  // ==========================================================
  // GOVERNMENT
  // ==========================================================

  'Government': <String>[
    'Civil Servant (CSS)',
    'Administrative Officer',
    'Government Officer',
    'Government Employee',
    'Assistant Commissioner',
    'Deputy Commissioner',
    'Police Officer',
    'Police Inspector',
    'Police Constable',
    'Government Teacher',
    'Government Lecturer',
    'Government Professor',
    'Government Doctor',
    'Government Nurse',
    'Government Engineer',
    'Government Accountant',
    'Clerk / Assistant',
    'Revenue Officer',
    'Customs Officer',
    'Tax Officer',
    'Railway Employee',
    'Postal Service Employee',
    'Other Government Job',
  ],

  // ==========================================================
  // PRIVATE
  // ==========================================================

  'Private': <String>[
    'Software Engineer',
    'Software Developer',
    'Web Developer',
    'Mobile App Developer',
    'Accountant',
    'Banker',
    'Sales Executive',
    'Marketing Executive',
    'HR Professional',
    'Project Manager',
    'Operations Manager',
    'Business Analyst',
    'Data Analyst',
    'Customer Service Representative',
    'Call Center Agent',
    'Office Manager',
    'Administrative Officer',
    'Doctor (Private Hospital)',
    'Nurse (Private Hospital)',
    'Teacher / Lecturer',
    'Engineer',
    'Architect',
    'Designer',
    'Manager',
    'Executive',
    'Other Private Job',
  ],

  // ==========================================================
  // CIVIL / PROFESSIONAL SERVICES
  // ==========================================================

  'Civil / Professional Services': <String>[
    'Civil Engineer',
    'Architect',
    'Lawyer',
    'Advocate',
    'Consultant',
    'Contractor',
    'Quantity Surveyor',
    'Town Planner',
    'Surveyor',
    'Project Consultant',
    'Construction Professional',
    'Real Estate Professional',
    'Other Professional Service',
  ],

  // ==========================================================
  // DEFENCE
  // ==========================================================

  'Defence': <String>[
    'Army Officer',
    'Army Soldier',
    'Army JCO',
    'Army NCO',
    'Navy Officer',
    'Navy Sailor',
    'Air Force Officer',
    'Air Force Airman',
    'Defence Civilian',
    'Coast Guard',
    'Rangers',
    'Frontier Corps',
    'Other Defence Job',
  ],

  // ==========================================================
  // MEDICAL / HEALTHCARE
  // ==========================================================

  'Medical / Healthcare': <String>[
    'Doctor',
    'Medical Specialist',
    'Surgeon',
    'Dentist',
    'Pharmacist',
    'Physiotherapist',
    'Psychologist',
    'Psychiatrist',
    'Nurse',
    'Midwife',
    'Medical Technician',
    'Lab Technician',
    'Radiologist',
    'Radiology Technician',
    'Nutritionist',
    'Dietitian',
    'Occupational Therapist',
    'Speech Therapist',
    'Veterinarian',
    'Optometrist',
    'Healthcare Administrator',
    'Medical Representative',
    'Other Healthcare Professional',
  ],

  // ==========================================================
  // EDUCATION
  // ==========================================================

  'Education': <String>[
    'School Teacher',
    'College Teacher',
    'University Lecturer',
    'University Professor',
    'Associate Professor',
    'Assistant Professor',
    'Principal',
    'Head Teacher',
    'Education Officer',
    'Researcher',
    'Research Assistant',
    'Academic Coordinator',
    'Tutor',
    'Private Tutor',
    'Islamic Studies Teacher',
    'Quran Teacher',
    'Other Education Professional',
  ],

  // ==========================================================
  // INFORMATION TECHNOLOGY
  // ==========================================================

  'Information Technology': <String>[
    'Software Engineer',
    'Software Developer',
    'Flutter Developer',
    'Android Developer',
    'iOS Developer',
    'Web Developer',
    'Frontend Developer',
    'Backend Developer',
    'Full Stack Developer',
    'MERN Stack Developer',
    'Laravel Developer',
    'PHP Developer',
    'Python Developer',
    'Java Developer',
    'JavaScript Developer',
    'DevOps Engineer',
    'Cloud Engineer',
    'Cloud Architect',
    'Data Scientist',
    'Data Analyst',
    'Machine Learning Engineer',
    'AI Engineer',
    'Cybersecurity Specialist',
    'Network Engineer',
    'System Administrator',
    'Database Administrator',
    'QA Engineer',
    'QA Tester',
    'UI/UX Designer',
    'Graphic Designer',
    'Product Designer',
    'Product Manager',
    'Project Manager',
    'IT Consultant',
    'IT Support Specialist',
    'Technical Support Engineer',
    'Solutions Architect',
    'Other IT Professional',
  ],

  // ==========================================================
  // FINANCE / BANKING
  // ==========================================================

  'Finance / Banking': <String>[
    'Bank Manager',
    'Bank Officer',
    'Banker',
    'Accountant',
    'Chartered Accountant (CA)',
    'ACCA',
    'Financial Analyst',
    'Financial Advisor',
    'Investment Banker',
    'Auditor',
    'Tax Consultant',
    'Tax Advisor',
    'Credit Analyst',
    'Finance Manager',
    'Branch Manager',
    'Insurance Professional',
    'Stock Market Professional',
    'Investment Manager',
    'Other Finance Professional',
  ],

  // ==========================================================
  // LEGAL
  // ==========================================================

  'Legal': <String>[
    'Lawyer',
    'Advocate',
    'Barrister',
    'Legal Advisor',
    'Legal Consultant',
    'Corporate Lawyer',
    'Judge',
    'Magistrate',
    'Prosecutor',
    'Legal Officer',
    'Law Professor',
    'Other Legal Professional',
  ],

  // ==========================================================
  // BUSINESS / ENTREPRENEURSHIP
  // ==========================================================

  'Business / Entrepreneurship': <String>[
    'Business Owner',
    'Entrepreneur',
    'Company Director',
    'CEO',
    'Managing Director',
    'Startup Founder',
    'Co-Founder',
    'Retail Business Owner',
    'Wholesale Business Owner',
    'Import / Export Business',
    'E-Commerce Business Owner',
    'Real Estate Business',
    'Property Dealer',
    'Construction Business',
    'Manufacturing Business',
    'Restaurant Owner',
    'Hotel Owner',
    'Pharmacy Owner',
    'School Owner',
    'Transport Business',
    'Other Business',
  ],

  // ==========================================================
  // SELF-EMPLOYED
  // ==========================================================

  'Self-Employed': <String>[
    'Business Owner',
    'Shopkeeper',
    'Trader',
    'Consultant',
    'Doctor (Own Clinic)',
    'Dentist (Own Clinic)',
    'Lawyer (Private Practice)',
    'Architect (Private Practice)',
    'Contractor',
    'Real Estate Agent',
    'Property Dealer',
    'Pharmacist (Own Pharmacy)',
    'Restaurant Owner',
    'Workshop Owner',
    'Transport Owner',
    'Farmer / Agriculture',
    'Other Self-Employed',
  ],

  // ==========================================================
  // FREELANCER / REMOTE WORK
  // ==========================================================

  'Freelancer / Remote Work': <String>[
    'Freelance Software Developer',
    'Freelance Flutter Developer',
    'Freelance Web Developer',
    'Freelance Graphic Designer',
    'Freelance UI/UX Designer',
    'Freelance Writer',
    'Freelance Content Creator',
    'Freelance Video Editor',
    'Freelance Photographer',
    'Freelance Digital Marketer',
    'Freelance SEO Specialist',
    'Virtual Assistant',
    'Remote Employee',
    'Online Tutor',
    'Online Seller',
    'Other Freelancer',
  ],

  // ==========================================================
  // MEDIA / ENTERTAINMENT
  // ==========================================================

  'Media / Entertainment': <String>[
    'Journalist',
    'News Reporter',
    'News Anchor',
    'Writer',
    'Author',
    'Content Creator',
    'YouTuber',
    'Blogger',
    'Social Media Influencer',
    'Photographer',
    'Videographer',
    'Video Editor',
    'Film Director',
    'Actor',
    'Actress',
    'Producer',
    'Musician',
    'Singer',
    'Artist',
    'Radio Host',
    'TV Host',
    'Other Media Professional',
  ],

  // ==========================================================
  // ENGINEERING
  // ==========================================================

  'Engineering': <String>[
    'Civil Engineer',
    'Mechanical Engineer',
    'Electrical Engineer',
    'Electronics Engineer',
    'Computer Engineer',
    'Software Engineer',
    'Chemical Engineer',
    'Industrial Engineer',
    'Environmental Engineer',
    'Telecommunication Engineer',
    'Biomedical Engineer',
    'Petroleum Engineer',
    'Aerospace Engineer',
    'Architect',
    'Other Engineer',
  ],

  // ==========================================================
  // SALES / MARKETING
  // ==========================================================

  'Sales / Marketing': <String>[
    'Sales Executive',
    'Sales Manager',
    'Business Development Executive',
    'Business Development Manager',
    'Marketing Executive',
    'Marketing Manager',
    'Digital Marketing Specialist',
    'Social Media Manager',
    'SEO Specialist',
    'Brand Manager',
    'Product Marketing Manager',
    'Public Relations Officer',
    'Advertising Professional',
    'Real Estate Sales Agent',
    'Other Sales / Marketing',
  ],

  // ==========================================================
  // SKILLED TRADE / TECHNICAL
  // ==========================================================

  'Skilled Trade / Technical': <String>[
    'Electrician',
    'Plumber',
    'Carpenter',
    'Mechanic',
    'Auto Mechanic',
    'Welder',
    'Technician',
    'AC Technician',
    'Refrigeration Technician',
    'Mobile Repair Technician',
    'Computer Technician',
    'Tailor',
    'Barber',
    'Beautician',
    'Painter',
    'Mason',
    'Driver',
    'Heavy Vehicle Driver',
    'Other Skilled Profession',
  ],

  // ==========================================================
  // AGRICULTURE / FARMING
  // ==========================================================

  'Agriculture / Farming': <String>[
    'Farmer',
    'Agriculturalist',
    'Landowner',
    'Agricultural Engineer',
    'Livestock Farmer',
    'Dairy Farmer',
    'Poultry Farmer',
    'Fisherman',
    'Fisheries Professional',
    'Horticulturist',
    'Agriculture Business Owner',
    'Other Agriculture Profession',
  ],

  // ==========================================================
  // NGO / NON-PROFIT
  // ==========================================================

  'NGO / Non-Profit': <String>[
    'NGO Worker',
    'NGO Manager',
    'Project Coordinator',
    'Program Officer',
    'Social Worker',
    'Humanitarian Worker',
    'Development Professional',
    'Community Worker',
    'Other NGO Professional',
  ],

  // ==========================================================
  // RETIRED
  // ==========================================================

  'Retired': <String>[
    'Retired Government Employee',
    'Retired Army Officer',
    'Retired Defence Personnel',
    'Retired Teacher',
    'Retired Professor',
    'Retired Doctor',
    'Retired Engineer',
    'Retired Businessperson',
    'Other Retired Professional',
  ],

  // ==========================================================
  // STUDENT
  // ==========================================================

  'Student': <String>[
    'School Student',
    'College Student',
    'University Student',
    'Undergraduate Student',
    'Graduate Student',
    'Postgraduate Student',
    'MPhil Student',
    'PhD Student',
    'Medical Student',
    'Engineering Student',
    'Other Student',
  ],

  // ==========================================================
  // UNEMPLOYED
  // ==========================================================

  'Unemployed': <String>[
    'Currently Unemployed',
    'Looking for Work',
    'Job Seeker',
    'Other',
  ],

  // ==========================================================
  // HOMEMAKER
  // ==========================================================

  'Homemaker': <String>[
    'Homemaker',
    'Housewife',
    'Househusband',
  ],

  // ==========================================================
  // OTHER
  // ==========================================================

  'Other': <String>[
    'Other Profession',
    'Not Specified',
  ],
};

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

  // Step 17 — Family financial status (doc wording).
  static const List<String> familyFinancialStatus = <String>[
    'Elite',
    'High',
    'Middle',
    'Aspiring',
    'Poor',
  ];

  static const List<String> yesNo = <String>['Yes', 'No'];

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
