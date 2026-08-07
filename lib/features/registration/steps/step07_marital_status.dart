import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/registration_options.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_card_selector.dart';
import '../../../widgets/step_scaffold.dart';

class Step07Controller extends StepController {
  Step07Controller() : super(7);

  final Rxn<int> maritalStatus = Rxn<int>();

  @override
  void restore() => maritalStatus.value = buffer.getInt('marital_status_id');

  @override
  bool extraValidate() {
    if (maritalStatus.value == null) {
      error.value = 'Please select your marital status.';
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{'marital_status_id': maritalStatus.value};
}

class Step07View extends StatefulWidget {
  const Step07View({super.key});
  @override
  State<Step07View> createState() => _Step07ViewState();
}

class _Step07ViewState extends State<Step07View> {
  late final Step07Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step07Controller());
  }

  @override
  void dispose() {
    Get.delete<Step07Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 7,
      totalSteps: 18,
      title: 'Marital status',
      subtitle: 'What is your current marital status?',
      busy: c.busy,
      error: c.error,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      children: <Widget>[
         SizedBox(height: 32),
        Obx(
          () => AppCardSelector(
            options: RegOptions.maritalStatus
                .map((LookupItem i) => CardOption(i.id, i.name))
                .toList(),
            selected: c.maritalStatus.value,
            onSelect: (CardOption o) => c.maritalStatus.value = o.value as int,
          ),
        ),
      ],
    );
  }
}
