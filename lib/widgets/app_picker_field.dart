import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import '../controllers/lookup_controller.dart';
import '../core/api/api_response.dart';
import '../models/lookup_item_model.dart';
import 'bilingual_text.dart';
import 'form_field_container.dart';
import 'state_widgets.dart';

/// A premium picker field backed by a [LookupController] entry: shows the
/// selected value in an underline field and opens a rounded bottom sheet with a
/// searchable, brand-highlighted list — a nicer alternative to a dropdown menu.
class AppLookupPicker extends StatelessWidget {
  const AppLookupPicker({
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

  LookupItem? _resolve(List<LookupItem> items) {
    if (selected == null) return null;
    for (final LookupItem i in items) {
      if (i.id == selected!.id) return i;
    }
    return selected!.name.isEmpty ? null : selected;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ApiState<List<LookupItem>> state = controller.stateOf(lookupKey, parentId: parentId);
      final List<LookupItem> items = state.data ?? const <LookupItem>[];
      final LookupItem? current = _resolve(items);
      final Color hintColor = Theme.of(context).hintColor;

      return FormFieldContainer(
        label: label,
        requirement: requirement,
        errorText: errorText,
        disabled: !enabled,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: InkWell(
          onTap: (!enabled)
              ? null
              : () => _open(context, items, state),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: current != null
                      ? Text(current.name, style: AppTextStyles.body)
                      : (enabled
                          ? BiText.inline(
                              hint,
                              textAlign: TextAlign.start,
                              style: AppTextStyles.body.copyWith(color: hintColor),
                            )
                          : Text(
                              disabledHint ?? 'Select the previous field first',
                              style: AppTextStyles.body.copyWith(color: hintColor),
                            )),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: hintColor),
              ],
            ),
          ),
        ),
      );
    });
  }

  Future<void> _open(
    BuildContext context,
    List<LookupItem> items,
    ApiState<List<LookupItem>> state,
  ) async {
    final LookupItem? picked = await showModalBottomSheet<LookupItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (BuildContext ctx) => _PickerSheet(
        title: label,
        items: items,
        selectedId: selected?.id,
        loading: state.status == ApiStatus.loading,
        onRetry: state.status == ApiStatus.loading
            ? null
            : () {
                controller.load(lookupKey, parentId: parentId, force: true);
                Navigator.of(ctx).pop();
              },
      ),
    );
    if (picked != null) onChanged(picked);
  }
}

/// A premium picker field backed by a plain [List<String>] of options — the
/// string-list counterpart of [AppLookupPicker]. Opens the same rounded,
/// searchable bottom sheet. When [allowCustom] is true, a user whose entry is
/// not in the list can type it in the search box and tap "Use …" to keep it.
class AppStringPicker extends StatelessWidget {
  const AppStringPicker({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.requirement = FieldRequirement.required,
    this.hint = 'Select',
    this.errorText,
    this.enabled = true,
    this.allowCustom = false,
    this.searchHint,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final FieldRequirement requirement;
  final String hint;
  final String? errorText;
  final bool enabled;

  /// Lets the user keep a free-text entry that is not in [options].
  final bool allowCustom;

  /// Optional hint shown inside the search box (defaults to "Search…").
  final String? searchHint;

  @override
  Widget build(BuildContext context) {
    final Color hintColor = Theme.of(context).hintColor;
    final bool hasValue = value != null && value!.trim().isNotEmpty;
    return FormFieldContainer(
      label: label,
      requirement: requirement,
      errorText: errorText,
      disabled: !enabled,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: enabled ? () => _open(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: hasValue
                    ? Text(value!, style: AppTextStyles.body)
                    : BiText.inline(
                        hint,
                        textAlign: TextAlign.start,
                        style: AppTextStyles.body.copyWith(color: hintColor),
                      ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, color: hintColor),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (BuildContext ctx) => _StringPickerSheet(
        title: label,
        options: options,
        selected: value,
        allowCustom: allowCustom,
        searchHint: searchHint,
      ),
    );
    if (picked != null) onChanged(picked);
  }
}

class _StringPickerSheet extends StatefulWidget {
  const _StringPickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.allowCustom,
    this.searchHint,
  });

  final String title;
  final List<String> options;
  final String? selected;
  final bool allowCustom;
  final String? searchHint;

  @override
  State<_StringPickerSheet> createState() => _StringPickerSheetState();
}

class _StringPickerSheetState extends State<_StringPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    // Search when the list is long, or whenever the user may type a custom entry.
    final bool searchable = widget.allowCustom || widget.options.length > 8;
    final String q = _query.trim();
    final List<String> filtered = q.isEmpty
        ? widget.options
        : widget.options
            .where((String o) => o.toLowerCase().contains(q.toLowerCase()))
            .toList();
    final bool showCustom = widget.allowCustom &&
        q.isNotEmpty &&
        !widget.options.any((String o) => o.toLowerCase() == q.toLowerCase());

    final double screenH = MediaQuery.of(context).size.height;
    final double estContent = 96 + (searchable ? 60 : 0) + widget.options.length * 56.0;
    final double initial = (estContent / screenH).clamp(0.32, 0.9);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: initial,
      minChildSize: 0.28,
      maxChildSize: 0.9,
      builder: (BuildContext ctx, ScrollController scroll) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: <Widget>[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BiText(widget.title, style: AppTextStyles.subtitle),
                ),
              ),
              if (searchable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                  child: TextField(
                    autofocus: false,
                    onChanged: (String v) => setState(() => _query = v),
                    style: AppTextStyles.body.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkInputText
                          : AppColors.lightInputText,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: widget.searchHint ??
                          (widget.allowCustom ? 'Search or type your own…' : 'Search…'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.mdAll,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: (filtered.isEmpty && !showCustom)
                    ? Center(
                        child: Text(
                          'No matches found',
                          style: AppTextStyles.body
                              .copyWith(color: Theme.of(context).hintColor),
                        ),
                      )
                    : ListView(
                        controller: scroll,
                        children: <Widget>[
                          if (showCustom)
                            ListTile(
                              leading: const Icon(Icons.add_circle_outline_rounded,
                                  color: AppColors.primary),
                              title: Text(
                                'Use “$q”',
                                style: AppTextStyles.body
                                    .copyWith(color: AppColors.primary),
                              ),
                              onTap: () => Navigator.of(context).pop(q),
                            ),
                          ...filtered.map((String o) {
                            final bool sel = o == widget.selected;
                            return ListTile(
                              onTap: () => Navigator.of(context).pop(o),
                              title: Text(
                                o,
                                style: AppTextStyles.body.copyWith(
                                  color: sel ? AppColors.primary : null,
                                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                ),
                              ),
                              trailing: sel
                                  ? const Icon(Icons.check_circle_rounded,
                                      color: AppColors.primary)
                                  : null,
                            );
                          }),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.selectedId,
    required this.loading,
    this.onRetry,
  });

  final String title;
  final List<LookupItem> items;
  final int? selectedId;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final bool searchable = widget.items.length > 10;
    final List<LookupItem> filtered = _query.isEmpty
        ? widget.items
        : widget.items
            .where((LookupItem i) => i.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    // Size the sheet to its content so short lists don't leave a big empty gap
    // below (grab handle + title ≈ 96, optional search ≈ 60, ~56 per row).
    final double screenH = MediaQuery.of(context).size.height;
    final double estContent =
        96 + (searchable ? 60 : 0) + widget.items.length * 56.0;
    final double initial = (estContent / screenH).clamp(0.32, 0.9);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: initial,
      minChildSize: 0.28,
      maxChildSize: 0.9,
      builder: (BuildContext ctx, ScrollController scroll) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: <Widget>[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BiText(widget.title, style: AppTextStyles.subtitle),
                ),
              ),
              if (searchable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                  child: TextField(
                    autofocus: false,
                    onChanged: (String v) => setState(() => _query = v),
                    style: AppTextStyles.body.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkInputText
                          : AppColors.lightInputText,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.mdAll,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: widget.loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : filtered.isEmpty
                        ? RetryWidget(
                            onRetry: widget.onRetry ?? () {},
                            message: 'No options found.',
                          )
                        : ListView.builder(
                            controller: scroll,
                            itemCount: filtered.length,
                            itemBuilder: (BuildContext c, int i) {
                              final LookupItem item = filtered[i];
                              final bool sel = item.id == widget.selectedId;
                              return ListTile(
                                onTap: () => Navigator.of(context).pop(item),
                                title: Text(
                                  item.name,
                                  style: AppTextStyles.body.copyWith(
                                    color: sel ? AppColors.primary : null,
                                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                                trailing: sel
                                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                                    : null,
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
