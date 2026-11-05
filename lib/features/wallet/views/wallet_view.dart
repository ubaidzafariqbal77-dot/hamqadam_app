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
import '../../payments/views/membership_plans_view.dart';
import '../../payments/views/payment_history_view.dart';

/// Drawer → Wallet. One screen that answers "what do I have right now":
/// the ACTIVE PACKAGE (name, tier, validity, remaining allowances) and MY
/// COINS (balance + where they went, linking into the usage log).
///
/// Data comes from the existing `GET /payments/current` — no new endpoint.
class WalletView extends StatefulWidget {
  const WalletView({super.key});

  @override
  State<WalletView> createState() => _WalletViewState();
}

class _WalletViewState extends State<WalletView> {
  late final PaymentController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<PaymentController>();
    _controller.loadCurrentPackage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.roseCanvas,
      appBar: const PremiumAppBar(
        title: 'My Wallet',
        subtitle: 'Your package & coin balance',
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _controller.loadCurrentPackage(silent: true),
        child: Obx(() {
          final ApiState<CurrentPackageData> s = _controller.currentPackageState.value;

          if (s.isLoading || s.isInitial) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (s.status == ApiStatus.noInternet) {
            return NoInternetWidget(onRetry: () => _controller.loadCurrentPackage());
          }
          if (!s.isSuccess || s.data == null) {
            return ErrorStateWidget(
              message: s.message ?? 'Could not load your wallet.',
              onRetry: () => _controller.loadCurrentPackage(),
            );
          }

          final CurrentPackageData data = s.data!;
          final PaymentPlanModel? pkg = data.currentPackage;
          final DateFormat df = DateFormat('dd MMM yyyy');
          final DateTime? validUntil =
              data.packageValidity != null ? DateTime.tryParse(data.packageValidity!) : null;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              // ----------------------------------------------------------
              // COIN BALANCE — the hero card.
              // ----------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.regPrimaryGradient,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.savings_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'My Coins',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${data.remaining.coins}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'available coins',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ----------------------------------------------------------
              // ACTIVE PACKAGE card.
              // ----------------------------------------------------------
              if (pkg != null) ...<Widget>[
                _SectionCard(
                  title: 'Active Package',
                  icon: Icons.workspace_premium_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              pkg.name,
                              style: AppTextStyles.bodyStrong.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (pkg.tier != null && pkg.tier!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                pkg.tier!.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          Icon(
                            data.isActive
                                ? Icons.verified_rounded
                                : Icons.info_outline_rounded,
                            size: 14,
                            color: data.isActive ? AppColors.success : AppColors.lightTextHint,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            data.isActive ? 'Package Active' : 'Package Inactive',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: data.isActive ? AppColors.success : AppColors.lightTextHint,
                            ),
                          ),
                          if (validUntil != null) ...<Widget>[
                            const Spacer(),
                            Text(
                              'Valid until ${df.format(validUntil)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Divider(height: 24),
                      _allowanceRow(
                          Icons.monetization_on_rounded, 'Coins left', '${data.remaining.coins}'),
                      _allowanceRow(Icons.favorite_rounded, 'Express interests',
                          '${data.remaining.profileViewerView}'),
                      _allowanceRow(Icons.photo_library_rounded, 'Photo gallery',
                          '${data.remaining.photoGallery}'),
                      _allowanceRow(Icons.contact_phone_rounded, 'Contact views',
                          '${data.remaining.contactView}'),
                    ],
                  ),
                ),
              ] else ...<Widget>[
                _SectionCard(
                  title: 'Active Package',
                  icon: Icons.workspace_premium_rounded,
                  child: Column(
                    children: <Widget>[
                      const Text('No package is active right now.'),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: () => Get.to<void>(() => const MembershipPlansView()),
                        child: const Text('Browse plans'),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.md),

              // ----------------------------------------------------------
              // Quick links.
              // ----------------------------------------------------------
              _SectionCard(
                title: 'Quick Actions',
                icon: Icons.bolt_rounded,
                child: Column(
                  children: <Widget>[
                    _linkTile(
                      context,
                      icon: Icons.workspace_premium_outlined,
                      label: 'Upgrade / Change Package',
                      onTap: () => Get.to<void>(() => const MembershipPlansView()),
                    ),
                    _linkTile(
                      context,
                      icon: Icons.receipt_long_outlined,
                      label: 'Payment History & Invoices',
                      onTap: () => Get.to<void>(() => const PaymentHistoryView()),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _allowanceRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _linkTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, color: AppColors.primary, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFB4487B).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}
