import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import 'app_button.dart';

/// Generic centred message + icon + optional action. The building block for the
/// empty/error/no-internet states.
class _StateBase extends StatelessWidget {
  const _StateBase({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: iconColor ?? AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.title, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.outline,
                icon: Icons.refresh_rounded,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key, this.title, this.message, this.onRefresh});
  final String? title;
  final String? message;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => _StateBase(
    icon: Icons.inbox_rounded,
    title: title ?? AppStrings.emptyTitle,
    message: message ?? 'There is nothing to show right now.',
    actionLabel: onRefresh == null ? null : AppStrings.refresh,
    onAction: onRefresh,
    iconColor: AppColors.optionalBadge,
  );
}

class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({super.key, this.title, this.message, this.onRetry});
  final String? title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _StateBase(
    icon: Icons.error_outline_rounded,
    title: title ?? AppStrings.serverErrorTitle,
    message: message ?? AppStrings.serverErrorMessage,
    actionLabel: onRetry == null ? null : AppStrings.retry,
    onAction: onRetry,
    iconColor: AppColors.error,
  );
}

class NoInternetWidget extends StatelessWidget {
  const NoInternetWidget({super.key, this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _StateBase(
    icon: Icons.wifi_off_rounded,
    title: AppStrings.noInternetTitle,
    message: AppStrings.noInternetMessage,
    actionLabel: onRetry == null ? null : AppStrings.retry,
    onAction: onRetry,
    iconColor: AppColors.warning,
  );
}

/// Compact inline retry row for small areas (e.g. failed dropdown load).
class RetryWidget extends StatelessWidget {
  const RetryWidget({super.key, required this.onRetry, this.message});
  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message ?? 'Could not load. Tap retry.',
            style: AppTextStyles.caption.copyWith(color: AppColors.error),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, AppDimensions.minTouchTarget),
          ),
          child: const Text(AppStrings.retry),
        ),
      ],
    );
  }
}
