import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../repositories/help_chat_repository.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/app_text_form_field.dart';

/// Help Center for visitors WITHOUT an account.
///
/// Pressing Help before login lands here: a short form (name, email,
/// description) posted to `POST /public/help`, which files the request into
/// the admin panel's Contact Us Queries list and emails the team. No token,
/// no thread — once the visitor signs up, the full Help Center chat (with
/// realtime replies and the ticket lock) takes over.
class GuestHelpView extends StatefulWidget {
  const GuestHelpView({super.key});

  /// Opens the guest form; used by every pre-login Help entry point.
  static void open() {
    Get.to<void>(() => const GuestHelpView());
  }

  @override
  State<GuestHelpView> createState() => _GuestHelpViewState();
}

class _GuestHelpViewState extends State<GuestHelpView> {
  final HelpChatRepository _repo = Get.find<HelpChatRepository>();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final RxBool _sending = false.obs;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _sending.value = true;
    try {
      await _repo.submitGuestHelp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        description: _descriptionController.text.trim(),
      );
      AppSnackbar.success(
        'Your request has been sent to our Help Center. '
        'Our team will reply on your email.',
      );
      if (mounted) Get.back<void>();
    } catch (_) {
      AppSnackbar.error('Could not send your request. Please try again.');
    } finally {
      _sending.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.roseCanvas,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).maybePop();
            } else {
              Get.back<void>();
            }
          },
        ),
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.regAccent.withValues(alpha: 0.15),
              child: const Icon(
                Icons.support_agent_rounded,
                color: AppColors.regAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'HamQadam Help Center',
                    style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                  ),
                  Text(
                    'Ask us anything — no account needed',
                    style: TextStyle(fontSize: 11, color: theme.hintColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // ---- Hero -------------------------------------------------
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.regPrimaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.support_agent_rounded,
                      size: 36, color: Colors.white),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Assalam-o-Alaikum!',
                textAlign: TextAlign.center,
                style: AppTextStyles.headline.copyWith(fontSize: 20),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tell us what you need help with and our team will get back '
                'to you on your email.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: theme.hintColor,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ---- Form card -------------------------------------------
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: AppRadius.xlAll,
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.roseFieldBorder,
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    AppTextFormField(
                      controller: _nameController,
                      label: 'Name',
                      hint: 'Your full name',
                      textCapitalization: TextCapitalization.words,
                      validator: (String? v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextFormField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (String? v) {
                        final String value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Email is required';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextFormField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Describe your issue or question…',
                      maxLines: 6,
                      minLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (String? v) {
                        if (v == null || v.trim().length < 10) {
                          return 'Please write at least a few words so the '
                              'team can help.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ---- Submit ----------------------------------------------
              Obx(() => AppButton(
                    label: 'Submit',
                    icon: Icons.send_rounded,
                    loading: _sending.value,
                    onPressed: _submit,
                  )),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Already a member? Log in to chat with the Help Center live.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
