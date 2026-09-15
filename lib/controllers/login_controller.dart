import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/api/api_response.dart';
import '../core/services/biometric_auth_service.dart';
import '../core/utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';
import '../models/auth_response_model.dart';
import '../repositories/auth_repository.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/biometric_optin_dialog.dart';
import 'auth_controller.dart';
import 'registration_controller.dart';

/// Handles the email/password login form. Session persistence and routing are
/// delegated to [AuthController] / [RegistrationController].
class LoginController extends GetxController {
  LoginController({required this.authRepository, required this.authController});

  final AuthRepository authRepository;
  final AuthController authController;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();

  final RxBool obscure = true.obs;
  final RxBool submitting = false.obs;
  final RxString generalError = ''.obs;
  final RxMap<String, String> serverErrors = <String, String>{}.obs;

  void toggleObscure() => obscure.toggle();

  void clearServerError(String field) {
    if (serverErrors.containsKey(field)) serverErrors.remove(field);
  }

  Future<void> submit() async {
    if (submitting.value) return;
    generalError.value = '';
    if (!(formKey.currentState?.validate() ?? false)) return;

    // Captured before the controllers are cleared, so the fingerprint opt-in
    // can store exactly what was just verified by the server.
    final String email = emailCtrl.text.trim();
    final String password = passwordCtrl.text;

    submitting.value = true;
    bool success = false;
    try {
      final AuthResponseModel res = await authRepository.loginWithEmail(
        email: email,
        password: password,
        deviceName: 'flutter-app',
      );
      if (!res.hasToken) {
        _fail('Login failed. Please try again.');
        return;
      }
      await authController.persistSession(res);
      passwordCtrl.clear();
      success = true;
    } on ValidationException catch (e) {
      serverErrors.clear();
      e.errors.forEach((String k, List<String> v) {
        if (v.isNotEmpty) serverErrors[k] = v.first;
      });
      // Prefer the field message ("These credentials do not match…") over the
      // generic "Validation failed." wrapper.
      _fail(serverErrors.values.isNotEmpty ? serverErrors.values.first : e.message);
    } on AppException catch (e) {
      // A 401 here is a wrong password, not a dead session: this request carried
      // no token, so nothing cleared the session or routed away, and without a
      // snackbar the only feedback was an inline line the keyboard often covers.
      _fail(e.message);
    } finally {
      submitting.value = false;
    }

    if (!success) return;

    // One-time offer: remember these verified credentials for fingerprint
    // login. Shown before the post-login routing so the dialog has a stable
    // screen behind it, and skipped entirely on non-biometric devices or when
    // the member already opted in / said "not now".
    try {
      if (Get.isRegistered<BiometricAuthService>()) {
        await BiometricOptInDialog.maybeShow(
          service: Get.find<BiometricAuthService>(),
          email: email,
          password: password,
        );
      }
    } catch (e) {
      AppLogger.w('biometric opt-in failed (ignored): $e');
    }

    // Route based on server registration status.
    final bool gated = await authController.checkManualReview();
    if (gated) return;
    await Get.find<RegistrationController>().resume();
  }

  /// Fingerprint login: verifies the member with the system BiometricPrompt,
  /// then replays the stored credentials through the normal login API so a
  /// fresh token is issued. Silent when the member cancels the prompt.
  Future<void> loginWithBiometric() async {
    if (submitting.value) return;
    if (!Get.isRegistered<BiometricAuthService>()) return;
    final BiometricAuthService bio = Get.find<BiometricAuthService>();

    final ({String email, String password})? creds = await bio.authenticate();
    if (creds == null) return; // cancelled / failed — nothing to say

    submitting.value = true;
    generalError.value = '';
    try {
      final AuthResponseModel res = await authRepository.loginWithEmail(
        email: creds.email,
        password: creds.password,
        deviceName: 'flutter-app',
      );
      if (!res.hasToken) {
        _fail('Login failed. Please try again.');
        return;
      }
      await authController.persistSession(res);
      final bool gated = await authController.checkManualReview();
      if (gated) return;
      await Get.find<RegistrationController>().resume();
    } on ValidationException catch (e) {
      // The stored password no longer matches (changed on another device, or
      // the account changed). The member falls back to typing; the stale
      // credentials are dropped so the fingerprint button stops offering a
      // login that cannot succeed.
      await bio.disable();
      final String? fieldMsg = e.errors.values
          .expand<String>((List<String> v) => v)
          .cast<String?>()
          .firstWhere((String? m) => (m ?? '').isNotEmpty, orElse: () => null);
      _fail(fieldMsg ?? e.message);
    } on AppException catch (e) {
      _fail(e.message);
    } finally {
      submitting.value = false;
    }
  }

  /// Every login failure lands here, so none of them can be silent.
  void _fail(String message) {
    generalError.value = message;
    AppSnackbar.error(message);
  }

  ApiStatus get status => submitting.value ? ApiStatus.loading : ApiStatus.initial;

  @override
  void onClose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    super.onClose();
  }
}
