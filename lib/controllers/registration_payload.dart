import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../constants/api_options.dart';
import '../core/storage/registration_buffer.dart';
import '../core/utils/app_logger.dart';
import '../core/validators/app_validators.dart';

/// A `multipart/form-data` body for the two upload steps (photos, identity).
class MultipartPayload {
  const MultipartPayload({
    this.fields = const <String, dynamic>{},
    this.files = const <String, String?>{},
    this.arrayFiles = const <String, List<String>>{},
  });

  final Map<String, dynamic> fields;
  final Map<String, String?> files;
  final Map<String, List<String>> arrayFiles;

  bool get isEmpty =>
      fields.isEmpty &&
      files.values.every((String? p) => p == null || p.isEmpty) &&
      arrayFiles.values.every((List<String> l) => l.isEmpty);
}

/// Builds the exact request body each documented registration step expects,
/// out of the values the screens buffered.
///
/// Field names, value formats and allowed enum values follow
/// `https://hamqadam.com/api-docs` → "Step-wise Registration Samples".
class RegPayload {
  const RegPayload._();

  static void _put(Map<String, dynamic> m, String key, dynamic v) {
    if (v == null) return;
    if (v is String && v.trim().isEmpty) return;
    if (v is List && v.isEmpty) return;
    m[key] = v is String ? v.trim() : v;
  }

  /// Reads [path] and returns it as a `data:` URI.
  ///
  /// `POST /auth/register/complete` validates all five media fields as
  /// STRINGS — an actual multipart file part is rejected with
  /// "The profile photo must be a string" — so every image travels base64
  /// encoded. Encoding runs off the UI isolate; a few hundred KB per photo is
  /// enough to drop frames otherwise.
  static Future<String?> _dataUri(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    try {
      final Uint8List bytes = await File(path).readAsBytes();
      final String b64 = await compute(base64Encode, bytes);
      return 'data:${_mimeOf(path)};base64,$b64';
    } catch (e) {
      AppLogger.w('Could not read media for upload ($path): $e');
      return null;
    }
  }

  static String _mimeOf(String path) {
    final String ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  // ---- POST /auth/register/complete -----------------------------------------

  /// The ONE JSON body that carries all 18 steps.
  ///
  /// The backend no longer stores registration step by step: the app collects
  /// every answer locally and submits this single payload, which creates the
  /// draft account and returns the token used for the email-OTP verification.
  ///
  /// Field order and names follow the documented "Complete Registration API"
  /// sample verbatim; anything the user did not answer is simply omitted
  /// (see [_put]), which is what the optional steps rely on.
  static Future<Map<String, dynamic>> complete(RegistrationBuffer b) async {
    final Map<String, dynamic> m = <String, dynamic>{};

    // Step 1 — account for.
    _put(m, 'on_behalf', b.getInt('on_behalf'));
    _put(m, 'gender', b.getInt('gender'));
    _put(m, 'marriage_timeline', b.getString('marriage_timeline'));
    _put(
      m,
      'willing_to_work_after_marriage',
      ApiOptions.workIntentToApi(b.getString('willing_to_work_after_marriage')),
    );
    _put(
      m,
      'expects_spouse_to_work',
      ApiOptions.workIntentToApi(b.getString('expects_spouse_to_work')),
    );

    // Step 2 — basic information.
    _put(m, 'full_name', fullName(b));
    _put(m, 'date_of_birth', b.getString('date_of_birth'));

    // Step 3 — religion & language.
    _put(m, 'religion_id', b.getInt('religion_id'));
    _put(m, 'mother_tongue', b.getInt('mother_tongue'));
    _put(m, 'sect_main_id', b.getInt('sect_main_id'));
    _put(m, 'school_of_thought_id', b.getInt('school_of_thought_id'));
    _put(m, 'tradition_id', b.getInt('tradition_id'));

    // Step 4 — location.
    _put(m, 'country_id', b.getInt('country_id'));
    _put(m, 'state_id', b.getInt('state_id'));
    _put(m, 'city_id', b.getInt('city_id'));
    _put(m, 'area', b.getString('area'));

    // Step 5 — contact information.
    final ({String countryCode, String phone}) split = ApiValues.splitPhone(
      b.getString('phone') ?? '',
      defaultCode: b.getString('country_code') ?? '+92',
    );
    _put(m, 'country_code', split.countryCode);
    _put(m, 'phone', split.phone);
    _put(m, 'email', b.getString('email')?.toLowerCase());

    // Step 6 — caste.
    _put(m, 'caste_id', b.getInt('caste_id'));
    _put(m, 'sub_caste_id', b.getInt('sub_caste_id'));

    // Step 7 — marital status.
    _put(m, 'marital_status_id', b.getInt('marital_status_id'));

    // Step 8 — education.
    _put(m, 'education_level_id', b.getInt('education_level_id'));
    _put(m, 'degree_id', b.getInt('degree_id'));
    _put(m, 'field_of_study_id', b.getInt('field_of_study_id'));
    _put(m, 'institution_id', b.getInt('institution_id'));
    final String? eduStatus = b.getString('education_status');
    _put(m, 'education_status', eduStatus);
    if (eduStatus == 'in_progress') {
      _put(m, 'expected_graduation_year', b.getInt('graduation_year'));
    } else {
      _put(m, 'graduation_year', b.getInt('graduation_year'));
    }

    // Step 9 — physical information.
    _put(m, 'height', ApiValues.heightFromCm(b.getInt('height_cm')));
    _put(m, 'diet', b.getString('diet'));

    // Step 10 — career & income.
    _put(m, 'annual_income', b.getInt('annual_income'));
    _put(m, 'employment_status', b.getString('employment_status'));
    _put(m, 'profession_category_id', b.getInt('profession_category_id'));
    _put(m, 'profession_id', b.getInt('profession_id'));
    _put(m, 'job_title', b.getString('job_title'));
    _put(m, 'organization', b.getString('organization'));
    _put(m, 'years_of_experience', b.getInt('years_of_experience'));

    // Step 12 — about yourself (11 & 13 are the file steps, below).
    _put(m, 'about_me', b.getString('about_me'));

    // Step 13 — identity verification (number; the images are files).
    _put(m, 'cnic_number', b.getString('cnic_number'));

    // Step 14 — interests & hobbies (optional). Documented as ONE
    // comma-separated string ("Reading, Music, Travel"), unlike deal_breakers
    // which stays a JSON array.
    final List<String> hobbies = b.getStringList('hobbies');
    if (hobbies.isNotEmpty) _put(m, 'hobbies', hobbies.join(', '));

    // Step 15 — family information (optional).
    _put(m, 'father_occupation', b.getString('father_occupation'));
    _put(m, 'mother_occupation', b.getString('mother_occupation'));
    _put(m, 'siblings_sisters', b.getInt('siblings_sisters'));
    _put(m, 'siblings_brothers', b.getInt('siblings_brothers'));

    // Step 16 — family details (optional).
    _put(m, 'family_location', b.getString('family_location'));
    _put(m, 'live_with_family', b.getString('live_with_family'));
    _put(m, 'family_values', b.getString('family_values'));
    _put(m, 'family_country_id', b.getInt('family_country_id'));
    _put(m, 'family_state', b.getString('family_state'));
    _put(m, 'family_city', b.getString('family_city'));

    // Step 17 — partner preferences.
    _put(m, 'partner_age_min', b.getInt('partner_age_min'));
    _put(m, 'partner_age_max', b.getInt('partner_age_max'));
    _put(m, 'partner_height_min', ApiValues.heightFromCm(b.getInt('partner_height_min')));
    _put(m, 'partner_height_max', ApiValues.heightFromCm(b.getInt('partner_height_max')));
    _put(m, 'partner_marital_status_id', b.getInt('partner_marital_status_id'));
    _put(m, 'partner_religion_id', b.getInt('partner_religion_id'));
    _put(m, 'partner_caste_id', b.getInt('partner_caste_id'));
    _put(m, 'partner_language_id', b.getInt('partner_language_id'));
    _put(m, 'partner_country_id', b.getInt('partner_country_id'));
    _put(m, 'partner_state_id', b.getInt('partner_state_id'));
    _put(m, 'partner_city_id', b.getInt('partner_city_id'));
    _put(m, 'partner_education', b.getString('partner_education'));
    _put(m, 'partner_profession', b.getString('partner_profession'));
    _put(m, 'partner_income_min', b.getInt('partner_income_min'));
    _put(m, 'partner_income_max', b.getInt('partner_income_max'));
    _put(m, 'deal_breakers', b.getStringList('deal_breakers'));

    // Step 18 — account security. `email_verify` re-confirms the address the
    // OTP will be sent to.
    _put(m, 'email_verify', b.getString('email')?.toLowerCase());
    _put(m, 'password', b.getString('password'));
    _put(m, 'password_confirmation', b.getString('password_confirmation'));

    // Steps 11 & 13 — photos and identity documents, base64 encoded because the
    // endpoint validates them as strings (see [_dataUri]).
    _put(m, 'profile_photo', await _dataUri(b.getString('profile_photo')));
    final List<String> gallery = <String>[];
    for (final String path in b.getStringList('gallery')) {
      final String? encoded = await _dataUri(path);
      if (encoded != null) gallery.add(encoded);
    }
    _put(m, 'additional_photos', gallery);
    _put(m, 'cnic_front', await _dataUri(b.getString('cnic_front')));
    _put(m, 'cnic_back', await _dataUri(b.getString('cnic_back')));
    _put(m, 'selfie_verification', await _dataUri(b.getString('selfie')));

    return m;
  }

  /// The JSON body for a UI step, or an empty map for the multipart steps.
  /// Still used when a single section is edited after signup.
  static Map<String, dynamic> forUiStep(int uiStep, RegistrationBuffer b) {
    switch (uiStep) {
      case 1:
        return accountFor(b);
      case 2:
        return basicInformation(b);
      case 3:
        return religionLanguage(b);
      case 4:
        return location(b);
      case 5:
        return contact(b);
      case 6:
        return caste(b);
      case 7:
        return maritalStatus(b);
      case 8:
        return education(b);
      case 9:
        return physical(b);
      case 10:
        return career(b);
      case 11:
        return accountSecurity(b);
      case 13:
        return about(b);
      case 15:
        return interests(b);
      case 16:
        return familyInformation(b);
      case 17:
        return familyDetails(b);
      case 18:
        return partnerPreferences(b);
      default:
        return <String, dynamic>{}; // 12 & 14 are multipart
    }
  }

  static MultipartPayload? multipartForUiStep(int uiStep, RegistrationBuffer b) {
    switch (uiStep) {
      case 12:
        return photos(b);
      case 14:
        return identity(b);
      default:
        return null;
    }
  }

  // ---- API step 1 — Account For ---------------------------------------------

  static Map<String, dynamic> accountFor(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'on_behalf', b.getInt('on_behalf'));
    _put(m, 'gender', b.getInt('gender'));
    _put(m, 'marriage_timeline', b.getString('marriage_timeline'));
    // Both work-intent columns are integers in the live database — see
    // [ApiOptions.workIntentToApi].
    _put(
      m,
      'willing_to_work_after_marriage',
      ApiOptions.workIntentToApi(b.getString('willing_to_work_after_marriage')),
    );
    _put(
      m,
      'expects_spouse_to_work',
      ApiOptions.workIntentToApi(b.getString('expects_spouse_to_work')),
    );
    return m;
  }

  // ---- API step 2 — Basic Information ---------------------------------------

  static Map<String, dynamic> basicInformation(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'full_name', fullName(b));
    _put(m, 'date_of_birth', b.getString('date_of_birth'));
    // Optional extras the API accepts on this step; sent only once known.
    _put(m, 'mother_tongue', b.getInt('mother_tongue'));
    final int? tongue = b.getInt('mother_tongue');
    if (tongue != null) _put(m, 'known_languages', <int>[tongue]);
    _put(m, 'height', ApiValues.heightFromCm(b.getInt('height_cm')));
    return m;
  }

  /// The name as the API wants it, and the single source of truth for reading it
  /// back out of the buffer.
  ///
  /// Step 2 collects one `full_name` field. The legacy `first_name`/`last_name`
  /// pair is still read as a fallback so a draft started before that change
  /// resumes with the name intact.
  static String? fullName(RegistrationBuffer b) {
    final String stored = AppValidators.collapseSpaces(b.getString('full_name'));
    if (stored.isNotEmpty) return stored;
    final String legacy = AppValidators.collapseSpaces(
      '${b.getString('first_name') ?? ''} ${b.getString('last_name') ?? ''}',
    );
    return legacy.isEmpty ? null : legacy;
  }

  // ---- API step 3 — Religion & Language -------------------------------------

  static Map<String, dynamic> religionLanguage(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'religion_id', b.getInt('religion_id'));
    _put(m, 'mother_tongue', b.getInt('mother_tongue'));
    _put(m, 'sect_main_id', b.getInt('sect_main_id'));
    _put(m, 'school_of_thought_id', b.getInt('school_of_thought_id'));
    _put(m, 'tradition_id', b.getInt('tradition_id'));
    return m;
  }

  // ---- API step 4 — Location ------------------------------------------------

  static Map<String, dynamic> location(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'country_id', b.getInt('country_id'));
    _put(m, 'state_id', b.getInt('state_id'));
    _put(m, 'city_id', b.getInt('city_id'));
    _put(m, 'area', b.getString('area'));
    return m;
  }

  // ---- API step 5 — Contact Information -------------------------------------

  static Map<String, dynamic> contact(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    final ({String countryCode, String phone}) split = ApiValues.splitPhone(
      b.getString('phone') ?? '',
      defaultCode: b.getString('country_code') ?? '+92',
    );
    _put(m, 'country_code', split.countryCode);
    _put(m, 'phone', split.phone);
    _put(m, 'email', b.getString('email')?.toLowerCase());
    return m;
  }

  // ---- API step 6 — Caste ---------------------------------------------------

  static Map<String, dynamic> caste(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'caste_id', b.getInt('caste_id'));
    _put(m, 'sub_caste_id', b.getInt('sub_caste_id'));
    return m;
  }

  // ---- API step 7 — Marital Status ------------------------------------------

  static Map<String, dynamic> maritalStatus(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'marital_status_id', b.getInt('marital_status_id'));
    return m;
  }

  // ---- API step 8 — Education ----------------------------------------------

  static Map<String, dynamic> education(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'education_level_id', b.getInt('education_level_id'));
    _put(m, 'degree_id', b.getInt('degree_id'));
    _put(m, 'field_of_study_id', b.getInt('field_of_study_id'));
    _put(m, 'institution_id', b.getInt('institution_id'));
    final String? status = b.getString('education_status');
    _put(m, 'education_status', status);
    if (status == 'in_progress') {
      _put(m, 'expected_graduation_year', b.getInt('graduation_year'));
    } else {
      _put(m, 'graduation_year', b.getInt('graduation_year'));
    }
    return m;
  }

  // ---- API step 9 — Physical Information ------------------------------------

  static Map<String, dynamic> physical(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'height', ApiValues.heightFromCm(b.getInt('height_cm')));
    _put(m, 'diet', b.getString('diet'));
    return m;
  }

  // ---- API step 10 — Career & Income ----------------------------------------

  static Map<String, dynamic> career(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'annual_income', b.getInt('annual_income'));
    _put(m, 'employment_status', b.getString('employment_status'));
    _put(m, 'profession_category_id', b.getInt('profession_category_id'));
    _put(m, 'profession_id', b.getInt('profession_id'));
    _put(m, 'job_title', b.getString('job_title'));
    _put(m, 'organization', b.getString('organization'));
    _put(m, 'years_of_experience', b.getInt('years_of_experience'));
    return m;
  }

  // ---- API step 18 — Account Security (UI step 11) --------------------------

  static Map<String, dynamic> accountSecurity(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'email_verify', b.getString('email')?.toLowerCase());
    _put(m, 'password', b.getString('password'));
    _put(m, 'password_confirmation', b.getString('password_confirmation'));
    return m;
  }

  // ---- API step 11 — Photos (UI step 12, multipart) -------------------------

  static MultipartPayload photos(RegistrationBuffer b) => MultipartPayload(
    files: <String, String?>{'profile_photo': b.getString('profile_photo')},
    arrayFiles: <String, List<String>>{'additional_photos': b.getStringList('gallery')},
  );

  // ---- API step 12 — About Yourself (UI step 13) ----------------------------

  static Map<String, dynamic> about(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'about_me', b.getString('about_me'));
    return m;
  }

  // ---- API step 13 — Identity Verification (UI step 14, multipart) ----------

  static MultipartPayload identity(RegistrationBuffer b) => MultipartPayload(
    fields: <String, dynamic>{'cnic_number': b.getString('cnic_number')},
    files: <String, String?>{
      'cnic_front': b.getString('cnic_front'),
      'cnic_back': b.getString('cnic_back'),
      'selfie_verification': b.getString('selfie'),
    },
  );

  static bool hasVerification(RegistrationBuffer b) =>
      (b.getString('cnic_number') ?? '').isNotEmpty &&
      (b.getString('cnic_front') ?? '').isNotEmpty &&
      (b.getString('cnic_back') ?? '').isNotEmpty &&
      (b.getString('selfie') ?? '').isNotEmpty;

  // ---- API step 14 — Interests & Hobbies (UI step 15) -----------------------

  static Map<String, dynamic> interests(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'hobbies', b.getStringList('hobbies'));
    return m;
  }

  // ---- API step 15 — Family Information (UI step 16) ------------------------

  static Map<String, dynamic> familyInformation(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'father_occupation', b.getString('father_occupation'));
    _put(m, 'mother_occupation', b.getString('mother_occupation'));
    _put(m, 'siblings_sisters', b.getInt('siblings_sisters'));
    _put(m, 'siblings_brothers', b.getInt('siblings_brothers'));
    return m;
  }

  // ---- API step 16 — Family Details (UI step 17) ----------------------------

  static Map<String, dynamic> familyDetails(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'family_location', b.getString('family_location'));
    _put(m, 'live_with_family', b.getString('live_with_family'));
    _put(m, 'family_values', b.getString('family_values'));
    _put(m, 'family_country_id', b.getInt('family_country_id'));
    // The API stores the family's state and city as plain names.
    _put(m, 'family_state', b.getString('family_state'));
    _put(m, 'family_city', b.getString('family_city'));
    return m;
  }

  // ---- API step 17 — Basic Partner Preferences (UI step 18) -----------------

  static Map<String, dynamic> partnerPreferences(RegistrationBuffer b) {
    final Map<String, dynamic> m = <String, dynamic>{};
    _put(m, 'partner_age_min', b.getInt('partner_age_min'));
    _put(m, 'partner_age_max', b.getInt('partner_age_max'));
    _put(m, 'partner_height_min', ApiValues.heightFromCm(b.getInt('partner_height_min')));
    _put(m, 'partner_height_max', ApiValues.heightFromCm(b.getInt('partner_height_max')));
    _put(m, 'partner_marital_status_id', b.getInt('partner_marital_status_id'));
    _put(m, 'partner_religion_id', b.getInt('partner_religion_id'));
    _put(m, 'partner_caste_id', b.getInt('partner_caste_id'));
    _put(m, 'partner_language_id', b.getInt('partner_language_id'));
    _put(m, 'partner_country_id', b.getInt('partner_country_id'));
    _put(m, 'partner_state_id', b.getInt('partner_state_id'));
    _put(m, 'partner_city_id', b.getInt('partner_city_id'));
    _put(m, 'partner_education', b.getString('partner_education'));
    _put(m, 'partner_profession', b.getString('partner_profession'));
    _put(m, 'partner_income_min', b.getInt('partner_income_min'));
    _put(m, 'partner_income_max', b.getInt('partner_income_max'));
    _put(m, 'deal_breakers', b.getStringList('deal_breakers'));
    return m;
  }
}
