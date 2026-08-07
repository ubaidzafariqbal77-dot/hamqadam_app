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
                AppTextFormField(
                  label: 'Email',
                  controller: c.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (String? v) => AppValidators.email(v),
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
