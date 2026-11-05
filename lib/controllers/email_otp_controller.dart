import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/validators/app_validators.dart';
import '../exceptions/app_exceptions.dart';
import '../models/auth_response_model.dart';
import '../repositories/auth_repository.dart';
import '../widgets/app_snackbar.dart';
import 'auth_controller.dart';
import 'registration_controller.dart';

/// EMAIL OTP login — the QA-required account-recovery path.
///
/// Mirrors [MobileOtpController] one-to-one: request a 6-digit code to the
/// registered email, then verify it to sign in. The backend endpoint
/// (`POST /auth/otp/email` + `POST /auth/login/email-otp`) replaces the old
/// mobile-OTP dependency.
class EmailOtpController extends GetxController {
  EmailOtpController({required this.authRepository, required this.authController});

  final AuthRepository authRepository;
  final AuthController authController;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController otpCtrl = TextEditingController();

  final RxBool otpRequested = false.obs;
  final RxBool submitting = false.obs;
  final RxString generalError = ''.obs;

  String get _email => emailCtrl.text.trim().toLowerCase();

  Future<void> requestOtp() async {
    generalError.value = '';
    if (AppValidators.email(emailCtrl.text) != null) {
      _fail('Enter a valid email address');
      return;
    }
    if (submitting.value) return;
    submitting.value = true;
    try {
      final String msg = await authRepository.requestEmailOtp(email: _email);
      otpRequested.value = true;
      AppSnackbar.success(msg.isEmpty ? 'Code sent to your email' : msg);
    } on AppException catch (e) {
      _fail(e.message);
    } finally {
      submitting.value = false;
    }
  }

  Future<void> verifyOtp() async {
    generalError.value = '';
    if (otpCtrl.text.trim().length < 4) {
      _fail('Enter the code you received');
      return;
    }
    if (submitting.value) return;
    submitting.value = true;
    try {
      final AuthResponseModel res = await authRepository.loginWithEmailOtp(
        email: _email,
        otp: otpCtrl.text.trim(),
        deviceName: 'flutter-app',
      );
      if (!res.hasToken) {
        _fail('Login failed. Please try again.');
        return;
      }
      await authController.persistSession(res);
      final bool gated = await authController.checkManualReview();
      if (gated) return;
      await Get.find<RegistrationController>().resumeAfterLogin();
    } on AppException catch (e) {
      _fail(e.message);
    } finally {
      submitting.value = false;
    }
  }

  void _fail(String message) {
    generalError.value = message;
    AppSnackbar.error(message);
  }

  void reset() {
    otpRequested.value = false;
    otpCtrl.clear();
    generalError.value = '';
  }

  @override
  void onClose() {
    emailCtrl.dispose();
    otpCtrl.dispose();
    super.onClose();
  }
}
