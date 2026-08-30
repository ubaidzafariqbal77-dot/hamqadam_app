import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';
import '../../controllers/finalizing_controller.dart';
import '../../widgets/app_button.dart';

class FinalizingView extends StatefulWidget {
  const FinalizingView({super.key});
  @override
  State<FinalizingView> createState() => _FinalizingViewState();
}

class _FinalizingViewState extends State<FinalizingView> {
  late final FinalizingController c;

  @override
  void initState() {
    super.initState();
    c = Get.put(FinalizingController());
  }

  @override
  void dispose() {
    Get.delete<FinalizingController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: AppSpacing.lg),
                Text('Finalizing your profile', style: AppTextStyles.display),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Sending your answers, photos and documents securely. Keep the '
                  'app open — this only takes a moment.',
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _UploadProgress(controller: c),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: Obx(() {
                    if (c.missing.isNotEmpty) return _MissingSteps(controller: c);
                    final List<FinalizeStep> items = c.steps.toList();
                    final List<RejectedField> rejected = c.rejectedFields;
                    return ListView(
                      children: <Widget>[
                        for (int i = 0; i < items.length; i++) ...<Widget>[
                          _StepRow(step: items[i], controller: c),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        if (rejected.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Please fix these before trying again:',
                            style: AppTextStyles.bodyStrong,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          for (final RejectedField f in rejected)
                            _RejectedRow(field: f, controller: c),
                        ],
                      ],
                    );
                  }),
                ),
                _Footer(controller: c),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.controller});
  final FinalizeStep step;
  final FinalizingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int s = step.status.value;
      final bool failed = s == 3;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: failed ? () => controller.runOne(step) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: failed
                  ? AppColors.error.withValues(alpha: 0.06)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: failed ? AppColors.error.withValues(alpha: 0.4) : Theme.of(context).dividerColor,
              ),
            ),
            child: Row(
              children: <Widget>[
                _StatusIcon(status: s),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(step.label, style: AppTextStyles.bodyStrong),
                      if (failed && step.message.value.isNotEmpty)
                        Text(
                          step.message.value,
                          style: AppTextStyles.caption.copyWith(color: AppColors.error),
                        ),
                      if (failed)
                        Text(
                          'Tap to retry',
                          style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                        ),
                    ],
                  ),
                ),
                if (failed) const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final int status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 1:
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary),
        );
      case 2:
        return const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24);
      case 3:
        return const Icon(Icons.error_rounded, color: AppColors.error, size: 24);
      default:
        return Icon(Icons.circle_outlined, color: Theme.of(context).dividerColor, size: 22);
    }
  }
}

/// One backend-rejected field, tappable to jump back to its screen.
class _RejectedRow extends StatelessWidget {
  const _RejectedRow({required this.field, required this.controller});
  final RejectedField field;
  final FinalizingController controller;

  @override
  Widget build(BuildContext context) {
    final bool canJump = field.uiStep != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: canJump ? () => controller.goToRejected(field) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.06),
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        field.label,
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(field.message, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                      if (field.stepTitle != null)
                        Text(
                          'Tap to edit “${field.stepTitle}”',
                          style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                        ),
                    ],
                  ),
                ),
                if (canJump)
                  const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Real byte progress for the single multipart upload.
class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.controller});
  final FinalizingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.missing.isNotEmpty) return const SizedBox.shrink();
      final double value = controller.uploadProgress.value;
      final bool active = controller.running.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              // An indeterminate bar while the server processes the finished
              // upload, a real one while bytes are still going out.
              value: active && value > 0 && value < 1 ? value : (active ? null : value),
              minHeight: 6,
              backgroundColor: Theme.of(context).dividerColor,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value >= 1
                ? 'Upload complete — waiting for confirmation…'
                : 'Uploading ${(value * 100).round()}%',
            style: AppTextStyles.caption.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      );
    });
  }
}

/// Shown when a mandatory screen was never filled in: the backend validates the
/// whole payload at once, so it is caught here before the request goes out.
///
/// Each row is tappable — tapping jumps directly to that step, and after the
/// user fills it in and taps Save the controller brings them back here and
/// rechecks.
class _MissingSteps extends StatelessWidget {
  const _MissingSteps({required this.controller});
  final FinalizingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'A few required sections are still empty:',
          style: AppTextStyles.bodyStrong,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (int i = 0; i < controller.missing.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppRadius.mdAll,
                onTap: () => controller.goToMissingStep(controller.missing[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.06),
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.edit_outlined, size: 18, color: AppColors.error),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              controller.missingTitles[i],
                              style: AppTextStyles.bodyStrong.copyWith(
                                color: AppColors.error,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Tap to fill in',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});
  final FinalizingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.missing.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: AppButton(
            label: 'Complete the missing sections',
            onPressed: controller.fixMissingStep,
          ),
        );
      }
      if (controller.running.value || !controller.hasFailures) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: AppButton(label: 'Try again', onPressed: controller.run),
      );
    });
  }
}
