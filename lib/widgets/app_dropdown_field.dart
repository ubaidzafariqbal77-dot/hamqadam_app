import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import '../controllers/lookup_controller.dart';
import '../core/api/api_response.dart';
import '../models/lookup_item_model.dart';
import 'form_field_container.dart';
import 'state_widgets.dart';

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
    final String? effective = options.contains(value) ? value : null;
    return FormFieldContainer(
      label: label,
      requirement: requirement,
      errorText: errorText,
      disabled: !enabled,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effective,
          isExpanded: true,
          hint: Text(hint, style: AppTextStyles.body.copyWith(color: AppColors.primaryDark),),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,color: AppColors.primaryDark),
          borderRadius: AppRadius.mdAll,
          onChanged: enabled ? onChanged : null,
          items: options
              .map(
                (String o) => DropdownMenuItem<String>(
                  value: o,
                  child: Text(labelBuilder?.call(o) ?? o, style: AppTextStyles.body),
                ),
              )
              .toList(),
        ),
      ),
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
    return Obx(() {
      final ApiState<List<LookupItem>> state = controller.stateOf(lookupKey, parentId: parentId);
      return FormFieldContainer(
        label: label,
        requirement: requirement,
        errorText: errorText,
        disabled: !enabled,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        child: _buildContent(context, state),
      );
    });
  }

  Widget _buildContent(BuildContext context, ApiState<List<LookupItem>> state) {
    if (!enabled) {
      return _InlineHint(text: disabledHint ?? 'Select the previous field first');
    }
    switch (state.status) {
      case ApiStatus.loading:
        return const _InlineLoading();
      case ApiStatus.serverError:
      case ApiStatus.noInternet:
      case ApiStatus.unauthorized:
        return RetryWidget(
          onRetry: () => controller.load(lookupKey, parentId: parentId, force: true),
          message: state.message ?? 'Could not load options.',
        );
      case ApiStatus.empty:
        return const _InlineHint(text: 'No options available');
      case ApiStatus.initial:
      case ApiStatus.validationError:
      case ApiStatus.success:
        final List<LookupItem> items = state.data ?? const <LookupItem>[];
        final LookupItem? effective = _match(items, selected);
        return DropdownButtonHideUnderline(
          child: DropdownButton<LookupItem>(
            value: effective,
            isExpanded: true,
            hint: Text(
              hint,
              style: AppTextStyles.body.copyWith(color: AppColors.primaryDark),
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded,color: AppColors.primaryDark),
            borderRadius: AppRadius.mdAll,
            onChanged: onChanged,
            items: items
                .map(
                  (LookupItem i) => DropdownMenuItem<LookupItem>(
                    value: i,
                    child: Text(i.name, style: AppTextStyles.body),
                  ),
                )
                .toList(),
          ),
        );
    }
  }

  LookupItem? _match(List<LookupItem> items, LookupItem? sel) {
    if (sel == null) return null;
    for (final LookupItem i in items) {
      if (i.id == sel.id) return i;
    }
    return null;
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text('Loading…', style: AppTextStyles.body.copyWith(color: Theme.of(context).hintColor)),
      ],
    );
  }
}

class _InlineHint extends StatelessWidget {
  const _InlineHint({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Text(text, style: AppTextStyles.body.copyWith(color: Theme.of(context).hintColor)),
  );
}
