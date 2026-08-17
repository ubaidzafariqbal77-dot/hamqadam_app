import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/storage/registration_buffer.dart';
import '../core/utils/app_logger.dart';
import '../core/validators/app_validators.dart';
import '../exceptions/app_exceptions.dart';
import '../models/user_model.dart';
import '../widgets/app_snackbar.dart';
import 'auth_controller.dart';
import 'registration_controller.dart';

/// Email verification, the last leg of signup.
///
/// `POST /auth/register/complete` returns a token but leaves the account
/// unverified; this screen drives `request-otp` → `verify-otp`. The code is
/// requested as soon as the screen opens (unless the finalizing screen already
/// sent one) and can be resent after a cooldown.
///
/// The address is changeable here: sending and verifying a code for a different
/// email moves the account onto it (verified against the live API), which is
/// the way out when the one used at signup turns out to be taken or wrong.
class VerifyEmailController extends GetxController {
  VerifyEmailController({this.codeAlreadySent = false});

  /// True when the finalizing screen already fired `request-otp`, so opening
  /// this screen must not immediately send a second code.
  final bool codeAlreadySent;

  RegistrationController get reg => Get.find<RegistrationController>();
  AuthController get auth => Get.find<AuthController>();
  RegistrationBuffer get buffer => Get.find<RegistrationBuffer>();

  final TextEditingController codeCtrl = TextEditingController();

  /// Backing field for the "use a different email" sheet.
  final TextEditingController newEmailCtrl = TextEditingController();

  final RxBool verifying = false.obs;
  final RxBool sending = false.obs;
  final RxString error = ''.obs;

  /// The address the code is currently going to; editable via [changeEmail].
  final RxString email = ''.obs;

  /// Seconds left before "Resend code" becomes tappable again.
  final RxInt resendIn = 0.obs;
  Timer? _ticker;

  static const int _resendCooldown = 60;
  static const int codeLength = 6;

  bool get canResend => resendIn.value == 0 && !sending.value;

  @override
  void onInit() {
    super.onInit();
    email.value = reg.registrationEmail ?? '';
    if (codeAlreadySent) {
      _startCooldown();
    } else {
      sendCode(silent: true);
    }
  }

  @override
  void onClose() {
    _ticker?.cancel();
    codeCtrl.dispose();
    newEmailCtrl.dispose();
    super.onClose();
  }

  /// Requests (or resends) the emailed code for [email].
  Future<void> sendCode({bool silent = false}) async {
    if (sending.value) return;
    sending.value = true;
    error.value = '';
    try {
      final String msg = await reg.requestEmailOtp(email: email.value);
      _startCooldown();
      if (!silent) {
        AppSnackbar.success(msg.isEmpty ? 'A new code is on its way.' : msg);
      }
    } on ApiException catch (e) {
      // The account this token belongs to is already verified — there is
      // nothing left to confirm, so finish instead of stranding the user.
      if (e.code == 'email_already_verified') {
        if (await _finishIfAlreadyVerified()) return;
      }
      error.value = e.message;
      if (!silent) AppSnackbar.error(e.message);
    } on AppException catch (e) {
      error.value = e.message;
      if (!silent) AppSnackbar.error(e.message);
    } finally {
      sending.value = false;
    }
  }

  /// Verifies the entered code and ends the signup flow on success.
  Future<void> verify() async {
    if (verifying.value) return;
    final String code = codeCtrl.text.trim();
    if (code.length < codeLength) {
      error.value = 'Enter the complete $codeLength-digit code.';
      return;
    }
    verifying.value = true;
    error.value = '';
    try {
      await reg.verifyEmailOtp(code, email: email.value);
      await reg.finishRegistration();
    } on AppException catch (e) {
      // KNOWN BACKEND DEFECT: verify-otp marks the account verified, consumes
      // the code, and THEN crashes applying the Basic Free package reward
      // (RegistrationReward::applyRegistrationDefaultPackage is undefined).
      // That leaves three different failures all meaning "already verified":
      //   500 invalid_method  — the crash itself
      //   422 invalid_otp     — retrying the now-consumed code
      //   409 email_already_verified — asking for a new one
      // So never trust the error alone: ask the server what the account's
      // actual state is before telling the user something went wrong.
      AppLogger.w('verify-otp failed (${e.statusCode} ${e.message}) — checking /auth/me');
      if (await _finishIfAlreadyVerified()) return;
      error.value = e.message;
    } finally {
      verifying.value = false;
    }
  }

  /// Points the flow at a different address and sends it a fresh code.
  Future<void> changeEmail() async {
    final String next = newEmailCtrl.text.trim().toLowerCase();
    final String? invalid = AppValidators.email(next);
    if (invalid != null) {
      error.value = invalid;
      return;
    }
    if (next == email.value) {
      error.value = 'That is the address the code was already sent to.';
      return;
    }
    error.value = '';
    email.value = next;
    // Keep the buffer in step so a relaunch resumes on the new address.
    buffer.putOne('email', next);
    codeCtrl.clear();
    resendIn.value = 0;
    await sendCode();
  }

  /// Asks the server whether the account is verified; finishes signup if so.
  /// Never throws — a failed check just means "keep showing the OTP screen".
  Future<bool> _finishIfAlreadyVerified() async {
    try {
      await auth.refreshUser();
      final UserModel? user = auth.user.value;
      AppLogger.i('/auth/me says email_verified=${user?.isEmailVerified}');
      if (user?.isEmailVerified != true) return false;
      AppLogger.i('Account already verified — completing registration.');
      await reg.finishRegistration();
      return true;
    } catch (e) {
      AppLogger.w('Could not confirm verification state: $e');
      return false;
    }
  }

  void _startCooldown() {
    _ticker?.cancel();
    resendIn.value = _resendCooldown;
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (resendIn.value <= 1) {
        resendIn.value = 0;
        t.cancel();
      } else {
        resendIn.value -= 1;
      }
    });
  }
}
