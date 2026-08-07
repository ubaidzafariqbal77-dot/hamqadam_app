import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/storage/registration_buffer.dart';
import 'registration_controller.dart';

/// Base class for every buffered registration step.
///
/// A step gathers its fields, writes them to the shared [RegistrationBuffer] and
/// hands control back to the [RegistrationController], which advances the flow
/// (and, at step 11, creates the account). No step except the finalize screen
/// talks to the network directly.
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

  bool _validate() {
    error.value = '';
    final bool formOk = formKey.currentState?.validate() ?? true;
    final bool extraOk = extraValidate();
    return formOk && extraOk;
  }

  Future<void> submit() async {
    if (busy.value) return;
    if (!_validate()) return;
    busy.value = true;
    try {
      buffer.put(collect());
      // Editing a single section after signup saves just this step; during the
      // flow the step is buffered and the registration advances.
      final bool editing = reg.isEditingSection;
      final bool ok = editing
          ? await reg.saveSection(stepNumber)
          : await reg.completeStep(stepNumber);
      if (!ok && error.value.isEmpty) {
        error.value = editing ? reg.sectionError.value : reg.accountError.value;
      }
    } finally {
      busy.value = false;
    }
  }

  Future<void> skip() async {
    if (busy.value) return;
    if (reg.isEditingSection) {
      Get.back<void>();
      return;
    }
    await reg.skipStep(stepNumber);
  }

  void back() {
    if (reg.isEditingSection || stepNumber > 1) reg.goToPreviousStep();
  }
}
