import 'package:flutter/material.dart';

import '../controllers/lookup_controller.dart';
import '../models/lookup_item_model.dart';
import 'app_picker_field.dart';
import 'form_field_container.dart';

/// Generic dropdown for a fixed list of string options.
class AppOptionDropdown extends StatelessWidget {
  const AppOptionDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.requirement = FieldRequirement.required,
    this.hint = 'Select',
    this.errorText,
    this.enabled = true,
    this.labelBuilder,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final FieldRequirement requirement;
  final String hint;
  final String? errorText;
  final bool enabled;
  final String Function(String)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    // Renders as the same searchable bottom sheet as every other picker in the
    // flow, so no dropdown in registration is ever an unsearchable menu.
    final List<String> labels =
        labelBuilder == null ? options : options.map(labelBuilder!).toList();
    final String? shown = options.contains(value)
        ? (labelBuilder?.call(value!) ?? value)
        : null;
    return AppStringPicker(
      label: label,
      value: shown,
      options: labels,
      requirement: requirement,
      hint: hint,
      errorText: errorText,
      enabled: enabled,
      onChanged: (String? picked) {
        if (picked == null || labelBuilder == null) return onChanged(picked);
        // Map the chosen label back to the option it was built from.
        final int i = labels.indexOf(picked);
        onChanged(i >= 0 ? options[i] : picked);
      },
    );
  }
}

/// Dropdown backed by a [LookupController] entry. Handles inline loading, empty
/// and retry states for dynamic and dependent lookups.
class AppLookupDropdown extends StatelessWidget {
  const AppLookupDropdown({
    super.key,
    required this.label,
    required this.lookupKey,
    required this.controller,
    required this.selected,
    required this.onChanged,
    this.parentId,
    this.requirement = FieldRequirement.required,
    this.hint = 'Select',
    this.errorText,
    this.enabled = true,
    this.disabledHint,
  });

  final String label;
  final String lookupKey;
  final LookupController controller;
  final LookupItem? selected;
  final ValueChanged<LookupItem?> onChanged;
  final int? parentId;
  final FieldRequirement requirement;
  final String hint;
  final String? errorText;
  final bool enabled;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    // Delegates to [AppLookupPicker] so every lookup dropdown opens the same
    // searchable sheet. Loading, retry and empty states are handled inside it.
    return AppLookupPicker(
      label: label,
      lookupKey: lookupKey,
      controller: controller,
      selected: selected,
      onChanged: onChanged,
      parentId: parentId,
      requirement: requirement,
      hint: hint,
      errorText: errorText,
      enabled: enabled,
      disabledHint: disabledHint,
    );
  }
}
