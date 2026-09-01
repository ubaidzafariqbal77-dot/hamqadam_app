import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/api_options.dart';
import '../constants/app_constants.dart';
import '../constants/registration_sections.dart';
import '../core/api/api_client.dart';
import '../core/routes/app_routes.dart';
import '../core/storage/profile_completion_service.dart';
import '../core/storage/registration_buffer.dart';
import '../core/utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';
import '../models/auth_response_model.dart';
import '../models/registration_status_model.dart';
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

  /// The backend step this screen posts to.
  int get apiStep => RegSteps.apiStep(number);
}

/// Orchestrates the documented 18-step registration journey.
///
/// The backend no longer stores registration step by step. Every screen writes
/// its answers to the local [RegistrationBuffer] and the flow advances without
/// touching the network; once the last step is done, the whole payload goes out
/// in a single `POST /auth/register/complete`, which returns the Sanctum token.
/// The account is then verified with an emailed OTP
/// (`request-otp` → `verify-otp`) before the user reaches the app.
///
/// Because the draft lives on the device, going back, closing the app and
/// resuming later never loses an answer — but it also means nothing is stored
/// server-side until the final submission.
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

  /// Error from the last step submission, surfaced on the step screen.
  final RxString stepError = ''.obs;

  /// Field-level validation errors returned by the backend (`errors` node).
  final RxMap<String, String> fieldErrors = <String, String>{}.obs;

  /// Server-authoritative progress from `GET /auth/register/status`.
  final Rxn<RegistrationStatusModel> status = Rxn<RegistrationStatusModel>();

  /// The section currently being edited from "Complete your profile" (null
  /// during the normal signup flow).
  final RxnInt editingStep = RxnInt();

  /// Error surfaced while saving a single section.
  final RxString sectionError = ''.obs;

  /// True when the last failure already put itself in front of the user (the
  /// duplicate email/phone dialog). Callers use it to avoid stacking a snackbar
  /// on top of a dialog that says the same thing.
  bool errorSurfaced = false;

  bool get isEditingSection => editingStep.value != null;

  /// The step opened from the FINALIZING screen to correct a field the backend
  /// rejected.
  ///
  /// Deliberately separate from [editingStep]: that one re-saves a section
  /// after signup and posts it to the server. Here the account does not exist
  /// yet — the whole payload was refused — so the correction is written to the
  /// buffer and the flow returns to finalizing to retry the submission. Without
  /// this mode, tapping a rejected field dropped the user back into the normal
  /// forward flow and made them walk every remaining step again.
  final RxnInt fixingStep = RxnInt();

  bool get isFixingForFinalize => fixingStep.value != null;

  int get totalSteps => AppConstants.totalRegistrationSteps;

  /// Kept for the screens that still read the old name.
  RxString get accountError => stepError;

  @override
  void onInit() {
    super.onInit();
    // Warm the dropdown reference data so no lookup shows a spinner. Before
    // step 1 there is no token, so this may fall back to the bundled lists and
    // is refreshed as soon as step 1 returns the token.
    preloadLookups();
  }

  /// Fetches `GET /profile/dropdown-reference-data` and warms the common lists.
  void preloadLookups({bool force = false}) {
    if (!Get.isRegistered<LookupController>()) return;
    Get.find<LookupController>().preloadReference(force: force);
  }

  /// Completion is driven by steps actually finished with data — skipped steps
  /// do not count, so skipping never raises the percentage.
  double get completedFraction =>
      (buffer.completedSteps.length / totalSteps).clamp(0.0, 1.0);

  int get completionPercent {
    final int? server = status.value?.completionPercentage;
    if (server != null && server > 0) return server;
    return (completedFraction * 100).round();
  }

  /// Progress shown in the step header: signup progress while registering, and
  /// the profile-completion percentage while editing one section afterwards.
  double get progressFraction => isEditingSection ? completion.fraction : completedFraction;

  int get progressPercent => isEditingSection ? completion.percent : completionPercent;

  StepMeta metaFor(int step) => steps[step - 1];
  StepMeta get currentMeta => metaFor(currentStep.value);

  /// Whether [step] may be skipped (the three optional API steps).
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

  // ---- Local step progression ------------------------------------------------

  /// Called by a step once its fields are validated and written to the buffer.
  /// Nothing is sent to the backend here — the answers are kept locally and the
  /// flow simply advances. The last step opens the finalizing screen, which
  /// performs the one and only submission.
  Future<bool> completeStep(int step) async {
    stepError.value = '';
    fieldErrors.clear();

    buffer.lastStep = step < totalSteps ? step + 1 : totalSteps;
    buffer.markCompleted(step);

    if (step >= totalSteps) {
      Get.toNamed(AppRoutes.finalizing);
      return true;
    }
    _goForward(step + 1);
    return true;
  }

  /// Posts a single UI step to the deprecated step endpoint. Only used when one
  /// section is re-saved after signup ([saveSection]). Sets [stepError] and
  /// [fieldErrors] on failure.
  Future<bool> submitStep(int step) async {
    stepError.value = '';
    fieldErrors.clear();
    errorSurfaced = false;
    try {
      final ApiEnvelope res = await _postStep(step);
      if (!res.success) {
        stepError.value = res.message.isEmpty
            ? 'Could not save this step. Please try again.'
            : res.message;
        return false;
      }
      buffer.markSubmitted(step);
      _refreshStatusInBackground();
      return true;
    } on ValidationException catch (e) {
      _applyValidationErrors(e);
      return false;
    } on AppException catch (e) {
      stepError.value = e.message;
      return false;
    } catch (e) {
      AppLogger.w('Registration step $step failed: $e');
      stepError.value = 'Something went wrong. Please try again.';
      return false;
    }
  }

  Future<ApiEnvelope> _postStep(int step) {
    final int apiStep = RegSteps.apiStep(step);
    final MultipartPayload? multipart = RegPayload.multipartForUiStep(step, buffer);
    if (multipart != null) {
      return registrationRepository.submitStepMultipart(
        apiStep,
        fields: multipart.fields,
        files: multipart.files,
        arrayFiles: multipart.arrayFiles,
      );
    }
    return registrationRepository.submitStep(apiStep, RegPayload.forUiStep(step, buffer));
  }

  // ---- The single submission + email OTP ------------------------------------

  /// Bytes uploaded / total for the one big multipart request, so the
  /// finalizing screen can show real progress instead of a spinner.
  final RxDouble uploadProgress = 0.0.obs;

  /// Mandatory steps the user has not filled in. The backend validates the
  /// whole payload at once, so an incomplete draft is caught here first and the
  /// user is sent back to the offending screen instead of reading a wall of
  /// field errors.
  List<int> get missingMandatorySteps => RegSections.mandatory
      .where((int s) => !buffer.completedSteps.contains(s))
      .toList()
    ..sort();

  /// Submits every buffered answer in one `POST /auth/register/complete` and
  /// stores the returned session. Returns false with [stepError] set on failure.
  Future<bool> submitRegistration() async {
    stepError.value = '';
    fieldErrors.clear();
    errorSurfaced = false;
    uploadProgress.value = 0;
    try {
      final Map<String, dynamic> payload = await RegPayload.complete(buffer);
      final ApiEnvelope res = await registrationRepository.submitComplete(
        payload,
        onProgress: (int sent, int total) {
          if (total > 0) uploadProgress.value = (sent / total).clamp(0.0, 1.0);
        },
      );
      if (!res.success) {
        stepError.value = res.message.isEmpty
            ? 'Could not submit your registration. Please try again.'
            : res.message;
        return false;
      }
      await _onRegistrationAccepted(res);
      return true;
    } on ValidationException catch (e) {
      _applyValidationErrors(e);
      return false;
    } on AppException catch (e) {
      stepError.value = e.message;
      return false;
    } catch (e) {
      AppLogger.w('Complete registration failed: $e');
      stepError.value = 'Something went wrong. Please try again.';
      return false;
    }
  }

  /// The complete-registration response carries the Sanctum token the OTP calls
  /// need, plus the server's view of which steps were recorded.
  Future<void> _onRegistrationAccepted(ApiEnvelope res) async {
    final AuthResponseModel auth = AuthResponseModel.fromJson(res.dataMap);
    if (auth.hasToken) {
      // persistSession also refetches the dropdown lists, which are only
      // reachable once a token exists.
      await authController.persistSession(auth);
      buffer.accountCreated = true;
    } else {
      AppLogger.w('register/complete succeeded without a token — OTP calls will 401.');
    }
    buffer.awaitingEmailOtp = true;
    _readRegistrationNode(res.dataMap['registration']);
  }

  /// Email the verification code. Returns the API message, or throws.
  /// [email] overrides the buffered address (used when the user switches to a
  /// different one on the verification screen).
  Future<String> requestEmailOtp({String? email}) async {
    final ApiEnvelope res = await registrationRepository.requestRegistrationOtp(
      email: (email == null || email.isEmpty) ? registrationEmail : email,
    );
    if (!res.success) {
      throw ApiException(res.message.isEmpty ? 'Could not send the code.' : res.message);
    }
    return res.message;
  }

  /// Confirm the emailed code. On success the account is verified and the
  /// signup flow ends.
  Future<String> verifyEmailOtp(String code, {String? email}) async {
    final ApiEnvelope res = await registrationRepository.verifyRegistrationOtp(
      code: code,
      email: (email == null || email.isEmpty) ? registrationEmail : email,
    );
    if (!res.success) {
      throw ApiException(res.message.isEmpty ? 'That code is not valid.' : res.message);
    }
    buffer.awaitingEmailOtp = false;
    await authController.refreshUser();
    return res.message;
  }

  /// The address the OTP is sent to — the one captured on the contact step.
  String? get registrationEmail => buffer.getString('email')?.trim().toLowerCase();

  void _readRegistrationNode(dynamic node) {
    if (node is Map<String, dynamic>) {
      status.value = RegistrationStatusModel.fromJson(node);
    }
  }

  void _applyValidationErrors(ValidationException e) {
    e.errors.forEach((String field, List<String> messages) {
      if (messages.isNotEmpty) fieldErrors[field] = messages.first;
    });
    stepError.value = fieldErrors.values.isNotEmpty
        ? fieldErrors.values.first
        : (e.message.isEmpty ? 'Please check the highlighted fields.' : e.message);
    // Email/phone already registered → offer a shortcut back to the contact
    // step. A plain format error stays as an inline message.
    if (_isDuplicateContactError()) {
      errorSurfaced = true;
      _showDuplicateDialog();
    }
  }

  bool _isDuplicateContactError() {
    for (final String field in <String>['email', 'phone']) {
      final String? msg = fieldErrors[field]?.toLowerCase();
      if (msg == null) continue;
      if (msg.contains('taken') || msg.contains('already') || msg.contains('exists')) {
        return true;
      }
    }
    return false;
  }

  /// Skips an optional step (no data recorded, percentage unchanged).
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

  /// Moves one step back in the signup flow.
  ///
  /// This used to be an unconditional `Get.back()`, which broke as soon as the
  /// app was closed and reopened part-way through: [resume] lands the user on
  /// their current step with `Get.offAllNamed`, which leaves NOTHING on the
  /// navigation stack, so `Get.back()` had nothing to pop and the step became a
  /// dead end. Pop when there is something to pop, and otherwise navigate to the
  /// previous step directly — the answers live in the buffer either way, so the
  /// step rebuilds fully populated.
  void goToPreviousStep() {
    if (isEditingSection) {
      Get.back();
      return;
    }

    final int target = currentStep.value - 1;
    // Step 1 has no previous step, so "back" there means leaving signup
    // altogether. Without this the first screen was a dead end: the chevron and
    // the system back gesture both did nothing, and a user who tapped "Create
    // account" by mistake could not return to the login screen.
    if (target < 1) {
      exitToLogin();
      return;
    }

    currentStep.value = target;
    // Resume should return to where the user actually is, not to the furthest
    // step they once reached; otherwise closing the app after going back throws
    // them forward again.
    buffer.lastStep = target;

    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
    } else {
      Get.offNamed<void>(AppRoutes.routeForStep(target));
    }
  }

  /// Leaves the signup flow and returns to the login screen.
  ///
  /// Called when the user backs out of step 1. The buffered answers are KEPT —
  /// tapping "Create account" again runs [resetForNewAccount], so nothing is
  /// silently carried into a different signup, while a user who only wanted to
  /// glance at login can come straight back to a half-filled draft.
  void exitToLogin() {
    // Login is normally still on the stack (it pushed step 1), so popping keeps
    // its state. After a resume there is nothing to pop, hence the fallback.
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back<void>();
    } else {
      Get.offAllNamed(AppRoutes.login);
    }
  }

  // ---- Correcting a rejected field from the finalizing screen ---------------

  /// Opens [step] so the user can correct a rejected field, and returns to the
  /// finalizing screen when they are done.
  Future<void> openStepForFix(int step) async {
    if (step < 1 || step > totalSteps) return;
    final int? previous = fixingStep.value;
    fixingStep.value = step;
    currentStep.value = step;
    await Get.toNamed<dynamic>(AppRoutes.routeForStep(step));
    // Restore rather than blanking: a nested open would otherwise clear the
    // outer one on the way back.
    fixingStep.value = previous;
  }

  /// Accepts a corrected step: the answer is already in the buffer, so this
  /// only clears the errors that step owned and pops back to finalizing.
  bool completeFix(int step) {
    buffer.markCompleted(step);
    clearFieldErrorsForStep(step);
    Get.back<void>();
    return true;
  }

  /// Drops the field errors belonging to [step], so the finalizing list shrinks
  /// as each one is corrected.
  void clearFieldErrorsForStep(int step) {
    fieldErrors.removeWhere(
      (String field, _) => RegSteps.uiStepForField(field) == step,
    );
    stepError.value =
        fieldErrors.values.isNotEmpty ? fieldErrors.values.first : '';
  }

  // ---- Editing one section after signup -------------------------------------

  /// Opens a single registration step in edit mode so the user can fill in (or
  /// change) a section they skipped. Saving submits only that section.
  Future<void> openSection(int step) async {
    if (!RegSections.isProfileSection(step)) return;
    sectionError.value = '';
    editingStep.value = step;
    await Get.toNamed<dynamic>(AppRoutes.routeForStep(step));
    editingStep.value = null;
  }

  /// Submits one step's payload on its own and pops back to the caller.
  Future<bool> saveSection(int step) async {
    sectionError.value = '';
    final MultipartPayload? multipart = RegPayload.multipartForUiStep(step, buffer);
    final bool hasData = multipart != null
        ? !multipart.isEmpty
        : RegPayload.forUiStep(step, buffer).isNotEmpty;
    if (!hasData) {
      sectionError.value = 'Please fill in at least one field before saving.';
      return false;
    }

    final bool ok = await submitStep(step);
    if (!ok) {
      sectionError.value = stepError.value.isEmpty
          ? 'Could not save this section.'
          : stepError.value;
      return false;
    }

    buffer.markCompleted(step);
    completion.markDone(step);
    if (Get.isRegistered<ProfileController>()) {
      Get.find<ProfileController>().reload();
    }
    AppSnackbar.success('Saved — your profile is now ${completion.percent}% complete.');
    Get.back<void>();
    return true;
  }

  void _showDuplicateDialog() {
    final String msg = fieldErrors['email'] ??
        fieldErrors['phone'] ??
        (stepError.value.isEmpty
            ? 'This email or phone number is already registered.'
            : stepError.value);
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

  /// Jumps back to the Contact-information step (5) to fix a duplicate
  /// email/phone. Uses `offNamed` rather than popping to a route that may not
  /// be on the stack (the failure now surfaces from the finalizing screen).
  void goToContactStep() {
    currentStep.value = 5;
    Get.offNamed<void>(AppRoutes.contact);
  }

  // ---- Status / resume / finish ---------------------------------------------

  /// Pulls `GET /auth/register/status` without blocking the UI.
  void _refreshStatusInBackground() {
    if (!authController.hasToken) return;
    refreshStatus().catchError((_) => null);
  }

  Future<RegistrationStatusModel?> refreshStatus() async {
    try {
      final RegistrationStatusModel res = await registrationRepository.status();
      status.value = res;
      return res;
    } on AppException catch (e) {
      AppLogger.d('Registration status unavailable: $e');
      return null;
    }
  }

  /// Decides the entry screen on launch.
  ///
  /// Progress now lives on the device until the single submission, so the local
  /// buffer — not the server — decides where the user lands:
  /// verified account → home, submitted but unverified → the OTP screen,
  /// part-way through the steps → the furthest screen reached.
  Future<void> resume() async {
    if (buffer.registrationDone) {
      Get.offAllNamed(AppRoutes.home);
      return;
    }

    // Registered but the emailed code was never entered.
    if (buffer.awaitingEmailOtp && authController.hasToken) {
      Get.offAllNamed(AppRoutes.verifyEmail);
      return;
    }

    // A local draft that never reached the backend — pick the steps back up.
    if (buffer.hasDraftInProgress) {
      final int step = buffer.lastStep.clamp(1, totalSteps);
      currentStep.value = step;
      Get.offAllNamed(AppRoutes.routeForStep(step));
      return;
    }

    Get.offAllNamed(authController.hasToken ? AppRoutes.home : AppRoutes.login);
  }

  /// Ends the signup flow. The buffered answers are deliberately KEPT (minus the
  /// sensitive ones, which never touch disk) so a section opened later from
  /// "Complete your profile" still shows what the user entered.
  Future<void> finishRegistration({bool navigate = true}) async {
    completion.seedFromRegistration(buffer.completedSteps);
    buffer.registrationDone = true;
    buffer.awaitingEmailOtp = false;
    if (navigate) Get.offAllNamed(AppRoutes.registrationCompleted);
  }

  /// Wipes the buffered draft + completion record (new signup / logout).
  Future<void> resetForNewAccount() async {
    editingStep.value = null;
    fixingStep.value = null;
    currentStep.value = 1;
    stepError.value = '';
    fieldErrors.clear();
    status.value = null;
    await buffer.clear();
    await completion.clear();
    if (Get.isRegistered<LookupController>()) {
      final LookupController lookups = Get.find<LookupController>();
      lookups.resetAll();
      // Dropping the cache puts every list back to `initial`. A step already on
      // screen has run its own `ensure` and will not ask again, so the lists are
      // warmed right back up here instead of leaving its dropdowns empty.
      lookups.preloadReference();
    }
  }
}
