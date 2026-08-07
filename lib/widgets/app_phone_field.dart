import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_dimensions.dart';
import 'app_text_form_field.dart';
import 'form_field_container.dart';

/// Phone input restricted to digits and an optional leading `+`.
class AppPhoneField extends StatelessWidget {
  const AppPhoneField({
    super.key,
    required this.label,
    required this.controller,
    this.requirement = FieldRequirement.required,
    this.validator,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.serverError,
    this.hint = '03001234567',
  });

  final String label;
  final TextEditingController controller;
  final FieldRequirement requirement;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final TextInputAction? textInputAction;
  final String? serverError;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return AppTextFormField(
      label: label,
      controller: controller,
      requirement: requirement,
      validator: validator,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      serverError: serverError,
      hint: hint,
      keyboardType: TextInputType.phone,
      autofillHints: const <String>[AutofillHints.telephoneNumber],
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
        LengthLimitingTextInputFormatter(16),
      ],
      prefixIcon: const Icon(Icons.phone_outlined, size: AppDimensions.iconMd),
    );
  }
}
