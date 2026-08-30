import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/payment_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../models/payment_model.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/state_widgets.dart';
import '../../../widgets/surface_card.dart';
import '../widgets/checkout_bottom_sheet.dart';

/// Screen showing current active subscription + available upgrade plans.
class MembershipPlansView extends StatefulWidget {
  const MembershipPlansView({super.key});

  @override
  State<MembershipPlansView> createState() => _MembershipPlansViewState();
}

class _MembershipPlansViewState extends State<MembershipPlansView> {
  late final PaymentController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<PaymentController>();
    _controller.loadCurrentPackage();
    _controller.loadPlans();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: PremiumAppBar(
        title: 'Membership Plans',
        subtitle: 'Upgrade your subscription',
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _controller.loadCurrentPackage();
              _controller.loadPlans();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await Future.wait(<Future<void>>[
            _controller.loadCurrentPackage(silent: true),
            _controller.loadPlans(silent: true),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Current Active Package Section
              Text('CURRENT SUBSCRIPTION', style: _sectionLabel(theme)),
              const SizedBox(height: AppSpacing.xs),
              Obx(() {
                final ApiState<CurrentPackageData> s = _controller.currentPackageState.value;
                if (s.isLoading || s.isInitial) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                }
                final CurrentPackageData? data = s.data;
                if (data == null) return const SizedBox.shrink();
                return _CurrentPackageCard(data: data);
              }),

              const SizedBox(height: AppSpacing.lg),

              // Available Plans Section
              Text('AVAILABLE PLANS', style: _sectionLabel(theme)),
              const SizedBox(height: AppSpacing.xs),

              Obx(() {
                final ApiState<List<PaymentPlanModel>> s = _controller.plansState.value;

                if (s.isLoading || s.isInitial) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                }
                if (!s.isSuccess || s.data == null || s.data!.isEmpty) {
                  return EmptyStateWidget(
                    title: 'No plans available',
                    message: 'No membership plans are currently available.',
                    onRefresh: () => _controller.loadPlans(),
                  );
                }

                final List<PaymentPlanModel> plans = s.data!;
                final int? currentId = _controller.currentPackageState.value.data?.currentPackage?.id;

                return Column(
                  children: plans.map((PaymentPlanModel plan) {
                    final bool isCurrent = plan.id == currentId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _PlanCard(
                        plan: plan,
                        isCurrent: isCurrent,
                        onSubscribe: isCurrent
                            ? null
                            : () => CheckoutBottomSheet.show(context, plan),
                      ),
                    );
                  }).toList(),
                );
              }),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _sectionLabel(ThemeData theme) => TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
        color: theme.hintColor,
      );
}

// ---------------------------------------------------------------------------
// Current Package Card
// ---------------------------------------------------------------------------
class _CurrentPackageCard extends StatelessWidget {
  const _CurrentPackageCard({required this.data});
  final CurrentPackageData data;

  @override
  Widget build(BuildContext context) {
    final PaymentPlanModel? pkg = data.currentPackage;
    if (pkg == null) return const SizedBox.shrink();

    final DateFormat df = DateFormat('dd MMM yyyy');
    final DateTime? validUntil = data.packageValidity != null
        ? DateTime.tryParse(data.packageValidity!)
        : null;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Badge row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.star_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 4),
                    Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (validUntil != null)
                Text(
                  'Valid until ${df.format(validUntil)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Plan Name & Coins
          Text(
            pkg.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${pkg.validityDays} Day Plan',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),

          const SizedBox(height: AppSpacing.md),

          // Remaining stats
          Row(
            children: <Widget>[
              _statChip(Icons.monetization_on_rounded, '${data.remaining.coins}', 'Coins Left'),
              const SizedBox(width: AppSpacing.xs),
              _statChip(Icons.favorite_rounded, '${data.remaining.profileViewerView}', 'Viewers Left'),
              const SizedBox(width: AppSpacing.xs),
              _statChip(Icons.photo_library_rounded, '${data.remaining.photoGallery}', 'Gallery'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 9.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Available Plan Card
// ---------------------------------------------------------------------------
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.onSubscribe,
  });

  final PaymentPlanModel plan;
  final bool isCurrent;
  final VoidCallback? onSubscribe;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SurfaceCard(

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header row: Plan name + Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    Text(
                      plan.name,
                      style: AppTextStyles.bodyStrong.copyWith(fontSize: 16),
                    ),
                    if (plan.tier != null && plan.tier!.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _tierColor(plan.tier!).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          plan.tier!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: _tierColor(plan.tier!),
                          ),
                        ),
                      ),
                    ],
                    if (isCurrent) ...<Widget>[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                    ],
                  ],
                ),
              ),
              Text(
                plan.priceFormatted,
                style: AppTextStyles.bodyStrong.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${plan.validityDays} Days • ${plan.isRecurring ? 'Auto-renew' : 'One-time'}',
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),

          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),

          // Feature grid
          _featureRow(Icons.monetization_on_rounded, '${plan.features.coins} Coins', AppColors.gold),
          const SizedBox(height: 6),
          _featureRow(Icons.favorite_rounded, '${plan.features.messagingInterests} Express Interests', AppColors.primary),
          const SizedBox(height: 6),
          _featureRow(Icons.photo_camera_rounded, '${plan.features.photoGallery} Photo Gallery', Colors.blue),
          const SizedBox(height: 6),
          _featureRow(Icons.person_search_rounded, '${plan.features.profileViewers} Profile Viewers', Colors.teal),
          if (plan.featureFlags.aiMatching || plan.featureFlags.advancedSearch) ...<Widget>[
            const SizedBox(height: 6),
            if (plan.featureFlags.aiMatching)
              _featureRow(Icons.auto_awesome_rounded, 'AI Matching', Colors.purple),
            if (plan.featureFlags.advancedSearch) ...<Widget>[
              const SizedBox(height: 6),
              _featureRow(Icons.manage_search_rounded, 'Advanced Search', Colors.indigo),
            ],
            if (plan.features.autoProfileMatch) ...<Widget>[
              const SizedBox(height: 6),
              _featureRow(Icons.compare_arrows_rounded, 'Auto Profile Matching', Colors.orange),
            ],
          ],

          if (onSubscribe != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                onPressed: onSubscribe,
                child: Text(
                  plan.isFree ? 'Get This Plan' : 'Subscribe — ${plan.priceFormatted}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                  SizedBox(width: 8),
                  Text(
                    'Currently Active',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
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

  Widget _featureRow(IconData icon, String label, Color color) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Color _tierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'free':
        return Colors.blueGrey;
      case 'basic':
        return Colors.blue;
      case 'premium':
        return AppColors.gold;
      case 'platinum':
        return Colors.deepPurple;
      default:
        return AppColors.primary;
    }
  }
}
