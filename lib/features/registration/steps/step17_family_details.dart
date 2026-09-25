import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/api_options.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_lookups.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_pill_grid.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/bilingual_text.dart';
import '../../../widgets/form_field_container.dart';
import '../../../widgets/step_scaffold.dart';
import '../../../constants/app_dimensions.dart';

/// Screen 17 — Family details, the API's step 16
/// (`POST /auth/register/step/16`, skippable).
///
/// `live_with_family` (yes/no) and `family_values` (Elite…Poor) are hardcoded
/// options; `family_country_id` is a dynamic dropdown, while the API stores the
/// family's state and city as plain names.
class Step17Controller extends StepController {
  Step17Controller() : super(17);

  LookupController get lookup => Get.find<LookupController>();

  final TextEditingController familyLocation = TextEditingController();
  final RxnString liveWithFamily = RxnString();
  final RxnString familyValues = RxnString();
  final Rxn<LookupItem> country = Rxn<LookupItem>();
  final Rxn<LookupItem> state = Rxn<LookupItem>();
  final Rxn<LookupItem> city = Rxn<LookupItem>();

  /// The family's own location is only asked when the member lives apart.
  bool get showExtraLocation => liveWithFamily.value == 'no';

  @override
  void restore() {
    familyLocation.text = buffer.getString('family_location') ?? '';
    familyValues.value = buffer.getString('family_values');
    liveWithFamily.value = buffer.getString('live_with_family');
    lookup.ensure(LookupKeys.countries);
    final int? co = buffer.getInt('family_country_id');
    if (co != null) {
      country.value = LookupItem(id: co, name: '');
      lookup.ensure(LookupKeys.states, parentId: co);
    }
  }

  void onCountry(LookupItem? v) {
    country.value = v;
    state.value = null;
    city.value = null;
    if (v != null) lookup.ensure(LookupKeys.states, parentId: v.id);
  }

  void onState(LookupItem? v) {
    state.value = v;
    city.value = null;
    if (v != null) lookup.ensure(LookupKeys.cities, parentId: v.id);
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'family_location': familyLocation.text.trim(),
    'live_with_family': liveWithFamily.value,
    'family_values': familyValues.value,
    if (showExtraLocation) ...<String, dynamic>{
      'family_country_id': country.value?.id,
      'family_state': state.value?.name,
      'family_city': city.value?.name,
    },
  };

  @override
  void disposeFields() => familyLocation.dispose();
}

class Step17View extends StatefulWidget {
  const Step17View({super.key});
  @override
  State<Step17View> createState() => _Step17ViewState();
}

class _Step17ViewState extends State<Step17View> {
  late final Step17Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step17Controller());
  }

  @override
  void dispose() {
    Get.delete<Step17Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The Family-details reference draws its questions on the blush canvas
    // itself — no floating white card — with serif rose section headings.
    return StepScaffold(
      stepNumber: 17,
      totalSteps: 18,
      title: 'Family details',
      flat: true,
      // The reference has no illustration slot — just the serif title.
      subtitle: 'A little more about your family (optional).',
      busy: c.busy,
      error: c.error,
      formKey: c.formKey,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      showSkip: true,
      onSkip: c.skip,
      children: <Widget>[
        AppTextFormField(
          insetLabel: true,
          label: 'Family location',
          controller: c.familyLocation,
          requirement: FieldRequirement.optional,
          hint: 'e.g. Lahore, Pakistan',
          textInputAction: TextInputAction.done,
          // The reference marks this row with a location pin.
          prefixIcon: const Icon(Icons.location_on_rounded),
        ),
        Obx(
          () => AppPillGrid(
            label: 'Living with family?',
            // The reference's chosen pill: pink gradient fill, white circled
            // check and white label.
            checkWhenSelected: true,
            labelStyle: _sectionHeading(context),
            options: ApiOptions.liveWithFamily
                .map((LookupItem o) => PillOption(o.code!, o.name))
                .toList(),
            selected: c.liveWithFamily.value,
            onSelect: (PillOption o) => c.liveWithFamily.value = o.value as String,
          ),
        ),
        // Financial status uses the reference's icon-tile grid: a thin rose
        // glyph (crown / diamond / house / sprout) above each label.
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: BiText(
                'Family financial status',
                textAlign: TextAlign.center,
                style: _sectionHeading(context),
              ),
            ),
            Obx(() => _financialGrid(c)),
          ],
        ),
        Obx(
          () => c.showExtraLocation
              ? AppLookupDropdown(
                  icon: Icons.public_rounded,
                  label: 'Family country',
                  lookupKey: LookupKeys.countries,
                  controller: c.lookup,
                  selected: c.country.value,
                  requirement: FieldRequirement.optional,
                  onChanged: c.onCountry,
                )
              : const SizedBox.shrink(),
        ),
        Obx(
          () => c.showExtraLocation
              ? AppLookupDropdown(
                  icon: Icons.layers_rounded,
                  label: 'Family province / state',
                  lookupKey: LookupKeys.states,
                  controller: c.lookup,
                  parentId: c.country.value?.id,
                  selected: c.state.value,
                  enabled: c.country.value != null,
                  requirement: FieldRequirement.optional,
                  onChanged: c.onState,
                )
              : const SizedBox.shrink(),
        ),
        Obx(
          () => c.showExtraLocation
              ? AppLookupDropdown(
                  icon: Icons.location_city_rounded,
                  label: 'Family city',
                  lookupKey: LookupKeys.cities,
                  controller: c.lookup,
                  parentId: c.state.value?.id,
                  selected: c.city.value,
                  enabled: c.state.value != null,
                  requirement: FieldRequirement.optional,
                  onChanged: (LookupItem? v) => c.city.value = v,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// The reference's serif rose section heading (same family as the step
  /// title, one step smaller).
  TextStyle _sectionHeading(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return AppTextStyles.displaySerif.copyWith(
      fontSize: 21,
      color: dark ? AppColors.darkTextPrimary : AppColors.roseTitleRose,
    );
  }

  /// The 2-column financial-status grid of icon tiles; a lone last tile keeps
  /// its half width, like the reference.
  Widget _financialGrid(Step17Controller c) {
    const List<LookupItem> options = ApiOptions.familyValues;
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < options.length; i += 2) {
      final bool hasPair = i + 1 < options.length;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: _tile(context, c, options[i])),
            const SizedBox(width: AppSpacing.md),
            hasPair
                ? Expanded(child: _tile(context, c, options[i + 1]))
                : const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
      if (i + 2 < options.length) rows.add(const SizedBox(height: AppSpacing.md));
    }
    return Column(children: rows);
  }

  Widget _tile(BuildContext context, Step17Controller c, LookupItem o) {
    final String value = o.code!;
    return FinancialOptionCard(
      label: o.name,
      selected: c.familyValues.value == value,
      onTap: () => c.familyValues.value = value,
    );
  }
}
