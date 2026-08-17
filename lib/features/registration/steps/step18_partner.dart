import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../constants/app_lookups.dart';
import '../../../constants/app_text_styles.dart';
import '../../../constants/registration_options.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_card_selector.dart';
import '../../../widgets/app_picker_field.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/bilingual_text.dart';
import '../../../widgets/form_field_container.dart';
import '../../../widgets/step_scaffold.dart';

/// Screen 18 — Partner preferences, the API's step 17
/// (`POST /auth/register/step/17`).
///
/// Dynamic dropdowns: `partner_marital_status_id`, `partner_religion_id`,
/// `partner_caste_id`, `partner_language_id`, `partner_country_id` →
/// `partner_state_id` → `partner_city_id`. Heights are converted to feet and
/// the age/income ranges are sent as plain numbers.
class Step18Controller extends StepController {
  Step18Controller() : super(18);

  LookupController get lookup => Get.find<LookupController>();
  late final List<LookupItem> heights = RegOptions.heights;

  final Rxn<int> ageMin = Rxn<int>();
  final Rxn<int> ageMax = Rxn<int>();
  final Rxn<int> heightMinCm = Rxn<int>();
  final Rxn<int> heightMaxCm = Rxn<int>();
  final Rxn<int> maritalStatus = Rxn<int>();
  final Rxn<LookupItem> religion = Rxn<LookupItem>();
  final Rxn<LookupItem> caste = Rxn<LookupItem>();
  final Rxn<LookupItem> language = Rxn<LookupItem>();
  final Rxn<LookupItem> country = Rxn<LookupItem>();
  final Rxn<LookupItem> state = Rxn<LookupItem>();
  final Rxn<LookupItem> city = Rxn<LookupItem>();
  final RxnString education = RxnString();
  final RxnString profession = RxnString();
  final TextEditingController incomeMin = TextEditingController();
  final TextEditingController incomeMax = TextEditingController();
  final RxnString diet = RxnString();
  final RxnString managedBy = RxnString();

  /// The ordered sub-questions of this step (step-1-style one-at-a-time flow).
  static const List<String> questions = <String>[
    'age',
    'height',
    'marital',
    'religion',
    'caste',
    'language',
    'location',
    'education',
    'profession',
    'income',
    'diet',
    'managedBy',
  ];

  final RxInt qIndex = 0.obs;
  final RxString primaryLabel = 'Continue'.obs;

  bool get _isLast => qIndex.value >= questions.length - 1;
  void _syncLabel() => primaryLabel.value = _isLast ? 'Finish' : 'Continue';

  List<String> get heightLabels => heights.map((LookupItem e) => e.name).toList();
  String? labelFor(int? cm) {
    for (final LookupItem h in heights) {
      if (h.id == cm) return h.name;
    }
    return null;
  }

  int? cmFor(String? label) {
    for (final LookupItem h in heights) {
      if (h.name == label) return h.id;
    }
    return null;
  }

  @override
  void restore() {
    lookup
      ..ensure(LookupKeys.religions)
      ..ensure(LookupKeys.languages)
      ..ensure(LookupKeys.countries)
      ..ensure(LookupKeys.castes)
      ..ensure(LookupKeys.maritalStatuses);
    ageMin.value = buffer.getInt('partner_age_min');
    ageMax.value = buffer.getInt('partner_age_max');
    heightMinCm.value = buffer.getInt('partner_height_min');
    heightMaxCm.value = buffer.getInt('partner_height_max');
    maritalStatus.value = buffer.getInt('partner_marital_status_id');
    education.value = buffer.getString('partner_education');
    profession.value = buffer.getString('partner_profession');
    incomeMin.text = buffer.getInt('partner_income_min')?.toString() ?? '';
    incomeMax.text = buffer.getInt('partner_income_max')?.toString() ?? '';
    diet.value = buffer.getString('partner_diet');
    managedBy.value = buffer.getString('profile_managed_by');
    _syncLabel();
  }

  void onReligion(LookupItem? v) => religion.value = v;

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

  /// Validates only the current sub-question. Returns an error message or null.
  String? _validateCurrent() {
    switch (questions[qIndex.value]) {
      case 'age':
        final int? aMin = ageMin.value;
        final int? aMax = ageMax.value;
        if (aMin != null && aMax != null && aMin > aMax) {
          return 'Minimum age cannot exceed the maximum.';
        }
        return null;
      case 'height':
        if (heightMinCm.value == null || heightMaxCm.value == null) {
          return 'Please select a preferred height range.';
        }
        if (heightMinCm.value! > heightMaxCm.value!) {
          return 'Minimum height cannot exceed the maximum.';
        }
        return null;
      case 'marital':
        if (maritalStatus.value == null) return 'Please select a preferred marital status.';
        return null;
      case 'religion':
        if (religion.value == null) return 'Please select a preferred religion.';
        return null;
      case 'education':
        if (education.value == null) return 'Please select a preferred education.';
        return null;
      case 'profession':
        if (profession.value == null) return 'Please select a preferred profession.';
        return null;
      case 'income':
        final int? iMin = int.tryParse(incomeMin.text.trim());
        final int? iMax = int.tryParse(incomeMax.text.trim());
        if (iMin != null && iMax != null && iMin > iMax) {
          return 'Minimum income cannot exceed the maximum.';
        }
        return null;
      default:
        return null; // caste / language / location / diet / managedBy are optional.
    }
  }

  /// Advance to the next sub-question, or submit the whole step on the last one.
  Future<void> goNext() async {
    final String? err = _validateCurrent();
    if (err != null) {
      error.value = err;
      return;
    }
    error.value = '';
    if (_isLast) {
      await submit();
    } else {
      qIndex.value += 1;
      _syncLabel();
    }
  }

  /// Go to the previous sub-question, or leave the step from the first one.
  void goBack() {
    error.value = '';
    if (qIndex.value > 0) {
      qIndex.value -= 1;
      _syncLabel();
    } else {
      back();
    }
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'partner_age_min': ageMin.value,
    'partner_age_max': ageMax.value,
    'partner_height_min': heightMinCm.value,
    'partner_height_max': heightMaxCm.value,
    'partner_marital_status_id': maritalStatus.value,
    'partner_religion_id': religion.value?.id,
    'partner_caste_id': caste.value?.id,
    'partner_language_id': language.value?.id,
    'partner_country_id': country.value?.id,
    'partner_state_id': state.value?.id,
    'partner_city_id': city.value?.id,
    'partner_education': education.value,
    'partner_profession': profession.value,
    'partner_income_min': int.tryParse(incomeMin.text.trim()),
    'partner_income_max': int.tryParse(incomeMax.text.trim()),
    'partner_diet': diet.value,
    'profile_managed_by': managedBy.value,
  };

  @override
  void disposeFields() {
    incomeMin.dispose();
    incomeMax.dispose();
  }
}

class Step18View extends StatefulWidget {
  const Step18View({super.key});
  @override
  State<Step18View> createState() => _Step18ViewState();
}

class _Step18ViewState extends State<Step18View> {
  late final Step18Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step18Controller());
  }

  @override
  void dispose() {
    Get.delete<Step18Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 18,
      totalSteps: 18,
      title: 'Partner preferences',
      subtitle: 'Describe your ideal match.',
      busy: c.busy,
      error: c.error,
      primaryLabel: 'Finish',
      primaryLabelRx: c.primaryLabel,
      onPrimary: c.goNext,
      onBack: c.goBack,
      children: <Widget>[
        Obx(() {
          final String key = Step18Controller.questions[c.qIndex.value];
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> anim) {
              final Animation<Offset> slide = Tween<Offset>(
                begin: const Offset(0.12, 0),
                end: Offset.zero,
              ).animate(anim);
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: KeyedSubtree(key: ValueKey<String>(key), child: _question(key)),
          );
        }),
      ],
    );
  }

  Widget _question(String key) {
    switch (key) {
      case 'height':
        return _wrap(
          'Preferred height range',
          Row(
            children: <Widget>[
              Expanded(
                child: Obx(
                  () => AppStringPicker(
                    label: 'Min height',
                    value: c.labelFor(c.heightMinCm.value),
                    options: c.heightLabels,
                    hint: 'Select',
                    onChanged: (String? v) => c.heightMinCm.value = c.cmFor(v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(
                  () => AppStringPicker(
                    label: 'Max height',
                    value: c.labelFor(c.heightMaxCm.value),
                    options: c.heightLabels,
                    hint: 'Select',
                    onChanged: (String? v) => c.heightMaxCm.value = c.cmFor(v),
                  ),
                ),
              ),
            ],
          ),
        );
      case 'marital':
        return Obx(
          () => AppCardSelector(
            label: 'Preferred marital status',
            options: c.lookup
                .itemsOf(LookupKeys.maritalStatuses)
                .map((LookupItem i) => CardOption(i.id, i.name))
                .toList(),
            selected: c.maritalStatus.value,
            onSelect: (CardOption o) {
              c.maritalStatus.value = o.value as int;
              c.goNext();
            },
          ),
        );
      case 'religion':
        return Obx(
          () => AppLookupPicker(
            label: 'Preferred religion / sect',
            lookupKey: LookupKeys.religions,
            controller: c.lookup,
            selected: c.religion.value,
            onChanged: c.onReligion,
          ),
        );
      case 'caste':
        return Obx(
          () => AppLookupPicker(
            label: 'Preferred caste',
            lookupKey: LookupKeys.castes,
            controller: c.lookup,
            selected: c.caste.value,
            requirement: FieldRequirement.optional,
            onChanged: (LookupItem? v) => c.caste.value = v,
          ),
        );
      case 'language':
        return Obx(
          () => AppLookupPicker(
            label: 'Preferred mother tongue',
            lookupKey: LookupKeys.languages,
            controller: c.lookup,
            selected: c.language.value,
            requirement: FieldRequirement.optional,
            onChanged: (LookupItem? v) => c.language.value = v,
          ),
        );
      case 'location':
        return _wrap(
          'Preferred location',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Obx(
                () => AppLookupPicker(
                  label: 'Country',
                  lookupKey: LookupKeys.countries,
                  controller: c.lookup,
                  selected: c.country.value,
                  requirement: FieldRequirement.optional,
                  onChanged: c.onCountry,
                ),
              ),
              const SizedBox(height: 20),
              Obx(
                () => AppLookupPicker(
                  label: 'Province / State',
                  lookupKey: LookupKeys.states,
                  controller: c.lookup,
                  parentId: c.country.value?.id,
                  selected: c.state.value,
                  enabled: c.country.value != null,
                  requirement: FieldRequirement.optional,
                  onChanged: c.onState,
                ),
              ),
              const SizedBox(height: 20),
              Obx(
                () => AppLookupPicker(
                  label: 'City',
                  lookupKey: LookupKeys.cities,
                  controller: c.lookup,
                  parentId: c.state.value?.id,
                  selected: c.city.value,
                  enabled: c.state.value != null,
                  requirement: FieldRequirement.optional,
                  onChanged: (LookupItem? v) => c.city.value = v,
                ),
              ),
            ],
          ),
        );
      case 'education':
        return Obx(
          () => AppCardSelector(
            label: 'Preferred education',
            options: RegOptions.partnerEducation.map((String s) => CardOption(s, s)).toList(),
            selected: c.education.value,
            onSelect: (CardOption o) {
              c.education.value = o.value as String;
              c.goNext();
            },
          ),
        );
      case 'profession':
        return Obx(
          () => AppCardSelector(
            label: 'Preferred profession',
            options: RegOptions.partnerProfession.map((String s) => CardOption(s, s)).toList(),
            selected: c.profession.value,
            onSelect: (CardOption o) {
              c.profession.value = o.value as String;
              c.goNext();
            },
          ),
        );
      case 'income':
        return _wrap(
          'Preferred annual income (PKR)',
          Row(
            children: <Widget>[
              Expanded(
                child: AppTextFormField(
                  label: 'Min income',
                  controller: c.incomeMin,
                  requirement: FieldRequirement.optional,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextFormField(
                  label: 'Max income',
                  controller: c.incomeMax,
                  requirement: FieldRequirement.optional,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
        );
      case 'diet':
        return Obx(
          () => AppCardSelector(
            label: 'Preferred diet',
            options: RegOptions.partnerDiet.map((String s) => CardOption(s, s)).toList(),
            selected: c.diet.value,
            onSelect: (CardOption o) {
              c.diet.value = o.value as String;
              c.goNext();
            },
          ),
        );
      case 'managedBy':
        return Obx(
          () => AppCardSelector(
            label: 'Profile managed by',
            options: RegOptions.profileManagedBy.map((String s) => CardOption(s, s)).toList(),
            selected: c.managedBy.value,
            onSelect: (CardOption o) {
              c.managedBy.value = o.value as String;
              c.goNext();
            },
          ),
        );
      case 'age':
      default:
        return _wrap(
          'Preferred age range',
          Row(
            children: <Widget>[
              Expanded(
                child: Obx(
                  () => AppStringPicker(
                    label: 'Min age',
                    value: c.ageMin.value?.toString(),
                    options: RegOptions.ages,
                    requirement: FieldRequirement.optional,
                    hint: 'Select',
                    onChanged: (String? v) => c.ageMin.value = int.tryParse(v ?? ''),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(
                  () => AppStringPicker(
                    label: 'Max age',
                    value: c.ageMax.value?.toString(),
                    options: RegOptions.ages,
                    requirement: FieldRequirement.optional,
                    hint: 'Select',
                    onChanged: (String? v) => c.ageMax.value = int.tryParse(v ?? ''),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  /// A centered question label above the field(s).
  Widget _wrap(String label, Widget body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BiText(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.subtitle.copyWith(fontSize: 17),
        ),
        const SizedBox(height: 18),
        body,
      ],
    );
  }
}
