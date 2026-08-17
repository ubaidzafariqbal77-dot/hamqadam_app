import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/api_options.dart';
import '../../../constants/app_lookups.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_card_selector.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/form_field_container.dart';
import '../../../widgets/step_scaffold.dart';

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
    return StepScaffold(
      stepNumber: 17,
      totalSteps: 18,
      title: 'Family details',
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
          label: 'Family location',
          controller: c.familyLocation,
          requirement: FieldRequirement.optional,
          hint: 'e.g. Lahore, Pakistan',
          textInputAction: TextInputAction.done,
        ),
        Obx(
          () => AppCardSelector(
            label: 'Do you live with your family?',
            options: ApiOptions.liveWithFamily
                .map((LookupItem o) => CardOption(o.code!, o.name))
                .toList(),
            selected: c.liveWithFamily.value,
            onSelect: (CardOption o) => c.liveWithFamily.value = o.value as String,
          ),
        ),
        Obx(
          () => AppCardSelector(
            label: 'Family financial status',
            options: ApiOptions.familyValues
                .map((LookupItem o) => CardOption(o.code!, o.name))
                .toList(),
            selected: c.familyValues.value,
            onSelect: (CardOption o) => c.familyValues.value = o.value as String,
          ),
        ),
        Obx(
          () => c.showExtraLocation
              ? AppLookupDropdown(
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
}
