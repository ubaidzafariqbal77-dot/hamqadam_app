import 'package:flutter/material.dart';

import '../constants/app_dimensions.dart';
import 'app_text_form_field.dart';

/// Password field with show/hide toggle. Reuses [AppTextFormField].
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.focusNode,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.serverError,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final String? serverError;
  final String? hint;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AppTextFormField(
      label: widget.label,
      controller: widget.controller,
      validator: widget.validator,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      serverError: widget.serverError,
      hint: widget.hint,
      obscureText: _obscure,
      keyboardType: TextInputType.visiblePassword,
      prefixIcon: const Icon(Icons.lock_outline_rounded, size: AppDimensions.iconMd),
      suffixIcon: IconButton(
        icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
        tooltip: _obscure ? 'Show password' : 'Hide password',
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}
