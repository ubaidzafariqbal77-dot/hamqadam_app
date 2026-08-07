import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_lookups.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../core/validators/app_validators.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/reveal.dart';
import '../../../widgets/step_scaffold.dart';

class Step04Controller extends StepController {
  Step04Controller() : super(4);

  LookupController get lookup => Get.find<LookupController>();

  final Rxn<LookupItem> country = Rxn<LookupItem>();
  final Rxn<LookupItem> state = Rxn<LookupItem>();
  final Rxn<LookupItem> city = Rxn<LookupItem>();
  final TextEditingController area = TextEditingController();

  @override
  void restore() {
    lookup.ensure(LookupKeys.countries);
    final int? co = buffer.getInt('country_id');
    if (co != null) {
      country.value = LookupItem(id: co, name: '');
      lookup.ensure(LookupKeys.states, parentId: co);
    }
    final int? st = buffer.getInt('state_id');
    if (st != null) {
      state.value = LookupItem(id: st, name: '');
      lookup.ensure(LookupKeys.cities, parentId: st);
    }
    final int? ci = buffer.getInt('city_id');
    if (ci != null) city.value = LookupItem(id: ci, name: '');
    area.text = buffer.getString('area') ?? '';
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
  bool extraValidate() {
    if (country.value == null || state.value == null || city.value == null) {
      error.value = 'Please select your country, province and city.';
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'country_id': country.value?.id,
    'state_id': state.value?.id,
    'city_id': city.value?.id,
    'area': area.text.trim(),
  };

  @override
  void disposeFields() => area.dispose();
}

class Step04View extends StatefulWidget {
  const Step04View({super.key});
  @override
  State<Step04View> createState() => _Step04ViewState();
}

class _Step04ViewState extends State<Step04View> {
  late final Step04Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step04Controller());
  }

  @override
  void dispose() {
    Get.delete<Step04Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 4,
      totalSteps: 18,
      title: 'Location',
      subtitle: 'Where do you currently live?',
      busy: c.busy,
      error: c.error,
      formKey: c.formKey,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      children: <Widget>[
        Obx(() {
          final bool hasCountry = c.country.value != null;
          final bool hasState = c.state.value != null;
          final bool hasCity = c.city.value != null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppLookupDropdown(
                label: 'Country',
                lookupKey: LookupKeys.countries,
                controller: c.lookup,
                selected: c.country.value,
                onChanged: c.onCountry,
              ),
              if (hasCountry) ...<Widget>[
                const SizedBox(height: 20),
                Reveal(
                  child: AppLookupDropdown(
                    label: 'Province / State',
                    lookupKey: LookupKeys.states,
                    controller: c.lookup,
                    parentId: c.country.value?.id,
                    selected: c.state.value,
                    onChanged: c.onState,
                  ),
                ),
              ],
              if (hasState) ...<Widget>[
                const SizedBox(height: 20),
                Reveal(
                  child: AppLookupDropdown(
                    label: 'City',
                    lookupKey: LookupKeys.cities,
                    controller: c.lookup,
                    parentId: c.state.value?.id,
                    selected: c.city.value,
                    onChanged: (LookupItem? v) => c.city.value = v,
                  ),
                ),
              ],
              if (hasCity) ...<Widget>[
                const SizedBox(height: 20),
                Reveal(
                  child: AppTextFormField(
                    label: 'Area / Neighbourhood',
                    controller: c.area,
                    hint: 'e.g. Gulberg, DHA Phase 5',
                    textInputAction: TextInputAction.done,
                    validator: (String? v) => AppValidators.required(v, field: 'Area'),
                  ),
                ),
              ],
            ],
          );
        }),
      ],
    );
  }
}
