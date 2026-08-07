import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import '../controllers/registration_controller.dart';
import 'bilingual_text.dart';
import 'dismiss_keyboard.dart';
import 'reveal.dart';

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

  @override
  Widget build(BuildContext context) {
    final Color muted = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.lightTextSecondary;

    final RegistrationController? reg =
        Get.isRegistered<RegistrationController>() ? Get.find<RegistrationController>() : null;

    // Editing one section from "Complete your profile": the step saves on its
    // own ("Save"), can always be left, and offers no Skip.
    final bool editing = reg?.isEditingSection ?? false;

    // Every step except the account ones (name, contact, password) can be
    // skipped and completed later, so the Skip action is offered automatically.
    final bool skipVisible = !editing && (showSkip || (reg?.canSkip(stepNumber) ?? false));
    final VoidCallback? skipAction =
        onSkip ?? (reg == null ? null : () => reg.skipStep(stepNumber));
    final VoidCallback? backAction = onBack ?? (editing ? () => Get.back<void>() : null);

    final Widget list = ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: <Widget>[
        if (title.isNotEmpty)
          BiText(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.display.copyWith(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        if (subtitle.isNotEmpty) ...<Widget>[
          if (title.isNotEmpty) const SizedBox(height: AppSpacing.xs),
          BiText(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontSize: 13.5, color: muted),
          ),
        ],
        if (note != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _NoteText(text: note!),
        ],
        SizedBox(
          height: (title.isNotEmpty || subtitle.isNotEmpty || note != null)
              ? AppSpacing.xl
              : AppSpacing.xs,
        ),
        if (error != null) Obx(() => _ErrorBanner(message: error!.value)),
        ..._spaced(children),
      ],
    );

    return DismissKeyboard(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: <Widget>[
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
                  child: formKey == null ? list : Form(key: formKey, child: list),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _BottomBar(
          // Editing a section saves it on its own; steps that drive their own
          // label (e.g. partner preferences) keep it.
          primaryLabel: editing ? 'Save' : primaryLabel,
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
        Get.isRegistered<RegistrationController>() ? Get.find<RegistrationController>() : null;

    if (reg == null) {
      return _bar(context, track, stepNumber / totalSteps,
          ((stepNumber / totalSteps) * 100).round());
    }

    return Obx(() {
      // `currentStep` is read so this bar rebuilds as the flow moves; while a
      // single section is edited the progress mirrors profile completion.
      reg.currentStep.value;
      return _bar(context, track, reg.progressFraction, reg.progressPercent);
    });
  }

  Widget _bar(BuildContext context, Color track, double fraction, int percent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      child: Row(
        children: <Widget>[
          _RoundIcon(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: fraction.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (BuildContext c, double v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 7,
                  backgroundColor: track,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$percent%',
            style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primary, fontSize: 14),
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
    const Color color = AppColors.primary;
    return Opacity(
      opacity: onTap == null ? 0.25 : 1,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: color),
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
      minimum: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.md),
      child: _Constrained(
        expand: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (footer != null) ...<Widget>[footer!, const SizedBox(height: AppSpacing.sm)],
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
                      color: AppColors.primary,
                      gradient: AppColors.brandGradient,
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
                    style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primary),
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
        color: useGradient ? Colors.transparent : (disabled ? color.withValues(alpha: 0.5) : color),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 54,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: BiText.inline(
                          label,
                          style: AppTextStyles.button.copyWith(color: Colors.white, fontSize: 14),
                          urduColor: Colors.white.withValues(alpha: 0.95),
                        ),
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

/// A soft red helper note (no box), stacked English + Urdu — matches the
/// verification-note style in the references.
class _NoteText extends StatelessWidget {
  const _NoteText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return BiText(
      text,
      style: AppTextStyles.body.copyWith(color: AppColors.primary, fontWeight: FontWeight.w500),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: BiText(
              message,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
              urduColor: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
