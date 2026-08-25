import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/storage/registration_buffer.dart';
import '../widgets/app_snackbar.dart';
import 'registration_controller.dart';

/// Base class for every registration step.
///
/// A step gathers its fields, writes them to the shared [RegistrationBuffer] and
/// hands control back to the [RegistrationController], which advances the flow
/// without touching the network — everything is submitted at once from the
/// finalizing screen (`POST /auth/register/complete`). The buffer keeps the
/// answers so back-navigation and resume never lose data.
///
/// The exception is [reg.saveSection], used when one section is re-opened
/// AFTER signup: that still posts just that section.
abstract class StepController extends GetxController {
  StepController(this.stepNumber);

  final int stepNumber;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final RxBool busy = false.obs;
  final RxString error = ''.obs;

  RegistrationController get reg => Get.find<RegistrationController>();
  RegistrationBuffer get buffer => Get.find<RegistrationBuffer>();

  /// Fields to merge into the buffer when the step is completed.
  Map<String, dynamic> collect();

  /// Prefill fields from the buffer (called on init so back/resume keeps data).
  void restore() {}

  /// Non-form validation (dropdowns, selections). Set [error] and return false
  /// to block progress.
  bool extraValidate() => true;

  void disposeFields() {}

  @override
  void onInit() {
    super.onInit();
    reg.currentStep.value = stepNumber;
    restore();
  }

  @override
  void onClose() {
    disposeFields();
    super.onClose();
  }

  /// Shown when the form itself is invalid. Flutter's [FormState] does not hand
  /// back the individual messages, and those are already under each field, so
  /// the snackbar only has to say where to look.
  static const String _formInvalid = 'Please fix the highlighted fields.';

  bool _validate() {
    error.value = '';
    final bool formOk = formKey.currentState?.validate() ?? true;
    final bool extraOk = extraValidate();
    if (formOk && extraOk) return true;
    // The inline banner sits at the top of the step, which is off-screen once
    // the user has scrolled down to the Continue button — so every failure is
    // also announced in a snackbar.
    if (!extraOk && error.value.isNotEmpty) {
      AppSnackbar.error(error.value);
    } else {
      if (error.value.isEmpty) error.value = _formInvalid;
      AppSnackbar.error(_formInvalid);
    }
    return false;
  }

  Future<void> submit() async {
    if (busy.value) return;
    if (!_validate()) return;
    busy.value = true;
    try {
      buffer.put(collect());

      // Three ways out of a step:
      //  * correcting a field the finalizing screen reported → buffer it and
      //    go straight back to finalizing, never onward through the flow;
      //  * editing a single section after signup → save just this step;
      //  * the normal flow → buffer it and advance.
      final bool fixing = reg.isFixingForFinalize;
      final bool editing = reg.isEditingSection;
      final bool ok = fixing
          ? reg.completeFix(stepNumber)
          : editing
              ? await reg.saveSection(stepNumber)
              : await reg.completeStep(stepNumber);
      if (ok) return;
      if (error.value.isEmpty) {
        error.value = editing ? reg.sectionError.value : reg.stepError.value;
      }
      // A rejected field can raise its own dialog (duplicate email/phone offers
      // a jump back to the contact step); a snackbar on top of that is noise.
      if (!reg.errorSurfaced) AppSnackbar.error(error.value);
    } finally {
      busy.value = false;
    }
  }

  Future<void> skip() async {
    if (busy.value) return;
    // Both "return to caller" modes leave without touching the flow position.
    if (reg.isEditingSection || reg.isFixingForFinalize) {
      Get.back<void>();
      return;
    }
    await reg.skipStep(stepNumber);
  }

  void back() {
    // Backing out of a correction returns to finalizing with the field still
    // unfixed, rather than stepping backwards through signup.
    if (reg.isFixingForFinalize) {
      Get.back<void>();
      return;
    }
    if (reg.isEditingSection || stepNumber > 1) reg.goToPreviousStep();
  }
}
