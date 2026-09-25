import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../constants/registration_options.dart';
import '../../../controllers/step_controller.dart';
import '../../../constants/reg_icons.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_card_selector.dart';
import '../../../widgets/app_picker_field.dart';
import '../../../widgets/bilingual_text.dart';
import '../../../widgets/step_scaffold.dart';

/// Step 9 — `POST /auth/register/step/9` → `{height, diet}`.
/// The picker works in centimetres; the API stores feet (168 cm -> 5.6).
class Step09Controller extends StepController {
  Step09Controller() : super(9);

  late final List<LookupItem> heights = RegOptions.heights;
  final Rxn<int> heightCm = Rxn<int>();
  final RxnString diet = RxnString();

  List<String> get heightLabels =>
      heights.map((LookupItem e) => e.name).toList();

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
      // Reference has no illustration slot here — an empty art string renders
      // nothing above the title.
      art: '',
      subtitle: 'Your height and dietary preference.',
      busy: c.busy,
      error: c.error,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      note:
          'These details help us show you matches with compatible lifestyles '
          'and preferences.',
      children: <Widget>[
        Obx(
          () => AppStringPicker(
            label: 'Height',
            value: c.heightLabel,
            options: c.heightLabels,
            hint: 'Select your height',
            onChanged: c.onHeight,
            image: RegIcons.heightRuler,
            icon: Icons.height_rounded,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BiText(
              'Dietary Preference',
              style: AppTextStyles.display.copyWith(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: AppColors.regAccent,
              ),
            ),
            const SizedBox(height: 4),
            BiText(
              'Select your dietary preference',
              style: AppTextStyles.body.copyWith(
                fontSize: 15.5,
                color: AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        Obx(
          () => AppCardSelector(
            options: const <CardOption>[
              CardOption(
                'Vegetarian',
                'Vegetarian',
                photo: 'assets/registration/physical-info/file_3.png',
                photoIcon: Icons.eco_outlined,
                description: 'Plant-based diet',
              ),
              CardOption(
                'Non-Vegetarian',
                'Non-Vegetarian',
                photo: 'assets/registration/physical-info/file_4.png',
                photoIcon: Icons.kebab_dining_rounded,
                description: 'Meat & poultry',
              ),
            ],
            selected: c.diet.value,
            onSelect: (CardOption o) => c.diet.value = o.value as String,
          ),
        ),
      ],
    );
  }
}
