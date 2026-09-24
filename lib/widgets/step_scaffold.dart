import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import '../controllers/registration_controller.dart';
import 'bilingual_text.dart';
import 'dismiss_keyboard.dart';
import 'reveal.dart';
import 'step_art.dart';

/// Clean, professional step scaffold matching the product design references:
/// a header with a back chevron + centered brand logo, a thin rounded progress
/// bar, a centered bilingual title + subtitle, an optional red note, the
/// scrollable body, and a bottom Back + Continue button pair (Continue only on
/// the first step) with an optional Skip.
class StepScaffold extends StatelessWidget {
  const StepScaffold({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    required this.busy,
    this.primaryLabelRx,
    this.error,
    this.formKey,
    this.primaryEnabled = true,
    this.showSkip = false,
    this.onSkip,
    this.onBack,
    this.helpText,
    this.note,
    this.footer,
    this.art,
    this.artIcon,
    this.titleColor,
    this.flat = false,
    this.compactHeader = false,
  });

  final int stepNumber;
  final int totalSteps;
  final String title;
  final String subtitle;
  final String? note;
  final List<Widget> children;
  final String primaryLabel;
  final RxString? primaryLabelRx;
  final Future<void> Function() onPrimary;
  final RxBool busy;
  final RxString? error;
  final GlobalKey<FormState>? formKey;
  final bool primaryEnabled;
  final bool showSkip;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;

  /// Retained for API compatibility; the redesigned header has no help button.
  final String? helpText;
  final Widget? footer;

  /// Decorative watercolour illustration shown above the title (reference
  /// style). The asset may not exist yet — [StepArt] falls back to a soft
  /// glow icon until the real artwork is dropped in.
  final String? art;
  final IconData? artIcon;

  /// Overrides the ink title (some reference screens use the deep-rose
  /// serif tone for the heading).
  final Color? titleColor;

  /// Skip the floating white card: content sits directly on the rose canvas
  /// (reference style for option-question screens).
  final bool flat;

  /// The Marital-status reference header: a large LEFT-aligned serif title
  /// with the percentage on the right, the progress bar underneath, and a
  /// left-aligned rose question line. Replaces the centred top bar (and its
  /// back chevron — the reference has none) with this inline block.
  final bool compactHeader;

  @override
  Widget build(BuildContext context) {
    final Color muted =
        Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.lightTextSecondary;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = dark
        ? AppColors.darkTextPrimary
        : const Color(0xFF2B2230);

    final RegistrationController? reg =
        Get.isRegistered<RegistrationController>()
        ? Get.find<RegistrationController>()
        : null;

    // Editing one section from "Complete your profile": the step saves on its
    // own ("Save"), can always be left, and offers no Skip.
    final bool editing = reg?.isEditingSection ?? false;

    // Correcting a field the finalizing screen rejected. Same shape as editing
    // — the step returns to its caller instead of advancing — but the wording
    // says what actually happens next.
    final bool fixing = reg?.isFixingForFinalize ?? false;

    // Every step except the account ones (name, contact, password) can be
    // skipped and completed later, so the Skip action is offered automatically.
    // A rejected field is never skippable: skipping is what left it empty.
    final bool skipVisible =
        !editing &&
        !fixing &&
        (showSkip || (reg?.canSkip(stepNumber) ?? false));
    final VoidCallback? skipAction =
        onSkip ?? (reg == null ? null : () => reg.skipStep(stepNumber));
    final VoidCallback? backAction =
        onBack ?? (editing ? () => Get.back<void>() : null);

    // A plain Column, NOT a ListView: the references draw a card that hugs its
    // content, and a ListView always takes every pixel it is given — on a short
    // step like Basic information that left most of the white card empty. The
    // scrolling moved outside the card (see below), so a long step still
    // scrolls; the card just grows with what is in it.
    final Widget list = Padding(
      padding: EdgeInsets.fromLTRB(
        dark ? AppSpacing.lg : 18,
        dark ? AppSpacing.xl : 10,
        dark ? AppSpacing.lg : 18,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
        if (compactHeader)
          _compactHeader(context, reg, ink, dark)
        else ...<Widget>[
        // An empty string means "this reference screen has no image slot"
        // (e.g. Physical information) — render nothing at all.
        if (art != null && art!.isNotEmpty) ...<Widget>[
          StepArt(asset: art!, icon: artIcon),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (title.isNotEmpty)
          BiText(
            title,
            textAlign: TextAlign.center,
            // Playfair Display, the way every step heading is drawn in the
            // design references. Only the English line takes the serif — the
            // Urdu companion stays Nastaliq, which has no serif counterpart.
            style: AppTextStyles.displaySerif.copyWith(
              fontSize: 27,
              color: titleColor ?? (dark ? ink : AppColors.roseTitleInk),
            ),
          ),
        if (subtitle.isNotEmpty) ...<Widget>[
          if (title.isNotEmpty) const SizedBox(height: AppSpacing.sm),
          BiText(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontSize: 13.5, color: muted),
          ),
        ],
        ],
        if (note != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _TipBanner(text: note!),
        ],
        SizedBox(
          height: (title.isNotEmpty || subtitle.isNotEmpty || note != null)
              ? AppSpacing.xl
              : AppSpacing.xs,
        ),
          if (error != null) Obx(() => _ErrorBanner(message: error!.value)),
          ..._spaced(children),
        ],
      ),
    );

    // Registration runs on the references' muted dusty rose, while the rest of
    // the app keeps the brand pink. Overriding the scheme here rather than in
    // AppColors is what keeps that difference contained: the shared field
    // widgets (also used by Edit profile and Login) read their accent from the
    // theme, so they pick up the rose in this flow and nowhere else.
    final ThemeData base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: dark ? AppColors.primary : AppColors.regAccent,
        ),
      ),
      child: _build(context, list, reg, backAction, skipAction, skipVisible,
          editing, fixing, dark),
    );
  }

  Widget _build(
    BuildContext context,
    Widget list,
    RegistrationController? reg,
    VoidCallback? backAction,
    VoidCallback? skipAction,
    bool skipVisible,
    bool editing,
    bool fixing,
    bool dark,
  ) {
    return PopScope(
      // The system back gesture must go through the same path as the on-screen
      // back button. Left to itself it pops the route without telling the
      // registration controller, so `currentStep` and the buffer resume point
      // drift out of sync with what is on screen — and on a resumed session,
      // where the stack holds a single route, it closes the app outright.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        backAction?.call();
      },
      child: DismissKeyboard(
        child: DecoratedBox(
          // Reference canvas: soft rose watercolour wash behind a floating
          // white card. Dark mode keeps the flat dark surface.
          decoration: BoxDecoration(
            gradient: dark
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      AppColors.roseCanvas,
                      AppColors.roseCanvasDeep,
                    ],
                  ),
            color: dark ? AppColors.darkBackground : null,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  // The compact header draws title + percentage + progress bar
                  // inside the scroll content, so the centred top bar (and its
                  // back chevron — the reference has none) is skipped.
                  if (!compactHeader)
                    _Constrained(
                      expand: false,
                      child: _TopBar(
                        stepNumber: stepNumber,
                        totalSteps: totalSteps,
                        onBack: backAction,
                      ),
                    ),
                  Expanded(
                    child: _Constrained(
                      // The scroll view sits OUTSIDE the card so the card can
                      // size itself to its content instead of stretching to
                      // fill the screen — which is how every reference screen
                      // draws it.
                      child: SingleChildScrollView(
                        child: formKey == null
                            ? _card(context, list)
                            : Form(key: formKey, child: _card(context, list)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: _BottomBar(
              // Editing a section saves it on its own; a correction returns to
              // finalizing; steps that drive their own label (e.g. partner
              // preferences) keep it.
              primaryLabel: fixing
                  ? 'Save & continue setup'
                  : editing
                  ? 'Save'
                  : primaryLabel,
              primaryLabelRx: primaryLabelRx,
              onPrimary: onPrimary,
              busy: busy,
              primaryEnabled: primaryEnabled,
              showSkip: skipVisible,
              onSkip: skipAction,
              onBack: backAction,
              footer: footer,
            ),
          ),
        ),
      ),
    );
  }

  /// The Marital-status reference header: LEFT-aligned serif title with the
  /// percentage at the right, the thin progress bar underneath, then a
  /// left-aligned rose question line. Reads the same live progress the top
  /// bar does (step fraction, or profile progress while editing a section).
  Widget _compactHeader(BuildContext context, RegistrationController? reg,
      Color ink, bool dark) {
    final double fraction;
    final int percent;
    if (reg == null) {
      fraction = stepNumber / totalSteps;
      percent = ((stepNumber / totalSteps) * 100).round();
    } else {
      fraction = reg.progressFraction;
      percent = reg.progressPercent;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: BiText(
                title,
                textAlign: TextAlign.left,
                style: AppTextStyles.displaySerif.copyWith(
                  fontSize: 32,
                  height: 1.1,
                  color: titleColor ?? (dark ? ink : AppColors.roseTitleInk),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$percent%',
              style: AppTextStyles.bodyStrong.copyWith(
                fontSize: 15,
                color: AppColors.regAccent.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: fraction.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (BuildContext c, double v, _) => Container(
              height: 7,
              color: dark ? Theme.of(c).dividerColor : const Color(0xFFF6D9E2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: v,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.regPrimaryGradient,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (subtitle.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          BiText(
            subtitle,
            textAlign: TextAlign.left,
            style: AppTextStyles.body.copyWith(
              fontSize: 15.5,
              color: dark
                  ? AppColors.darkTextSecondary
                  : AppColors.regAccent.withValues(alpha: 0.9),
            ),
          ),
        ],
      ],
    );
  }

  /// The floating white rounded card that holds the step content (reference
  /// style). Dark mode keeps the plain surface without the card treatment.
  Widget _card(BuildContext context, Widget child) {
    if (Theme.of(context).brightness == Brightness.dark || flat) return child;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFB4487B).withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(28), child: child),
    );
  }

  List<Widget> _spaced(List<Widget> items) {
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      // Every field/card bounces in (like the gender cards). Children that
      // already animate themselves are left as-is to avoid a double bounce.
      final Widget child = items[i] is Reveal
          ? items[i]
          : Reveal(delayMs: i * 70 > 490 ? 490 : i * 70, child: items[i]);
      out.add(child);
      if (i != items.length - 1) out.add(const SizedBox(height: AppSpacing.lg));
    }
    return out;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.stepNumber,
    required this.totalSteps,
    this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final Color track = Theme.of(context).dividerColor;
    final RegistrationController? reg =
        Get.isRegistered<RegistrationController>()
        ? Get.find<RegistrationController>()
        : null;

    if (reg == null) {
      return _bar(
        context,
        track,
        stepNumber / totalSteps,
        ((stepNumber / totalSteps) * 100).round(),
      );
    }

    return Obx(() {
      // `currentStep` is read so this bar rebuilds as the flow moves; while a
      // single section is edited the progress mirrors profile completion.
      reg.currentStep.value;
      return _bar(context, track, reg.progressFraction, reg.progressPercent);
    });
  }

  Widget _bar(BuildContext context, Color track, double fraction, int percent) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          _RoundIcon(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: fraction.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                // The references fill the bar with a left-to-right rose
                // gradient rather than one flat pink, which is why this is a
                // sized box over a FractionallySizedBox instead of a plain
                // LinearProgressIndicator.
                builder: (BuildContext c, double v, _) => Container(
                  height: 8,
                  color: dark ? track : const Color(0xFFF6D9E2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: v,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppColors.regPrimaryGradient,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$percent%',
            style: AppTextStyles.bodyStrong.copyWith(
              color: AppColors.regAccent,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const Color color = AppColors.regAccent;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: onTap == null ? 0.25 : 1,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Soft pink disc behind the back chevron (reference style).
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.regAccent.withValues(alpha: 0.16),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.primaryLabel,
    required this.primaryLabelRx,
    required this.onPrimary,
    required this.busy,
    required this.primaryEnabled,
    required this.showSkip,
    this.onSkip,
    this.onBack,
    this.footer,
  });

  final String primaryLabel;
  final RxString? primaryLabelRx;
  final Future<void> Function() onPrimary;
  final RxBool busy;
  final bool primaryEnabled;
  final bool showSkip;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final Color backColor = Color.lerp(AppColors.primary, Colors.white, 0.42)!;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: _Constrained(
        expand: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (footer != null) ...<Widget>[
              footer!,
              const SizedBox(height: AppSpacing.sm),
            ],
            Obx(
              () => Row(
                children: <Widget>[
                  if (onBack != null) ...<Widget>[
                    Expanded(
                      child: _PillButton(
                        label: 'Back',
                        color: backColor,
                        onTap: busy.value ? null : onBack,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: _PillButton(
                      label: primaryLabelRx?.value ?? primaryLabel,
                      color: AppColors.regAccent,
                      gradient: AppColors.regPrimaryGradient,
                      busy: busy.value,
                      onTap: (busy.value || !primaryEnabled) ? null : onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (showSkip)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: TextButton(
                  onPressed: () {
                    if (!busy.value) onSkip?.call();
                  },
                  child: BiText.inline(
                    'Skip',
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Flat, rounded action button used in the bottom bar.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.gradient,
    this.busy = false,
  });

  final String label;
  final Color color;
  final List<Color>? gradient;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;
    final bool useGradient = gradient != null && !disabled;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    // Reference style: the Back pill is white with a pink hairline and pink
    // label; the primary stays the filled brand gradient.
    final bool isBackPill =
        gradient == null &&
        color == Color.lerp(AppColors.primary, Colors.white, 0.42);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: useGradient
            ? LinearGradient(
                colors: gradient!,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: useGradient
            ? <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.38),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  spreadRadius: -3,
                ),
              ]
            : null,
      ),
      child: Material(
        color: useGradient
            ? Colors.transparent
            : isBackPill
            ? (dark ? Colors.white.withValues(alpha: 0.06) : Colors.white)
            : (disabled ? color.withValues(alpha: 0.5) : color),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: isBackPill && !dark
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.roseFieldBorder,
                      width: 1.4,
                    ),
                  )
                : null,
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: BiText.inline(
                        label,
                        style: AppTextStyles.button.copyWith(
                          color: isBackPill ? AppColors.regAccent : Colors.white,
                          fontSize: 14,
                        ),
                        urduColor: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Centres content and caps its width on large screens so the flow stays
/// comfortably readable and never stretches edge-to-edge.
class _Constrained extends StatelessWidget {
  const _Constrained({required this.child, this.expand = true});
  final Widget child;
  final bool expand;

  static const double maxWidth = 600;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: expand ? null : 1.0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Soft pink "Tip:" banner with a bulb icon — the reference design's helper
/// note. Reads the same [note] text steps already pass in.
class _TipBanner extends StatelessWidget {
  const _TipBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    // "Did you know? …" notes render as the Education reference card: a bulb
    // disc, a bold question title, and the fact underneath.
    const String q = 'Did you know?';
    final bool splitTitle = text.startsWith(q);
    // Colours and the outline bulb come from the references; the "Did you
    // know?" variant additionally carries the thin gold rule the Education
    // screen draws around it.
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.primary.withValues(alpha: 0.10)
            : AppColors.tipBg,
        borderRadius: BorderRadius.circular(16),
        border: (!dark && splitTitle)
            ? Border.all(color: AppColors.tipGoldBorder, width: 1)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: dark
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : AppColors.tipDisc,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              size: 24,
              color: dark ? AppColors.primary : AppColors.tipGlyph,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: splitTitle
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      BiText(
                        q,
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontSize: 16.5,
                          color: dark
                              ? AppColors.primaryLight
                              : AppColors.tipTitleInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      BiText(
                        text.substring(q.length).trim(),
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 13.5,
                          height: 1.4,
                          color: dark
                              ? AppColors.darkTextSecondary
                              : AppColors.tipBodyInk,
                        ),
                      ),
                    ],
                  )
                : BiText(
                    text,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 13,
                      height: 1.45,
                      color: dark
                          ? AppColors.darkTextSecondary
                          : AppColors.tipBodyInk,
                    ),
                    urduColor: AppColors.tipBodyInk,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    // The references draw this prompt as a soft rose notice with a gold "i"
    // disc — not a red error strip. Colours sampled off the Gender screen.
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.noticeBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.noticeIconDisc),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.noticeIconDisc,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.noticeIconRing, width: 1.4),
            ),
            // The reference marks this notice with a lower-case "i", not an
            // exclamation — drawn as a glyph so it sits inside the gold ring
            // rather than bringing a second circle of its own.
            child: Text(
              'i',
              style: AppTextStyles.displaySerif.copyWith(
                fontSize: 17,
                height: 1,
                fontWeight: FontWeight.w700,
                color: AppColors.noticeIconRing,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: BiText(
              message,
              style: AppTextStyles.bodyStrong.copyWith(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: AppColors.noticeInk,
              ),
              urduColor: AppColors.noticeInk,
            ),
          ),
        ],
      ),
    );
  }
}
