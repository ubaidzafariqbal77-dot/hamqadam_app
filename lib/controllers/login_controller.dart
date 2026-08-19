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
        _fail('Login failed. Please try again.');
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
