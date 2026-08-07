import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_constants.dart';
import '../constants/app_lookups.dart';
import '../constants/registration_sections.dart';
import '../core/api/api_client.dart';
import '../core/routes/app_routes.dart';
import '../core/storage/profile_completion_service.dart';
import '../core/storage/registration_buffer.dart';
import '../core/validators/app_validators.dart';
import '../exceptions/app_exceptions.dart';
import '../models/auth_response_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/registration_repository.dart';
import '../widgets/app_snackbar.dart';
import 'auth_controller.dart';
import 'lookup_controller.dart';
import 'profile_controller.dart';
import 'registration_payload.dart';

/// Lightweight metadata for a single UI step.
class StepMeta {
  const StepMeta({
    required this.number,
    required this.title,
    required this.subtitle,
    this.optional = false,
  });

  final int number;
  final String title;
  final String subtitle;
  final bool optional;

  /// Whether the user may skip this step during signup and fill it in later.
  bool get skippable => RegSections.canSkip(number);
}

/// Orchestrates the 18-step registration journey.
///
/// Steps 1–11 buffer their fields locally (no network). Step 11 (Account
/// Security) creates the real account via `POST /auth/register` using the
/// buffered account fields and stores the token. Steps 12–18 keep buffering,
/// and the buffered profile is submitted to the backend step-endpoints on the
/// Finalizing screen.
class RegistrationController extends GetxController {
  RegistrationController({
    required this.buffer,
    required this.authRepository,
    required this.registrationRepository,
    required this.authController,
    required this.completion,
  });

  final RegistrationBuffer buffer;
  final AuthRepository authRepository;
  final RegistrationRepository registrationRepository;
  final AuthController authController;
  final ProfileCompletionService completion;

  final RxInt currentStep = 1.obs;

  /// Account-creation error surfaced on the Security step.
  final RxString accountError = ''.obs;
  final RxMap<String, String> accountFieldErrors = <String, String>{}.obs;

  /// The section currently being edited from "Complete your profile" (null
  /// during the normal signup flow).
  final RxnInt editingStep = RxnInt();

  /// Error surfaced while saving a single section.
  final RxString sectionError = ''.obs;

  bool get isEditingSection => editingStep.value != null;

  int get totalSteps => AppConstants.totalRegistrationSteps;

  @override
  void onInit() {
    super.onInit();
    // Warm the lookups the early steps need so no dropdown shows a spinner.
    preloadLookups();
  }

  /// Preloads (and caches) the parent-less lookups used across the flow.
  void preloadLookups() {
    if (!Get.isRegistered<LookupController>()) return;
    final LookupController lookup = Get.find<LookupController>();
    lookup.ensure(LookupKeys.religions);
    lookup.ensure(LookupKeys.languages);
    lookup.ensure(LookupKeys.countries);
  }

  /// Completion is driven by steps actually finished with data — skipped steps
  /// do not count, so skipping never raises the percentage.
  double get completedFraction =>
      (buffer.completedSteps.length / totalSteps).clamp(0.0, 1.0);

  int get completionPercent => (completedFraction * 100).round();

  /// Progress shown in the step header: signup progress while registering, and
  /// the profile-completion percentage while editing one section afterwards.
  double get progressFraction => isEditingSection ? completion.fraction : completedFraction;

  int get progressPercent => isEditingSection ? completion.percent : completionPercent;

  StepMeta metaFor(int step) => steps[step - 1];
  StepMeta get currentMeta => metaFor(currentStep.value);

  /// Whether [step] may be skipped (everything except the account steps).
  bool canSkip(int step) => RegSections.canSkip(step);

  static const List<StepMeta> steps = <StepMeta>[
    StepMeta(number: 1, title: 'Account for', subtitle: 'Who is this profile for?'),
    StepMeta(number: 2, title: 'Basic information', subtitle: 'Tell us the essentials'),
    StepMeta(number: 3, title: 'Religion & language', subtitle: 'Your faith and tongue'),
    StepMeta(number: 4, title: 'Location', subtitle: 'Where you live'),
    StepMeta(number: 5, title: 'Contact information', subtitle: 'How we reach you'),
    StepMeta(number: 6, title: 'Caste', subtitle: 'Your community'),
    StepMeta(number: 7, title: 'Marital status', subtitle: 'Your current status'),
    StepMeta(number: 8, title: 'Education', subtitle: 'Your qualifications'),
    StepMeta(number: 9, title: 'Physical information', subtitle: 'Height and diet'),
    StepMeta(number: 10, title: 'Career & income', subtitle: 'Your work life'),
    StepMeta(number: 11, title: 'Account security', subtitle: 'Set your password'),
    StepMeta(number: 12, title: 'Upload photos', subtitle: 'Show your best self'),
    StepMeta(number: 13, title: 'About yourself', subtitle: 'A few words about you'),
    StepMeta(number: 14, title: 'Identity verification', subtitle: 'Build trust'),
    StepMeta(number: 15, title: 'Interests & hobbies', subtitle: 'What you love', optional: true),
    StepMeta(number: 16, title: 'Family information', subtitle: 'About your family', optional: true),
    StepMeta(number: 17, title: 'Family details', subtitle: 'A little more', optional: true),
    StepMeta(number: 18, title: 'Partner preferences', subtitle: 'Your ideal match'),
  ];

  // ---- Navigation -----------------------------------------------------------

  /// Called by a step once its fields are validated and written to the buffer.
  /// Returns false only when account creation (step 11) fails, so the caller
  /// stays on the screen.
  Future<bool> completeStep(int step) async {
    buffer.lastStep = step < totalSteps ? step + 1 : totalSteps;

    if (step == 11 && !buffer.accountCreated) {
      final bool created = await _createAccount();
      if (!created) return false;
    }

    // Count this step as completed (raises the percentage). Idempotent.
    buffer.markCompleted(step);

    if (step >= totalSteps) {
      Get.toNamed(AppRoutes.finalizing);
      return true;
    }
    _goForward(step + 1);
    return true;
  }

  /// Skips a step (no data recorded, percentage unchanged). The step is
  /// remembered as skipped so the user can complete it later from their profile.
  Future<void> skipStep(int step) async {
    if (!canSkip(step)) return;
    buffer.lastStep = step < totalSteps ? step + 1 : totalSteps;
    buffer.unmarkCompleted(step); // ensure a skipped step never counts
    buffer.markSkipped(step);
    if (step >= totalSteps) {
      Get.toNamed(AppRoutes.finalizing);
      return;
    }
    _goForward(step + 1);
  }

  void _goForward(int step) {
    currentStep.value = step;
    Get.toNamed(AppRoutes.routeForStep(step));
  }

  void goToPreviousStep() {
    if (isEditingSection) {
      Get.back();
      return;
    }
    if (currentStep.value > 1) currentStep.value -= 1;
    Get.back();
  }

  // ---- Editing one section after signup -------------------------------------

  /// Opens a single registration step in edit mode so the user can fill in (or
  /// change) a section they skipped. Saving submits only that section.
  Future<void> openSection(int step) async {
    // Only profile sections are editable this way — name, contact and password
    // belong to the account and are changed from Edit Profile.
    if (!RegSections.isProfileSection(step)) return;
    sectionError.value = '';
    editingStep.value = step;
    await Get.toNamed<dynamic>(AppRoutes.routeForStep(step));
    editingStep.value = null;
  }

  /// Submits the buffered fields of a single step to the backend endpoints that
  /// step feeds, marks the section complete and pops back to the caller.
  /// Returns false (with [sectionError] set) when nothing could be saved.
  Future<bool> saveSection(int step) async {
    sectionError.value = '';
    try {
      if (step == 14) {
        if (!RegPayload.hasVerification(buffer)) {
          sectionError.value = 'Please capture the CNIC front, back and a selfie.';
          return false;
        }
        await _submitVerificationDocs();
      } else {
        bool sentSomething = false;
        for (final int endpoint in RegPayload.endpointsForStep(step)) {
          final Map<String, dynamic> payload = RegPayload.forEndpoint(endpoint, buffer);
          if (payload.isEmpty) continue;
          final ApiEnvelope res = await registrationRepository.submitStep(endpoint, payload);
          if (!res.success) {
            throw ApiException(
              res.message.isEmpty ? 'Could not save this section.' : res.message,
            );
          }
          sentSomething = true;
        }
        if (!sentSomething) {
          sectionError.value = 'Please fill in at least one field before saving.';
          return false;
        }
      }

      completion.markDone(step);
      if (Get.isRegistered<ProfileController>()) {
        Get.find<ProfileController>().reload();
      }
      AppSnackbar.success('Saved — your profile is now ${completion.percent}% complete.');
      Get.back<void>();
      return true;
    } on AppException catch (e) {
      sectionError.value = e.message;
      return false;
    } catch (_) {
      sectionError.value = 'Something went wrong. Please try again.';
      return false;
    }
  }

  Future<void> _submitVerificationDocs() async {
    final ApiEnvelope res = await registrationRepository.submitVerification(
      cnicNumber: buffer.getString('cnic_number') ?? '',
      cnicFrontPath: buffer.getString('cnic_front') ?? '',
      cnicBackPath: buffer.getString('cnic_back') ?? '',
      selfiePath: buffer.getString('selfie') ?? '',
    );
    if (!res.success) {
      throw ApiException(res.message.isEmpty ? 'Verification upload failed.' : res.message);
    }
  }

  // ---- Account creation (step 11) -------------------------------------------

  Map<String, dynamic> _accountBody() {
    final String phone = buffer.getString('phone') ?? '';
    return <String, dynamic>{
      'first_name': buffer.getString('first_name'),
      'last_name': buffer.getString('last_name'),
      'email': (buffer.getString('email') ?? '').toLowerCase(),
      'phone': AppValidators.normalizePakPhone(phone) ?? phone,
      'password': buffer.getString('password'),
      'password_confirmation': buffer.getString('password_confirmation'),
      'gender': buffer.getInt('gender')?.toString(),
      'date_of_birth': buffer.getString('date_of_birth'),
      'on_behalf': buffer.getInt('on_behalf'),
    };
  }

  Future<bool> _createAccount() async {
    accountError.value = '';
    accountFieldErrors.clear();
    try {
      final AuthResponseModel res = await authRepository.register(_accountBody());
      if (!res.hasToken) {
        accountError.value = 'Registration succeeded but no token was returned.';
        return false;
      }
      await authController.persistSession(res);
      buffer.accountCreated = true;
      // Drop the plaintext password from memory the moment it is no longer
      // needed (the account now exists).
      buffer.put(<String, dynamic>{'password': null, 'password_confirmation': null});
      return true;
    } on ValidationException catch (e) {
      e.errors.forEach((String field, List<String> messages) {
        if (messages.isNotEmpty) accountFieldErrors[field] = messages.first;
      });
      accountError.value = e.message;
      // Email/phone already registered → show a clear popup with a shortcut back
      // to the Contact step so the user can fix it.
      if (accountFieldErrors.containsKey('email') || accountFieldErrors.containsKey('phone')) {
        _showDuplicateDialog();
      }
      return false;
    } on AppException catch (e) {
      accountError.value = e.message;
      return false;
    }
  }

  void _showDuplicateDialog() {
    final String msg = accountFieldErrors['email'] ??
        accountFieldErrors['phone'] ??
        (accountError.value.isEmpty
            ? 'This email or phone number is already registered.'
            : accountError.value);
    Get.dialog<void>(
      AlertDialog(
        title: const Text('Account already exists'),
        content: Text(msg),
        actions: <Widget>[
          TextButton(onPressed: () => Get.back<void>(), child: const Text('Try again')),
          FilledButton(
            onPressed: () {
              Get.back<void>();
              goToContactStep();
            },
            child: const Text('Edit contact'),
          ),
        ],
      ),
    );
  }

  /// Jumps back to the Contact-information step (5) to fix a duplicate email/phone.
  void goToContactStep() {
    currentStep.value = 5;
    Get.until((Route<dynamic> route) => route.settings.name == AppRoutes.contact);
  }

  // ---- Resume / finish ------------------------------------------------------

  /// Decides the entry screen on launch when a token already exists.
  Future<void> resume() async {
    if (!buffer.registrationDone && buffer.accountCreated && !buffer.isEmpty) {
      final int step = buffer.lastStep.clamp(12, totalSteps);
      currentStep.value = step;
      Get.offAllNamed(AppRoutes.routeForStep(step));
      return;
    }
    Get.offAllNamed(AppRoutes.home);
  }

  /// Ends the signup flow. The buffered answers are deliberately KEPT (minus the
  /// sensitive ones, which never touch disk) so a section opened later from
  /// "Complete your profile" still shows what the user entered; the completion
  /// record remembers what was filled and what was skipped.
  Future<void> finishRegistration() async {
    completion.seedFromRegistration(buffer.completedSteps);
    buffer.registrationDone = true;
    Get.offAllNamed(AppRoutes.registrationCompleted);
  }

  /// Wipes the buffered draft + completion record (new signup / logout).
  Future<void> resetForNewAccount() async {
    editingStep.value = null;
    currentStep.value = 1;
    await buffer.clear();
    await completion.clear();
  }
}
