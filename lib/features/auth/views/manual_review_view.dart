import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/auth_controller.dart';
import '../../../features/help_center/views/help_chat_view.dart';
import '../../../models/manual_review_state.dart';
import '../../../repositories/auth_repository.dart';
import '../../../exceptions/app_exceptions.dart';
import '../../../core/routes/app_routes.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/app_text_form_field.dart';

/// Full-screen gate shown when the server answers `423 manual_review` or the
/// status check reports the account is under manual review.
///
/// The account stays read-only until the review clears, so nothing else in the
/// app is reachable from here on purpose. The member gets one clear, centered
/// explanation and exactly two actions: reach support, or leave to login.
class ManualReviewView extends StatefulWidget {
  const ManualReviewView({super.key});

  @override
  State<ManualReviewView> createState() => _ManualReviewViewState();
}

class _ManualReviewViewState extends State<ManualReviewView> {
  AuthController get _auth => Get.find<AuthController>();

  /// Ticks the "time remaining" line so the window visibly moves.
  Timer? _ticker;
  final RxInt _remainingSeconds = 0.obs;
  final RxBool _leaving = false.obs;

  @override
  void initState() {
    super.initState();
    _syncFromController();
    // Re-ask the server on entry: a review can clear while the gate screen was
    // sitting in memory, and the state cached on the controller may be stale.
    _refresh(silent: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds.value > 0) _remainingSeconds.value -= 1;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncFromController() {
    final ManualReviewState? state = _auth.manualReview.value;
    _remainingSeconds.value = state?.remainingSeconds ?? 0;
  }

  Future<void> _refresh({bool silent = false}) async {
    await _auth.checkManualReview(navigate: false);
    _syncFromController();
    if (!silent) _syncTickerAfterRefresh();
  }

  /// `checkManualReview` replaced the cached state; recompute the ticker so a
  /// just-cleared window does not keep counting down from stale seconds.
  void _syncTickerAfterRefresh() {
    final ManualReviewState? state = _auth.manualReview.value;
    _remainingSeconds.value = state?.remainingSeconds ?? 0;
  }

  Future<void> _goToLogin() async {
    _leaving.value = true;
    try {
      // Full session clear — same contract as explicit logout. The review gate
      // state is wiped with it so the next login starts clean.
      await Get.find<AuthController>().logout();
    } finally {
      _leaving.value = false;
    }
  }

  /// Opens the full Help Center chat. The backend's review gate explicitly
  /// allows help-chat routes, so a member stuck in review can always reach a
  /// human through here — that is the whole point of the button.
  void _openHelpCenter() {
    HelpChatView.open();
  }

  /// Support request through the one endpoint the review gate leaves open.
  Future<void> _openSupportSheet() async {
    // NOTE: no local TextEditingController here — the sheet's exit animation
    // keeps its TextFormField alive for a moment AFTER the awaited future
    // resolves, and a controller disposed right after the await gets read
    // during that window ("used after being disposed"). The typed text is
    // captured through onChanged instead, so there is nothing to dispose.
    String message = '';
    final RxBool sending = false.obs;
    await Get.bottomSheet<void>(
      Container(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.xl,
          bottom: MediaQuery.of(Get.context!).viewInsets.bottom + AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: Theme.of(Get.context!).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Contact support', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tell our team what you need help with — your message goes '
              'straight to the verification desk.',
              style: AppTextStyles.caption.copyWith(
                color: Theme.of(Get.context!).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextFormField(
              label: 'Your message',
              onChanged: (String v) => message = v,
              hint: 'e.g. I have already submitted my documents…',
              maxLines: 4,
              minLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),
            Obx(() => AppButton(
                  label: 'Send message',
                  icon: Icons.send_rounded,
                  loading: sending.value,
                  onPressed: () async {
                    final String msg = message.trim();
                    if (msg.length < 10) {
                      AppSnackbar.error(
                          'Please write at least a few words so the team can help.');
                      return;
                    }
                    sending.value = true;
                    try {
                      final String reply = await Get.find<AuthRepository>()
                          .submitManualReviewContact(msg);
                      AppSnackbar.success(
                          reply.isEmpty ? 'Message sent to our team.' : reply);
                      Get.back<void>();
                    } on AppException catch (e) {
                      AppSnackbar.error(e.message);
                    } finally {
                      sending.value = false;
                    }
                  },
                )),
          ],
        ),
      ),
      isScrollControlled: true,
      isDismissible: true,
    );
  }

  String get _statusText {
    final ManualReviewState? s = _auth.manualReview.value;
    if (s == null) return 'Manual review in progress';
    if (s.expired) return 'Review window has expired';
    if (s.status == 'manual_review') return 'Manual review in progress';
    return 'Identity verification in review';
  }

  String get _remainingText {
    final int s = _remainingSeconds.value;
    if (s <= 0) return '';
    final int hours = s ~/ 3600;
    final int minutes = (s % 3600) ~/ 60;
    final int seconds = s % 60;
    if (hours > 0) {
      return 'Estimated time remaining · ${hours}h ${minutes}m';
    }
    if (minutes > 0) return 'Estimated time remaining · ${minutes}m ${seconds}s';
    return 'Estimated time remaining · ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color onCard = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color onCardSecondary =
        dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color cardColor = dark ? AppColors.darkSurface : AppColors.lightSurface;

    return PopScope(
      // Nothing to pop back to (this is pushed with offAllNamed) and nothing to
      // go back INTO — the app is read-only while the gate is active.
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: LinearGradient(
            colors: AppColors.brandGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // ---- Review badge ---------------------------------
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.hourglass_top_rounded,
                            color: Colors.white,
                            size: 64,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      // ---- Title ----------------------------------------
                      Text(
                        'Account under manual review',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.title.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'HamQadam — Rishtu Ki Dunya',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // ---- The message the user asked for ----------------
                      Text(
                        'You are under review. Our team will review your '
                        'account and send you an email for verification.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // The one thing a stuck member must be able to do.
                      Text(
                        'If your account is not getting verified even though '
                        'your information is correct, contact our Help Center '
                        'and the team will review your case.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // ---- Status card ----------------------------------
                      Obx(() {
                        final String remaining = _remainingText;
                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: cardColor.withValues(alpha: 0.97),
                            borderRadius: AppRadius.xlAll,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const Icon(
                                    Icons.verified_user_rounded,
                                    size: AppDimensions.iconSm,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Flexible(
                                    child: Text(
                                      _statusText,
                                      style: AppTextStyles.label
                                          .copyWith(color: onCard),
                                    ),
                                  ),
                                ],
                              ),
                              if (remaining.isNotEmpty) ...<Widget>[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  remaining,
                                  style: AppTextStyles.caption
                                      .copyWith(color: onCardSecondary),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.md),
                              // What still works during the window.
                              _ReviewNote(
                                icon: Icons.mark_email_unread_outlined,
                                text: 'The decision will arrive on your '
                                    'registered email address.',
                                textColor: onCardSecondary,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              _ReviewNote(
                                icon: Icons.support_agent_rounded,
                                text: 'Stuck on verification? Use Help Center '
                                    'below — our team can re-check your case.',
                                textColor: onCardSecondary,
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: AppSpacing.xl),
                      // ---- Primary action: back to login ----------------
                      Obx(() => AppButton(
                            label: 'Go To Login',
                            icon: Icons.login_rounded,
                            loading: _leaving.value,
                            onPressed: _goToLogin,
                          )),
                      const SizedBox(height: AppSpacing.sm),
                      // ---- Secondary: Help Center -----------------------
                      // Two doors out of a stuck verification: the quick
                      // message to the verification desk, or the full Help
                      // Center chat. Both stay reachable through the 423 gate.
                      TextButton.icon(
                        onPressed: _openSupportSheet,
                        icon: const Icon(Icons.forward_to_inbox_rounded,
                            size: 18, color: Colors.white),
                        label: Text(
                          'Message verification desk',
                          style: AppTextStyles.label.copyWith(color: Colors.white),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openHelpCenter,
                        icon: const Icon(Icons.support_agent_rounded,
                            size: 18, color: Colors.white),
                        label: Text(
                          'Open Help Center',
                          style: AppTextStyles.label.copyWith(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Obx(() {
                        if (!_auth.underManualReview.value) {
                          // Review cleared while sitting here — send them in.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              Get.offAllNamed<dynamic>(AppRoutes.home);
                            }
                          });
                          return const SizedBox.shrink();
                        }
                        return Text(
                          'This screen updates automatically once the review '
                          'clears.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewNote extends StatelessWidget {
  const _ReviewNote({required this.icon, required this.text, required this.textColor});

  final IconData icon;
  final String text;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: AppDimensions.iconSm, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(color: textColor),
          ),
        ),
      ],
    );
  }
}
