import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_text_styles.dart';
import '../../../constants/registration_options.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_card_selector.dart';
import '../../../widgets/bilingual_text.dart';
import '../../../widgets/step_scaffold.dart';

class Step01Controller extends StepController {
  Step01Controller() : super(1);

  final Rxn<int> onBehalf = Rxn<int>();
  final Rxn<int> gender = Rxn<int>();
  final RxnString marriageTimeline = RxnString();
  final RxnString willingToWork = RxnString();
  final RxnString expectsSpouseWork = RxnString();

  bool get showGender =>
      onBehalf.value != null && RegOptions.needsExplicitGender.contains(onBehalf.value);

  int? get effectiveGender {
    if (RegOptions.impliesMale.contains(onBehalf.value)) return 1;
    if (RegOptions.impliesFemale.contains(onBehalf.value)) return 2;
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
    onBehalf.value = buffer.getInt('on_behalf');
    gender.value = buffer.getInt('gender');
    marriageTimeline.value = buffer.getString('marriage_timeline');
    willingToWork.value = buffer.getString('willing_to_work');
    expectsSpouseWork.value = buffer.getString('expects_spouse_work');
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
    'willing_to_work': isFemale ? willingToWork.value : null,
    'expects_spouse_work': expectsSpouseWork.value,
  };
}

/// Icons for the account-for cards, keyed by [RegOptions.accountFor] id.
const Map<int, IconData> _accountIcons = <int, IconData>{
  1: Icons.person_rounded, // Myself
  2: Icons.boy_rounded, // Son
  3: Icons.girl_rounded, // Daughter
  4: Icons.man_rounded, // Brother
  5: Icons.woman_rounded, // Sister
  7: Icons.diversity_3_rounded, // Friend
  6: Icons.family_restroom_rounded, // Relative
};

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
            options: RegOptions.gender
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
          _stringCards(RegOptions.marriageTimeline, c.marriageTimeline.value,
              (String v) => c.marriageTimeline.value = v),
        );
      case 'work':
        return _wrap(
          'Will you continue working after marriage?',
          _stringCards(RegOptions.workIntent, c.willingToWork.value,
              (String v) => c.willingToWork.value = v),
        );
      case 'spouseWork':
        return _wrap(
          'Do you expect your spouse to work after marriage?',
          _stringCards(RegOptions.workIntent, c.expectsSpouseWork.value,
              (String v) => c.expectsSpouseWork.value = v),
        );
      case 'accountFor':
      default:
        return _head(
          'Account for',
          subtitle: 'Who is this profile being created for?',
          child: AppCardSelector(
            options: RegOptions.accountFor
                .map((LookupItem i) => CardOption(i.id, i.name, icon: _accountIcons[i.id]))
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

  Widget _stringCards(List<String> options, String? selected, ValueChanged<String> onSelect) {
    return AppCardSelector(
      options: options.map((String s) => CardOption(s, s)).toList(),
      selected: selected,
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
