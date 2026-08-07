import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/registration_options.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_card_selector.dart';
import '../../../widgets/app_picker_field.dart';
import '../../../widgets/step_scaffold.dart';

class Step09Controller extends StepController {
  Step09Controller() : super(9);

  late final List<LookupItem> heights = RegOptions.heights;
  final Rxn<int> heightCm = Rxn<int>();
  final RxnString diet = RxnString();

  List<String> get heightLabels => heights.map((LookupItem e) => e.name).toList();

  String? get heightLabel {
    for (final LookupItem h in heights) {
      if (h.id == heightCm.value) return h.name;
    }
    return null;
  }

  void onHeight(String? label) {
    for (final LookupItem h in heights) {
      if (h.name == label) {
        heightCm.value = h.id;
        return;
      }
    }
  }

  @override
  void restore() {
    heightCm.value = buffer.getInt('height_cm');
    diet.value = buffer.getString('diet');
  }

  @override
  bool extraValidate() {
    if (heightCm.value == null) {
      error.value = 'Please select your height.';
      return false;
    }
    if (diet.value == null) {
      error.value = 'Please select your diet.';
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'height_cm': heightCm.value,
    'diet': diet.value,
  };
}

class Step09View extends StatefulWidget {
  const Step09View({super.key});
  @override
  State<Step09View> createState() => _Step09ViewState();
}

class _Step09ViewState extends State<Step09View> {
  late final Step09Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step09Controller());
  }

  @override
  void dispose() {
    Get.delete<Step09Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 9,
      totalSteps: 18,
      title: 'Physical information',
      subtitle: 'Your height and dietary preference.',
      busy: c.busy,
      error: c.error,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      note: 'These details help us show you matches with compatible lifestyles '
          'and preferences.',
      children: <Widget>[
        Obx(
          () => AppStringPicker(
            label: 'Height',
            value: c.heightLabel,
            options: c.heightLabels,
            hint: 'Select your height',
            onChanged: c.onHeight,
          ),
        ),
        Obx(
          () => AppCardSelector(
            label: 'Diet',
            options: RegOptions.diet.map((String d) => CardOption(d, d)).toList(),
            selected: c.diet.value,
            onSelect: (CardOption o) => c.diet.value = o.value as String,
          ),
        ),
      ],
    );
  }
}
