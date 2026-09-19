import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_lookups.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_card_selector.dart';
import '../../../widgets/step_scaffold.dart';

/// Reference icon artwork, dropped into `assets/lookups/` as File 1..6 in the
/// reference's reading order. Files keep those names so swapping artwork later
/// never needs a code change.
const List<String> _maritalArt = <String>[
  'assets/lookups/File 1.png', // Never Married — person
  'assets/lookups/File 2.png', // Divorced — broken heart
  'assets/lookups/File 3.png', // Widowed — heart
  'assets/lookups/File 4.png', // Awaiting Divorce — hourglass
  'assets/lookups/File 5.png', // Annulled — plus
  'assets/lookups/File 6.png', // Separated — two people
];

/// Order-independent lookup by server name, so an unexpected list order or a
/// missing file still shows the right artwork.
String? _artFor(String name) {
  final String n = name.toLowerCase();
  if (n.contains('never')) return _maritalArt[0];
  if (n.contains('divorc') && n.contains('await')) return _maritalArt[3];
  if (n.contains('divorc')) return _maritalArt[1];
  if (n.contains('widow')) return _maritalArt[2];
  if (n.contains('annul')) return _maritalArt[4];
  if (n.contains('separat')) return _maritalArt[5];
  return null;
}

/// Material fallback while/if the image files are missing.
IconData _fallbackIcon(String name) {
  final String n = name.toLowerCase();
  if (n.contains('never')) return Icons.person_outline_rounded;
  if (n.contains('divorc') && n.contains('await'))
    return Icons.hourglass_bottom_rounded;
  if (n.contains('divorc')) return Icons.heart_broken_rounded;
  if (n.contains('widow')) return Icons.favorite_rounded;
  if (n.contains('annul')) return Icons.add_rounded;
  if (n.contains('separat')) return Icons.people_outline_rounded;
  return Icons.person_outline_rounded;
}

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
        const SizedBox(height: 32),
        Obx(() {
          final List<LookupItem> options = c.options;
          if (options.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return AppCardSelector(
            // Reference artwork: one icon per status, keyed by the server's
            // name so a renamed/reordered list still degrades gracefully.
            options: options
                .map(
                  (LookupItem i) => CardOption(
                    i.id,
                    i.name,
                    image: _artFor(i.name),
                    icon: _fallbackIcon(i.name),
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
