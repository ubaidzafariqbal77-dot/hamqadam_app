import 'package:get/get.dart';

import '../constants/api_options.dart';
import '../core/routes/app_routes.dart';
import '../core/storage/registration_buffer.dart';
import '../exceptions/app_exceptions.dart';
import '../repositories/registration_repository.dart';
import 'registration_controller.dart';

/// One task shown on the finalizing screen.
class FinalizeStep {
  FinalizeStep(this.label, this.action);

  final String label;
  final Future<void> Function() action;

  /// 0 = pending, 1 = running, 2 = done, 3 = failed.
  final RxInt status = 0.obs;
  final RxString message = ''.obs;
}

/// Closes the signup flow.
///
/// Nothing was sent while the user walked the 18 steps, so this screen performs
/// the whole submission: it uploads the complete payload
/// (`POST /auth/register/complete`, one multipart request carrying the photos
/// and identity documents), then asks the backend to email the verification
/// code (`POST /auth/register/request-otp`) and hands over to the OTP screen.
///
/// Both tasks are retryable: a failed upload leaves every answer in the buffer,
/// so tapping retry re-sends exactly the same payload.
class FinalizingController extends GetxController {
  RegistrationRepository get repo => Get.find<RegistrationRepository>();
  RegistrationBuffer get buffer => Get.find<RegistrationBuffer>();
  RegistrationController get reg => Get.find<RegistrationController>();

  final RxList<FinalizeStep> steps = <FinalizeStep>[].obs;
  final RxBool running = false.obs;
  final RxBool finished = false.obs;

  /// Mandatory screens the user never filled in. Non-empty means the payload
  /// would be rejected, so the flow sends them back instead of submitting.
  final RxList<int> missing = <int>[].obs;

  bool get hasFailures => steps.any((FinalizeStep s) => s.status.value == 3);

  /// Upload progress of the multipart request (0..1).
  RxDouble get uploadProgress => reg.uploadProgress;

  @override
  void onInit() {
    super.onInit();
    missing.assignAll(reg.missingMandatorySteps);
    _build();
    if (missing.isEmpty) run();
  }

  void _build() {
    steps.assignAll(<FinalizeStep>[
      FinalizeStep('Creating your account', _submitRegistration),
      FinalizeStep('Sending your verification code', _requestOtp),
    ]);
  }

  Future<void> run() async {
    if (running.value || missing.isNotEmpty) return;
    running.value = true;
    finished.value = false;
    bool ok = true;
    for (final FinalizeStep s in steps) {
      if (s.status.value == 2) continue; // already succeeded (retry case)
      s.status.value = 1;
      try {
        await s.action();
        s.status.value = 2;
        s.message.value = '';
      } on AppException catch (e) {
        s.status.value = 3;
        s.message.value = e.message;
        ok = false;
        break; // the OTP request is pointless without an account
      } catch (e) {
        s.status.value = 3;
        s.message.value = 'Something went wrong.';
        ok = false;
        break;
      }
    }
    running.value = false;
    finished.value = true;
    if (ok && !hasFailures) _goToVerification();
  }

  /// Re-run a single task (used when the user taps a failed row to retry it).
  Future<void> runOne(FinalizeStep s) async {
    if (running.value || s.status.value == 1) return;
    s.status.value = 1;
    s.message.value = '';
    try {
      await s.action();
      s.status.value = 2;
    } on AppException catch (e) {
      s.status.value = 3;
      s.message.value = e.message;
    } catch (e) {
      s.status.value = 3;
      s.message.value = 'Something went wrong.';
    }
    if (!hasFailures && steps.every((FinalizeStep e) => e.status.value == 2)) {
      _goToVerification();
    }
  }

  /// The one and only registration request.
  Future<void> _submitRegistration() async {
    // An account created by an earlier attempt must not be created twice — the
    // email would already be taken.
    if (buffer.awaitingEmailOtp) return;
    final bool ok = await reg.submitRegistration();
    if (!ok) {
      throw ApiException(
        reg.stepError.value.isEmpty
            ? 'Could not submit your registration.'
            : reg.stepError.value,
      );
    }
  }

  Future<void> _requestOtp() => reg.requestEmailOtp();

  void _goToVerification() {
    Get.offNamed<void>(
      AppRoutes.verifyEmail,
      arguments: <String, dynamic>{'codeAlreadySent': true},
    );
  }

  /// Sends the user to the first mandatory screen they left empty, and brings
  /// them back here when it is filled in.
  Future<void> fixMissingStep() async {
    if (missing.isEmpty) return;
    await reg.openStepForFix(missing.first);
    await _afterFix();
  }

  /// Titles of the screens still missing data, for the on-screen message.
  List<String> get missingTitles => missing
      .map((int s) => RegistrationController.steps[s - 1].title)
      .toList();

  /// Field errors the backend returned for the whole payload, resolved back to
  /// the screen that owns each one so the user can jump straight there.
  List<RejectedField> get rejectedFields {
    final List<RejectedField> out = <RejectedField>[];
    reg.fieldErrors.forEach((String field, String message) {
      final int? step = RegSteps.uiStepForField(field);
      out.add(
        RejectedField(
          field: field,
          message: message,
          uiStep: step,
          stepTitle: step == null ? null : RegistrationController.steps[step - 1].title,
        ),
      );
    });
    out.sort((RejectedField a, RejectedField b) =>
        (a.uiStep ?? 99).compareTo(b.uiStep ?? 99));
    return out;
  }

  /// Opens the screen that owns a rejected field so the user can correct it,
  /// then returns here.
  ///
  /// This used to `Get.offNamed` the step, which replaced the finalizing screen
  /// and dropped the user back into the ordinary forward flow — so correcting
  /// one field meant walking every remaining step again instead of coming
  /// straight back to submit. [RegistrationController.openStepForFix] pushes
  /// the step over this screen and pops back to it.
  Future<void> goToRejected(RejectedField f) async {
    final int? step = f.uiStep;
    if (step == null) return;
    await reg.openStepForFix(step);
    await _afterFix();
  }

  /// Back on the finalizing screen after a correction.
  ///
  /// Recomputes what is still outstanding, and retries the submission by itself
  /// once nothing is — the user already said what they wanted by fixing the
  /// last field; making them hunt for a retry button as well is busywork.
  Future<void> _afterFix() async {
    missing.assignAll(reg.missingMandatorySteps);
    if (missing.isNotEmpty || rejectedFields.isNotEmpty) return;

    // Re-arm whatever failed so `run` picks it up again. A task that already
    // succeeded is left alone, so the account is never created twice.
    for (final FinalizeStep s in steps) {
      if (s.status.value == 3) {
        s.status.value = 0;
        s.message.value = '';
      }
    }
    await run();
  }
}

/// One field the backend rejected, tied to the screen that collected it.
class RejectedField {
  const RejectedField({
    required this.field,
    required this.message,
    this.uiStep,
    this.stepTitle,
  });

  /// The API's field name, e.g. `annual_income`.
  final String field;

  final String message;
  final int? uiStep;
  final String? stepTitle;

  /// Human name for [field] — `siblings_brothers` reads as "Siblings brothers",
  /// `religion_id` as "Religion". The server's message usually names the field
  /// too, but in its own wording; this is what the user saw on the form.
  String get label {
    String s = field.split('.').first.trim();
    if (s.endsWith('_id')) s = s.substring(0, s.length - 3);
    s = s.replaceAll('_', ' ').trim();
    if (s.isEmpty) return field;
    return s[0].toUpperCase() + s.substring(1);
  }
}
