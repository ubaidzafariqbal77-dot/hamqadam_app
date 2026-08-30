import 'package:get/get.dart';
import '../repositories/safety_repository.dart';
import '../widgets/app_snackbar.dart';

/// Safety actions: report, block, mute, restrict.
class SafetyController extends GetxController {
  SafetyController(this._repo);

  final SafetyRepository _repo;

  final RxBool busy = false.obs;

  Future<bool> report({
    required int userId,
    required String reason,
    String severity = 'medium',
  }) async {
    if (busy.value) return false;
    busy.value = true;
    try {
      await _repo.report(userId: userId, reason: reason, severity: severity);
      AppSnackbar.success('Report submitted. Thank you for helping keep HamQadam safe.');
      return true;
    } catch (e) {
      AppSnackbar.error('Failed to submit report: $e');
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<bool> block({required int userId, String? reason}) async {
    if (busy.value) return false;
    busy.value = true;
    try {
      await _repo.block(userId: userId, reason: reason);
      AppSnackbar.success('User blocked successfully.');
      return true;
    } catch (e) {
      AppSnackbar.error('Failed to block user: $e');
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<bool> mute({required int userId, String? reason}) async {
    if (busy.value) return false;
    busy.value = true;
    try {
      await _repo.mute(userId: userId, reason: reason);
      AppSnackbar.success('User muted successfully.');
      return true;
    } catch (e) {
      AppSnackbar.error('Failed to mute user: $e');
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<bool> restrict({required int userId, String? reason}) async {
    if (busy.value) return false;
    busy.value = true;
    try {
      await _repo.restrict(userId: userId, reason: reason);
      AppSnackbar.success('User restricted successfully.');
      return true;
    } catch (e) {
      AppSnackbar.error('Failed to restrict user: $e');
      return false;
    } finally {
      busy.value = false;
    }
  }
}
