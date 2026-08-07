import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

/// Full-screen modal overlay shown during blocking operations (e.g. submit).
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.progress,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  /// 0..1 for determinate uploads; null for indeterminate.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        child,
        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: AppRadius.lgAll,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        height: 44,
                        width: 44,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3.2,
                          color: AppColors.primary,
                        ),
                      ),
                      if (progress != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${(progress! * 100).clamp(0, 100).toStringAsFixed(0)}%',
                          style: AppTextStyles.bodyStrong,
                        ),
                      ],
                      if ((message ?? '').isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        Text(message!, style: AppTextStyles.caption),
                      ],
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
