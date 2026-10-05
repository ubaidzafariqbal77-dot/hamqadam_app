import 'package:flutter/material.dart';

import '../constants/app_dimensions.dart';
import 'app_text_form_field.dart';

/// Password field with show/hide toggle. Reuses [AppTextFormField].
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.revalidateWhenControllerChanges,
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
  final TextEditingController? revalidateWhenControllerChanges;
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
  final GlobalKey<FormFieldState<String>> _fieldKey =
      GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    widget.revalidateWhenControllerChanges?.addListener(_revalidate);
  }

  @override
  void didUpdateWidget(covariant AppPasswordField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revalidateWhenControllerChanges !=
        widget.revalidateWhenControllerChanges) {
      oldWidget.revalidateWhenControllerChanges?.removeListener(_revalidate);
      widget.revalidateWhenControllerChanges?.addListener(_revalidate);
    }
  }

  void _revalidate() {
    if (widget.controller.text.isNotEmpty) {
      _fieldKey.currentState?.validate();
    }
  }

  @override
  void dispose() {
    widget.revalidateWhenControllerChanges?.removeListener(_revalidate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextFormField(
      fieldKey: _fieldKey,
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
