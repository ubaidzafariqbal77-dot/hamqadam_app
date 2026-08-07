import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/validators/app_validators.dart';
import '../exceptions/app_exceptions.dart';
import '../models/auth_response_model.dart';
import '../repositories/auth_repository.dart';
import '../widgets/app_snackbar.dart';
import 'auth_controller.dart';
import 'registration_controller.dart';

/// Mobile OTP login: request an OTP, then verify it to sign in.
class MobileOtpController extends GetxController {
  MobileOtpController({required this.authRepository, required this.authController});

  final AuthRepository authRepository;
  final AuthController authController;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController otpCtrl = TextEditingController();

  /// Default Pakistan country code.
  final RxString countryCode = '92'.obs;
  final RxBool otpRequested = false.obs;
  final RxBool submitting = false.obs;
  final RxString generalError = ''.obs;

  String get _phone =>
      AppValidators.normalizePakPhone(phoneCtrl.text) ?? phoneCtrl.text.trim();

  Future<void> requestOtp() async {
    generalError.value = '';
    if (AppValidators.pakistaniPhone(phoneCtrl.text) != null) {
      generalError.value = 'Enter a valid Pakistani mobile number';
      return;
    }
    if (submitting.value) return;
    submitting.value = true;
    try {
      final String msg = await authRepository.requestMobileOtp(
        phone: _phone,
        countryCode: countryCode.value,
      );
      otpRequested.value = true;
      AppSnackbar.success(msg.isEmpty ? 'OTP sent to your mobile' : msg);
    } on AppException catch (e) {
      generalError.value = e.message;
      AppSnackbar.error(e.message);
    } finally {
      submitting.value = false;
    }
  }

  Future<void> verifyOtp() async {
    generalError.value = '';
    if (otpCtrl.text.trim().length < 4) {
      generalError.value = 'Enter the OTP you received';
      return;
    }
    if (submitting.value) return;
    submitting.value = true;
    try {
      final AuthResponseModel res = await authRepository.loginWithMobileOtp(
        phone: _phone,
        countryCode: countryCode.value,
        otp: otpCtrl.text.trim(),
        deviceName: 'flutter-app',
      );
      if (!res.hasToken) {
        generalError.value = 'Login failed. Please try again.';
        return;
      }
      await authController.persistSession(res);
      await Get.find<RegistrationController>().resume();
    } on AppException catch (e) {
      generalError.value = e.message;
      AppSnackbar.error(e.message);
    } finally {
      submitting.value = false;
    }
  }

  void reset() {
    otpRequested.value = false;
    otpCtrl.clear();
    generalError.value = '';
  }

  @override
  void onClose() {
    phoneCtrl.dispose();
    otpCtrl.dispose();
    super.onClose();
  }
}
