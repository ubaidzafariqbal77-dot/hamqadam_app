import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_lookups.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/search_profiles_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../widgets/app_button.dart';

/// Modal bottom sheet for configuring search and filter options.
class SearchFilterBottomSheet extends StatefulWidget {
  const SearchFilterBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    final SearchProfilesController c = Get.find<SearchProfilesController>();
    c.prepareDraftFilter();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => const SearchFilterBottomSheet(),
    );
  }

  @override
  State<SearchFilterBottomSheet> createState() => _SearchFilterBottomSheetState();
}

class _SearchFilterBottomSheetState extends State<SearchFilterBottomSheet> {
  final SearchProfilesController _controller = Get.find<SearchProfilesController>();
  final LookupController _lookup = Get.find<LookupController>();

  late RangeValues _ageRange;
  late double _minCompatibility;
  late bool _verifiedOnly;
  late bool _photoOnly;
  late bool _nearby;
  late String? _selectedSort;
  /// Carried through untouched so applying the sheet cannot drop the
  /// opposite-gender rule. There is no control that edits it.
  late String? _selectedGender;
  late int? _maritalStatusId;
  late int? _religionId;
  late int? _casteId;
  late int? _countryId;
  late int? _stateId;
  late int? _cityId;

  @override
  void initState() {
    super.initState();
    final SearchFilterModel f = _controller.draftFilter.value;
    _ageRange = RangeValues(
      (f.ageMin ?? 18).toDouble().clamp(18, 70),
      (f.ageMax ?? 60).toDouble().clamp(18, 70),
    );
    _minCompatibility = (f.compatibilityMin ?? 0).toDouble().clamp(0, 100);
    _verifiedOnly = f.verifiedOnly;
    _photoOnly = f.photoOnly;
    _nearby = f.nearby;
    _selectedSort = f.sort;
    _selectedGender = f.gender;
    _maritalStatusId = f.maritalStatusId;
    _religionId = f.religionId;
    _casteId = f.casteId;
    _countryId = f.countryId;
    _stateId = f.stateId;
    _cityId = f.cityId;
  }

  void _resetAll() {
    setState(() {
      _ageRange = const RangeValues(18, 60);
      _minCompatibility = 0;
      _verifiedOnly = false;
      _photoOnly = false;
      _nearby = false;
      _selectedSort = null;
      // `_selectedGender` deliberately survives a reset — it is the
      // opposite-gender rule, not one of the filters being cleared.
      _maritalStatusId = null;
      _religionId = null;
      _casteId = null;
      _countryId = null;
      _stateId = null;
      _cityId = null;
    });
  }

  void _apply() {
    final SearchFilterModel updated = SearchFilterModel(
      ageMin: _ageRange.start.round() > 18 ? _ageRange.start.round() : null,
      ageMax: _ageRange.end.round() < 60 ? _ageRange.end.round() : null,
      verifiedOnly: _verifiedOnly,
      photoOnly: _photoOnly,
      compatibilityMin: _minCompatibility.round() > 0 ? _minCompatibility.round() : null,
      nearby: _nearby,
      sort: _selectedSort,
      gender: _selectedGender,
      maritalStatusId: _maritalStatusId,
      religionId: _religionId,
      casteId: _casteId,
      countryId: _countryId,
      stateId: _stateId,
      cityId: _cityId,
      searchQuery: _controller.filter.value.searchQuery,
    );

    _controller.applyFilter(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: theme.hintColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Text('Filters', style: AppTextStyles.title),
                  const Spacer(),
                  TextButton(
                    onPressed: _resetAll,
                    child: Text(
                      'Reset All',
                      style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.lightDivider),
            // Filter form content
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                children: <Widget>[
                  // ---- Age Range ----
                  _sectionTitle('Age Range', '${_ageRange.start.round()} - ${_ageRange.end.round()} years'),
                  RangeSlider(
                    values: _ageRange,
                    min: 18,
                    max: 70,
                    divisions: 52,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.primary.withValues(alpha: 0.15),
                    labels: RangeLabels(
                      '${_ageRange.start.round()}',
                      '${_ageRange.end.round()}',
                    ),
                    onChanged: (RangeValues v) => setState(() => _ageRange = v),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ---- Compatibility Min ----
                  _sectionTitle(
                    'Minimum Compatibility',
                    _minCompatibility > 0 ? '${_minCompatibility.round()}%' : 'Any match',
                  ),
                  Slider(
                    value: _minCompatibility,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.primary.withValues(alpha: 0.15),
                    label: _minCompatibility > 0 ? '${_minCompatibility.round()}%' : 'Any',
                    onChanged: (double v) => setState(() => _minCompatibility = v),
                  ),
                  Wrap(
                    spacing: 8,
                    children: <int>[0, 50, 70, 80, 90].map((int val) {
                      final bool selected = _minCompatibility.round() == val;
                      return ChoiceChip(
                        label: Text(val == 0 ? 'All' : '$val%+'),
                        selected: selected,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : theme.textTheme.bodyMedium?.color,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (bool s) {
                          if (s) setState(() => _minCompatibility = val.toDouble());
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ---- Quick Badges & Flags ----
                  _sectionTitle('Quick Options', null),
                  const SizedBox(height: 6),
                  _toggleTile(
                    title: 'Verified Profiles Only',
                    subtitle: 'Only show members with approved identity',
                    icon: Icons.verified_rounded,
                    iconColor: AppColors.info,
                    value: _verifiedOnly,
                    onChanged: (bool v) => setState(() => _verifiedOnly = v),
                  ),
                  const SizedBox(height: 8),
                  _toggleTile(
                    title: 'Profiles with Photo Only',
                    subtitle: 'Hide profiles without a display picture',
                    icon: Icons.photo_camera_rounded,
                    iconColor: AppColors.primary,
                    value: _photoOnly,
                    onChanged: (bool v) => setState(() => _photoOnly = v),
                  ),
                  const SizedBox(height: 8),
                  _toggleTile(
                    title: 'Nearby Profiles',
                    subtitle: 'Show matches in your location first',
                    icon: Icons.near_me_rounded,
                    iconColor: AppColors.success,
                    value: _nearby,
                    onChanged: (bool v) => setState(() => _nearby = v),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ---- Sort By ----
                  _sectionTitle('Sort By', null),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Map<String, String>>[
                      <String, String>{'id': 'compatibility', 'label': 'Best Match'},
                      <String, String>{'id': 'latest', 'label': 'Recently Active'},
                      <String, String>{'id': 'newest', 'label': 'Newest'},
                      <String, String>{'id': 'age_asc', 'label': 'Young to Old'},
                      <String, String>{'id': 'age_desc', 'label': 'Old to Young'},
                    ].map((Map<String, String> item) {
                      final bool selected = _selectedSort == item['id'];
                      return ChoiceChip(
                        label: Text(item['label']!),
                        selected: selected,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : theme.textTheme.bodyMedium?.color,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (bool s) {
                          setState(() => _selectedSort = s ? item['id'] : null);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // No gender selector: Discover only ever lists the other
                  // gender, so offering "All / Male / Female" here let a member
                  // browse their own gender. SearchProfilesController pins it.

                  // ---- Marital Status (small list — safe as dropdown) ----
                  _dropdownSection(
                    title: 'Marital Status',
                    lookupKey: LookupKeys.maritalStatuses,
                    selectedValue: _maritalStatusId,
                    onChanged: (int? v) => setState(() => _maritalStatusId = v),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ---- Religion ----
                  _dropdownSection(
                    title: 'Religion',
                    lookupKey: LookupKeys.religions,
                    selectedValue: _religionId,
                    onChanged: (int? v) => setState(() {
                      _religionId = v;
                      _casteId = null; // reset caste on religion change
                    }),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ---- Caste ----
                  _dropdownSection(
                    title: 'Caste / Community',
                    lookupKey: LookupKeys.castes,
                    parentId: _religionId,
                    selectedValue: _casteId,
                    onChanged: (int? v) => setState(() => _casteId = v),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ---- Country (searchable for 241 items) ----
                  _searchableField(
                    title: 'Country',
                    lookupKey: LookupKeys.countries,
                    selectedId: _countryId,
                    hintText: 'Search country...',
                    onSelect: (int? v) => setState(() {
                      _countryId = v;
                      _stateId = null; // reset state + city when country changes
                      _cityId = null;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ---- State / Region (searchable for 4000+ items) ----
                  _searchableField(
                    title: 'State / Region',
                    lookupKey: LookupKeys.states,
                    parentId: _countryId,
                    selectedId: _stateId,
                    hintText: 'Search state...',
                    onSelect: (int? v) => setState(() {
                      _stateId = v;
                      _cityId = null; // reset city when state changes
                    }),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ---- City (searchable for 47000+ items) ----
                  _searchableField(
                    title: 'City',
                    lookupKey: LookupKeys.cities,
                    parentId: _stateId,
                    selectedId: _cityId,
                    hintText: 'Search city...',
                    onSelect: (int? v) => setState(() => _cityId = v),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
            // Bottom Action Button
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBackground,
                border: const Border(top: BorderSide(color: AppColors.lightDivider)),
              ),
              child: AppButton(
                label: 'Apply Filters',
                icon: Icons.check_circle_outline_rounded,
                onPressed: _apply,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String? highlight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(title, style: AppTextStyles.bodyStrong),
        if (highlight != null)
          Text(
            highlight,
            style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primary),
          ),
      ],
    );
  }

  Widget _toggleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: value ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightDivider),
            width: value ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: AppTextStyles.bodyStrong),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeTrackColor: AppColors.primary,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  /// Small dropdown for lists with < 50 items (marital statuses, religions, castes).
  Widget _dropdownSection({
    required String title,
    required String lookupKey,
    int? parentId,
    required int? selectedValue,
    required ValueChanged<int?> onChanged,
  }) {
    final List<LookupItem> items = _lookup.itemsOf(lookupKey, parentId: parentId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: AppTextStyles.bodyStrong),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurfaceAlt
                : AppColors.lightSurface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: selectedValue != null ? AppColors.primary : AppColors.lightDivider,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: items.any((LookupItem i) => i.id == selectedValue) ? selectedValue : null,
              isExpanded: true,
              hint: Text('Any $title', style: AppTextStyles.body.copyWith(color: Theme.of(context).hintColor)),
              items: <DropdownMenuItem<int?>>[
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Any $title', style: AppTextStyles.body),
                ),
                ...items.map((LookupItem item) => DropdownMenuItem<int?>(
                      value: item.id,
                      child: Text(item.name, style: AppTextStyles.body),
                    )),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  /// Searchable field for large lists (countries, states, cities).
  /// Opens a full-screen searchable dialog instead of a dropdown.
  Widget _searchableField({
    required String title,
    required String lookupKey,
    int? parentId,
    required int? selectedId,
    required String hintText,
    required ValueChanged<int?> onSelect,
  }) {
    final List<LookupItem> allItems = _lookup.itemsOf(lookupKey, parentId: parentId);
    final String selectedName = selectedId != null
        ? allItems
            .where((LookupItem i) => i.id == selectedId)
            .map((LookupItem i) => i.name)
            .firstOrNull ?? 'Unknown'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: AppTextStyles.bodyStrong),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _openSearchDialog(
            title: title,
            items: allItems,
            selectedId: selectedId,
            hintText: hintText,
            onSelect: (int? id) {
              onSelect(id);
            },
          ),
          borderRadius: AppRadius.mdAll,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurfaceAlt
                  : AppColors.lightSurface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: selectedId != null ? AppColors.primary : AppColors.lightDivider,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: selectedId != null
                      ? Text(
                          selectedName,
                          style: AppTextStyles.body.copyWith(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Text(
                          'Any $title',
                          style: AppTextStyles.body.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                ),
                if (selectedId != null)
                  GestureDetector(
                    onTap: () => onSelect(null),
                    child: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.search_rounded, size: 20, color: Theme.of(context).hintColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Opens a searchable dialog to pick an item from a large list.
  Future<void> _openSearchDialog({
    required String title,
    required List<LookupItem> items,
    required int? selectedId,
    required String hintText,
    required ValueChanged<int?> onSelect,
  }) async {
    final int? result = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _SearchablePicker(
        title: title,
        items: items,
        selectedId: selectedId,
        hintText: hintText,
      ),
    );
    // result is null when user taps "Clear" or back
    onSelect(result);
  }
}

// ---------------------------------------------------------------------------
// Searchable Picker — a bottom sheet with search field + filtered list
// ---------------------------------------------------------------------------

class _SearchablePicker extends StatefulWidget {
  const _SearchablePicker({
    required this.title,
    required this.items,
    required this.selectedId,
    required this.hintText,
  });

  final String title;
  final List<LookupItem> items;
  final int? selectedId;
  final String hintText;

  @override
  State<_SearchablePicker> createState() => _SearchablePickerState();
}

class _SearchablePickerState extends State<_SearchablePicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<LookupItem> _filtered = <LookupItem>[];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final String q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.items;
      } else {
        _filtered = widget.items
            .where((LookupItem i) => i.name.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (BuildContext ctx, ScrollController scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: Column(
            children: <Widget>[
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.hintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(widget.title, style: AppTextStyles.title),
                    ),
                    if (widget.selectedId != null)
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop<int?>(null),
                        child: const Text('Clear', style: TextStyle(color: AppColors.error)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop<int?>(widget.selectedId),
                    ),
                  ],
                ),
              ),
              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
                    ),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _focusNode,
                    onChanged: _filter,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        color: theme.hintColor.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Item count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_filtered.length} result${_filtered.length == 1 ? '' : 's'}',
                    style: AppTextStyles.caption.copyWith(color: theme.hintColor),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // List
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            'No results found',
                            style: TextStyle(color: theme.hintColor, fontSize: 15),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: _filtered.length,
                        itemBuilder: (BuildContext ctx, int i) {
                          final LookupItem item = _filtered[i];
                          final bool isSelected = item.id == widget.selectedId;
                          return ListTile(
                            dense: true,
                            leading: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                                : const Icon(Icons.circle_outlined, size: 22, color: Colors.grey),
                            title: Text(
                              item.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppColors.primary : theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                            onTap: () => Navigator.of(ctx).pop<int?>(item.id),
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
