import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/rewards_controller.dart';
import '../../../repositories/rewards_repository.dart';
import '../../../widgets/premium_app_bar.dart';

/// The Redeem screen: press CLAIM → coins fly into the balance → server has
/// already credited the account. Reached from the profile's Redeem section.
class WelcomeBonusClaimView extends StatefulWidget {
  const WelcomeBonusClaimView({super.key});

  static Future<void> open() async {
    await Get.to<void>(() => const WelcomeBonusClaimView());
  }

  @override
  State<WelcomeBonusClaimView> createState() => _WelcomeBonusClaimViewState();
}

class _WelcomeBonusClaimViewState extends State<WelcomeBonusClaimView>
    with SingleTickerProviderStateMixin {
  final RewardsController controller = Get.find<RewardsController>();

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _anim,
    curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
  );
  late final Animation<double> _coinsRise = CurvedAnimation(
    parent: _anim,
    curve: const Interval(0.15, 0.9, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _balanceIn = CurvedAnimation(
    parent: _anim,
    curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
  );

  bool _played = false;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _onClaimPressed() async {
    final bool ok = await controller.claim();
    if (ok && mounted && !_played) {
      _played = true;
      _anim.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: const PremiumAppBar(
        title: 'Redeem',
        subtitle: 'Welcome bonus',
      ),
      body: Obx(() {
        final WelcomeBonusState s = controller.state.value;
        final bool done = s.claimed;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: <Widget>[
              const SizedBox(height: AppSpacing.lg),

              // ---- Coin medallion: locked → claimable → claimed -----------
              ScaleTransition(
                scale: done ? _scale : const AlwaysStoppedAnimation<double>(1),
                child: Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: AppColors.brandGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: Colors.white,
                        size: 64,
                      ),
                      if (!s.eligible && !done)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              color: AppColors.primary,
                              size: 34,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ---- Flying "+25" after the claim lands ----------------------
              if (done)
                FadeTransition(
                  opacity: _coinsRise,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.6),
                      end: const Offset(0, -0.9),
                    ).animate(_coinsRise),
                    child: Text(
                      '+${s.coins} coins',
                      style: AppTextStyles.display.copyWith(
                        color: AppColors.primary,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: AppSpacing.lg),
              Text(
                done ? 'Bonus Claimed!' : '${s.coins} Free Coins',
                style: AppTextStyles.title.copyWith(
                  color: AppColors.roseTitleInk,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                done
                    ? 'Your welcome bonus has been added to your coin balance.'
                    : s.eligible
                        ? 'Thank you for verifying your profile! Claim your '
                            'one-time ${s.coins}-coin welcome gift.'
                        : 'Complete your profile verification to unlock the '
                            '${s.coins}-coin welcome bonus.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.lightTextSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ---- New balance appears as part of the celebration ----------
              if (done)
                FadeTransition(
                  opacity: _balanceIn,
                  child: _balanceCard(s.balance),
                )
              else
                _balanceCard(s.balance),

              const SizedBox(height: AppSpacing.xl),

              // ---- The claim button ---------------------------------------
              if (!done)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: controller.claimable
                          ? const LinearGradient(colors: AppColors.brandGradient)
                          : null,
                      color: controller.claimable
                          ? null
                          : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: controller.claimable
                          ? <BoxShadow>[
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.30),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                                spreadRadius: -4,
                              ),
                            ]
                          : null,
                    ),
                    child: TextButton(
                      onPressed: controller.claimable ? _onClaimPressed : null,
                      child: controller.claiming.value
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              s.eligible
                                  ? 'Claim ${s.coins} Coins'
                                  : 'Locked — Verify your profile',
                              style: AppTextStyles.bodyStrong.copyWith(
                                color: controller.claimable
                                    ? Colors.white
                                    : AppColors.lightTextHint,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: AppColors.brandGradient),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: TextButton(
                      onPressed: () => Get.back<void>(),
                      child: Text(
                        'Done',
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _balanceCard(int balance) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: AppRadius.lgAll,
      border: Border.all(color: const Color(0xFFF3F4F6)),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFF1F4),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Current balance',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.lightTextSecondary,
                ),
              ),
              Text(
                '$balance coins',
                style: AppTextStyles.title.copyWith(
                  color: AppColors.roseTitleInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
