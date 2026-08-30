import 'package:get/get.dart';

import '../constants/feature_access.dart';
import '../core/api/api_response.dart';
import '../exceptions/app_exceptions.dart';
import '../models/verification_model.dart';
import '../repositories/verification_repository.dart';

/// Document identity verification: what was submitted, where each part stands,
/// and whether the member may submit again.
///
/// Drives the verification card and the feature gate. Kept apart from
/// [AiVerificationController] on purpose — the AI pre-screen runs itself and
/// only advises; this is the human decision that actually verifies an account.
class VerificationController extends GetxController {
  VerificationController(this._repo);

  final VerificationRepository _repo;

  final Rx<ApiState<VerificationModel>> state =
      const ApiState<VerificationModel>.initial().obs;

  /// Past requests, loaded on demand by the details screen.
  final RxList<VerificationModel> history = <VerificationModel>[].obs;

  final RxBool submitting = false.obs;
  final RxnString actionError = RxnString();

  /// Upload progress for [submit], 0..1. Null while nothing is uploading.
  final RxnDouble uploadProgress = RxnDouble();

  VerificationModel get current => state.value.data ?? VerificationModel.none();

  /// The gate the rest of the app reads to decide what is available.
  VerificationGate get gate {
    if (current.isApproved) return VerificationGate.verified;
    if (current.isRejected) return VerificationGate.rejected;
    if (current.isInManualReview) return VerificationGate.inManualReview;
    return VerificationGate.notSubmitted;
  }

  FeatureAccess get access => FeatureAccess(gate);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    state.value = const ApiState<VerificationModel>.loading();
    try {
      final VerificationModel data = await _repo.fetchCurrent();
      state.value = ApiState<VerificationModel>.success(data);
    } on AppException catch (e) {
      state.value = ApiState<VerificationModel>.fromException(e);
    } catch (e) {
      state.value = ApiState<VerificationModel>.serverError(e.toString());
    }
  }

  Future<void> reload() => load();

  Future<void> loadHistory() async {
    try {
      history.assignAll(await _repo.fetchHistory());
    } on AppException catch (e) {
      actionError.value = e.message;
    }
  }

  /// Submits CNIC front/back and a selfie for review.
  ///
  /// Returns null on success, or a message to show. The server refuses a second
  /// submission while one is open, so this checks the gate first rather than
  /// letting the member fill a whole form and then hit a 409.
  Future<String?> submit({
    required String cnicNumber,
    required String cnicFrontPath,
    required String cnicBackPath,
    required String selfiePath,
    String? facePath,
  }) async {
    if (submitting.value) return null;

    final String? blocked = access.reasonFor(AppFeature.submitVerification);
    if (blocked != null) {
      actionError.value = blocked;
      return blocked;
    }

    submitting.value = true;
    actionError.value = null;
    uploadProgress.value = 0;
    try {
      final VerificationModel result = await _repo.submit(
        cnicNumber: cnicNumber,
        cnicFrontPath: cnicFrontPath,
        cnicBackPath: cnicBackPath,
        selfiePath: selfiePath,
        facePath: facePath,
        onProgress: (int sent, int total) {
          if (total > 0) uploadProgress.value = sent / total;
        },
      );
      state.value = ApiState<VerificationModel>.success(result);
      return null;
    } on AppException catch (e) {
      actionError.value = e.message;
      return e.message;
    } catch (e) {
      actionError.value = e.toString();
      return e.toString();
    } finally {
      submitting.value = false;
      uploadProgress.value = null;
    }
  }
}
