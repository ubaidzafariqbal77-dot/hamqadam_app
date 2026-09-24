import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_lookups.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../constants/reg_icons.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_card_selector.dart';
import '../../../widgets/step_scaffold.dart';

/// Step 7 — `POST /auth/register/step/7` → `{marital_status_id}`.
/// `marital_status_id` is a dynamic dropdown (`marital_statuses`).
class Step07Controller extends StepController {
  Step07Controller() : super(7);

  LookupController get lookup => Get.find<LookupController>();

  final Rxn<int> maritalStatus = Rxn<int>();

  List<LookupItem> get options => lookup.itemsOf(LookupKeys.maritalStatuses);

  @override
  void restore() {
    lookup.ensure(LookupKeys.maritalStatuses);
    maritalStatus.value = buffer.getInt('marital_status_id');
  }

  @override
  bool extraValidate() {
    if (maritalStatus.value == null) {
      error.value = 'Please select your marital status.';
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'marital_status_id': maritalStatus.value,
  };
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
    // The Marital-status reference: no white card and no back chevron — the
    // title sits left with the percentage beside it, the progress bar runs
    // underneath, and the question line sits in rose above the grid.
    return StepScaffold(
      stepNumber: 7,
      totalSteps: 18,
      title: 'Marital status',
      subtitle: 'What is your current marital status?',
      flat: true,
      compactHeader: true,
      busy: c.busy,
      error: c.error,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      children: <Widget>[
        Obx(() {
          final List<LookupItem> options = c.options;
          if (options.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return AppCardSelector(
            // The reference's tall cards carry a noticeably larger disc than
            // the other grids, with the exact glyph set drawn on it.
            discSize: 88,
            options: options
                .map(
                  (LookupItem i) => CardOption(
                    i.id,
                    i.name,
                    icon: RegIcons.maritalStatusGlyph(i.name),
                  ),
                )
                .toList(),
            selected: c.maritalStatus.value,
            onSelect: (CardOption o) => c.maritalStatus.value = o.value as int,
          );
        }),
      ],
    );
  }
}
