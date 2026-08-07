import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_lookups.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_picker_field.dart';
import '../../../widgets/reveal.dart';
import '../../../widgets/step_scaffold.dart';

class Step03Controller extends StepController {
  Step03Controller() : super(3);

  LookupController get lookup => Get.find<LookupController>();

  final Rxn<LookupItem> religion = Rxn<LookupItem>();
  final Rxn<LookupItem> motherTongue = Rxn<LookupItem>();

  @override
  void restore() {
    lookup.ensure(LookupKeys.religions);
    lookup.ensure(LookupKeys.languages);
    final int? r = buffer.getInt('religion_id');
    if (r != null) religion.value = LookupItem(id: r, name: '');
    final int? t = buffer.getInt('mother_tongue');
    if (t != null) motherTongue.value = LookupItem(id: t, name: '');
    if (r != null) lookup.ensure(LookupKeys.castes, parentId: r);
  }

  void onReligion(LookupItem? v) {
    religion.value = v;
    // Warm the caste list (step 6) so it never shows a spinner.
    if (v != null) lookup.ensure(LookupKeys.castes, parentId: v.id);
  }

  @override
  bool extraValidate() {
    if (religion.value == null) {
      error.value = 'Please select your religion.';
      return false;
    }
    if (motherTongue.value == null) {
      error.value = 'Please select your language.';
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'religion_id': religion.value?.id,
    'mother_tongue': motherTongue.value?.id,
  };
}

class Step03View extends StatefulWidget {
  const Step03View({super.key});
  @override
  State<Step03View> createState() => _Step03ViewState();
}

class _Step03ViewState extends State<Step03View> {
  late final Step03Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step03Controller());
  }

  @override
  void dispose() {
    Get.delete<Step03Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 3,
      totalSteps: 18,
      title: 'Religion & language',
      subtitle: 'Your faith and mother tongue.',
      busy: c.busy,
      error: c.error,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      children: <Widget>[
        Obx(
          () => AppLookupPicker(
            label: 'Religion',
            lookupKey: LookupKeys.religions,
            controller: c.lookup,
            selected: c.religion.value,
            onChanged: c.onReligion,
          ),
        ),
        Obx(
          () => c.religion.value == null
              ? const SizedBox.shrink()
              : Reveal(
                  child: AppLookupPicker(
                    label: 'Language',
                    lookupKey: LookupKeys.languages,
                    controller: c.lookup,
                    selected: c.motherTongue.value,
                    onChanged: (LookupItem? v) => c.motherTongue.value = v,
                  ),
                ),
        ),
      ],
    );
  }
}
