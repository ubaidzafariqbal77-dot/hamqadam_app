import 'dart:ui';

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
import '../../../widgets/bilingual_text.dart';
import '../../../widgets/step_scaffold.dart';
import '../../../constants/reg_icons.dart';

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
  static const List<String> _femaleWords = <String>[
    'daughter',
    'sister',
    'mother',
  ];

  String get _selectedName => (selectedOption?.name ?? '').toLowerCase();

  bool get _impliesMale => _maleWords.any(_selectedName.contains);
  bool get _impliesFemale => _femaleWords.any(_selectedName.contains);

  bool get showGender =>
      onBehalf.value != null && !_impliesMale && !_impliesFemale;

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
      // Step 1 is the only screen that had no back action, which trapped the
      // user in signup with no way back to login. `back()` leaves the flow.
      onBack: c.back,
      // Reference style: option questions sit directly on the rose canvas —
      // no white card. Titles use the deep-ink serif tone.
      flat: true,
      titleColor: const Color(0xFF3A2E33),
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
            child: KeyedSubtree(key: ValueKey<String>(q), child: _question(q)),
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
          // The reference sets this one heading in rose (#874453) rather than
          // the flow's usual dark plum.
          titleColor: AppColors.roseTitleRose,
          subtitle: 'Select your gender identity',
          _GenderCardRow(
            options: ApiOptions.gender,
            selected: c.gender.value,
            onSelect: (int v) => c.gender.value = v,
          ),
        );
      case 'marriage':
        return _wrap(
          'When are you planning to get married?',
          subtitle: 'Select an option that best fits your plans',
          _optionCards(
            ApiOptions.marriageTimeline,
            c.marriageTimeline.value,
            (String v) => c.marriageTimeline.value = v,
          ),
        );
      case 'work':
        return _wrap(
          'Will you continue working after marriage?',
          subtitle: 'Select what suits you',
          _optionCards(
            ApiOptions.workIntent,
            c.willingToWork.value,
            (String v) => c.willingToWork.value = v,
          ),
        );
      case 'spouseWork':
        return _wrap(
          'Do you expect your spouse to work after marriage?',
          subtitle: 'Select your preference',
          _optionCards(
            ApiOptions.workIntent,
            c.expectsSpouseWork.value,
            (String v) => c.expectsSpouseWork.value = v,
          ),
        );
      case 'accountFor':
      default:
        final List<LookupItem> options = c.accountForOptions;
        return _head(
          'Account for',
          subtitle: 'Who is this profile being created for?',
          child: options.isEmpty
              ? _lookupFallback(c.lookup.stateOf(LookupKeys.onBehalf))
              : _AccountForImageGrid(
                  options: options,
                  selected: c.onBehalf.value,
                  onSelect: (int id) {
                    c.onBehalf.value = id;
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
                style: AppTextStyles.bodyStrong.copyWith(
                  color: AppColors.regAccent,
                ),
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
          // Playfair Display, matching every step heading in the references.
          style: AppTextStyles.displaySerif.copyWith(
            fontSize: 22,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.roseTitleInk,
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 6),
          BiText(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontSize: 14.5,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
        const SizedBox(height: 22),
        child,
      ],
    );
  }

  /// Cards for a hardcoded option list: the label is shown, the API value is
  /// kept. Reference style — full-width frosted rows with a numbered gradient
  /// circle on the left, stacked directly on the rose canvas.
  Widget _optionCards(
    List<LookupItem> options,
    String? selectedValue,
    ValueChanged<String> onSelect,
  ) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < options.length; i++) ...<Widget>[
          _OptionRow(
            index: i + 1,
            label: options[i].name,
            isSelected: selectedValue == options[i].code,
            onTap: () => onSelect(options[i].code!),
          ),
          if (i != options.length - 1) const SizedBox(height: 18),
        ],
      ],
    );
  }

  /// A centered question label above the selector — reference-style large
  /// serif-feel ink title with a soft muted subtitle.
  Widget _wrap(
    String label,
    Widget selector, {
    String? subtitle,
    Color? titleColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BiText(
          label,
          textAlign: TextAlign.center,
          // Playfair Display, matching every step heading in the references.
          style: AppTextStyles.displaySerif.copyWith(
            fontSize: 22,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : (titleColor ?? AppColors.roseTitleInk),
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
        const SizedBox(height: 26),
        selector,
      ],
    );
  }
}

/// The reference design's gender picker: two tall cards side by side, each
/// with the gender symbol on top, the floral-wreath portrait in the middle
/// (`male.png` / `female.png`), a big serif-feel name and a muted subtitle.
class _GenderCardRow extends StatelessWidget {
  const _GenderCardRow({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<LookupItem> options;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          // NOT stretch: this row sits inside the question AnimatedSwitcher,
          // which lays out with unbounded height — stretch forces a tight
          // (circular) height and crashes with "RenderBox was not laid out".
          // Equal heights come from AspectRatio sizing every portrait from
          // the card width instead.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: options
              .map(
                (LookupItem o) => Expanded(
                  child: _GenderCard(
                    id: o.id,
                    name: o.name,
                    isSelected: selected == o.id,
                    onTap: () => onSelect(o.id),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        BiText(
          'You can update this anytime in your profile settings',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }
}

/// The reference design's option row: a frosted-glass pill (white blur over
/// the rose canvas) with a soft pink gradient numbered circle on the left and
/// a large ink label. Selected = pink border + gentle glow + check badge.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.index,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  String get _num => index.toString().padLeft(2, '0');

  /// The painted badge artwork for rows 01–04 (reference discs). Extra rows
  /// fall back to the gradient text inside the widget above.
  String _badgeFor(int i) => switch (i) {
    1 => RegIcons.badge01,
    2 => RegIcons.badge02,
    3 => RegIcons.badge03,
    4 => RegIcons.badge04,
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // Frosted white wash — the rose petals behind blur through it.
              color: dark
                  ? AppColors.darkSurface.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected
                    ? AppColors.regAccent
                    : Colors.white.withValues(alpha: 0.8),
                width: isSelected ? 1.8 : 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: isSelected
                      ? AppColors.regAccent.withValues(alpha: 0.20)
                      : const Color(0xFFB4487B).withValues(alpha: 0.06),
                  blurRadius: isSelected ? 18 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                // Numbered gradient circle — the reference's painted badge
                // artwork (badge01–04) when present, gradient text fallback.
                Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    _badgeFor(index),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            AppColors.regAccent.withValues(alpha: 0.75),
                            AppColors.regAccentSoft.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                      child: Text(
                        _num,
                        style: AppTextStyles.display.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF2B2230),
                    ),
                  ),
                ),
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 24,
                      color: AppColors.regAccent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.id,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  final int id;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  /// "Female" also contains "male", so check the longer word first.
  bool get _isFemale => name.toLowerCase().contains('female') || id == 2;

  String get _asset =>
      _isFemale ? 'assets/images/female.png' : 'assets/images/male.png';

  IconData get _symbol => _isFemale ? Icons.female_rounded : Icons.male_rounded;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 7),
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkSurface : const Color(0xFFFDF6F8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.regAccent : AppColors.roseFieldBorder,
            width: isSelected ? 2 : 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: isSelected
                  ? AppColors.regAccent.withValues(alpha: 0.20)
                  : const Color(0xFFB4487B).withValues(alpha: 0.07),
              blurRadius: isSelected ? 18 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              _symbol,
              size: 38,
              color: AppColors.regAccent.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 16),
            // Floral-wreath portrait inside a soft pink disc.
            AspectRatio(
              aspectRatio: 1.05,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.regAccent.withValues(alpha: 0.08),
                ),
                padding: const EdgeInsets.all(8),
                child: ClipOval(
                  child: Image.asset(
                    _asset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      _isFemale ? Icons.woman_rounded : Icons.man_rounded,
                      size: 56,
                      color: AppColors.regAccent.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.displaySerif.copyWith(
                fontSize: 22,
                color: AppColors.roseTitleRose,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Typically identifies as ${name.toLowerCase()}',
              textAlign: TextAlign.center,
              // Two lines, not one: at the card's width the sentence was
              // ellipsing to "Typically identifies …" on every phone, which is
              // not what the reference shows and says nothing to the reader.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                height: 1.35,
                color: AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reference design's photo-card grid for "Account for": each option is a
/// rounded photo card with the label on a frosted strip at the bottom.
///
/// The artwork files are matched by the option's NAME (`accountfor.png` …
/// `accountfor8.png`, added in the reference order: Self, Son, Daughter,
/// Brother, Sister, Friend, Relative, Counselor). An option whose name has no
/// artwork — e.g. the server renames one or adds a new one — falls back to a
/// tinted icon card, and unknown ids still work.
class _AccountForImageGrid extends StatelessWidget {
  const _AccountForImageGrid({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<LookupItem> options;
  final int? selected;
  final ValueChanged<int> onSelect;

  static const List<String> _artNames = <String>[
    'self',
    'son',
    'daughter',
    'brother',
    'sister',
    'friend',
    'relative',
    'guardian',
  ];

  String? _artFor(String name) {
    final String n = name.toLowerCase().trim();
    for (int i = 0; i < _artNames.length; i++) {
      if (n.contains(_artNames[i]))
        return 'assets/images/accountfor${i == 0 ? '' : i + 1}.png';
    }
    return null;
  }

  IconData _fallbackIcon(String name) {
    final String n = name.toLowerCase();
    if (n.contains('son') || n.contains('brother')) return Icons.man_rounded;
    if (n.contains('daughter') || n.contains('sister'))
      return Icons.woman_rounded;
    if (n.contains('relative') || n.contains('family'))
      return Icons.family_restroom_rounded;
    if (n.contains('counselor')) return Icons.support_agent_rounded;
    return Icons.person_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        const int columns = 2;
        const double gap = 14;
        final double tileWidth = (c.maxWidth - gap * (columns - 1)) / columns;
        // Photos are 4:3; the frosted label strip rides the bottom.
        final double tileHeight = (tileWidth * 0.78).clamp(140.0, 190.0);

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: options.map((LookupItem o) {
            final String art = _artFor(o.name) ?? '';
            return SizedBox(
              width: tileWidth,
              height: tileHeight,
              child: _AccountForCard(
                label: o.name,
                asset: art.isEmpty ? null : art,
                fallbackIcon: _fallbackIcon(o.name),
                isSelected: selected == o.id,
                onTap: () => onSelect(o.id),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _AccountForCard extends StatelessWidget {
  const _AccountForCard({
    required this.label,
    required this.asset,
    required this.fallbackIcon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String? asset;
  final IconData fallbackIcon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.regAccent : AppColors.roseFieldBorder,
            width: isSelected ? 2 : 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: isSelected
                  ? AppColors.regAccent.withValues(alpha: 0.22)
                  : const Color(0xFFB4487B).withValues(alpha: 0.08),
              blurRadius: isSelected ? 16 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(7),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (asset != null)
                Image.asset(asset!, fit: BoxFit.cover)
              else
                Container(
                  color: AppColors.regAccent.withValues(alpha: 0.08),
                  child: Icon(
                    fallbackIcon,
                    size: 40,
                    color: AppColors.regAccent.withValues(alpha: 0.6),
                  ),
                ),
              // Frosted label strip: FULL width, pinned to the bottom edge —
              // the photo shows through a real blur (reference close-up).
              // The parent ClipRRect gives it the matching bottom corners.
              Align(
                alignment: Alignment.bottomCenter,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.42),
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2B2230),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.regAccent,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
