import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/routes/app_routes.dart';
import '../core/validators/app_validators.dart';
import '../exceptions/app_exceptions.dart';
import '../repositories/auth_repository.dart';
import '../widgets/app_snackbar.dart';

/// Forgot-password flow: request an OTP to the email, then verify it with a new
/// password to reset. Two on-screen stages driven by [otpSent].
class ForgotPasswordController extends GetxController {
  ForgotPasswordController(this.authRepository);

  final AuthRepository authRepository;

  final GlobalKey<FormState> emailFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> resetFormKey = GlobalKey<FormState>();

  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController otpCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  final TextEditingController confirmCtrl = TextEditingController();

  final RxBool otpSent = false.obs;
  final RxBool submitting = false.obs;
  final RxString generalError = ''.obs;

  String get _email => emailCtrl.text.trim().toLowerCase();

  /// Stage 1 — request the reset OTP.
  Future<void> requestOtp() async {
    generalError.value = '';
    if (!(emailFormKey.currentState?.validate() ?? false)) return;
    if (submitting.value) return;
    submitting.value = true;
    try {
      final String msg = await authRepository.forgotPassword(_email);
      otpSent.value = true;
      AppSnackbar.success(msg.isEmpty ? 'OTP sent to your email' : msg);
    } on AppException catch (e) {
      generalError.value = e.message;
      AppSnackbar.error(e.message);
    } finally {
      submitting.value = false;
    }
  }

  /// Stage 2 — verify OTP + set the new password.
  Future<void> resetPassword() async {
    generalError.value = '';
    if (otpCtrl.text.trim().length < 6) {
      generalError.value = 'Enter the complete 6-digit OTP';
      return;
    }
    if (!(resetFormKey.currentState?.validate() ?? false)) return;
    if (submitting.value) return;
    submitting.value = true;
    try {
      final String msg = await authRepository.resetPassword(
        email: _email,
        otp: otpCtrl.text.trim(),
        password: passwordCtrl.text,
        passwordConfirmation: confirmCtrl.text,
      );
      AppSnackbar.success(msg.isEmpty ? 'Password changed. Please sign in.' : msg);
      // Back to login so the user signs in with the new password.
      Get.offAllNamed(AppRoutes.login);
    } on ValidationException catch (e) {
      generalError.value = e.message;
      AppSnackbar.error(e.message);
    } on AppException catch (e) {
      generalError.value = e.message;
      AppSnackbar.error(e.message);
    } finally {
      submitting.value = false;
    }
  }

  void changeEmail() {
    otpSent.value = false;
    otpCtrl.clear();
    passwordCtrl.clear();
    confirmCtrl.clear();
    generalError.value = '';
  }

  String? validateEmail(String? v) => AppValidators.email(v);
  String? validateOtp(String? v) =>
      (v == null || v.trim().length < 4) ? 'Enter the OTP you received' : null;
  String? validatePassword(String? v) => AppValidators.password(v);
  String? validateConfirm(String? v) =>
      AppValidators.confirmPassword(v, passwordCtrl.text);

  @override
  void onClose() {
    emailCtrl.dispose();
    otpCtrl.dispose();
    passwordCtrl.dispose();
    confirmCtrl.dispose();
    super.onClose();
  }
}
