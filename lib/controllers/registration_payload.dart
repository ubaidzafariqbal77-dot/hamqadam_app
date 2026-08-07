import '../constants/registration_options.dart';
import '../core/storage/registration_buffer.dart';

/// Maps the buffered 18-step form data onto the backend's 12 step-endpoints.
///
/// Only the fields the product document actually collects are sent — no filler
/// values. Empty maps are skipped by the caller so no half-built step is
/// posted.
class RegPayload {
  const RegPayload._();

  static void _put(Map<String, dynamic> m, String key, dynamic v) {
    if (v == null) return;
    if (v is String && v.trim().isEmpty) return;
    if (v is List && v.isEmpty) return;
    m[key] = v;
  }

  /// Converts a centimetre height to metres, rounded to 2 dp so it always
  /// satisfies the backend's `between 0 and 9.99` rule (168 cm -> 1.68 m).
  static double _cmToMetres(int cm) => (cm / 100).clamp(0, 9.99).toDouble();

  static bool? _workIntentToBool(String? v) {
    if (v == null) return null;
    if (v == 'Yes') return true;
    if (v == 'No') return false;
    return null; // "Depends on Mutual Understanding" -> omit.
  }

  /// Step 2 — Basic profile.
  static Map<String, dynamic> basic(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'marital_status_id', b.getInt('marital_status_id'));
    final int? tongue = b.getInt('mother_tongue');
    _put(m, 'mother_tongue', tongue);
    if (tongue != null) _put(m, 'known_languages', <int>[tongue]);
    final int? cm = b.getInt('height_cm');
    // Backend stores height in METRES (validation: between 0 and 9.99), while
    // the form collects centimetres — convert cm → m (168 cm -> 1.68).
    if (cm != null) _put(m, 'height', _cmToMetres(cm));
    _put(m, 'country_id', b.getInt('country_id'));
    _put(m, 'state_id', b.getInt('state_id'));
    _put(m, 'city_id', b.getInt('city_id'));
    return m;
  }

  /// Step 3 — About me.
  static Map<String, dynamic> about(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'about_me', b.getString('about_me'));
    return m;
  }

  /// Step 4 — Religion & culture.
  static Map<String, dynamic> religion(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'religion_id', b.getInt('religion_id'));
    _put(m, 'caste_id', b.getInt('caste_id'));
    return m;
  }

  /// Step 5 — Education & career.
  static Map<String, dynamic> education(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'education_level', b.getString('education_level'));
    _put(m, 'institution', b.getString('institution'));
    _put(m, 'profession', b.getString('profession'));
    _put(m, 'annual_income', b.getInt('annual_income'));
    final String? cat = b.getString('work_category');
    if (cat != null) {
      _put(m, 'employment_status', cat == 'Self-Employed' ? 'self-employed' : 'yes');
    }
    return m;
  }

  /// Step 6 — Family (info + details).
  static Map<String, dynamic> family(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'father_occupation', b.getString('father_occupation'));
    _put(m, 'mother_occupation', b.getString('mother_occupation'));
    _put(m, 'siblings_brothers', b.getInt('siblings_brothers'));
    _put(m, 'siblings_sisters', b.getInt('siblings_sisters'));
    _put(m, 'family_location', b.getString('family_location'));
    _put(m, 'family_values', b.getString('family_financial_status'));
    return m;
  }

  /// Step 7 — Marriage & future plans (collected on step 1).
  static Map<String, dynamic> future(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'marriage_timeline', b.getString('marriage_timeline'));
    _put(m, 'willing_to_work_after_marriage', _workIntentToBool(b.getString('willing_to_work')));
    _put(m, 'expects_spouse_to_work', _workIntentToBool(b.getString('expects_spouse_work')));
    return m;
  }

  /// Step 8 — Lifestyle & interests.
  static Map<String, dynamic> lifestyle(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'diet', b.getString('diet'));
    final List<String> interests = b
        .getStringList('interests')
        .map(RegOptions.plain)
        .toList();
    if (interests.isNotEmpty) {
      _put(m, 'interests_multi_select', interests);
      _put(m, 'hobbies', interests.join(', '));
    }
    return m;
  }

  /// Step 9 — Profile media (backend accepts string paths).
  static Map<String, dynamic> media(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'profile_photo', b.getString('profile_photo'));
    _put(m, 'private_gallery', b.getStringList('gallery'));
    return m;
  }

  /// Step 10 — Partner preferences.
  static Map<String, dynamic> partner(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'partner_age_min', b.getInt('partner_age_min'));
    _put(m, 'partner_age_max', b.getInt('partner_age_max'));
    // Same metres conversion as the member's own height (validation 0–9.99).
    final int? hMin = b.getInt('partner_height_min');
    final int? hMax = b.getInt('partner_height_max');
    if (hMin != null) _put(m, 'partner_height_min', _cmToMetres(hMin));
    if (hMax != null) _put(m, 'partner_height_max', _cmToMetres(hMax));
    _put(m, 'partner_marital_status_id', b.getInt('partner_marital_status_id'));
    _put(m, 'partner_religion_id', b.getInt('partner_religion_id'));
    _put(m, 'partner_caste_id', b.getInt('partner_caste_id'));
    _put(m, 'partner_language_id', b.getInt('partner_language_id'));
    _put(m, 'partner_country_id', b.getInt('partner_country_id'));
    _put(m, 'partner_city_id', b.getInt('partner_city_id'));
    _put(m, 'partner_education', b.getString('partner_education'));
    _put(m, 'partner_profession', b.getString('partner_profession'));
    _put(m, 'partner_income_min', b.getInt('partner_income_min'));
    _put(m, 'partner_income_max', b.getInt('partner_income_max'));
    _put(m, 'partner_diet', b.getString('partner_diet'));
    return m;
  }

  // ---- Single-section saves (editing a skipped step after signup) -----------

  /// Backend step-endpoints a single UI step writes to.
  ///
  /// The 18 UI steps are a reorganisation of the backend's 12 step-endpoints, so
  /// one screen can feed more than one endpoint (e.g. "Physical information"
  /// carries the height into the basic profile and the diet into lifestyle).
  /// Steps 2/5/11 hold pure account fields (name, contact, password) which are
  /// edited through `PUT /profile`, and step 14 uses the verification endpoint —
  /// all four map to no step-endpoint here.
  static const Map<int, List<int>> _endpointsForStep = <int, List<int>>{
    1: <int>[7], // marriage plans & work intent
    2: <int>[], // name / date of birth -> account
    3: <int>[4, 2], // religion + mother tongue
    4: <int>[2], // location
    5: <int>[], // email / phone -> account
    6: <int>[4], // caste
    7: <int>[2], // marital status
    8: <int>[5], // education
    9: <int>[2, 8], // height + diet
    10: <int>[5], // career & income
    11: <int>[], // password -> account
    12: <int>[9], // photos
    13: <int>[3], // about me
    14: <int>[], // verification endpoint (multipart)
    15: <int>[8], // interests
    16: <int>[6], // family information
    17: <int>[6], // family details
    18: <int>[10], // partner preferences
  };

  static List<int> endpointsForStep(int uiStep) =>
      _endpointsForStep[uiStep] ?? const <int>[];

  /// Builds the payload for one backend step-endpoint from the buffer.
  static Map<String, dynamic> forEndpoint(int endpointStep, RegistrationBuffer b) {
    switch (endpointStep) {
      case 2:
        return basic(b);
      case 3:
        return about(b);
      case 4:
        return religion(b);
      case 5:
        return education(b);
      case 6:
        return family(b);
      case 7:
        return future(b);
      case 8:
        return lifestyle(b);
      case 9:
        return media(b);
      case 10:
        return partner(b);
      default:
        return <String, dynamic>{};
    }
  }

  /// Whether identity documents were captured (step 14).
  static bool hasVerification(RegistrationBuffer b) =>
      (b.getString('cnic_number') ?? '').isNotEmpty &&
      (b.getString('cnic_front') ?? '').isNotEmpty &&
      (b.getString('cnic_back') ?? '').isNotEmpty &&
      (b.getString('selfie') ?? '').isNotEmpty;
}
