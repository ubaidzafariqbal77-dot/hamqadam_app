import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import 'bilingual_text.dart';

/// Whether a field must be filled to continue.
enum FieldRequirement { required, optional }

/// Resolves theme-aware background/border colours for the required/optional
/// field system. Defined centrally so no screen assigns these colours itself.
class FieldStyle {
  const FieldStyle._();

  static Color background(
    BuildContext context,
    FieldRequirement req, {
    bool hasError = false,
    bool disabled = false,
  }) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (disabled) {
      return dark ? AppColors.fieldDisabledBackgroundDark : AppColors.fieldDisabledBackgroundLight;
    }
    if (hasError) {
      return dark ? AppColors.fieldErrorBackgroundDark : AppColors.fieldErrorBackgroundLight;
    }
    switch (req) {
      case FieldRequirement.required:
        return dark
            ? AppColors.requiredFieldBackgroundDark
            : AppColors.requiredFieldBackgroundLight;
      case FieldRequirement.optional:
        return dark
            ? AppColors.optionalFieldBackgroundDark
            : AppColors.optionalFieldBackgroundLight;
    }
  }

  static Color border(
    BuildContext context,
    FieldRequirement req, {
    bool hasError = false,
    bool focused = false,
  }) {
    if (hasError) return AppColors.error;
    if (focused) return AppColors.primary;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    switch (req) {
      case FieldRequirement.required:
        return dark ? AppColors.requiredFieldBorderDark : AppColors.requiredFieldBorderLight;
      case FieldRequirement.optional:
        return dark ? AppColors.optionalFieldBorderDark : AppColors.optionalFieldBorderLight;
    }
  }
}

/// Renders a labelled field wrapper: label + required/optional badge, the field
/// content on the correctly-tinted background, and an error line.
class FormFieldContainer extends StatelessWidget {
  const FormFieldContainer({
    super.key,
    required this.label,
    required this.requirement,
    required this.child,
    this.errorText,
    this.helperText,
    this.disabled = false,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
  });

  final String label;
  final FieldRequirement requirement;
  final Widget child;
  final String? errorText;
  final String? helperText;
  final bool disabled;
  final EdgeInsets padding;

  bool get _hasError => (errorText ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final Color textSecondary = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.lightTextSecondary;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color fill = disabled
        ? (dark ? AppColors.fieldDisabledBackgroundDark : AppColors.fieldDisabledBackgroundLight)
        : (dark ? AppColors.requiredFieldBackgroundDark : AppColors.requiredFieldBackgroundLight);
    final Color borderColor = dark ? AppColors.requiredFieldBorderDark : AppColors.lightBorder2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: BiText.inline(
            label,
            textAlign: TextAlign.start,
            style: AppTextStyles.caption.copyWith(color: textSecondary),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hasError ? AppColors.error : borderColor,
              width: 1.3,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: child,
        ),
        if (_hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: <Widget>[
                const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    errorText!,
                    style: AppTextStyles.caption.copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          )
        else if ((helperText ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: BiText(
              helperText!,
              style: AppTextStyles.caption.copyWith(color: textSecondary),
            ),
          ),
      ],
    );
  }
}

/// Standalone label row for fields that render their own input/error
/// (e.g. [AppTextFormField]). The `requirement` argument is kept for API
/// compatibility but is no longer shown as a text badge.
class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.label, this.requirement = FieldRequirement.required});

  final String label;
  final FieldRequirement requirement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: BiText(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.label.copyWith(
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
      ),
    );
  }
}
