import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'bilingual_text.dart';
import 'form_field_container.dart';

/// The workhorse text field. Filled with the required/optional background,
/// supports prefix/suffix, validators, server-side errors, counters and
/// multiline. Renders its own label + badge and validator error.
class AppTextFormField extends StatelessWidget {
  const AppTextFormField({
    super.key,
    required this.label,
    this.requirement = FieldRequirement.required,
    this.controller,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.focusNode,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.obscureText = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.serverError,
    this.showCounter = false,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.insetLabel = false,
  });

  final String label;

  /// Draw the label INSIDE the field, above the value — the registration
  /// references' field card. Off by default so Login and Forgot password keep
  /// the label-as-placeholder field they already use.
  final bool insetLabel;

  final FieldRequirement requirement;
  final TextEditingController? controller;
  final String? hint;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final bool obscureText;
  final bool enabled;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final TextInputAction? textInputAction;
  final String? serverError;
  final bool showCounter;
  final Iterable<String>? autofillHints;

  /// Names are typed in words case; most other fields want none.
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final bool hasServerError = (serverError ?? '').isNotEmpty;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color hintColor = Theme.of(context).hintColor;
    // Accent comes from the theme, not AppColors: registration overrides the
    // scheme with its muted rose while the rest of the app keeps brand pink.
    final Color accent = Theme.of(context).colorScheme.primary;

    // Premium filled look: a soft, neutral rounded field that lifts to the
    // brand colour (with a whisper of glow) when focused.
    final Color fill = enabled
        ? (dark ? AppColors.requiredFieldBackgroundDark : AppColors.requiredFieldBackgroundLight)
        : (dark ? AppColors.fieldDisabledBackgroundDark : AppColors.fieldDisabledBackgroundLight);
    final Color borderColor = dark ? AppColors.requiredFieldBorderDark : AppColors.lightBorder;

    OutlineInputBorder ob(Color c, [double w = 1.3]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );

    final Widget field = TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      // The text the user types is black (light) / near-white (dark) for
      // readability — everything else stays on the pink palette.
      style: AppTextStyles.body.copyWith(
        color: dark ? AppColors.darkInputText : AppColors.lightInputText,
      ),
      cursorColor: accent,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      maxLength: maxLength,
      obscureText: obscureText,
      enabled: enabled,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (String? value) {
        if (hasServerError) return serverError;
        return validator?.call(value);
      },
      buildCounter: showCounter
          ? null
          : (
              BuildContext c, {
              required int currentLength,
              required bool isFocused,
              int? maxLength,
            }) => null,
      decoration: InputDecoration(
        isDense: insetLabel,
        filled: !insetLabel,
        fillColor: fill,
        // The label doubles as the placeholder, shown bilingually inline.
        hint: BiText.inline(
          insetLabel ? (hint ?? '') : label,
          textAlign: TextAlign.start,
          style: AppTextStyles.body.copyWith(color: Theme.of(context).hintColor),
        ),
        prefixIcon: insetLabel ? null : prefixIcon,
        suffixIcon: suffixIcon,
        prefixIconColor: accent,
        suffixIconColor: hintColor,
        contentPadding: insetLabel
            ? EdgeInsets.zero
            : EdgeInsets.fromLTRB(prefixIcon == null ? 16 : 4, 16, 16, 16),
        border: insetLabel ? InputBorder.none : ob(borderColor),
        enabledBorder: insetLabel ? InputBorder.none : ob(borderColor),
        focusedBorder: insetLabel ? InputBorder.none : ob(accent, 1.6),
        errorBorder: insetLabel ? InputBorder.none : ob(AppColors.error),
        focusedErrorBorder:
            insetLabel ? InputBorder.none : ob(AppColors.error, 1.6),
        disabledBorder: insetLabel ? InputBorder.none : ob(borderColor),
      ),
    );

    if (!insetLabel) return field;

    // The reference's field card: the label sits inside, above the value, with
    // the leading disc to its left. FormFieldContainer already draws exactly
    // that for the pickers, so the two field families stay identical.
    return FormFieldContainer(
      label: label,
      requirement: requirement,
      leading: prefixIcon,
      child: field,
    );
  }
}
