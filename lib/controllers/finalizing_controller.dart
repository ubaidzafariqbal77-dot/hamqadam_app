import 'package:get/get.dart';

import '../core/api/api_client.dart';
import '../core/storage/registration_buffer.dart';
import '../exceptions/app_exceptions.dart';
import '../repositories/registration_repository.dart';
import 'registration_controller.dart';
import 'registration_payload.dart';

/// One backend submission during finalization.
class FinalizeStep {
  FinalizeStep(this.label, this.action);

  final String label;
  final Future<void> Function() action;

  /// 0 = pending, 1 = running, 2 = done, 3 = failed.
  final RxInt status = 0.obs;
  final RxString message = ''.obs;
}

/// Submits the buffered profile to the backend step-endpoints once the account
/// has been created. Runs sequentially, is resilient to individual failures,
/// and lets the user retry the failed steps.
class FinalizingController extends GetxController {
  RegistrationRepository get repo => Get.find<RegistrationRepository>();
  RegistrationBuffer get buffer => Get.find<RegistrationBuffer>();
  RegistrationController get reg => Get.find<RegistrationController>();

  final RxList<FinalizeStep> steps = <FinalizeStep>[].obs;
  final RxBool running = false.obs;
  final RxBool finished = false.obs;

  bool get hasFailures => steps.any((FinalizeStep s) => s.status.value == 3);

  @override
  void onInit() {
    super.onInit();
    _build();
    run();
  }

  void _build() {
    final List<FinalizeStep> list = <FinalizeStep>[];

    void add(String label, int step, Map<String, dynamic> payload) {
      if (payload.isEmpty) return;
      list.add(FinalizeStep(label, () => _submit(step, payload)));
    }

    add('Basic profile', 2, RegPayload.basic(buffer));
    add('About you', 3, RegPayload.about(buffer));
    add('Religion & culture', 4, RegPayload.religion(buffer));
    add('Education & career', 5, RegPayload.education(buffer));
    add('Family details', 6, RegPayload.family(buffer));
    add('Marriage plans', 7, RegPayload.future(buffer));
    add('Lifestyle & interests', 8, RegPayload.lifestyle(buffer));
    add('Photos', 9, RegPayload.media(buffer));
    add('Partner preferences', 10, RegPayload.partner(buffer));

    if (RegPayload.hasVerification(buffer)) {
      list.add(FinalizeStep('Identity verification', _submitVerification));
    }

    steps.assignAll(list);
  }

  Future<void> run() async {
    if (running.value) return;
    running.value = true;
    finished.value = false;
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
      } catch (e) {
        s.status.value = 3;
        s.message.value = 'Something went wrong.';
      }
    }
    running.value = false;
    finished.value = true;
    if (!hasFailures) await reg.finishRegistration();
  }

  /// Re-run a single step (used when the user taps a failed row to retry it).
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
    if (!hasFailures) await reg.finishRegistration();
  }

  Future<void> _submit(int step, Map<String, dynamic> payload) async {
    final ApiEnvelope res = await repo.submitStep(step, payload);
    if (!res.success) {
      throw ApiException(res.message.isEmpty ? 'Could not save this step.' : res.message);
    }
  }

  Future<void> _submitVerification() async {
    final ApiEnvelope res = await repo.submitVerification(
      cnicNumber: buffer.getString('cnic_number') ?? '',
      cnicFrontPath: buffer.getString('cnic_front') ?? '',
      cnicBackPath: buffer.getString('cnic_back') ?? '',
      selfiePath: buffer.getString('selfie') ?? '',
    );
    if (!res.success) {
      throw ApiException(res.message.isEmpty ? 'Verification upload failed.' : res.message);
    }
  }

  /// Skip the remaining failed steps and enter the app (account already exists).
  Future<void> continueAnyway() => reg.finishRegistration();
}
