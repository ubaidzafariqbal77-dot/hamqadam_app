import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
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
  const CompatibilitySection({super.key, required this.future});

  final Future<CompatibilityModel?> future;

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
        // the profile is still perfectly usable.
        if (snap.hasError || data == null || data.percentage <= 0) {
          return const SizedBox.shrink();
        }
        return _CompatibilityCard(data: data);
      },
    );
  }
}

class _CompatibilityCard extends StatelessWidget {
  const _CompatibilityCard({required this.data});

  final CompatibilityModel data;

  Color get _scoreColor {
    if (data.percentage >= 80) return AppColors.success;
    if (data.percentage >= 60) return AppColors.gold;
    if (data.percentage >= 40) return Colors.orange;
    return AppColors.error;
  }

  String get _levelLabel {
    if (data.percentage >= 80) return 'Very high compatibility';
    if (data.percentage >= 60) return 'High compatibility';
    if (data.percentage >= 40) return 'Moderate compatibility';
    return 'Low compatibility';
  }

  @override
  Widget build(BuildContext context) {
    final List<CompatibilityCriterion> matched = data.matched;
    final List<CompatibilityCriterion> unmatched = data.unmatched;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _scoreColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: _scoreColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _ScoreDial(percentage: data.percentage, color: _scoreColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _levelLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _scoreColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Icon(
                          data.isAi ? Icons.auto_awesome_rounded : Icons.tune_rounded,
                          size: 13,
                          color: AppColors.lightTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            data.sourceLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (data.explanation != null && data.explanation!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              data.explanation!.trim(),
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.lightInputText,
              ),
            ),
          ],

          // Reasons the model gave, in its own words.
          if (data.reasons.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            ...data.reasons.take(4).map(
                  (String r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            r,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: AppColors.lightInputText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],

          if (matched.isNotEmpty || unmatched.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: AppSpacing.lg),
            const Text(
              'What was compared',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                ...matched.map((CompatibilityCriterion c) => _CriterionChip(criterion: c, met: true)),
                ...unmatched.map((CompatibilityCriterion c) => _CriterionChip(criterion: c, met: false)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A criterion as a chip. Long-press shows the model's own sentence for it,
/// which is far more specific than the label ("Age 26 is within preferred
/// range 22-30").
class _CriterionChip extends StatelessWidget {
  const _CriterionChip({required this.criterion, required this.met});

  final CompatibilityCriterion criterion;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final Color color = met ? AppColors.success : AppColors.error;
    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(met ? Icons.check_rounded : Icons.close_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            criterion.label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
          ),
          if (criterion.isHardConstraint) ...<Widget>[
            const SizedBox(width: 3),
            Icon(Icons.priority_high_rounded, size: 11, color: color),
          ],
        ],
      ),
    );

    final String? reason = criterion.reason;
    if (reason == null) return chip;
    return Tooltip(
      message: reason,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 4),
      child: chip,
    );
  }
}

class _ScoreDial extends StatelessWidget {
  const _ScoreDial({required this.percentage, required this.color});

  final int percentage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              strokeWidth: 5,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            '$percentage%',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
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
