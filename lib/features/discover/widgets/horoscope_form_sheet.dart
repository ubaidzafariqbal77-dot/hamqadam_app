import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/horoscope_controller.dart';
import '../../../widgets/app_button.dart';

/// Bottom sheet for updating horoscope / astronomic details.
class HoroscopeFormSheet extends StatefulWidget {
  const HoroscopeFormSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HoroscopeFormSheet(),
    );
  }

  @override
  State<HoroscopeFormSheet> createState() => _HoroscopeFormSheetState();
}

class _HoroscopeFormSheetState extends State<HoroscopeFormSheet> {
  late final HoroscopeController _ctrl;
  late final TextEditingController _timeCtrl;
  late final TextEditingController _cityCtrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<HoroscopeController>();
    _timeCtrl = TextEditingController(text: _ctrl.timeOfBirth.value);
    _cityCtrl = TextEditingController(text: _ctrl.cityOfBirth.value);
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Horoscope Information', style: AppTextStyles.title),
                          Text(
                            'Update your astronomic details for better matching',
                            style: AppTextStyles.caption.copyWith(color: theme.hintColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.lightDivider),
              // Form content
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: <Widget>[
                    // ---- Time of Birth ----
                    _buildTextField(
                      controller: _timeCtrl,
                      label: 'Time of Birth',
                      hint: 'e.g. 09:30 PM',
                      icon: Icons.access_time_rounded,
                      required: true,
                      onChanged: (String v) => _ctrl.timeOfBirth.value = v,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ---- City of Birth ----
                    _buildTextField(
                      controller: _cityCtrl,
                      label: 'City of Birth',
                      hint: 'e.g. Lahore',
                      icon: Icons.location_city_rounded,
                      required: true,
                      onChanged: (String v) => _ctrl.cityOfBirth.value = v,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ---- Sun Sign ----
                    _buildDropdown(
                      title: 'Sun Sign',
                      items: _ctrl.sunSigns,
                      selectedValue: _ctrl.sunSign.value,
                      onChanged: (String v) => _ctrl.sunSign.value = v,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ---- Moon Sign ----
                    _buildDropdown(
                      title: 'Moon Sign',
                      items: _ctrl.moonSigns,
                      selectedValue: _ctrl.moonSign.value,
                      onChanged: (String v) => _ctrl.moonSign.value = v,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ---- Nakshatra ----
                    _buildDropdown(
                      title: 'Nakshatra',
                      items: _ctrl.nakshatras,
                      selectedValue: _ctrl.nakshatra.value,
                      onChanged: (String v) => _ctrl.nakshatra.value = v,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ---- Gana ----
                    _buildDropdown(
                      title: 'Gana',
                      items: _ctrl.ganaList,
                      selectedValue: _ctrl.gana.value,
                      onChanged: (String v) => _ctrl.gana.value = v,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ---- Nadi ----
                    _buildDropdown(
                      title: 'Nadi',
                      items: _ctrl.nadiList,
                      selectedValue: _ctrl.nadi.value,
                      onChanged: (String v) => _ctrl.nadi.value = v,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ---- Manglik ----
                    _buildDropdown(
                      title: 'Manglik',
                      items: _ctrl.manglikList,
                      selectedValue: _ctrl.manglik.value,
                      onChanged: (String v) => _ctrl.manglik.value = v,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ---- Save Button ----
                    Obx(() => AppButton(
                      label: _ctrl.saving.value ? 'Saving...' : 'Update Horoscope',
                      icon: Icons.check_circle_outline_rounded,
                      onPressed: _ctrl.saving.value ? null : _saveAndClose,
                    )),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveAndClose() async {
    _ctrl.timeOfBirth.value = _timeCtrl.text;
    _ctrl.cityOfBirth.value = _cityCtrl.text;
    final bool ok = await _ctrl.save();
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = false,
    required ValueChanged<String> onChanged,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(label, style: AppTextStyles.bodyStrong),
            if (required)
              const Text(' *', style: TextStyle(color: AppColors.error, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightDivider),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Theme.of(context).hintColor.withValues(alpha: 0.6)),
              prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String title,
    required List<Map<String, String>> items,
    required String selectedValue,
    required ValueChanged<String> onChanged,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String? currentLabel = items
        .where((Map<String, String> i) => i['value'] == selectedValue)
        .map((Map<String, String> i) => i['label'])
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: AppTextStyles.bodyStrong),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _openPicker(title: title, items: items, selectedValue: selectedValue, onSelect: onChanged),
          borderRadius: AppRadius.mdAll,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: selectedValue.isNotEmpty ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightDivider),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    currentLabel ?? 'Select $title',
                    style: TextStyle(
                      color: selectedValue.isNotEmpty
                          ? Theme.of(context).textTheme.bodyMedium?.color
                          : Theme.of(context).hintColor,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (selectedValue.isNotEmpty)
                  GestureDetector(
                    onTap: () => onChanged(''),
                    child: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).hintColor, size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openPicker({
    required String title,
    required List<Map<String, String>> items,
    required String selectedValue,
    required ValueChanged<String> onSelect,
  }) async {
    final String? result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SimplePicker(title: title, items: items, selectedValue: selectedValue),
    );
    if (result != null) onSelect(result);
  }
}

/// Simple searchable picker for horoscope dropdown options.
class _SimplePicker extends StatefulWidget {
  const _SimplePicker({
    required this.title,
    required this.items,
    required this.selectedValue,
  });

  final String title;
  final List<Map<String, String>> items;
  final String selectedValue;

  @override
  State<_SimplePicker> createState() => _SimplePickerState();
}

class _SimplePickerState extends State<_SimplePicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late List<Map<String, String>> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List<Map<String, String>>.from(widget.items);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final String query = q.toLowerCase().trim();
    setState(() {
      _filtered = query.isEmpty
          ? List<Map<String, String>>.from(widget.items)
          : widget.items.where((Map<String, String> i) => (i['label'] ?? '').toLowerCase().contains(query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      builder: (BuildContext ctx, ScrollController scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: Column(
            children: <Widget>[
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.hintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(widget.title, style: AppTextStyles.title)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop<String?>(null),
                    ),
                  ],
                ),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightDivider),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _focusNode,
                    onChanged: _filter,
                    decoration: InputDecoration(
                      hintText: 'Search ${widget.title.toLowerCase()}...',
                      hintStyle: TextStyle(color: theme.hintColor.withValues(alpha: 0.7), fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(child: Text('No results found'))
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: _filtered.length,
                        itemBuilder: (BuildContext c, int i) {
                          final Map<String, String> item = _filtered[i];
                          final bool isSelected = item['value'] == widget.selectedValue;
                          return ListTile(
                            dense: true,
                            leading: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                                : Icon(Icons.circle_outlined, size: 20, color: theme.hintColor),
                            title: Text(
                              item['label'] ?? item['value'] ?? '',
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppColors.primary : theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                            onTap: () => Navigator.of(ctx).pop<String?>(item['value']),
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
