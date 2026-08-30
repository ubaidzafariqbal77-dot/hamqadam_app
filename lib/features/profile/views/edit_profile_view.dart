import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_lookups.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/edit_profile_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../core/validators/app_validators.dart';
import '../../../models/lookup_item_model.dart';
import '../../../repositories/profile_repository.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_date_field.dart';
import '../../../widgets/app_picker_field.dart';
import '../../../widgets/app_switch_tile.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/form_field_container.dart';
import '../../../widgets/premium_app_bar.dart';

/// Full-screen Edit Profile form. Pushed from the Profile tab; submits
/// `PUT /profile` via [EditProfileController].
class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  late final EditProfileController c;

  @override
  void initState() {
    super.initState();
    c = Get.put(
      EditProfileController(
        Get.find<ProfileRepository>(),
        Get.find<ProfileController>(),
        Get.find(),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<EditProfileController>();
    super.dispose();
  }

  static String? _yesNo(bool? v) => v == null ? null : (v ? 'Yes' : 'No');
  static bool? _boolOf(String? v) => v == null ? null : v == 'Yes';

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    return Scaffold(
      appBar: const PremiumAppBar(title: 'Edit Profile', subtitle: 'Update your details'),
      body: Form(
        key: c.formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xxxl,
          ),
          children: <Widget>[
            _Section(
              icon: Icons.badge_outlined,
              title: 'Account',
              children: <Widget>[
                AppTextFormField(
                  label: 'First name',
                  controller: c.firstName,
                  textInputAction: TextInputAction.next,
                  validator: (String? v) => AppValidators.required(v, field: 'First name'),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  label: 'Last name',
                  controller: c.lastName,
                  textInputAction: TextInputAction.next,
                  validator: (String? v) => AppValidators.required(v, field: 'Last name'),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Read-only: `PUT /profile` declares no email rule, so a change
                // typed here was silently discarded. Changing the address needs
                // the verification flow (request code -> verify).
                AppTextFormField(
                  label: 'Email',
                  controller: c.email,
                  enabled: false,
                  requirement: FieldRequirement.optional,
                ),
                const SizedBox(height: 4),
                Text(
                  'Email changes go through verification — contact support.',
                  style: AppTextStyles.caption.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  label: 'Phone',
                  controller: c.phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'Gender',
                    lookupKey: LookupKeys.genders,
                    controller: c.lookup,
                    selected: c.itemFor(LookupKeys.genders, c.genderId.value),
                    onChanged: (LookupItem? v) => c.genderId.value = v?.id,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppDateField(
                    label: 'Date of birth',
                    value: c.dob.value,
                    firstDate: DateTime(now.year - 90),
                    lastDate: DateTime(now.year - 18, now.month, now.day),
                    onChanged: (DateTime d) => c.dob.value = d,
                  ),
                ),
              ],
            ),
            _Section(
              icon: Icons.person_outline_rounded,
              title: 'About me',
              children: <Widget>[
                AppTextFormField(
                  label: 'About me',
                  controller: c.aboutMe,
                  requirement: FieldRequirement.optional,
                  hint: 'Tell us a little about yourself',
                  maxLines: 4,
                  minLines: 3,
                  maxLength: 500,
                ),
              ],
            ),
            _Section(
              icon: Icons.info_outline_rounded,
              title: 'Personal details',
              children: <Widget>[
                Obx(
                  () => AppLookupPicker(
                    label: 'Marital status',
                    lookupKey: LookupKeys.maritalStatuses,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(LookupKeys.maritalStatuses, c.maritalId.value),
                    onChanged: (LookupItem? v) => c.maritalId.value = v?.id,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'Profile for',
                    lookupKey: LookupKeys.onBehalf,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(LookupKeys.onBehalf, c.onBehalfId.value),
                    onChanged: (LookupItem? v) => c.onBehalfId.value = v?.id,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextFormField(
                  label: 'Number of children',
                  controller: c.children,
                  requirement: FieldRequirement.optional,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                  hint: '0',
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'Mother tongue',
                    lookupKey: LookupKeys.languages,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(LookupKeys.languages, c.motherTongueId.value),
                    onChanged: (LookupItem? v) => c.motherTongueId.value = v?.id,
                  ),
                ),
              ],
            ),
            _Section(
              icon: Icons.language_rounded,
              title: 'Known languages',
              children: <Widget>[
                Obx(
                  () => c.knownLanguageIds.isEmpty
                      ? Text(
                          'No languages added yet.',
                          style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: c.knownLanguageIds
                              .map((int id) => _LangChip(
                                    label: c.labelFor(LookupKeys.languages, id),
                                    onRemove: () => c.removeLanguage(id),
                                  ))
                              .toList(),
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppLookupPicker(
                  label: 'Add a language',
                  lookupKey: LookupKeys.languages,
                  controller: c.lookup,
                  requirement: FieldRequirement.optional,
                  hint: 'Select to add',
                  selected: null,
                  onChanged: (LookupItem? v) {
                    if (v != null) c.addLanguage(v.id);
                  },
                ),
              ],
            ),
            _Section(
              icon: Icons.explore_outlined,
              title: 'Lifestyle & goals',
              children: <Widget>[
                AppTextFormField(
                  label: 'Travel preferences',
                  controller: c.travel,
                  requirement: FieldRequirement.optional,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 300,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  label: 'Future goals',
                  controller: c.goals,
                  requirement: FieldRequirement.optional,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 300,
                ),
              ],
            ),
            _Section(
              icon: Icons.mosque_rounded,
              title: 'Religion & language',
              children: <Widget>[
                Obx(
                  () => AppLookupPicker(
                    label: 'Religion',
                    lookupKey: LookupKeys.religions,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(LookupKeys.religions, c.religionId.value),
                    onChanged: (LookupItem? v) => c.religionId.value = v?.id,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'Sect',
                    lookupKey: LookupKeys.sectMain,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(LookupKeys.sectMain, c.sectMainId.value),
                    onChanged: (LookupItem? v) => c.sectMainId.value = v?.id,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'School of thought',
                    lookupKey: LookupKeys.schoolOfThought,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(
                      LookupKeys.schoolOfThought,
                      c.schoolOfThoughtId.value,
                    ),
                    onChanged: (LookupItem? v) => c.schoolOfThoughtId.value = v?.id,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'Tradition',
                    lookupKey: LookupKeys.traditions,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(LookupKeys.traditions, c.traditionId.value),
                    onChanged: (LookupItem? v) => c.traditionId.value = v?.id,
                  ),
                ),
              ],
            ),
            _Section(
              icon: Icons.diversity_3_rounded,
              title: 'Caste & community',
              children: <Widget>[
                Obx(
                  () => AppLookupPicker(
                    label: 'Caste',
                    lookupKey: LookupKeys.castes,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(LookupKeys.castes, c.casteId.value),
                    onChanged: c.onCaste,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'Sub-caste',
                    lookupKey: LookupKeys.subCastes,
                    controller: c.lookup,
                    parentId: c.casteId.value,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(LookupKeys.subCastes, c.subCasteId.value),
                    onChanged: (LookupItem? v) => c.subCasteId.value = v?.id,
                  ),
                ),
              ],
            ),
            _Section(
              icon: Icons.place_rounded,
              title: 'Location',
              children: <Widget>[
                Obx(
                  () => AppLookupPicker(
                    label: 'Country',
                    lookupKey: LookupKeys.countries,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(LookupKeys.countries, c.countryId.value),
                    onChanged: c.onCountry,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'State / Province',
                    lookupKey: LookupKeys.states,
                    controller: c.lookup,
                    parentId: c.countryId.value,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(LookupKeys.states, c.stateId.value),
                    onChanged: c.onState,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'City',
                    lookupKey: LookupKeys.cities,
                    controller: c.lookup,
                    parentId: c.stateId.value,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(LookupKeys.cities, c.cityId.value),
                    onChanged: (LookupItem? v) => c.cityId.value = v?.id,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  label: 'Area',
                  controller: c.area,
                  requirement: FieldRequirement.optional,
                  hint: 'Neighbourhood or town',
                ),
              ],
            ),
            _Section(
              icon: Icons.school_rounded,
              title: 'Education',
              children: <Widget>[
                Obx(
                  () => AppLookupPicker(
                    label: 'Education level',
                    lookupKey: LookupKeys.educationLevels,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(
                      LookupKeys.educationLevels,
                      c.educationLevelId.value,
                    ),
                    onChanged: c.onEducationLevel,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'Degree',
                    lookupKey: LookupKeys.degrees,
                    controller: c.lookup,
                    parentId: c.educationLevelId.value,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(LookupKeys.degrees, c.degreeId.value),
                    onChanged: (LookupItem? v) => c.degreeId.value = v?.id,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'Field of study',
                    lookupKey: LookupKeys.fieldsOfStudy,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(
                      LookupKeys.fieldsOfStudy,
                      c.fieldOfStudyId.value,
                    ),
                    onChanged: (LookupItem? v) => c.fieldOfStudyId.value = v?.id,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'Institution',
                    lookupKey: LookupKeys.institutions,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(
                      LookupKeys.institutions,
                      c.institutionId.value,
                    ),
                    onChanged: (LookupItem? v) => c.institutionId.value = v?.id,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'Education status',
                    lookupKey: LookupKeys.educationStatus,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.optionFor(
                      LookupKeys.educationStatus,
                      c.educationStatus.value,
                    ),
                    onChanged: (LookupItem? v) =>
                        c.educationStatus.value = v?.code,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  label: 'Graduation year',
                  controller: c.graduationYear,
                  requirement: FieldRequirement.optional,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  hint: 'e.g. 2020',
                ),
              ],
            ),
            _Section(
              icon: Icons.accessibility_new_rounded,
              title: 'Physical',
              children: <Widget>[
                AppTextFormField(
                  label: 'Height (feet.inches)',
                  controller: c.height,
                  requirement: FieldRequirement.optional,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  hint: "e.g. 5.6 for 5'6\"",
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  label: 'Weight (kg)',
                  controller: c.weight,
                  requirement: FieldRequirement.optional,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppStringPicker(
                    label: 'Body type',
                    value: c.bodyType.value,
                    options: FieldOptions.bodyType,
                    requirement: FieldRequirement.optional,
                    onChanged: (String? v) => c.bodyType.value = v,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppStringPicker(
                    label: 'Complexion',
                    value: c.complexion.value,
                    options: FieldOptions.complexion,
                    requirement: FieldRequirement.optional,
                    onChanged: (String? v) => c.complexion.value = v,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppStringPicker(
                    label: 'Blood group',
                    value: c.bloodGroup.value,
                    options: const <String>[
                      'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
                    ],
                    requirement: FieldRequirement.optional,
                    onChanged: (String? v) => c.bloodGroup.value = v,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'Diet',
                    lookupKey: LookupKeys.diet,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.optionFor(LookupKeys.diet, c.diet.value),
                    onChanged: (LookupItem? v) => c.diet.value = v?.code,
                  ),
                ),
              ],
            ),
            _Section(
              icon: Icons.work_outline_rounded,
              title: 'Career & income',
              children: <Widget>[
                Obx(
                  () => AppLookupPicker(
                    label: 'Annual income (PKR)',
                    lookupKey: LookupKeys.annualIncome,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.annualIncome.value,
                    onChanged: (LookupItem? v) => c.annualIncome.value = v,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'Employment status',
                    lookupKey: LookupKeys.employmentStatus,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.optionFor(
                      LookupKeys.employmentStatus,
                      c.employmentStatus.value,
                    ),
                    onChanged: (LookupItem? v) =>
                        c.employmentStatus.value = v?.code,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'Profession category',
                    lookupKey: LookupKeys.professionCategories,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(
                      LookupKeys.professionCategories,
                      c.professionCategoryId.value,
                    ),
                    onChanged: c.onProfessionCategory,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'Profession',
                    lookupKey: LookupKeys.professions,
                    controller: c.lookup,
                    parentId: c.professionCategoryId.value,
                    requirement: FieldRequirement.optional,
                    selected: c.itemFor(
                      LookupKeys.professions,
                      c.professionId.value,
                    ),
                    onChanged: (LookupItem? v) => c.professionId.value = v?.id,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  label: 'Job title',
                  controller: c.jobTitle,
                  requirement: FieldRequirement.optional,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  label: 'Organization',
                  controller: c.organization,
                  requirement: FieldRequirement.optional,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  label: 'Years of experience',
                  controller: c.yearsOfExperience,
                  requirement: FieldRequirement.optional,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ],
            ),
            _Section(
              icon: Icons.family_restroom_rounded,
              title: 'Family',
              children: <Widget>[
                AppTextFormField(
                  label: "Father's occupation",
                  controller: c.fatherOccupation,
                  requirement: FieldRequirement.optional,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  label: "Mother's occupation",
                  controller: c.motherOccupation,
                  requirement: FieldRequirement.optional,
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'Number of brothers',
                    lookupKey: LookupKeys.siblings,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.brothers.value,
                    onChanged: (LookupItem? v) => c.brothers.value = v,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupPicker(
                    label: 'Number of sisters',
                    lookupKey: LookupKeys.siblings,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.sisters.value,
                    onChanged: (LookupItem? v) => c.sisters.value = v,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  label: 'Family location',
                  controller: c.familyLocation,
                  requirement: FieldRequirement.optional,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  label: 'Family values',
                  controller: c.familyValues,
                  requirement: FieldRequirement.optional,
                ),
              ],
            ),
            _Section(
              icon: Icons.favorite_outline_rounded,
              title: 'Marriage plans',
              children: <Widget>[
                Obx(
                  () => AppLookupPicker(
                    label: 'Marriage timeline',
                    lookupKey: LookupKeys.marriageTimeline,
                    controller: c.lookup,
                    requirement: FieldRequirement.optional,
                    selected: c.optionFor(
                      LookupKeys.marriageTimeline,
                      c.marriageTimeline.value,
                    ),
                    onChanged: (LookupItem? v) =>
                        c.marriageTimeline.value = v?.code,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // `PUT /profile` validates these as booleans, so the three-way
                // "depends on mutual understanding" from signup is not offered.
                Obx(
                  () => AppStringPicker(
                    label: 'Willing to work after marriage',
                    value: _yesNo(c.willingToWorkAfterMarriage.value),
                    options: const <String>['Yes', 'No'],
                    requirement: FieldRequirement.optional,
                    onChanged: (String? v) =>
                        c.willingToWorkAfterMarriage.value = _boolOf(v),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppStringPicker(
                    label: 'Expects spouse to work',
                    value: _yesNo(c.expectsSpouseToWork.value),
                    options: const <String>['Yes', 'No'],
                    requirement: FieldRequirement.optional,
                    onChanged: (String? v) => c.expectsSpouseToWork.value = _boolOf(v),
                  ),
                ),
              ],
            ),
            _Section(
              icon: Icons.lock_outline_rounded,
              title: 'Privacy & visibility',
              children: <Widget>[
                Obx(() => AppSwitchTile(
                      title: 'Hide my profile',
                      subtitle: 'Temporarily hide your profile from search',
                      icon: Icons.visibility_off_rounded,
                      value: c.hideProfile.value,
                      onChanged: (bool v) => c.hideProfile.value = v,
                    )),
                Obx(() => AppSwitchTile(
                      title: 'Show photo',
                      icon: Icons.photo_camera_front_rounded,
                      value: c.showPhoto.value,
                      onChanged: (bool v) => c.showPhoto.value = v,
                    )),
                Obx(() => AppSwitchTile(
                      title: 'Show gallery',
                      icon: Icons.collections_rounded,
                      value: c.showGallery.value,
                      onChanged: (bool v) => c.showGallery.value = v,
                    )),
                Obx(() => AppSwitchTile(
                      title: 'Show contact',
                      icon: Icons.contact_page_rounded,
                      value: c.showContact.value,
                      onChanged: (bool v) => c.showContact.value = v,
                    )),
                Obx(() => AppSwitchTile(
                      title: 'Show email',
                      icon: Icons.email_rounded,
                      value: c.showEmail.value,
                      onChanged: (bool v) => c.showEmail.value = v,
                    )),
                Obx(() => AppSwitchTile(
                      title: 'Show phone',
                      icon: Icons.phone_rounded,
                      value: c.showPhone.value,
                      onChanged: (bool v) => c.showPhone.value = v,
                    )),
                Obx(() => AppSwitchTile(
                      title: 'Show location',
                      icon: Icons.location_on_rounded,
                      value: c.showLocation.value,
                      onChanged: (bool v) => c.showLocation.value = v,
                    )),
                Obx(() => AppSwitchTile(
                      title: 'Profile-view notifications',
                      subtitle: 'Get notified when someone views your profile',
                      icon: Icons.notifications_active_rounded,
                      value: c.allowProfileViewNotifications.value,
                      onChanged: (bool v) => c.allowProfileViewNotifications.value = v,
                    )),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
        child: Obx(
          () => AppButton(
            label: 'Save changes',
            icon: Icons.check_rounded,
            loading: c.busy.value,
            onPressed: c.submit,
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.children});
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.primary.withValues(alpha: dark ? 0.18 : 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: AppDimensions.iconMd, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(title, style: AppTextStyles.subtitle),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: const Icon(Icons.close_rounded, size: 15, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
