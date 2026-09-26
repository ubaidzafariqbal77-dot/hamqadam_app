import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_lookups.dart';
import '../../../constants/app_text_styles.dart';
import '../../../constants/income_options.dart';
import '../../../constants/registration_options.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_card_selector.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_picker_field.dart';
import '../../../widgets/bilingual_text.dart';
import '../../../widgets/form_field_container.dart';
import '../../../widgets/step_scaffold.dart';
import '../../../constants/reg_icons.dart';
import '../../../constants/app_colors.dart';

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
  /// Preferred income, picked as a band at each end rather than typed. `From`
  /// posts the band's lower bound and `To` its upper bound, which is what
  /// `income_min` / `income_max` expect (both numeric).
  final Rxn<LookupItem> incomeFrom = Rxn<LookupItem>();
  final Rxn<LookupItem> incomeTo = Rxn<LookupItem>();
  final RxnString diet = RxnString();
  final RxnString managedBy = RxnString();

  /// The ordered sub-questions of this step (step-1-style one-at-a-time flow).
  static const List<String> questions = <String>[
    'marital',
    'age',
    'height',
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
    lookup.ensure(LookupKeys.partnerIncome);
    incomeFrom.value = _band(buffer.getInt('partner_income_min'));
    incomeTo.value = _band(buffer.getInt('partner_income_max'));
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
        final int? iMin = incomeFrom.value?.id;
        final int? iMax = incomeTo.value?.id;
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
    'partner_income_min': incomeFrom.value?.id,
    // The top band is open-ended, so it contributes no ceiling.
    'partner_income_max': IncomeBand.forValue(incomeTo.value?.id)?.max,
    'partner_diet': diet.value,
    'profile_managed_by': managedBy.value,
  };

  /// Rebuilds a picked band row from a saved amount.
  static LookupItem? _band(int? amount) => IncomeBand.forValue(amount)?.item;
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
    // Obx wraps the whole scaffold, not just the body: twelve questions sit
    // behind one heading, so the step title's colour and the bottom button's
    // label are part of what changes as the member advances.
    return Obx(() => _scaffold(context, Step18Controller.questions[c.qIndex.value]));
  }

  Widget _scaffold(BuildContext context, String key) {
    return StepScaffold(
      stepNumber: 18,
      totalSteps: 18,
      title: 'Partner preferences',
      // One design for all twelve sub-questions: the bare rose canvas, the
      // bright pink step title and NO watercolour hero. The option questions
      // carry their artwork in the tiles, and age/height draw theirs inside
      // the body under the fields — a hero above the title made the option
      // screens look like a different flow from the field ones.
      //
      // Flat rather than the floating white card: the Preferred-education
      // reference draws its option tiles straight on the blush canvas, and the
      // tiles are already white. Keeping the card would stack white on white
      // and box the grid in. The same treatment runs across the whole step so
      // the canvas does not change shape between sub-questions.
      art: '',
      flat: true,
      titleColor: AppColors.accent,
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
        return _heightRange();
      case 'marital':
        // Deliberately NOT the tile grid the other option questions use: the
        // Marital-status reference draws these as tall cards with the glyph
        // floating in a soft rose disc, and it is the same question the member
        // already answered about themselves in step 07 — so the two screens
        // must read as the same design.
        return Obx(
          () => AppCardSelector(
            discSize: 88,
            label: 'Preferred marital status',
            options: c.lookup
                .itemsOf(LookupKeys.maritalStatuses)
                .map(
                  (LookupItem i) => CardOption(
                    i.id,
                    i.name,
                    icon: RegIcons.maritalStatusGlyph(i.name),
                  ),
                )
                .toList(),
            selected: c.maritalStatus.value,
            onSelect: (CardOption o) =>
                c.maritalStatus.value = o.value as int,
          ),
        );
      case 'religion':
        return Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // One design across the whole step: the same tall disc cards the
              // Marital-status reference draws, with the 3D faith symbols in
              // the disc and the full server list one tap below so anything the
              // artwork does not cover is still reachable.
              AppCardSelector(
                discSize: 88,
                label: 'Preferred religion / sect',
                options: c.lookup
                    .itemsOf(LookupKeys.religions)
                    .take(6)
                    .map(
                      (LookupItem i) => CardOption(
                        i,
                        i.name,
                        image: RegIcons.religionRowArt[i.id],
                        icon: RegIcons.faithGlyph(i.name),
                      ),
                    )
                    .toList(),
                selected: c.religion.value,
                onSelect: (CardOption o) =>
                    c.religion.value = o.value as LookupItem,
              ),
              const SizedBox(height: 20),
              AppLookupPicker(
                label: 'Or pick from the full list',
                lookupKey: LookupKeys.religions,
                controller: c.lookup,
                selected: c.religion.value,
                onChanged: c.onReligion,
              ),
            ],
          ),
        );
      case 'caste':
        return Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppLookupPicker(
                label: 'Preferred caste',
                lookupKey: LookupKeys.castes,
                controller: c.lookup,
                selected: c.caste.value,
                requirement: FieldRequirement.optional,
                onChanged: (LookupItem? v) => c.caste.value = v,
              ),
              _popularRow(
                items: c.lookup.itemsOf(LookupKeys.castes),
                selected: c.caste.value,
                onTap: (LookupItem i) =>
                    c.caste.value = c.caste.value?.id == i.id ? null : i,
              ),
            ],
          ),
        );
      case 'language':
        return Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppLookupPicker(
                label: 'Preferred mother tongue',
                lookupKey: LookupKeys.languages,
                controller: c.lookup,
                selected: c.language.value,
                requirement: FieldRequirement.optional,
                onChanged: (LookupItem? v) => c.language.value = v,
              ),
              _popularRow(
                items: c.lookup.itemsOf(LookupKeys.languages),
                selected: c.language.value,
                onTap: (LookupItem i) =>
                    c.language.value = c.language.value?.id == i.id ? null : i,
              ),
            ],
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
              Obx(
                () => _popularRow(
                  items: c.lookup.itemsOf(LookupKeys.cities),
                  selected: c.city.value,
                  onTap: (LookupItem i) =>
                      c.city.value = c.city.value?.id == i.id ? null : i,
                ),
              ),
            ],
          ),
          subtitle: 'Describe your ideal match.',
        );
      case 'education':
        return Obx(
          () => AppCardSelector(
            discSize: 88,
            label: 'Preferred education',
            options: RegOptions.partnerEducation
                .map(
                  (String s) => CardOption(
                    s,
                    s,
                    image: RegIcons.partnerEducationArt[s],
                    icon: RegIcons.educationGlyph(s),
                  ),
                )
                .toList(),
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
            discSize: 88,
            label: 'Preferred profession',
            options: RegOptions.partnerProfession
                .map(
                  (String s) => CardOption(
                    s,
                    s,
                    icon: RegIcons.professionGlyph(s),
                  ),
                )
                .toList(),
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
          Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppLookupDropdown(
                  label: 'From',
                  lookupKey: LookupKeys.partnerIncome,
                  controller: c.lookup,
                  selected: c.incomeFrom.value,
                  requirement: FieldRequirement.optional,
                  onChanged: (LookupItem? v) => c.incomeFrom.value = v,
                ),
                const SizedBox(height: 20),
                AppLookupDropdown(
                  label: 'Up to',
                  lookupKey: LookupKeys.partnerIncome,
                  controller: c.lookup,
                  selected: c.incomeTo.value,
                  requirement: FieldRequirement.optional,
                  onChanged: (LookupItem? v) => c.incomeTo.value = v,
                ),
              ],
            ),
          ),
        );
      case 'diet':
        return Obx(
          () => AppCardSelector(
            discSize: 88,
            label: 'Preferred diet',
            options: RegOptions.partnerDiet
                .map(
                  (String s) => CardOption(
                    s,
                    s,
                    icon: RegIcons.dietGlyph(s),
                  ),
                )
                .toList(),
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
            discSize: 88,
            label: 'Profile managed by',
            options: RegOptions.profileManagedBy
                .map(
                  (String s) => CardOption(
                    s,
                    s,
                    icon: RegIcons.managedByGlyph(s),
                  ),
                )
                .toList(),
            selected: c.managedBy.value,
            onSelect: (CardOption o) {
              c.managedBy.value = o.value as String;
              c.goNext();
            },
          ),
        );
      case 'age':
        return _ageRange();
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

  /// The Preferred-height reference: dark section heading, left-labelled gray
  /// field pair, then the couple + ruler artwork mid-screen with each chosen
  /// height floating beside its figure and the pink range caption below.
  Widget _heightRange() {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final int? hMin = c.heightMinCm.value;
      final int? hMax = c.heightMaxCm.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          BiText(
            'Preferred height range',
            textAlign: TextAlign.center,
            style: AppTextStyles.displaySerif.copyWith(
              fontSize: 22,
              color: dark ? AppColors.darkTextPrimary : const Color(0xFF2B2230),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _rangeField(
                  'Min height',
                  c.labelFor(hMin),
                  dark,
                  () => _pickHeight('Min height', hMin, c.heightMinCm),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _rangeField(
                  'Max height',
                  c.labelFor(hMax),
                  dark,
                  () => _pickHeight('Max height', hMax, c.heightMaxCm),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // The reference's couple + ruler artwork, mid-screen, with each
          // chosen height floating beside its figure.
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.asset(
                  RegIcons.partnerQuestionArt['height']!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, Object __, StackTrace? ___) =>
                      const SizedBox.shrink(),
                ),
                if (hMin != null)
                  Align(
                    alignment: const Alignment(-0.47, -0.48),
                    child: Text(
                      '$hMin cm / ${_hShort(hMin)}',
                      style: AppTextStyles.bodyStrong.copyWith(
                        fontSize: 15,
                        color: dark
                            ? AppColors.primaryLight
                            : AppColors.regAccent,
                      ),
                    ),
                  ),
                if (hMax != null)
                  Align(
                    alignment: const Alignment(0.34, -0.89),
                    child: Text(
                      '$hMax cm / ${_hShort(hMax)}',
                      style: AppTextStyles.bodyStrong.copyWith(
                        fontSize: 15,
                        color: dark
                            ? AppColors.primaryLight
                            : AppColors.regAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          BiText(
            'Ideal range • '
            '${hMin == null ? '—' : _hShort(hMin)} to '
            '${hMax == null ? '—' : _hShort(hMax)} • Comfortable match',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyStrong.copyWith(
              fontSize: 13.5,
              color: dark ? AppColors.primaryLight : AppColors.regAccent,
            ),
          ),
        ],
      );
    });
  }

  /// One gray field with its label sitting OUTSIDE, above-left — the age and
  /// height references' layout (every other registration field insets the
  /// label). [text] is the already-formatted value, or null for "Select".
  Widget _rangeField(String label, String? text, bool dark, VoidCallback onTap) {
    final Color ink =
        dark ? AppColors.darkTextPrimary : const Color(0xFF2B2230);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        BiText(
          label,
          style: AppTextStyles.body.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              height: 76,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                // The reference's fields are flat neutral gray, not white
                // with a pink hairline like the rest of the flow.
                color: dark
                    ? AppColors.darkSurface
                    : const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: text == null
                        ? Text(
                            'Select',
                            style: AppTextStyles.body.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                          )
                        : Text(
                            text,
                            maxLines: 2,
                            style: AppTextStyles.body.copyWith(
                              fontSize: 15.5,
                              color: ink,
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: Theme.of(context).hintColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Opens the standard picker sheet for one end of the height range and
  /// stores the result as centimetres.
  Future<void> _pickHeight(String title, int? current, Rxn<int> target) async {
    final String? picked = await showStringPickerSheet(
      context,
      title: title,
      options: c.heightLabels,
      selected: c.labelFor(current),
    );
    if (picked != null) target.value = c.cmFor(picked);
  }

  /// `5' 2" (157 cm)` → `5'2"`, the way the reference labels its figures.
  String _hShort(int cm) {
    final String? label = c.labelFor(cm);
    if (label == null) return '$cm cm';
    return label.split(' (').first.replaceAll(' ', '');
  }

  /// The Preferred-age reference — the same simple pattern as the height
  /// screen: dark serif heading, outside-labelled gray fields, the clock
  /// artwork underneath, and the pink range caption.
  Widget _ageRange() {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final int? aMin = c.ageMin.value;
      final int? aMax = c.ageMax.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          BiText(
            'Preferred age range',
            textAlign: TextAlign.center,
            style: AppTextStyles.displaySerif.copyWith(
              fontSize: 22,
              color: dark ? AppColors.darkTextPrimary : const Color(0xFF2B2230),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _rangeField(
                  'Min age',
                  aMin?.toString(),
                  dark,
                  () => _pickAge('Min age', aMin, c.ageMin),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _rangeField(
                  'Max age',
                  aMax?.toString(),
                  dark,
                  () => _pickAge('Max age', aMax, c.ageMax),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1,
            child: Image.asset(
              RegIcons.partnerQuestionArt['age']!,
              fit: BoxFit.contain,
              errorBuilder: (_, Object __, StackTrace? ___) =>
                  const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 8),
          BiText(
            'Ideal range • ${aMin ?? '—'} to ${aMax ?? '—'} years • '
            'Comfortable match',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyStrong.copyWith(
              fontSize: 13.5,
              color: dark ? AppColors.primaryLight : AppColors.regAccent,
            ),
          ),
        ],
      );
    });
  }

  /// Opens the shared picker sheet for one end of the range and stores the
  /// picked age as an int.
  Future<void> _pickAge(String title, int? current, Rxn<int> target) async {
    final String? picked = await showStringPickerSheet(
      context,
      title: title,
      options: RegOptions.ages,
      selected: current?.toString(),
    );
    if (picked != null) target.value = int.tryParse(picked);
  }

  /// A centered question label above the field(s).
  /// Reference-style question heading: large serif-ink title centered, with
  /// an optional muted subtitle ("Describe your ideal match.").
  Widget _wrap(String label, Widget body, {String? subtitle}) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BiText(
          label,
          textAlign: TextAlign.center,
          // Playfair Display, matching the Partner preferences references.
          style: AppTextStyles.displaySerif.copyWith(
            fontSize: 19,
            color: dark ? AppColors.darkTextPrimary : AppColors.roseTitleInk,
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 8),
          BiText(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontSize: 15,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
            ),
          ),
        ],
        const SizedBox(height: 22),
        body,
      ],
    );
  }

  /// Popular quick-pick chips (reference: "Popular castes / cities / mother
  /// tongues"). First few server options, one-tap to select or toggle off.
  Widget _popularRow({
    required List<LookupItem> items,
    required LookupItem? selected,
    required ValueChanged<LookupItem> onTap,
    int limit = 6,
  }) {
    final List<LookupItem> picks = items.take(limit).toList();
    if (picks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BiText(
            'Popular',
            style: AppTextStyles.bodyStrong.copyWith(
              fontSize: 13.5,
              color: AppColors.regAccent,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: picks
                .map(
                  (LookupItem i) => _PopularChip(
                    label: i.name,
                    selected: selected?.id == i.id,
                    onTap: () => onTap(i),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// One quick-pick chip in the "Popular" row (reference design): soft pink
/// pill, solid brand fill when selected.
class _PopularChip extends StatelessWidget {
  const _PopularChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.regAccent
              : dark
              ? AppColors.darkSurface
              : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.regAccent
                : AppColors.regAccent.withValues(alpha: 0.28),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyStrong.copyWith(
            fontSize: 13.5,
            color: selected
                ? Colors.white
                : dark
                ? AppColors.darkTextPrimary
                : const Color(0xFF3A2E33),
          ),
        ),
      ),
    );
  }
}
