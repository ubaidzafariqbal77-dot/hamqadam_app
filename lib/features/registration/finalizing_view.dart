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
                  'Saving your details securely. This will only take a moment.',
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Expanded(
                  child: Obx(() {
                    final List<FinalizeStep> items = c.steps.toList();
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (BuildContext ctx, int i) =>
                          _StepRow(step: items[i], controller: c),
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

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});
  final FinalizingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.running.value || !controller.hasFailures) {
        return const SizedBox.shrink();
      }
      return Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Retry failed steps', onPressed: controller.run),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: controller.continueAnyway,
            child: const Text('Continue to app anyway'),
          ),
        ],
      );
    });
  }
}
