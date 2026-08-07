import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_lookups.dart';
import '../../../constants/registration_options.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_card_selector.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/form_field_container.dart';
import '../../../widgets/step_scaffold.dart';

class Step17Controller extends StepController {
  Step17Controller() : super(17);

  LookupController get lookup => Get.find<LookupController>();

  final TextEditingController familyLocation = TextEditingController();
  final RxnString liveWithFamily = RxnString();
  final RxnString financialStatus = RxnString();
  final Rxn<LookupItem> country = Rxn<LookupItem>();
  final Rxn<LookupItem> state = Rxn<LookupItem>();
  final Rxn<LookupItem> city = Rxn<LookupItem>();

  bool get showExtraLocation => liveWithFamily.value == 'No';

  @override
  void restore() {
    familyLocation.text = buffer.getString('family_location') ?? '';
    financialStatus.value = buffer.getString('family_financial_status');
    final bool? live = buffer.get<bool>('live_with_family');
    if (live != null) liveWithFamily.value = live ? 'Yes' : 'No';
    lookup.ensure(LookupKeys.countries);
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
    'live_with_family': liveWithFamily.value == null ? null : liveWithFamily.value == 'Yes',
    'family_financial_status': financialStatus.value,
    if (showExtraLocation) 'family_country_id': country.value?.id,
    if (showExtraLocation) 'family_state_id': state.value?.id,
    if (showExtraLocation) 'family_city_id': city.value?.id,
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
            options: RegOptions.yesNo.map((String s) => CardOption(s, s)).toList(),
            selected: c.liveWithFamily.value,
            onSelect: (CardOption o) => c.liveWithFamily.value = o.value as String,
          ),
        ),
        Obx(
          () => AppCardSelector(
            label: 'Family financial status',
            options:
                RegOptions.familyFinancialStatus.map((String s) => CardOption(s, s)).toList(),
            selected: c.financialStatus.value,
            onSelect: (CardOption o) => c.financialStatus.value = o.value as String,
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
