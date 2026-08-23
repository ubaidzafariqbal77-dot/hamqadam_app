import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../widgets/surface_card.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/ai_verification_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../models/ai_verification_model.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/state_widgets.dart';

/// AI identity verification screen.
///
/// The check runs against the CNIC and selfie already submitted at registration
/// step 13 — this screen never asks for another upload. It shows the current
/// verdict, lets the member re-run the check, and explains the attempt history.
class AiVerificationView extends StatelessWidget {
  const AiVerificationView({super.key});

  @override
  Widget build(BuildContext context) {
    final AiVerificationController c = Get.find<AiVerificationController>();
    return Scaffold(
      appBar: const PremiumAppBar(
        title: 'Identity Verification',
        subtitle: 'Confirm your identity to build trust',
      ),
      body: Obx(() {
        final ApiState<AiVerificationModel> s = c.state.value;
        switch (s.status) {
          case ApiStatus.initial:
          case ApiStatus.loading:
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          case ApiStatus.noInternet:
            return NoInternetWidget(onRetry: c.load);
          case ApiStatus.unauthorized:
          case ApiStatus.serverError:
          case ApiStatus.validationError:
          case ApiStatus.empty:
            return ErrorStateWidget(message: s.message, onRetry: c.load);
          case ApiStatus.success:
            return _Body(controller: c, status: s.data!);
        }
      }),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller, required this.status});

  final AiVerificationController controller;
  final AiVerificationModel status;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.reload,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          _StatusCard(status: status),
          const SizedBox(height: AppSpacing.md),
          _ExplainerCard(status: status),
          if (status.showsAction) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Obx(
              () => AppButton(
                label: status.attempts > 0 ? 'Retry verification' : 'Verify my identity',
                icon: Icons.verified_user_rounded,
                loading: controller.running.value,
                onPressed: () => _run(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Obx(() {
              final String? msg = controller.lastRunMessage.value;
              if (msg == null || msg.isEmpty) return const SizedBox.shrink();
              return Text(msg, style: AppTextStyles.caption, textAlign: TextAlign.center);
            }),
          ],
          const SizedBox(height: AppSpacing.lg),
          _HistorySection(controller: controller),
        ],
      ),
    );
  }

  Future<void> _run(BuildContext context) async {
    final AiVerificationRunResult? result = await controller.runNow();
    if (result == null) {
      AppSnackbar.error(controller.lastRunMessage.value ?? 'Verification could not run.');
      return;
    }
    if (result.isApproved) {
      AppSnackbar.success(result.message);
    } else if (!result.serviceReachable) {
      // Worth distinguishing: nothing is wrong with the member's documents.
      AppSnackbar.error('The verification service is unreachable. Please try again later.');
    } else {
      AppSnackbar.info(result.message);
    }
  }
}

/// The headline verdict.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final AiVerificationModel status;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String title) = _visuals(context, status);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 48, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTextStyles.title.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
          if ((status.message ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(status.message!, style: AppTextStyles.body, textAlign: TextAlign.center),
          ],
          if (status.attempts > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Attempts: ${status.attempts}'
              '${status.recommendation != null ? '  ·  Last result: ${status.recommendation}' : ''}',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
          if (status.lastError != null && status.lastError!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(status.lastError!, style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  (Color, IconData, String) _visuals(BuildContext context, AiVerificationModel s) {
    if (s.isApproved) return (AppColors.success, Icons.verified_rounded, 'Identity verified');
    if (s.isRejected) {
      return (AppColors.error, Icons.gpp_bad_rounded, 'Verification did not pass');
    }
    if (s.needsManualReview) {
      return (AppColors.warning, Icons.person_search_rounded, 'Awaiting manual review');
    }
    if (s.hasFailed) {
      return (AppColors.warning, Icons.error_outline_rounded, 'Verification incomplete');
    }
    if (s.isPending) return (AppColors.info, Icons.hourglass_top_rounded, 'Verification running');
    return (Theme.of(context).hintColor, Icons.badge_outlined, 'Not verified yet');
  }
}

/// Explains what happens next, in the member's terms.
class _ExplainerCard extends StatelessWidget {
  const _ExplainerCard({required this.status});

  final AiVerificationModel status;

  @override
  Widget build(BuildContext context) {
    final List<String> points = _points(status);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CardTitle(icon: Icons.help_outline_rounded, title: 'How this works'),
          const SizedBox(height: AppSpacing.sm),
          ...points.map(
            (String p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 3, right: 8),
                    child: Icon(Icons.circle, size: 6, color: AppColors.primary),
                  ),
                  Expanded(child: Text(p, style: AppTextStyles.body)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _points(AiVerificationModel s) {
    if (s.isApproved) {
      return <String>[
        'Your CNIC and selfie matched, so your profile now carries a verified badge.',
        'Verified profiles are trusted more and get better responses.',
      ];
    }
    return <String>[
      'We check the CNIC and selfie you submitted during registration — you do not need to upload anything again.',
      'A clear, well-lit selfie where your face is fully visible gives the best result.',
      if (s.needsManualReview)
        'Our team reviews anything the automated check cannot decide. You can keep using the app meanwhile.',
      if (s.hasFailed)
        'The last attempt could not reach the verification service. Trying again usually resolves it.',
      'Your documents are never shared with other members.',
    ];
  }
}

/// Attempt history, loaded on demand.
class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.controller});

  final AiVerificationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ApiState<List<AiVerificationAttempt>> s = controller.history.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Verification history', style: AppTextStyles.subtitle),
              if (s.isInitial)
                TextButton(onPressed: controller.loadHistory, child: const Text('Show')),
            ],
          ),
          if (s.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (s.status == ApiStatus.empty)
            Text(s.message ?? 'No attempts yet.', style: AppTextStyles.caption)
          else if (s.isError)
            RetryWidget(message: s.message, onRetry: controller.loadHistory)
          else if (s.isSuccess)
            ...s.data!.map((AiVerificationAttempt a) => _AttemptTile(attempt: a)),
        ],
      );
    });
  }
}

class _AttemptTile extends StatelessWidget {
  const _AttemptTile({required this.attempt});

  final AiVerificationAttempt attempt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(attempt.sourceLabel, style: AppTextStyles.bodyStrong)),
                Text(attempt.recommendation ?? attempt.status, style: AppTextStyles.caption),
              ],
            ),
            const SizedBox(height: 4),
            // Whether the model could actually compare two images is the single
            // most useful thing here: a lone selfie can never produce a match.
            Text(
              attempt.comparedIdentity
                  ? 'Compared your selfie against your CNIC photo'
                  : 'Only one photo was available, so no identity comparison was possible',
              style: AppTextStyles.caption,
            ),
            if (attempt.faceDetected == false)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'No face was detected — usually the photo is too dark or blurred.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.warning),
                ),
              ),
            if ((attempt.errorMessage ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  attempt.errorMessage!,
                  style: AppTextStyles.caption.copyWith(color: AppColors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
