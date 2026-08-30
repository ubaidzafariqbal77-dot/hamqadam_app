import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../constants/app_lookups.dart';
import '../constants/income_options.dart';
import '../exceptions/app_exceptions.dart';
import '../models/lookup_item_model.dart';
import '../models/privacy_settings_model.dart';
import '../models/profile_model.dart';
import '../repositories/profile_repository.dart';
import '../widgets/app_snackbar.dart';
import 'lookup_controller.dart';
import 'profile_controller.dart';

/// Backs the Edit Profile form. Seeds itself from the currently-loaded
/// [ProfileModel], submits `PUT /profile`, and pushes the fresh copy back into
/// [ProfileController] on success. Created/disposed by [EditProfileView].
///
/// ## Two endpoints, not one
///
/// The form covers both profile data and privacy switches, but they belong to
/// different endpoints. `PUT /profile` ignores anything it does not declare in
/// UpdateProfileRequest — and it ignores it SILENTLY, returning 200 with an
/// unchanged profile. The privacy switches (`show_photo`, `show_email`, …) were
/// being posted there, so flipping any of them appeared to succeed and changed
/// nothing. They go to `PATCH /profile/privacy` now.
///
/// Two other keys were being dropped the same way and are fixed here:
///
///  * `on_behalf_id` — the request rule is `on_behalf`, so "Profile for" never
///    saved.
///  * `email` — `PUT /profile` has no email rule at all. Changing the address
///    needs the verification flow (`POST /auth/email/verification-code` then
///    `/auth/email/verify`), so the field is shown read-only rather than
///    pretending to save.
class EditProfileController extends GetxController {
  EditProfileController(this._repo, this._profile, this.lookup);

  final ProfileRepository _repo;
  final ProfileController _profile;
  final LookupController lookup;

  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final RxBool busy = false.obs;

  // ---- Account --------------------------------------------------------------
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();

  /// Read-only. Kept so the form can show it; never submitted.
  final TextEditingController email = TextEditingController();
  final TextEditingController phone = TextEditingController();

  // ---- About / personal -----------------------------------------------------
  final TextEditingController aboutMe = TextEditingController();
  final TextEditingController children = TextEditingController();
  final TextEditingController travel = TextEditingController();
  final TextEditingController goals = TextEditingController();

  final Rxn<DateTime> dob = Rxn<DateTime>();
  final RxnInt genderId = RxnInt();
  final RxnInt maritalId = RxnInt();
  final RxnInt onBehalfId = RxnInt();
  final RxnInt motherTongueId = RxnInt();
  final RxList<int> knownLanguageIds = <int>[].obs;

  // ---- Religion & language (step 3) -----------------------------------------
  final RxnInt religionId = RxnInt();
  final RxnInt sectMainId = RxnInt();
  final RxnInt schoolOfThoughtId = RxnInt();
  final RxnInt traditionId = RxnInt();

  // ---- Caste (step 6) --------------------------------------------------------
  final RxnInt casteId = RxnInt();
  final RxnInt subCasteId = RxnInt();

  // ---- Location (step 4) -----------------------------------------------------
  final RxnInt countryId = RxnInt();
  final RxnInt stateId = RxnInt();
  final RxnInt cityId = RxnInt();
  final TextEditingController area = TextEditingController();

  // ---- Education (step 8) ----------------------------------------------------
  final RxnInt educationLevelId = RxnInt();
  final RxnInt degreeId = RxnInt();
  final RxnInt fieldOfStudyId = RxnInt();
  final RxnInt institutionId = RxnInt();
  final TextEditingController graduationYear = TextEditingController();
  final RxnString educationStatus = RxnString();

  // ---- Physical (step 9) -----------------------------------------------------
  final TextEditingController height = TextEditingController();
  final TextEditingController weight = TextEditingController();
  final RxnString bodyType = RxnString();
  final RxnString complexion = RxnString();
  final RxnString bloodGroup = RxnString();
  final RxnString diet = RxnString();

  // ---- Career & income (step 10) ---------------------------------------------
  final RxnInt professionCategoryId = RxnInt();
  final RxnInt professionId = RxnInt();
  final TextEditingController jobTitle = TextEditingController();
  final TextEditingController organization = TextEditingController();
  final TextEditingController yearsOfExperience = TextEditingController();
  final RxnString employmentStatus = RxnString();

  /// Chosen income band; the band's lower bound is what gets posted.
  final Rxn<LookupItem> annualIncome = Rxn<LookupItem>();

  // ---- Family (steps 16-17) --------------------------------------------------
  final TextEditingController fatherOccupation = TextEditingController();
  final TextEditingController motherOccupation = TextEditingController();
  final Rxn<LookupItem> brothers = Rxn<LookupItem>();
  final Rxn<LookupItem> sisters = Rxn<LookupItem>();
  final TextEditingController familyLocation = TextEditingController();
  final TextEditingController familyValues = TextEditingController();

  // ---- Marriage expectations -------------------------------------------------
  final RxnString marriageTimeline = RxnString();

  /// `PUT /profile` validates these two as booleans, so the three-way
  /// "depends on mutual understanding" that registration allows cannot be sent
  /// here — the form offers Yes / No / unset only.
  final RxnBool willingToWorkAfterMarriage = RxnBool();
  final RxnBool expectsSpouseToWork = RxnBool();

  // ---- Privacy (PATCH /profile/privacy) --------------------------------------
  final RxBool hideProfile = false.obs;
  final RxBool showPhoto = false.obs;
  final RxBool showGallery = false.obs;
  final RxBool showContact = false.obs;
  final RxBool showEmail = false.obs;
  final RxBool showPhone = false.obs;
  final RxBool showLocation = false.obs;
  final RxBool allowProfileViewNotifications = false.obs;

  // ---- Preserved (not user-editable in this form) ---------------------------
  String? _videoIntroduction;
  String? _voiceIntroduction;
  int? _annualSalaryRangeId;

  /// Privacy as it was when the form opened, so only real changes are sent.
  PrivacySettingsModel _privacyAtOpen = const PrivacySettingsModel();
  bool _hideProfileAtOpen = false;

  @override
  void onInit() {
    super.onInit();
    lookup
      ..ensure(LookupKeys.genders)
      ..ensure(LookupKeys.maritalStatuses)
      ..ensure(LookupKeys.onBehalf)
      ..ensure(LookupKeys.languages)
      ..ensure(LookupKeys.religions)
      ..ensure(LookupKeys.sectMain)
      ..ensure(LookupKeys.schoolOfThought)
      ..ensure(LookupKeys.traditions)
      ..ensure(LookupKeys.castes)
      ..ensure(LookupKeys.countries)
      ..ensure(LookupKeys.educationLevels)
      ..ensure(LookupKeys.fieldsOfStudy)
      ..ensure(LookupKeys.institutions)
      ..ensure(LookupKeys.professionCategories)
      ..ensure(LookupKeys.educationStatus)
      ..ensure(LookupKeys.employmentStatus)
      ..ensure(LookupKeys.diet)
      ..ensure(LookupKeys.marriageTimeline)
      ..ensure(LookupKeys.annualIncome)
      ..ensure(LookupKeys.siblings);
    _seed();
  }

  void _seed() {
    final ProfileModel? p = _profile.profile;
    if (p == null) return;
    final ProfileUser u = p.user;
    final MemberDetails m = p.member;
    final ProfilePrivacy pr = p.privacy;

    firstName.text = u.firstName ?? '';
    lastName.text = u.lastName ?? '';
    email.text = u.email ?? '';
    phone.text = u.phone ?? '';
    aboutMe.text = m.aboutMe ?? '';
    children.text = (m.children ?? 0).toString();
    travel.text = m.travelPreferences ?? '';
    goals.text = m.futureGoals ?? '';

    dob.value = m.dateOfBirth;
    genderId.value = m.genderId;
    maritalId.value = m.maritalStatusId;
    onBehalfId.value = m.onBehalfId;
    motherTongueId.value = m.motherTongue;
    knownLanguageIds.assignAll(m.knownLanguages);

    // ---- Registration sections, straight off the profile payload ----
    final ProfileSection rel = p.religionAndLanguage;
    religionId.value = rel.integer('religion_id');
    sectMainId.value = rel.integer('sect_main_id');
    schoolOfThoughtId.value = rel.integer('school_of_thought_id');
    traditionId.value = rel.integer('tradition_id');

    casteId.value = p.caste.integer('caste_id');
    subCasteId.value = p.caste.integer('sub_caste_id');
    if (casteId.value != null) {
      lookup.ensure(LookupKeys.subCastes, parentId: casteId.value);
    }

    final ProfileSection loc = p.location;
    countryId.value = loc.integer('country_id');
    stateId.value = loc.integer('state_id');
    cityId.value = loc.integer('city_id');
    area.text = loc.string('area') ?? '';
    if (countryId.value != null) {
      lookup.ensure(LookupKeys.states, parentId: countryId.value);
    }
    if (stateId.value != null) {
      lookup.ensure(LookupKeys.cities, parentId: stateId.value);
    }

    final ProfileSection edu = p.education;
    educationLevelId.value = edu.integer('education_level_id');
    degreeId.value = edu.integer('degree_id');
    fieldOfStudyId.value = edu.integer('field_of_study_id');
    institutionId.value = edu.integer('institution_id');
    graduationYear.text = edu.integer('graduation_year')?.toString() ?? '';
    educationStatus.value = edu.string('education_status');
    if (educationLevelId.value != null) {
      lookup.ensure(LookupKeys.degrees, parentId: educationLevelId.value);
    }

    final ProfileSection phy = p.physical;
    height.text = phy.string('height') ?? '';
    weight.text = phy.string('weight') ?? '';
    bodyType.value = phy.string('body_type');
    complexion.value = phy.string('complexion');
    bloodGroup.value = phy.string('blood_group');
    diet.value = phy.string('diet');

    final ProfileSection car = p.career;
    professionCategoryId.value = car.integer('profession_category_id');
    professionId.value = car.integer('profession_id');
    jobTitle.text = car.string('job_title') ?? '';
    organization.text = car.string('organization') ?? '';
    yearsOfExperience.text = car.string('years_of_experience') ?? '';
    employmentStatus.value = car.string('employment_status');
    annualIncome.value = IncomeBand.forValue(car.number('annual_income'))?.item;
    if (professionCategoryId.value != null) {
      lookup.ensure(LookupKeys.professions, parentId: professionCategoryId.value);
    }

    final ProfileSection fam = p.family;
    fatherOccupation.text = fam.string('father_occupation') ?? '';
    motherOccupation.text = fam.string('mother_occupation') ?? '';
    brothers.value = _siblingItem(fam.integer('siblings_brothers'));
    sisters.value = _siblingItem(fam.integer('siblings_sisters'));
    familyLocation.text = fam.string('family_location') ?? '';
    familyValues.text = fam.string('family_values') ?? '';

    final ProfileSection marriage = p.marriageExpectations;
    marriageTimeline.value = marriage.string('marriage_timeline');
    willingToWorkAfterMarriage.value = car.boolean('willing_to_work_after_marriage');
    expectsSpouseToWork.value = car.boolean('expects_spouse_to_work');

    hideProfile.value = m.hideProfile;
    _hideProfileAtOpen = m.hideProfile;
    showPhoto.value = pr.showPhoto;
    showGallery.value = pr.showGallery;
    showContact.value = pr.showContact;
    showEmail.value = pr.showEmail;
    showPhone.value = pr.showPhone;
    showLocation.value = pr.showLocation;
    allowProfileViewNotifications.value = pr.allowProfileViewNotifications;
    _privacyAtOpen = _currentPrivacy();

    _videoIntroduction = m.videoIntroduction;
    _voiceIntroduction = m.voiceIntroduction;
    _annualSalaryRangeId = m.annualSalaryRangeId;
  }

  static LookupItem? _siblingItem(int? count) =>
      count == null ? null : LookupItem(id: count, name: SiblingOptions.labelFor(count));

  PrivacySettingsModel _currentPrivacy() => PrivacySettingsModel(
    showPhoto: showPhoto.value,
    showGallery: showGallery.value,
    showContact: showContact.value,
    showEmail: showEmail.value,
    showPhone: showPhone.value,
    showLocation: showLocation.value,
    allowProfileViewNotifications: allowProfileViewNotifications.value,
  );

  // ---- Dependent-dropdown handlers ------------------------------------------

  void onCaste(LookupItem? v) {
    casteId.value = v?.id;
    subCasteId.value = null;
    if (v != null) lookup.ensure(LookupKeys.subCastes, parentId: v.id);
  }

  void onCountry(LookupItem? v) {
    countryId.value = v?.id;
    stateId.value = null;
    cityId.value = null;
    if (v != null) lookup.ensure(LookupKeys.states, parentId: v.id);
  }

  void onState(LookupItem? v) {
    stateId.value = v?.id;
    cityId.value = null;
    if (v != null) lookup.ensure(LookupKeys.cities, parentId: v.id);
  }

  void onEducationLevel(LookupItem? v) {
    educationLevelId.value = v?.id;
    degreeId.value = null;
    if (v != null) lookup.ensure(LookupKeys.degrees, parentId: v.id);
  }

  void onProfessionCategory(LookupItem? v) {
    professionCategoryId.value = v?.id;
    professionId.value = null;
    if (v != null) lookup.ensure(LookupKeys.professions, parentId: v.id);
  }

  // ---- Lookup helpers -------------------------------------------------------

  /// Resolves an id into its lookup item (or a name-less placeholder that the
  /// pickers still match by id once the list finishes loading).
  LookupItem? itemFor(String key, int? id) {
    if (id == null) return null;
    for (final LookupItem i in lookup.itemsOf(key)) {
      if (i.id == id) return i;
    }
    return LookupItem(id: id, name: '');
  }

  /// Same as [itemFor] for the option lists whose API value is a string
  /// (`immediate`, `private`, `completed`, …) rather than a numeric id.
  LookupItem? optionFor(String key, String? code) {
    if (code == null || code.isEmpty) return null;
    for (final LookupItem i in lookup.itemsOf(key)) {
      if (i.code == code || '${i.apiValue}' == code) return i;
    }
    return LookupItem.option(code, code);
  }

  String labelFor(String key, int id) {
    for (final LookupItem i in lookup.itemsOf(key)) {
      if (i.id == id) return i.name;
    }
    return '#$id';
  }

  void addLanguage(int id) {
    if (!knownLanguageIds.contains(id)) knownLanguageIds.add(id);
  }

  void removeLanguage(int id) => knownLanguageIds.remove(id);

  // ---- Submit ---------------------------------------------------------------

  /// Only keys UpdateProfileRequest actually declares. Anything else would be
  /// dropped without a word, which is how "Profile for" and the privacy
  /// switches used to fail silently.
  Map<String, dynamic> _payload() {
    String? text(TextEditingController c) {
      final String v = c.text.trim();
      return v.isEmpty ? null : v;
    }

    return <String, dynamic>{
      'first_name': firstName.text.trim(),
      'last_name': lastName.text.trim(),
      'phone': text(phone),
      'gender': genderId.value?.toString(),
      'date_of_birth': dob.value == null ? null : _fmt.format(dob.value!),
      'about_me': aboutMe.text.trim(),
      'video_introduction': _videoIntroduction,
      'voice_introduction': _voiceIntroduction,
      'marital_status_id': maritalId.value,
      'children': int.tryParse(children.text.trim()) ?? 0,
      // The rule is `on_behalf`, NOT `on_behalf_id`.
      'on_behalf': onBehalfId.value,
      'annual_salary_range_id': _annualSalaryRangeId,
      'mother_tongue': motherTongueId.value,
      'known_languages': knownLanguageIds.toList(),
      'travel_preferences': text(travel),
      'future_goals': text(goals),
      'hide_profile': hideProfile.value,

      // Religion & language
      'religion_id': religionId.value,
      'sect_main_id': sectMainId.value,
      'school_of_thought_id': schoolOfThoughtId.value,
      'tradition_id': traditionId.value,

      // Caste
      'caste_id': casteId.value,
      'sub_caste_id': subCasteId.value,

      // Location
      'country_id': countryId.value,
      'state_id': stateId.value,
      'city_id': cityId.value,
      'area': text(area),

      // Education
      'education_level_id': educationLevelId.value,
      'degree_id': degreeId.value,
      'field_of_study_id': fieldOfStudyId.value,
      'institution_id': institutionId.value,
      'graduation_year': int.tryParse(graduationYear.text.trim()),
      'education_status': educationStatus.value,

      // Physical
      'height': double.tryParse(height.text.trim()),
      'weight': double.tryParse(weight.text.trim()),
      'body_type': bodyType.value,
      'complexion': complexion.value,
      'blood_group': bloodGroup.value,
      'diet': diet.value,

      // Career & income
      'profession_category_id': professionCategoryId.value,
      'profession_id': professionId.value,
      'job_title': text(jobTitle),
      'organization': text(organization),
      'years_of_experience': text(yearsOfExperience),
      'employment_status': employmentStatus.value,
      'annual_income': annualIncome.value?.id,

      // Family
      'father_occupation': text(fatherOccupation),
      'mother_occupation': text(motherOccupation),
      'siblings_brothers': brothers.value?.id,
      'siblings_sisters': sisters.value?.id,
      'family_location': text(familyLocation),
      'family_values': text(familyValues),

      // Marriage expectations
      'marriage_timeline': marriageTimeline.value,
      'willing_to_work_after_marriage': willingToWorkAfterMarriage.value,
      'expects_spouse_to_work': expectsSpouseToWork.value,
    };
  }

  Future<void> submit() async {
    if (busy.value) return;
    if (!(formKey.currentState?.validate() ?? true)) return;
    busy.value = true;
    try {
      final ProfileModel updated = await _repo.updateProfile(_payload());

      // Privacy lives on its own endpoint; send it only when something moved.
      final Map<String, dynamic> privacyChanges =
          _currentPrivacy().changesFrom(_privacyAtOpen);
      if (privacyChanges.isNotEmpty) {
        await _repo.updatePrivacy(privacyChanges);
      }

      // `hide_profile` goes through PUT /profile above, but re-reading keeps
      // the cached copy authoritative when privacy also changed.
      if (privacyChanges.isNotEmpty || hideProfile.value != _hideProfileAtOpen) {
        await _profile.load();
      } else {
        _profile.applyUpdated(updated);
      }

      AppSnackbar.success('Profile updated successfully.');
      Get.back<void>();
    } on ValidationException catch (e) {
      AppSnackbar.error(e.errors.values.isNotEmpty ? e.errors.values.first.first : e.message);
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
    } catch (_) {
      AppSnackbar.error('Something went wrong. Please try again.');
    } finally {
      busy.value = false;
    }
  }

  @override
  void onClose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    phone.dispose();
    aboutMe.dispose();
    children.dispose();
    travel.dispose();
    goals.dispose();
    area.dispose();
    graduationYear.dispose();
    height.dispose();
    weight.dispose();
    jobTitle.dispose();
    organization.dispose();
    yearsOfExperience.dispose();
    fatherOccupation.dispose();
    motherOccupation.dispose();
    familyLocation.dispose();
    familyValues.dispose();
    super.onClose();
  }
}
