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
  late String? _selectedGender;
  late int? _maritalStatusId;
  late int? _religionId;
  late int? _casteId;
  late int? _countryId;
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
      _selectedGender = null;
      _maritalStatusId = null;
      _religionId = null;
      _casteId = null;
      _countryId = null;
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
                      <String, String>{'id': 'compatibility', 'label': 'Best Match (Compatibility)'},
                      <String, String>{'id': 'latest', 'label': 'Recently Active'},
                      <String, String>{'id': 'newest', 'label': 'Newest Members'},
                      <String, String>{'id': 'age_asc', 'label': 'Age: Young to Old'},
                      <String, String>{'id': 'age_desc', 'label': 'Age: Old to Young'},
                    ].map((Map<String, String> item) {
                      final bool selected = _selectedSort == item['id'];
                      return ChoiceChip(
                        label: Text(item['label']!),
                        selected: selected,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : theme.textTheme.bodyMedium?.color,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (bool s) {
                          setState(() => _selectedSort = s ? item['id'] : null);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ---- Gender Selector ----
                  _sectionTitle('Gender', null),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      _genderChip('All', null),
                      const SizedBox(width: 8),
                      _genderChip('Male', '1'),
                      const SizedBox(width: 8),
                      _genderChip('Female', '2'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ---- Marital Status ----
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

                  // ---- Country ----
                  _dropdownSection(
                    title: 'Country',
                    lookupKey: LookupKeys.countries,
                    selectedValue: _countryId,
                    onChanged: (int? v) => setState(() {
                      _countryId = v;
                      _cityId = null;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ---- City ----
                  _dropdownSection(
                    title: 'City',
                    lookupKey: LookupKeys.cities,
                    selectedValue: _cityId,
                    onChanged: (int? v) => setState(() => _cityId = v),
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

  Widget _genderChip(String label, String? value) {
    final bool selected = _selectedGender == value;
    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(label)),
        selected: selected,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (bool s) {
          if (s) setState(() => _selectedGender = value);
        },
      ),
    );
  }

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
}
