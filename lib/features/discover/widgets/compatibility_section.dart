import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../models/public_profile_model.dart';

/// Shows what the matchmaking model actually decided about a pair.
///
/// The score itself was already on the profile chip; what was missing was the
/// reasoning behind it. `GET /profiles/{id}/compatibility` has always returned
/// the explanation, the reasons and the per-criterion breakdown — nothing in
/// the app ever read them, so every member saw a bare number with no way to
/// tell a 90% built on religion and age from a 90% built on hobbies.
///
/// Unmet criteria are shown alongside the met ones on purpose: a matchmaking
/// score that only ever lists positives is not information, it is decoration.
class CompatibilitySection extends StatelessWidget {
  const CompatibilitySection({super.key, required this.future, this.overridePercentage});

  final Future<CompatibilityModel?> future;

  /// The AI match percentage the listing card already shows
  /// (`compatibility_percentage` on `GET /search/profiles` and `GET /matches`).
  ///
  /// The detail endpoint `/profiles/{id}/compatibility` can answer with a
  /// DIFFERENT number — a stored rule-based row or a re-scored value — and the
  /// section then contradicts the very card the member tapped from. When this
  /// is set, the AI listing score WINS: the endpoint is only read for the
  /// explanation and the per-criterion checklist around it.
  final int? overridePercentage;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CompatibilityModel?>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<CompatibilityModel?> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _CompatibilitySkeleton();
        }
        final CompatibilityModel? data = snap.data;
        // A missing score is not an error worth shouting about — the rest of
        // the profile is still perfectly usable. But when the listing card
        // carried a score, this section still draws with it, keeping the
        // card and the detail page in agreement even when the endpoint failed.
        if (snap.hasError || data == null) {
          final int? o = overridePercentage;
          if (o == null || o <= 0) return const SizedBox.shrink();
          return _CompatibilityCard(
            data: CompatibilityModel(profileId: 0, percentage: o),
          );
        }
        // Without a listing override, a zero / absent score stays hidden —
        // the rest of the profile is still perfectly usable.
        if (overridePercentage == null && data.percentage <= 0) {
          return const SizedBox.shrink();
        }
        return _CompatibilityCard(
          data: data,
          displayPercentage:
              (overridePercentage != null && overridePercentage! > 0)
                  ? overridePercentage
                  : data.percentage,
        );
      },
    );
  }
}

class _CompatibilityCard extends StatelessWidget {
  const _CompatibilityCard({required this.data, int? displayPercentage})
      : _displayPercentage = displayPercentage;

  final CompatibilityModel data;

  /// The headline number. Defaults to the endpoint's own percentage; the
  /// section passes the AI listing score here so the card never disagrees
  /// with what the member saw on the list.
  final int? _displayPercentage;

  int get _shownPercentage => _displayPercentage ?? data.percentage;

  Color get _scoreColor {
    if (_shownPercentage >= 80) return AppColors.success;
    if (_shownPercentage >= 60) return AppColors.gold;
    if (_shownPercentage >= 40) return Colors.orange;
    return AppColors.error;
  }

  String get _levelLabel {
    if (_shownPercentage >= 80) return 'Very high compatibility';
    if (_shownPercentage >= 60) return 'High compatibility';
    if (_shownPercentage >= 40) return 'Moderate compatibility';
    return 'Growing compatibility';
  }

  @override
  Widget build(BuildContext context) {
    final List<CompatibilityCriterion> matched = data.matched;
    final List<CompatibilityCriterion> unmatched = data.unmatched;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lightDivider),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ---- Header: "Why this match?" -------------------------------
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: AppColors.brandGradient),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Why this match?',
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          // ---- Score: accent bar + "82% compatibility" -----------------
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 4,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: _scoreColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$_shownPercentage% compatibility',
                style: AppTextStyles.title.copyWith(
                  color: AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(
              '${data.sourceLabel} · $_levelLabel',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.lightTextSecondary,
              ),
            ),
          ),

          // ---- The model's explanation, softened for display -----------
          if (data.displayExplanation != null && data.displayExplanation!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Text(
                data.displayExplanation!.trim(),
                style: AppTextStyles.caption.copyWith(
                  height: 1.5,
                  color: AppColors.lightInputText,
                ),
              ),
            ),
          ],

          // ---- "Why?" checklist — met and unmet criteria alike ---------
          if (matched.isNotEmpty || unmatched.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Text(
                'Why?',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Column(
                children: <Widget>[
                  ...matched.map(
                    (CompatibilityCriterion c) => _WhyRow(
                      criterion: c,
                      met: true,
                    ),
                  ),
                  ...unmatched.map(
                    (CompatibilityCriterion c) => _WhyRow(
                      criterion: c,
                      met: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One line of the "Why?" checklist: ✓ for a satisfied criterion, ⚠ for one
/// that did not line up. Tap shows the model's own sentence for that criterion
/// when it has one — far more specific than the label alone.
class _WhyRow extends StatelessWidget {
  const _WhyRow({required this.criterion, required this.met});

  final CompatibilityCriterion criterion;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final Color color = met ? AppColors.success : Colors.orange;
    final Widget row = Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              met ? Icons.check_rounded : Icons.warning_amber_rounded,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              criterion.label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.lightInputText,
              ),
            ),
          ),
        ],
      ),
    );

    final String? reason = criterion.reason;
    if (reason == null || reason.trim().isEmpty) return row;
    return Tooltip(
      message: reason,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 4),
      child: row,
    );
  }
}

class _CompatibilitySkeleton extends StatelessWidget {
  const _CompatibilitySkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 92,
      decoration: BoxDecoration(
        color: AppColors.lightTextSecondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
