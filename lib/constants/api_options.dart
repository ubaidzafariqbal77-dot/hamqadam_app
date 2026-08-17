import '../models/lookup_item_model.dart';

/// Everything the API documentation fixes in stone: the hardcoded dropdown
/// values, the UI-step ↔ API-step map, and the small value conversions the
/// backend expects (height in feet, phone split into country code + number).
///
/// Source: `https://hamqadam.com/api-docs` → "Step-wise Registration
/// (Mobile/Web Portal)" and "Complete Dropdown Reference".
class ApiOptions {
  const ApiOptions._();

  /// `gender`: 1 (Male), 2 (Female).
  static const List<LookupItem> gender = <LookupItem>[
    LookupItem(id: 1, name: 'Male'),
    LookupItem(id: 2, name: 'Female'),
  ];

  /// `marriage_timeline`.
  static const List<LookupItem> marriageTimeline = <LookupItem>[
    LookupItem.option('immediate', 'Immediate'),
    LookupItem.option('within_3_months', 'Within 3 Months'),
    LookupItem.option('within_6_months', 'Within 6 Months'),
    LookupItem.option('within_1_year', 'Within 1 Year'),
  ];

  /// `willing_to_work_after_marriage` and `expects_spouse_to_work`.
  static const List<LookupItem> workIntent = <LookupItem>[
    LookupItem.option('yes', 'Yes'),
    LookupItem.option('no', 'No'),
    LookupItem.option('depends_on_mutual_understanding', 'Depends on Mutual Understanding'),
  ];

  /// `diet`.
  static const List<LookupItem> diet = <LookupItem>[
    LookupItem.option('Vegetarian', 'Vegetarian'),
    LookupItem.option('Non-Vegetarian', 'Non-Vegetarian'),
  ];

  /// `employment_status`.
  static const List<LookupItem> employmentStatus = <LookupItem>[
    LookupItem.option('government', 'Government'),
    LookupItem.option('private', 'Private'),
    LookupItem.option('civil', 'Civil / Professional Services'),
    LookupItem.option('defence', 'Defence'),
    LookupItem.option('self_employed', 'Self-Employed'),
    LookupItem.option('unemployed', 'Unemployed'),
    LookupItem.option('retired', 'Retired'),
  ];

  /// `education_status`.
  static const List<LookupItem> educationStatus = <LookupItem>[
    LookupItem.option('completed', 'Completed'),
    LookupItem.option('in_progress', 'In Progress'),
    LookupItem.option('dropped', 'Dropped'),
  ];

  /// `live_with_family`.
  static const List<LookupItem> liveWithFamily = <LookupItem>[
    LookupItem.option('yes', 'Yes'),
    LookupItem.option('no', 'No'),
  ];

  /// `family_values` (family financial status).
  static const List<LookupItem> familyValues = <LookupItem>[
    LookupItem.option('Elite', 'Elite'),
    LookupItem.option('High', 'High'),
    LookupItem.option('Middle', 'Middle'),
    LookupItem.option('Aspiring', 'Aspiring'),
    LookupItem.option('Poor', 'Poor'),
  ];

  /// Whether the contact step can verify the email with an OTP *before* the
  /// registration is submitted.
  ///
  /// OFF because `POST /auth/register/request-otp` and `/verify-otp` sit behind
  /// `auth:sanctum` — during signup there is no token yet, so both answer 401
  /// (re-verified against hamqadam.com on 2026-08-16). The documented flow is
  /// submit first, verify after.
  ///
  /// BACKEND CHANGE THAT TURNS THIS ON: let those two endpoints run
  /// unauthenticated when an `email` is supplied (keying the code to the email
  /// instead of the user), and have `/auth/register/complete` accept the
  /// already-verified address. Then flip this to `true` — the UI, the resend
  /// cooldown and the green tick are already built.
  static const bool emailOtpBeforeSubmit = false;

  /// Send the documented strings for `willing_to_work_after_marriage` /
  /// `expects_spouse_to_work` (true) or omit them (false).
  ///
  /// KNOWN LIVE-API DEFECT (verified against hamqadam.com on 2026-08-14): the
  /// step-1 validator accepts only the documented strings — `1` is rejected with
  /// "The selected expects spouse to work is invalid" — but the `members` table
  /// stores both columns as INTEGER, so an accepted string dies in MySQL with
  /// `SQLSTATE[22007] … Incorrect integer value: 'yes' for column
  /// members.expects_spouse_to_work`. `expects_spouse_to_work` is also
  /// required, so omitting it fails too: no client value can make step 1 pass.
  ///
  /// BACKEND FIX (nothing to change in the app afterwards):
  ///   ALTER TABLE members
  ///     MODIFY willing_to_work_after_marriage VARCHAR(40) NULL,
  ///     MODIFY expects_spouse_to_work         VARCHAR(40) NULL;
  ///
  /// Set this to `false` only if the columns instead become nullable integers,
  /// in which case the answers stay local until the API can store them.
  static const bool workIntentSupported = true;

  /// The value to post for a work-intent answer. See [workIntentSupported].
  static dynamic workIntentToApi(String? value) =>
      workIntentSupported ? value : null;

  /// Looks an option up by the value stored in the buffer.
  static LookupItem? byValue(List<LookupItem> options, String? value) {
    if (value == null || value.isEmpty) return null;
    for (final LookupItem o in options) {
      if (o.code == value || o.name == value) return o;
    }
    return null;
  }

  static String? labelOf(List<LookupItem> options, String? value) =>
      byValue(options, value)?.name;

  static List<String> labelsOf(List<LookupItem> options) =>
      options.map((LookupItem o) => o.name).toList();

  /// Turns a picked label back into the API value.
  static String? valueOfLabel(List<LookupItem> options, String? label) {
    if (label == null) return null;
    for (final LookupItem o in options) {
      if (o.name == label) return o.code;
    }
    return null;
  }
}

/// Maps the 18 screens of the app onto the 18 documented API steps.
///
/// The screens keep the product's own order (Account security sits at screen
/// 11, Partner preferences closes the flow) while the backend numbers those
/// same sections 18 and 17 — this table is the single place that translates.
class RegSteps {
  const RegSteps._();

  static const int total = 18;

  /// UI step -> API step (`POST /auth/register/step/{apiStep}`).
  static const Map<int, int> _uiToApi = <int, int>{
    1: 1, // Account for
    2: 2, // Basic information
    3: 3, // Religion & language
    4: 4, // Location
    5: 5, // Contact information
    6: 6, // Caste
    7: 7, // Marital status
    8: 8, // Education
    9: 9, // Physical information
    10: 10, // Career & income
    11: 18, // Account security   -> API step 18
    12: 11, // Upload photos      -> API step 11 (multipart)
    13: 12, // About yourself     -> API step 12
    14: 13, // Identity verification -> API step 13 (multipart)
    15: 14, // Interests & hobbies-> API step 14 (optional)
    16: 15, // Family information -> API step 15 (optional)
    17: 16, // Family details     -> API step 16 (optional)
    18: 17, // Partner preferences-> API step 17
  };

  static int apiStep(int uiStep) => _uiToApi[uiStep] ?? uiStep;

  static int uiStep(int apiStep) {
    for (final MapEntry<int, int> e in _uiToApi.entries) {
      if (e.value == apiStep) return e.key;
    }
    return apiStep;
  }

  /// API steps the documentation marks skippable (14, 15, 16) expressed as UI
  /// steps: Interests, Family information, Family details.
  static const Set<int> optionalApiSteps = <int>{14, 15, 16};

  static bool isOptional(int uiStep) => optionalApiSteps.contains(apiStep(uiStep));

  /// Steps whose payload is a multipart upload (photos, identity documents).
  static const Set<int> multipartApiSteps = <int>{11, 13};

  static bool isMultipart(int uiStep) => multipartApiSteps.contains(apiStep(uiStep));

  /// Which screen owns each field of the complete-registration payload.
  ///
  /// The backend validates the whole payload in one request, so a rejected
  /// field has to be traced back to the screen the user must return to.
  static const Map<String, int> _fieldToUiStep = <String, int>{
    'on_behalf': 1,
    'gender': 1,
    'marriage_timeline': 1,
    'willing_to_work_after_marriage': 1,
    'expects_spouse_to_work': 1,
    'full_name': 2,
    'date_of_birth': 2,
    'religion_id': 3,
    'mother_tongue': 3,
    'sect_main_id': 3,
    'school_of_thought_id': 3,
    'tradition_id': 3,
    'country_id': 4,
    'state_id': 4,
    'city_id': 4,
    'area': 4,
    'country_code': 5,
    'phone': 5,
    'email': 5,
    'caste_id': 6,
    'sub_caste_id': 6,
    'marital_status_id': 7,
    'education_level_id': 8,
    'degree_id': 8,
    'field_of_study_id': 8,
    'institution_id': 8,
    'graduation_year': 8,
    'expected_graduation_year': 8,
    'education_status': 8,
    'height': 9,
    'diet': 9,
    'annual_income': 10,
    'employment_status': 10,
    'profession_category_id': 10,
    'profession_id': 10,
    'job_title': 10,
    'organization': 10,
    'years_of_experience': 10,
    'email_verify': 11,
    'password': 11,
    'password_confirmation': 11,
    'profile_photo': 12,
    'additional_photos': 12,
    'about_me': 13,
    'cnic_number': 14,
    'cnic_front': 14,
    'cnic_back': 14,
    'selfie_verification': 14,
    'hobbies': 15,
    'father_occupation': 16,
    'mother_occupation': 16,
    'siblings_sisters': 16,
    'siblings_brothers': 16,
    'family_location': 17,
    'live_with_family': 17,
    'family_values': 17,
    'family_country_id': 17,
    'family_state': 17,
    'family_city': 17,
    'partner_age_min': 18,
    'partner_age_max': 18,
    'partner_height_min': 18,
    'partner_height_max': 18,
    'partner_marital_status_id': 18,
    'partner_religion_id': 18,
    'partner_caste_id': 18,
    'partner_language_id': 18,
    'partner_country_id': 18,
    'partner_state_id': 18,
    'partner_city_id': 18,
    'partner_education': 18,
    'partner_profession': 18,
    'partner_income_min': 18,
    'partner_income_max': 18,
    'deal_breakers': 18,
  };

  /// The UI step a rejected field belongs to, or null when it is unknown.
  /// Laravel reports array members as `additional_photos.0`, so the index is
  /// stripped before the lookup.
  static int? uiStepForField(String field) =>
      _fieldToUiStep[field.split('.').first.trim()];
}

/// Value conversions between what the UI collects and what the API stores.
class ApiValues {
  const ApiValues._();

  /// Height is documented in feet (`"height": 5.4`, partner range `5.0`–`6.0`),
  /// while the pickers work in centimetres. 168 cm -> 5.6 (5 feet 6 inches).
  static double? heightFromCm(int? cm) {
    if (cm == null || cm <= 0) return null;
    final int totalInches = (cm / 2.54).round();
    final int feet = totalInches ~/ 12;
    final int inches = totalInches % 12;
    return double.tryParse('$feet.$inches');
  }

  /// Inverse of [heightFromCm], used when restoring a value the server sent.
  static int? cmFromHeight(num? height) {
    if (height == null || height <= 0) return null;
    final int feet = height.floor();
    final int inches = ((height - feet) * 10).round();
    return ((feet * 12 + inches) * 2.54).round();
  }

  /// Splits a locally-typed number into the documented `country_code` + `phone`
  /// pair: `03001234567` -> `+92` / `3001234567`.
  static ({String countryCode, String phone}) splitPhone(
    String raw, {
    String defaultCode = '+92',
  }) {
    String value = raw.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (value.startsWith('00')) value = '+${value.substring(2)}';
    if (value.startsWith('+92')) {
      return (countryCode: '+92', phone: _stripLeadingZero(value.substring(3)));
    }
    if (value.startsWith('+')) {
      // Country codes are 1–3 digits and are not self-delimiting, so the split
      // assumes a 10-digit subscriber number (true for every market the app
      // ships in today) and falls back to a 2-digit code.
      final String digits = value.substring(1).replaceAll(RegExp(r'\D'), '');
      final int codeLength = digits.length - 10;
      if (digits.length > 6) {
        final int len = (codeLength >= 1 && codeLength <= 3) ? codeLength : 2;
        return (
          countryCode: '+${digits.substring(0, len)}',
          phone: _stripLeadingZero(digits.substring(len)),
        );
      }
    }
    return (countryCode: defaultCode, phone: _stripLeadingZero(value));
  }

  static String _stripLeadingZero(String v) =>
      v.startsWith('0') ? v.replaceFirst(RegExp(r'^0+'), '') : v;
}
