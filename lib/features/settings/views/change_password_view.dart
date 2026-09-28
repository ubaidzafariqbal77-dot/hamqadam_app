import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/api/api_client.dart';
import '../../../exceptions/app_exceptions.dart';
import '../../../repositories/account_check_repository.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/surface_card.dart';

/// Drawer → Change Password. Old, new and confirm — the controller verifies
/// the OLD password server-side first (422 with a field error when it is
/// wrong) and only then stores the new one. On success the member stays
/// logged in; the backend does not invalidate sessions for a password change.
class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  late final AccountCheckRepository _repo;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentCtrl = TextEditingController();
  final TextEditingController _newCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  final RxBool _saving = false.obs;
  final Rxn<String> _fieldError = Rxn<String>();
  final RxBool _obscureCurrent = true.obs;
  final RxBool _obscureNew = true.obs;
  final RxBool _obscureConfirm = true.obs;

  @override
  void initState() {
    super.initState();
    _repo = Get.isRegistered<AccountCheckRepository>()
        ? Get.find<AccountCheckRepository>()
        : Get.put(AccountCheckRepository(Get.find<ApiClient>()), permanent: true);
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _fieldError.value = null;
    _saving.value = true;
    try {
      final String message = await _repo.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      AppSnackbar.success(message.isEmpty ? 'Password changed successfully.' : message);
      Get.back<void>();
    } on AppException catch (e) {
      // The backend answers 422 with a `current_password` (or `password`)
      // field error — surface the first message inline instead of a toast.
      String? detail = e.message;
      if (e is ValidationException) {
        detail = e.firstFor('current_password') ??
            e.firstFor('password') ??
            e.message;
      }
      _fieldError.value = detail;
      if ((detail ?? '').toLowerCase().contains('current')) {
        _currentCtrl.clear();
      }
    } catch (_) {
      _fieldError.value = 'Could not change the password. Please try again.';
    } finally {
      _saving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.roseCanvas,
      appBar: const PremiumAppBar(
        title: 'Change Password',
        subtitle: 'Keep your account secure',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: AppSpacing.xs),
              AppTextFormField(
                insetLabel: true,
                label: 'Current password',
                controller: _currentCtrl,
                obscureText: _obscureCurrent.value,
                validator: (String? v) =>
                    (v == null || v.isEmpty) ? 'Enter your current password' : null,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrent.value
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                  ),
                  onPressed: () => _obscureCurrent.value = !_obscureCurrent.value,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                insetLabel: true,
                label: 'New password',
                controller: _newCtrl,
                obscureText: _obscureNew.value,
                validator: (String? v) =>
                    (v == null || v.length < 8) ? 'At least 8 characters' : null,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew.value
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                  ),
                  onPressed: () => _obscureNew.value = !_obscureNew.value,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                insetLabel: true,
                label: 'Confirm new password',
                controller: _confirmCtrl,
                obscureText: _obscureConfirm.value,
                validator: (String? v) =>
                    v != _newCtrl.text ? 'Passwords do not match' : null,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm.value
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                  ),
                  onPressed: () => _obscureConfirm.value = !_obscureConfirm.value,
                ),
              ),
              Obx(() {
                if (_fieldError.value == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.error_rounded, size: 16, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _fieldError.value!,
                          style: AppTextStyles.caption.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.lg),
              Obx(() => SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      onPressed: _saving.value ? null : _submit,
                      child: _saving.value
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Change Password',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  )),
              const SizedBox(height: AppSpacing.sm),
              SurfaceCard(
                child: Row(
                  children: <Widget>[
                    Icon(Icons.shield_outlined,
                        size: 18, color: AppColors.primary.withValues(alpha: 0.7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Use at least 8 characters. You stay signed in on this device after changing your password.',
                        style: AppTextStyles.caption.copyWith(
                          color: Theme.of(context).hintColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
