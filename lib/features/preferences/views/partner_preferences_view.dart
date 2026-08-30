import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_lookups.dart';
import '../../../constants/app_text_styles.dart';
import '../../../constants/income_options.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/partner_preference_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../models/lookup_item_model.dart';
import '../../../models/partner_preference_model.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/form_field_container.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/state_widgets.dart';
import '../../../widgets/surface_card.dart';

/// Partner preferences, editable after signup.
///
/// These are not cosmetic: the backend filters the candidate pool with age,
/// marital status, religion, caste and preferred location. Height, education,
/// profession and income influence the compatibility SCORE but do not exclude
/// anybody — height in particular is stored in different units on the two
/// sides, so comparing it would drop valid matches. The screen says so, because
/// a member who sets a height range and sees it ignored will otherwise assume
/// the app is broken.
class PartnerPreferencesView extends StatelessWidget {
  const PartnerPreferencesView({super.key});

  @override
  Widget build(BuildContext context) {
    final PartnerPreferenceController c = Get.find<PartnerPreferenceController>();
    return Scaffold(
      appBar: const PremiumAppBar(
        title: 'Partner Preferences',
        subtitle: 'What you are looking for',
      ),
      body: Obx(() {
        final ApiState<PartnerPreferenceModel> s = c.state.value;
        switch (s.status) {
          case ApiStatus.initial:
          case ApiStatus.loading:
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          case ApiStatus.noInternet:
            return NoInternetWidget(onRetry: c.load);
          case ApiStatus.unauthorized:
          case ApiStatus.serverError:
          case ApiStatus.validationError:
          case ApiStatus.empty:
            return ErrorStateWidget(message: s.message, onRetry: c.load);
          case ApiStatus.success:
            return _Form(controller: c);
        }
      }),
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({required this.controller});

  final PartnerPreferenceController controller;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  // AppTextFormField takes a controller rather than an initialValue, so the
  // text fields are seeded once from the loaded draft. Rebuilding them from the
  // draft on every keystroke would fight the cursor.
  late final Map<String, TextEditingController> _text;

  PartnerPreferenceController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    final PartnerPreferenceModel d = controller.draft.value;
    _text = <String, TextEditingController>{
      'ageMin': TextEditingController(text: d.ageMin?.toString() ?? ''),
      'ageMax': TextEditingController(text: d.ageMax?.toString() ?? ''),
      'heightMin': TextEditingController(text: d.heightMin?.toStringAsFixed(2) ?? ''),
      'heightMax': TextEditingController(text: d.heightMax?.toStringAsFixed(2) ?? ''),
      'education': TextEditingController(text: d.education ?? ''),
      'profession': TextEditingController(text: d.profession ?? ''),
      'general': TextEditingController(text: d.general ?? ''),
    };
  }

  @override
  void dispose() {
    for (final TextEditingController c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Resolves a stored id back to its lookup row. Returns null when the id is
  /// not in the list (stale reference data), so the field shows the hint rather
  /// than an empty selection.
  LookupItem? _selected(LookupController lookup, String key, int? id) {
    if (id == null) return null;
    for (final LookupItem i in lookup.itemsOf(key)) {
      if (i.id == id) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final LookupController lookup = Get.find<LookupController>();
    // These lists back the dropdowns; the bundled fallback makes them instant.
    lookup
      ..ensure(LookupKeys.maritalStatuses)
      ..ensure(LookupKeys.religions)
      ..ensure(LookupKeys.languages)
      ..ensure(LookupKeys.countries);

    return Obx(() {
      final PartnerPreferenceModel d = controller.draft.value;
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          if (d.isEmpty) const _EmptyInvite(),
          _FilteringNotice(preference: d),
          const SizedBox(height: AppSpacing.md),

          // ---- Filters that genuinely narrow the pool ----
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const CardTitle(
                  icon: Icons.filter_alt_outlined,
                  title: 'Used to filter your matches',
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextFormField(
                        label: 'Minimum age',
                        controller: _text['ageMin'],
                        keyboardType: TextInputType.number,
                        serverError: controller.errorFor('preferred_age_min'),
                        onChanged: (String v) => controller.edit(
                          (PartnerPreferenceModel c) => c.copyWith(ageMin: int.tryParse(v)),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppTextFormField(
                        label: 'Maximum age',
                        controller: _text['ageMax'],
                        keyboardType: TextInputType.number,
                        serverError: controller.errorFor('preferred_age_max'),
                        onChanged: (String v) => controller.edit(
                          (PartnerPreferenceModel c) => c.copyWith(ageMax: int.tryParse(v)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppLookupDropdown(
                  label: 'Marital status',
                  lookupKey: LookupKeys.maritalStatuses,
                  controller: lookup,
                  requirement: FieldRequirement.optional,
                  selected: _selected(lookup, LookupKeys.maritalStatuses, d.maritalStatusId),
                  errorText: controller.errorFor('marital_status_id'),
                  onChanged: (LookupItem? v) => controller.edit(
                    (PartnerPreferenceModel c) => c.copyWith(maritalStatusId: v?.id),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppLookupDropdown(
                  label: 'Religion',
                  lookupKey: LookupKeys.religions,
                  controller: lookup,
                  requirement: FieldRequirement.optional,
                  selected: _selected(lookup, LookupKeys.religions, d.religionId),
                  errorText: controller.errorFor('religion_id'),
                  onChanged: (LookupItem? v) =>
                      controller.edit((PartnerPreferenceModel c) => c.copyWith(religionId: v?.id)),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppLookupDropdown(
                  label: 'Preferred country',
                  lookupKey: LookupKeys.countries,
                  controller: lookup,
                  requirement: FieldRequirement.optional,
                  selected: _selected(lookup, LookupKeys.countries, d.countryId),
                  errorText: controller.errorFor('preferred_country_id'),
                  onChanged: (LookupItem? v) =>
                      controller.edit((PartnerPreferenceModel c) => c.copyWith(countryId: v?.id)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- Scored, not filtered ----
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const CardTitle(icon: Icons.tune_rounded, title: 'Improves your match score'),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'These shape the order of your matches rather than who is '
                  'eligible, so nobody is excluded by them.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextFormField(
                        label: 'Min height (m)',
                        controller: _text['heightMin'],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        serverError: controller.errorFor('height_min'),
                        onChanged: (String v) => controller.edit(
                          (PartnerPreferenceModel c) => c.copyWith(heightMin: double.tryParse(v)),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppTextFormField(
                        label: 'Max height (m)',
                        controller: _text['heightMax'],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        serverError: controller.errorFor('height_max'),
                        onChanged: (String v) => controller.edit(
                          (PartnerPreferenceModel c) => c.copyWith(heightMax: double.tryParse(v)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  label: 'Education',
                  controller: _text['education'],
                  serverError: controller.errorFor('education'),
                  onChanged: (String v) =>
                      controller.edit((PartnerPreferenceModel c) => c.copyWith(education: v)),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  label: 'Profession',
                  controller: _text['profession'],
                  serverError: controller.errorFor('profession'),
                  onChanged: (String v) =>
                      controller.edit((PartnerPreferenceModel c) => c.copyWith(profession: v)),
                ),
                const SizedBox(height: AppSpacing.md),
                // Preferred annual income. The endpoint takes plain numbers
                // (`income_min` / `income_max`); the bands are an app-side list
                // because the reference endpoint serves no income list at all.
                Obx(
                  () => AppLookupDropdown(
                    label: 'Income from (PKR / year)',
                    lookupKey: LookupKeys.partnerIncome,
                    controller: Get.find<LookupController>(),
                    requirement: FieldRequirement.optional,
                    selected: IncomeBand.forValue(
                      controller.draft.value.incomeMin,
                    )?.item,
                    onChanged: (LookupItem? v) => controller.edit(
                      (PartnerPreferenceModel c) =>
                          c.copyWith(incomeMin: v?.id.toDouble()),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => AppLookupDropdown(
                    label: 'Income up to (PKR / year)',
                    lookupKey: LookupKeys.partnerIncome,
                    controller: Get.find<LookupController>(),
                    requirement: FieldRequirement.optional,
                    selected: IncomeBand.forValue(
                      controller.draft.value.incomeMax,
                    )?.item,
                    onChanged: (LookupItem? v) => controller.edit(
                      (PartnerPreferenceModel c) => c.copyWith(
                        // The top band is open-ended, so it sets no ceiling.
                        incomeMax: IncomeBand.forValue(v?.id)?.max?.toDouble(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- Free text ----
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const CardTitle(icon: Icons.notes_rounded, title: 'In your own words'),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  label: 'What matters most to you',
                  controller: _text['general'],
                  maxLines: 3,
                  serverError: controller.errorFor('general'),
                  onChanged: (String v) =>
                      controller.edit((PartnerPreferenceModel c) => c.copyWith(general: v)),
                ),
                if (d.dealBreakers.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text('Deal breakers', style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: d.dealBreakers
                        .map((String t) => StatusPill(label: t, color: AppColors.warning))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Obx(
            () => AppButton(
              label: 'Save preferences',
              icon: Icons.save_rounded,
              loading: controller.saving.value,
              onPressed: () => _save(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Obx(
            () => TextButton(
              onPressed: controller.saving.value ? null : () => _confirmClear(context),
              child: const Text('Clear all preferences'),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      );
    });
  }

  Future<void> _save(BuildContext context) async {
    final String? error = await controller.save();
    if (error != null) {
      AppSnackbar.error(error);
      return;
    }
    // Telling the member their matches changed is the difference between
    // "nothing happened" and "this did something".
    AppSnackbar.success(
      controller.changedFiltering.value
          ? 'Preferences saved. Your matches will update.'
          : 'Preferences saved.',
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Clear all preferences?'),
        content: const Text(
          'Your matches will widen to include everyone eligible. You can set '
          'preferences again at any time.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    final String? error = await controller.clearAll();
    if (error != null) {
      AppSnackbar.error(error);
      return;
    }
    AppSnackbar.info('Preferences cleared.');
  }
}

/// Shown when the member never completed step 17.
class _EmptyInvite extends StatelessWidget {
  const _EmptyInvite();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SurfaceCard(
        child: Row(
          children: <Widget>[
            const Icon(Icons.info_outline_rounded, color: AppColors.info),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'You have not set any preferences yet. Adding them helps us show '
                'you more relevant matches.',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lists which preferences are actively narrowing the pool right now.
class _FilteringNotice extends StatelessWidget {
  const _FilteringNotice({required this.preference});

  final PartnerPreferenceModel preference;

  @override
  Widget build(BuildContext context) {
    final List<String> active = preference.activeFilters;
    if (active.isEmpty) return const SizedBox.shrink();
    return SurfaceCard(
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Filtering your matches by: ${active.join(', ')}',
              style: AppTextStyles.caption.copyWith(color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}
