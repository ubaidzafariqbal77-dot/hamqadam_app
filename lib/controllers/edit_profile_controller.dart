import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../constants/app_lookups.dart';
import '../exceptions/app_exceptions.dart';
import '../models/lookup_item_model.dart';
import '../models/profile_model.dart';
import '../repositories/profile_repository.dart';
import '../widgets/app_snackbar.dart';
import 'lookup_controller.dart';
import 'profile_controller.dart';

/// Backs the Edit Profile form. Seeds itself from the currently-loaded
/// [ProfileModel], submits `PUT /profile`, and pushes the fresh copy back into
/// [ProfileController] on success. Created/disposed by [EditProfileView].
class EditProfileController extends GetxController {
  EditProfileController(this._repo, this._profile, this.lookup);

  final ProfileRepository _repo;
  final ProfileController _profile;
  final LookupController lookup;

  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final RxBool busy = false.obs;

  // ---- Text fields ----------------------------------------------------------
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController aboutMe = TextEditingController();
  final TextEditingController children = TextEditingController();
  final TextEditingController travel = TextEditingController();
  final TextEditingController goals = TextEditingController();

  // ---- Selections -----------------------------------------------------------
  final Rxn<DateTime> dob = Rxn<DateTime>();
  final RxnInt genderId = RxnInt();
  final RxnInt maritalId = RxnInt();
  final RxnInt onBehalfId = RxnInt();
  final RxnInt motherTongueId = RxnInt();
  final RxList<int> knownLanguageIds = <int>[].obs;

  // ---- Switches -------------------------------------------------------------
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

  @override
  void onInit() {
    super.onInit();
    lookup
      ..ensure(LookupKeys.genders)
      ..ensure(LookupKeys.maritalStatuses)
      ..ensure(LookupKeys.onBehalf)
      ..ensure(LookupKeys.languages);
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

    hideProfile.value = m.hideProfile;
    showPhoto.value = pr.showPhoto;
    showGallery.value = pr.showGallery;
    showContact.value = pr.showContact;
    showEmail.value = pr.showEmail;
    showPhone.value = pr.showPhone;
    showLocation.value = pr.showLocation;
    allowProfileViewNotifications.value = pr.allowProfileViewNotifications;

    _videoIntroduction = m.videoIntroduction;
    _voiceIntroduction = m.voiceIntroduction;
    _annualSalaryRangeId = m.annualSalaryRangeId;
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

  Map<String, dynamic> _payload() => <String, dynamic>{
        'first_name': firstName.text.trim(),
        'last_name': lastName.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'gender': genderId.value?.toString(),
        'date_of_birth': dob.value == null ? null : _fmt.format(dob.value!),
        'about_me': aboutMe.text.trim(),
        'video_introduction': _videoIntroduction,
        'voice_introduction': _voiceIntroduction,
        'marital_status_id': maritalId.value,
        'children': int.tryParse(children.text.trim()) ?? 0,
        'on_behalf_id': onBehalfId.value,
        'annual_salary_range_id': _annualSalaryRangeId,
        'mother_tongue': motherTongueId.value,
        'known_languages': knownLanguageIds.toList(),
        'travel_preferences': travel.text.trim(),
        'future_goals': goals.text.trim(),
        'hide_profile': hideProfile.value,
        'show_photo': showPhoto.value,
        'show_gallery': showGallery.value,
        'show_contact': showContact.value,
        'show_email': showEmail.value,
        'show_phone': showPhone.value,
        'show_location': showLocation.value,
        'allow_profile_view_notifications': allowProfileViewNotifications.value,
      };

  Future<void> submit() async {
    if (busy.value) return;
    if (!(formKey.currentState?.validate() ?? true)) return;
    busy.value = true;
    try {
      final ProfileModel updated = await _repo.updateProfile(_payload());
      _profile.applyUpdated(updated);
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
    super.onClose();
  }
}
