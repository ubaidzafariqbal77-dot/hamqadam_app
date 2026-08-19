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

/// Multi-select for lookup-backed lists (e.g. known languages). Selected items
/// show as removable chips; a bottom sheet offers the full list.
class AppLookupMultiSelect extends StatelessWidget {
  const AppLookupMultiSelect({
    super.key,
    required this.label,
    required this.lookupKey,
    required this.controller,
    required this.selected,
    required this.onChanged,
    this.parentId,
    this.requirement = FieldRequirement.required,
    this.errorText,
  });

  final String label;
  final String lookupKey;
  final LookupController controller;
  final List<LookupItem> selected;
  final ValueChanged<List<LookupItem>> onChanged;
  final int? parentId;
  final FieldRequirement requirement;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return FormFieldContainer(
      label: label,
      requirement: requirement,
      errorText: errorText,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: InkWell(
        borderRadius: AppRadius.smAll,
        onTap: () => _openSheet(context),
        child: Row(
          children: <Widget>[
            Expanded(
              child: selected.isEmpty
                  ? Text(
                      'Tap to select',
                      style: AppTextStyles.body.copyWith(color: Theme.of(context).hintColor),
                    )
                  : Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: 6,
                      children: selected
                          .map(
                            (LookupItem i) => Chip(
                              label: Text(i.name.isEmpty ? '#${i.id}' : i.name),
                              labelStyle: AppTextStyles.caption.copyWith(color: Colors.white),
                              backgroundColor: AppColors.primary,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onDeleted: () => onChanged(
                                selected.where((LookupItem e) => e.id != i.id).toList(),
                              ),
                              deleteIconColor: Colors.white70,
                            ),
                          )
                          .toList(),
                    ),
            ),
            const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    controller.ensure(lookupKey, parentId: parentId);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        final RxList<LookupItem> temp = <LookupItem>[...selected].obs;
        final RxString query = ''.obs;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (BuildContext c, ScrollController scroll) {
            return Column(
              children: <Widget>[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(label, style: AppTextStyles.title),
                ),
                // Same searchable sheet as every other picker in the flow — a
                // lookup list can be long, so it is never an unsearchable list.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                  child: TextField(
                    autofocus: false,
                    onChanged: (String v) => query.value = v,
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
                  child: Obx(() {
                    final ApiState<List<LookupItem>> state = controller.stateOf(
                      lookupKey,
                      parentId: parentId,
                    );
                    if (state.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state.status == ApiStatus.empty) {
                      return const EmptyStateWidget(message: 'No options available.');
                    }
                    if (state.isError) {
                      return ErrorStateWidget(
                        message: state.message,
                        onRetry: () => controller.load(lookupKey, parentId: parentId, force: true),
                      );
                    }
                    final List<LookupItem> all = state.data ?? const <LookupItem>[];
                    final String q = query.value.trim().toLowerCase();
                    final List<LookupItem> items = q.isEmpty
                        ? all
                        : all
                            .where((LookupItem i) => i.name.toLowerCase().contains(q))
                            .toList();
                    // A search that matches nothing is not a load failure, so it
                    // must not offer a retry — only a genuinely empty list does.
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          'No matches for “${query.value.trim()}”',
                          style: AppTextStyles.body
                              .copyWith(color: Theme.of(context).hintColor),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scroll,
                      itemCount: items.length,
                      itemBuilder: (BuildContext c, int index) {
                        final LookupItem item = items[index];
                        return Obx(() {
                          final bool checked = temp.any((LookupItem e) => e.id == item.id);
                          return CheckboxListTile(
                            value: checked,
                            title: Text(item.name),
                            activeColor: AppColors.primary,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (_) {
                              if (checked) {
                                temp.removeWhere((LookupItem e) => e.id == item.id);
                              } else {
                                temp.add(item);
                              }
                            },
                          );
                        });
                      },
                    );
                  }),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
                      ),
                      onPressed: () {
                        onChanged(temp.toList());
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Done'),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
