import 'package:get/get.dart';
import '../repositories/auth_extra_repository.dart';
import '../widgets/app_snackbar.dart';

/// Extra auth features: device sessions, email verification.
class AuthExtraController extends GetxController {
  AuthExtraController(this._repo);

  final AuthExtraRepository _repo;

  final RxList<DeviceSession> devices = <DeviceSession>[].obs;
  final RxBool loading = false.obs;

  Future<void> loadDevices() async {
    loading.value = true;
    try {
      devices.assignAll(await _repo.fetchDevices());
    } catch (_) {}
    loading.value = false;
  }

  Future<bool> requestEmailVerification({String? email}) async {
    try {
      await _repo.requestEmailVerification(email: email);
      AppSnackbar.success('Verification code sent to your email.');
      return true;
    } catch (e) {
      AppSnackbar.error('Failed to send verification code.');
      return false;
    }
  }

  Future<bool> verifyEmail({required String code, String? email}) async {
    try {
      await _repo.verifyEmail(code: code, email: email);
      AppSnackbar.success('Email verified successfully.');
      return true;
    } catch (e) {
      AppSnackbar.error('Verification failed: $e');
      return false;
    }
  }
}
