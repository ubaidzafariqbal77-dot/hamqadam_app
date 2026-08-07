import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/api/api_response.dart';
import '../exceptions/app_exceptions.dart';
import '../models/auth_response_model.dart';
import '../repositories/auth_repository.dart';
import '../widgets/app_snackbar.dart';
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

    submitting.value = true;
    try {
      final AuthResponseModel res = await authRepository.loginWithEmail(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text,
        deviceName: 'flutter-app',
      );
      if (!res.hasToken) {
        generalError.value = 'Login failed. Please try again.';
        return;
      }
      await authController.persistSession(res);
      passwordCtrl.clear();
      // Route based on server registration status.
      await Get.find<RegistrationController>().resume();
    } on ValidationException catch (e) {
      serverErrors.clear();
      e.errors.forEach((String k, List<String> v) {
        if (v.isNotEmpty) serverErrors[k] = v.first;
      });
      generalError.value = e.message;
    } on AppException catch (e) {
      generalError.value = e.message;
      if (e is! UnauthorizedException) AppSnackbar.error(e.message);
    } finally {
      submitting.value = false;
    }
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
