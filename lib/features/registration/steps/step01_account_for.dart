import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../../../constants/api_options.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_lookups.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_card_selector.dart';
import '../../../widgets/bilingual_text.dart';
import '../../../widgets/step_scaffold.dart';

/// Step 1 — the opening questions of the local 18-step flow.
///
/// `on_behalf` is a dynamic dropdown (`on_behalves`); gender, marriage timeline
/// and the two work-intent questions are the documented hardcoded options.
/// Nothing is sent here — the answers are buffered and submitted with the rest
/// of the payload in `POST /auth/register/complete`.
class Step01Controller extends StepController {
  Step01Controller() : super(1);

  LookupController get lookup => Get.find<LookupController>();

  final Rxn<int> onBehalf = Rxn<int>();
  final Rxn<int> gender = Rxn<int>();
  final RxnString marriageTimeline = RxnString();
  final RxnString willingToWork = RxnString();
  final RxnString expectsSpouseWork = RxnString();

  List<LookupItem> get accountForOptions => lookup.itemsOf(LookupKeys.onBehalf);

  LookupItem? get selectedOption {
    for (final LookupItem i in accountForOptions) {
      if (i.id == onBehalf.value) return i;
    }
    return null;
  }

  /// The server owns the `on_behalves` ids, so the gender a choice implies is
  /// derived from its label rather than from a hardcoded id.
  static const List<String> _maleWords = <String>['son', 'brother', 'father'];
  static const List<String> _femaleWords = <String>['daughter', 'sister', 'mother'];

  String get _selectedName => (selectedOption?.name ?? '').toLowerCase();

  bool get _impliesMale => _maleWords.any(_selectedName.contains);
  bool get _impliesFemale => _femaleWords.any(_selectedName.contains);

  bool get showGender => onBehalf.value != null && !_impliesMale && !_impliesFemale;

  int? get effectiveGender {
    if (_impliesMale) return 1;
    if (_impliesFemale) return 2;
    return gender.value;
  }

  bool get isFemale => effectiveGender == 2;

  /// The ordered list of sub-questions that currently apply.
  List<String> get activeQuestions {
    final List<String> q = <String>['accountFor'];
    if (showGender) q.add('gender');
    q.add('marriage');
    if (isFemale) q.add('work');
    q.add('spouseWork');
    return q;
  }

  bool answered(String key) {
    switch (key) {
      case 'accountFor':
        return onBehalf.value != null;
      case 'gender':
        return gender.value != null;
      case 'marriage':
        return marriageTimeline.value != null;
      case 'work':
        return willingToWork.value != null;
      case 'spouseWork':
        return expectsSpouseWork.value != null;
    }
    return true;
  }

  /// The first unanswered question, or the last one once everything is filled.
  String get currentQuestion {
    final List<String> q = activeQuestions;
    for (final String key in q) {
      if (!answered(key)) return key;
    }
    return q.last;
  }

  @override
  void restore() {
    lookup.ensure(LookupKeys.onBehalf);
    onBehalf.value = buffer.getInt('on_behalf');
    gender.value = buffer.getInt('gender');
    marriageTimeline.value = buffer.getString('marriage_timeline');
    willingToWork.value = buffer.getString('willing_to_work_after_marriage');
    expectsSpouseWork.value = buffer.getString('expects_spouse_to_work');
  }

  @override
  bool extraValidate() {
    if (onBehalf.value == null) {
      error.value = 'Please choose who this profile is for.';
      return false;
    }
    if (showGender && gender.value == null) {
      error.value = 'Please select a gender.';
      return false;
    }
    if (marriageTimeline.value == null) {
      error.value = 'Please choose when you plan to get married.';
      return false;
    }
    if (isFemale && willingToWork.value == null) {
      error.value = 'Please answer whether you will work after marriage.';
      return false;
    }
    if (expectsSpouseWork.value == null) {
      error.value = 'Please answer the spouse-work question.';
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'on_behalf': onBehalf.value,
    'gender': effectiveGender,
    'marriage_timeline': marriageTimeline.value,
    // Sent only when it was asked; the API keeps the same allowed values for both.
    'willing_to_work_after_marriage': isFemale ? willingToWork.value : null,
    'expects_spouse_to_work': expectsSpouseWork.value,
  };
}

/// Icon for an "account for" card, chosen from its label (ids are server-side).
IconData _iconFor(String name) {
  final String n = name.toLowerCase();
  if (n.contains('self') || n.contains('myself')) return Icons.person_rounded;
  if (n.contains('son')) return Icons.boy_rounded;
  if (n.contains('daughter')) return Icons.girl_rounded;
  if (n.contains('brother')) return Icons.man_rounded;
  if (n.contains('sister')) return Icons.woman_rounded;
  if (n.contains('friend')) return Icons.diversity_3_rounded;
  return Icons.family_restroom_rounded;
}

class Step01View extends StatefulWidget {
  const Step01View({super.key});
  @override
  State<Step01View> createState() => _Step01ViewState();
}

class _Step01ViewState extends State<Step01View> {
  late final Step01Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step01Controller());
  }

  @override
  void dispose() {
    Get.delete<Step01Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 1,
      totalSteps: 18,
      title: '',
      subtitle: '',
      busy: c.busy,
      error: c.error,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      children: <Widget>[
        Obx(() {
          final String q = c.currentQuestion;
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
            child: KeyedSubtree(
              key: ValueKey<String>(q),
              child: _question(q),
            ),
          );
        }),
      ],
    );
  }

  Widget _question(String key) {
    switch (key) {
      case 'gender':
        return _wrap(
          'Gender',
          AppCardSelector(
            options: ApiOptions.gender
                .map((LookupItem i) => CardOption(
                      i.id,
                      i.name,
                      icon: i.id == 1 ? Icons.male_rounded : Icons.female_rounded,
                    ))
                .toList(),
            selected: c.gender.value,
            onSelect: (CardOption o) => c.gender.value = o.value as int,
          ),
        );
      case 'marriage':
        return _wrap(
          'When are you planning to get married?',
          _optionCards(ApiOptions.marriageTimeline, c.marriageTimeline.value,
              (String v) => c.marriageTimeline.value = v),
        );
      case 'work':
        return _wrap(
          'Will you continue working after marriage?',
          _optionCards(ApiOptions.workIntent, c.willingToWork.value,
              (String v) => c.willingToWork.value = v),
        );
      case 'spouseWork':
        return _wrap(
          'Do you expect your spouse to work after marriage?',
          _optionCards(ApiOptions.workIntent, c.expectsSpouseWork.value,
              (String v) => c.expectsSpouseWork.value = v),
        );
      case 'accountFor':
      default:
        final List<LookupItem> options = c.accountForOptions;
        return _head(
          'Account for',
          subtitle: 'Who is this profile being created for?',
          child: options.isEmpty
              ? _lookupFallback(c.lookup.stateOf(LookupKeys.onBehalf))
              : AppCardSelector(
                  options: options
                      .map((LookupItem i) => CardOption(i.id, i.name, icon: _iconFor(i.name)))
                      .toList(),
                  selected: c.onBehalf.value,
                  onSelect: (CardOption o) {
                    c.onBehalf.value = o.value as int;
                    if (!c.showGender) c.gender.value = null;
                    // currentQuestion recomputes to the next unanswered question, so
                    // the switcher auto-advances (the "Account for" heading disappears).
                  },
                ),
        );
    }
  }

  /// Shown while the `on_behalves` list is unavailable.
  ///
  /// The list is cached app-wide, so "empty" is never "no options" — it is a
  /// load in flight, a failure, or a cache that was dropped (starting a fresh
  /// signup wipes it) with nobody left to ask for it again. The last case used
  /// to leave this step on a spinner forever, so an `initial` state re-triggers
  /// the load and a failure offers a retry.
  Widget _lookupFallback(ApiState<List<LookupItem>> state) {
    if (state.isInitial) {
      // A load flips the state to `loading` immediately, so this cannot loop.
      SchedulerBinding.instance.addPostFrameCallback((_) => _loadAccountFor());
    }
    if (state.isError || state.status == ApiStatus.empty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: <Widget>[
            BiText(
              'Could not load the options.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.error),
              urduColor: AppColors.error,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadAccountFor,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: BiText.inline(
                'Retry',
                style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  void _loadAccountFor() {
    if (mounted) c.lookup.load(LookupKeys.onBehalf);
  }

  /// A prominent centered heading (title + optional subtitle) for a question.
  Widget _head(String title, {String? subtitle, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BiText(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.display.copyWith(fontSize: 23, fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 6),
          BiText(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontSize: 13.5,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
        const SizedBox(height: 22),
        child,
      ],
    );
  }

  /// Cards for a hardcoded option list: the label is shown, the API value is kept.
  Widget _optionCards(
    List<LookupItem> options,
    String? selectedValue,
    ValueChanged<String> onSelect,
  ) {
    return AppCardSelector(
      options: options.map((LookupItem o) => CardOption(o.code!, o.name)).toList(),
      selected: selectedValue,
      onSelect: (CardOption o) => onSelect(o.value as String),
    );
  }

  /// A centered question label above the selector.
  Widget _wrap(String label, Widget selector) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BiText(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.subtitle.copyWith(fontSize: 17),
        ),
        const SizedBox(height: 18),
        selector,
      ],
    );
  }
}
