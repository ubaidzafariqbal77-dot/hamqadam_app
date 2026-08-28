import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/payment_controller.dart';
import '../../../models/payment_model.dart';
import '../../../widgets/app_snackbar.dart';


/// Modal bottom sheet allowing user to select a payment gateway, apply a coupon,
/// enter mobile credentials (for EasyPaisa / JazzCash), and complete checkout.
class CheckoutBottomSheet extends StatefulWidget {
  const CheckoutBottomSheet({super.key, required this.plan});

  final PaymentPlanModel plan;

  static Future<void> show(BuildContext context, PaymentPlanModel plan) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => CheckoutBottomSheet(plan: plan),
    );
  }

  @override
  State<CheckoutBottomSheet> createState() => _CheckoutBottomSheetState();
}

class _CheckoutBottomSheetState extends State<CheckoutBottomSheet> {
  final PaymentController _controller = Get.find<PaymentController>();
  final TextEditingController _couponInput = TextEditingController();
  final TextEditingController _phoneInput = TextEditingController();

  String _selectedGateway = 'stripe'; // 'stripe' | 'easypaisa' | 'jazzcash'

  @override
  void initState() {
    super.initState();
    _controller.clearCoupon();
  }

  @override
  void dispose() {
    _couponInput.dispose();
    _phoneInput.dispose();
    super.dispose();
  }

  num get _finalAmount {
    final num basePrice = widget.plan.price;
    final num discount = _controller.couponResult.value?.discountAmount ?? 0;
    final num result = basePrice - discount;
    return result > 0 ? result : 0;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Upgrade Subscription',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Selected Plan Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.brandGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.plan.name,
                          style: AppTextStyles.title.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.plan.validityDays} Days Validity • ${widget.plan.features.coins} Coins',
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                        ),
                      ],
                    ),
                    Text(
                      widget.plan.priceFormatted,
                      style: AppTextStyles.title.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              Text(
                'Select Payment Method',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Gateways: Stripe, EasyPaisa, JazzCash
              _gatewayTile(
                id: 'stripe',
                title: 'Credit / Debit Card',
                subtitle: 'Powered by Stripe (Instant Activation)',
                icon: Icons.credit_card_rounded,
                iconColor: const Color(0xFF635BFF),
              ),
              const SizedBox(height: AppSpacing.xs),
              _gatewayTile(
                id: 'easypaisa',
                title: 'EasyPaisa Wallet',
                subtitle: 'Direct mobile wallet payment',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF00A651),
              ),
              const SizedBox(height: AppSpacing.xs),
              _gatewayTile(
                id: 'jazzcash',
                title: 'JazzCash Wallet',
                subtitle: 'Direct mobile account payment',
                icon: Icons.payments_rounded,
                iconColor: const Color(0xFFED1C24),
              ),

              // Mobile number input for EasyPaisa / JazzCash
              if (_selectedGateway == 'easypaisa' || _selectedGateway == 'jazzcash') ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${_selectedGateway == 'easypaisa' ? 'EasyPaisa' : 'JazzCash'} Mobile Account Number',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneInput,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'e.g. 03001234567',
                    prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              Text(
                'Have a Promo Coupon?',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),

              // Coupon Box
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _couponInput,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Enter Coupon Code',
                        prefixIcon: const Icon(Icons.local_offer_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Obx(() {
                    return FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                      ),
                      onPressed: _controller.isValidatingCoupon.value
                          ? null
                          : () {
                              final String code = _couponInput.text.trim();
                              if (code.isNotEmpty) {
                                _controller.validateCoupon(widget.plan.id, code);
                              }
                            },
                      child: _controller.isValidatingCoupon.value
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Apply'),
                    );
                  }),
                ],
              ),

              // Coupon Result Banner
              Obx(() {
                final CouponValidationResult? res = _controller.couponResult.value;
                if (res == null) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Coupon Applied! Discount: PKR ${res.discountAmount}',
                          style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.success),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          _controller.clearCoupon();
                          _couponInput.clear();
                        },
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.xs),

              // Price Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text('Plan Price', style: TextStyle(fontSize: 14)),
                  Text(widget.plan.priceFormatted, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
              Obx(() {
                final CouponValidationResult? res = _controller.couponResult.value;
                if (res == null || res.discountAmount <= 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Discount', style: TextStyle(fontSize: 14, color: AppColors.success)),
                      Text('- PKR ${res.discountAmount}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.success)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Total Payable', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Obx(() {
                    return Text(
                      'PKR ${_finalAmount.toStringAsFixed(0)}',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppColors.primary),
                    );
                  }),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),              // Checkout Button
              Obx(() {
                final bool busy = _controller.isCheckingOut.value;
                return SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: busy ? null : () => _handleCheckout(),
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Pay & Activate',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gatewayTile({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final bool isSelected = _selectedGateway == id;
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: () => setState(() => _selectedGateway = id),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.25),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11.5, color: theme.hintColor)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primary : Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCheckout() async {
    final String? phone = _phoneInput.text.trim().isNotEmpty ? _phoneInput.text.trim() : null;

    if ((_selectedGateway == 'easypaisa' || _selectedGateway == 'jazzcash') && (phone == null || phone.isEmpty)) {
      AppSnackbar.error('Please enter your mobile account number.');
      return;
    }

    _controller.selectedGateway.value = _selectedGateway;

    final CheckoutResult? result = await _controller.checkout(
      packageId: widget.plan.id,
      easypaisaPhone: _selectedGateway == 'easypaisa' ? phone : null,
      jazzcashPhone: _selectedGateway == 'jazzcash' ? phone : null,
    );

    if (!mounted || result == null) return;
    Navigator.of(context).pop();
    _showCheckoutSuccessDialog(context, result);
  }

  void _showCheckoutSuccessDialog(BuildContext context, CheckoutResult res) {

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: <Widget>[
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
            const SizedBox(width: 8),
            const Text('Payment Initiated'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(res.message ?? 'Your payment request has been received.'),
            if (res.invoiceNumber != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Invoice: ${res.invoiceNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
            if (res.instructions != null && res.instructions!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  res.instructions!,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
