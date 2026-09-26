import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/payment_controller.dart';
import '../../../models/payment_model.dart';
import '../../../widgets/app_snackbar.dart';
import 'payment_flow.dart';


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

  /// Payment methods exactly as `GET /payments/gateways` reports them, so the
  /// sheet never offers a method the admin has switched off.
  List<PaymentGatewayInfo> _gateways = const <PaymentGatewayInfo>[];
  bool _gatewaysLoading = true;

  /// Static stand-in used while the endpoint is in flight or unreachable.
  static const List<PaymentGatewayInfo> _fallbackGateways = <PaymentGatewayInfo>[
    PaymentGatewayInfo(
      id: 1,
      key: 'stripe',
      name: 'Stripe',
      label: 'Credit / Debit Card',
      description: 'Powered by Stripe (Instant Activation)',
      enabled: true,
      configured: true,
      available: true,
      sandbox: false,
      checkoutType: 'stripe_checkout',
    ),
    PaymentGatewayInfo(
      id: 2,
      key: 'easypaisa',
      name: 'EasyPaisa',
      label: 'EasyPaisa Wallet',
      description: 'Direct mobile wallet payment',
      enabled: true,
      configured: true,
      available: true,
      sandbox: false,
    ),
    PaymentGatewayInfo(
      id: 3,
      key: 'jazzcash',
      name: 'JazzCash',
      label: 'JazzCash Wallet',
      description: 'Direct mobile account payment',
      enabled: true,
      configured: true,
      available: true,
      sandbox: false,
    ),
  ];

  List<PaymentGatewayInfo> get _methods =>
      _gateways.isNotEmpty ? _gateways : _fallbackGateways;

  PaymentGatewayInfo? get _selectedInfo {
    for (final PaymentGatewayInfo g in _methods) {
      if (g.key == _selectedGateway) return g;
    }
    return null;
  }

  /// True when the chosen method pays on Stripe's hosted page.
  bool get _hostedCard =>
      _selectedGateway == 'stripe' || (_selectedInfo?.isHostedCheckout ?? false);

  @override
  void initState() {
    super.initState();
    _controller.clearCoupon();
    _loadGateways();
  }

  Future<void> _loadGateways() async {
    await _controller.loadGateways();
    if (!mounted) return;
    setState(() {
      _gateways = _controller.gatewaysState.value.data ??
          const <PaymentGatewayInfo>[];
      _gatewaysLoading = false;
      _ensureValidSelection();
    });
  }

  /// Keeps the selection on a method that is actually payable.
  void _ensureValidSelection() {
    final List<PaymentGatewayInfo> methods = _methods;
    for (final PaymentGatewayInfo g in methods) {
      if (g.key == _selectedGateway && g.available) return;
    }
    for (final PaymentGatewayInfo g in methods) {
      if (g.available) {
        _selectedGateway = g.key;
        return;
      }
    }
  }

  /// Pakistani mobile numbers in any of the shapes people type them.
  static bool _validWalletNumber(String value) {
    final String digits = value.replaceAll(RegExp(r'[\s\-()]'), '');
    return RegExp(r'^(?:\+92|0092|92|0)?3\d{9}$').hasMatch(digits);
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
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
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
                    colors: AppColors.regPrimaryGradient,
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
                        fontSize: 18,
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

              // Gateways — loaded from the server so the list matches what is
              // actually configured, with the built-in three as the stand-in.
              if (_gatewaysLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(
                      minHeight: 2, color: AppColors.regAccent),
                ),
              for (int i = 0; i < _methods.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: AppSpacing.xs),
                _gatewayTileFrom(_methods[i]),
              ],

              // Card panel — what the member is actually handing over and where.
              if (_hostedCard) _cardPanel(),

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
                        backgroundColor: AppColors.regAccent,
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
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppColors.regAccent),
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
                      backgroundColor: AppColors.regAccent,
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
                        : Text(
                            _hostedCard
                                ? 'Pay ${_finalAmount.toStringAsFixed(0)} with Card'
                                : 'Pay & Activate',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
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

  /// Maps a server gateway onto the tile widget, choosing the icon/colour the
  /// member already recognises for that method.
  Widget _gatewayTileFrom(PaymentGatewayInfo g) {
    final String title = g.label.isNotEmpty ? g.label : g.name;
    final String subtitle = (g.description ?? '').isNotEmpty
        ? g.description!
        : (g.isHostedCheckout
            ? 'Powered by Stripe (Instant Activation)'
            : 'Direct mobile wallet payment');

    return _gatewayTile(
      id: g.key,
      title: title,
      subtitle: subtitle,
      icon: switch (g.key) {
        'stripe' => Icons.credit_card_rounded,
        'easypaisa' => Icons.account_balance_wallet_rounded,
        'jazzcash' => Icons.payments_rounded,
        _ => Icons.account_balance_rounded,
      },
      iconColor: switch (g.key) {
        'stripe' => const Color(0xFF635BFF),
        'easypaisa' => const Color(0xFF00A651),
        'jazzcash' => const Color(0xFFED1C24),
        _ => AppColors.regAccent,
      },
      available: g.available,
      sandbox: g.sandbox,
    );
  }

  /// The card panel: where the money is actually taken and what is never
  /// shared with the app.
  Widget _cardPanel() {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.roseFieldBorder.withValues(alpha: 0.9)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1AB4487B),
            blurRadius: 24,
            offset: Offset(0, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.lock_rounded, size: 16, color: AppColors.regAccent),
              SizedBox(width: 6),
              Text(
                'Secure card payment',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'You continue on Stripe\'s hosted checkout page. The app never sees, '
            'stores or transmits your card number — Stripe does that, and the '
            'plan activates the moment the charge succeeds.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _brandPill('VISA'),
              _brandPill('Mastercard'),
              _brandPill('AMEX'),
              _brandPill('Discover'),
              if (_selectedInfo?.sandbox == true)
                _brandPill('TEST MODE', color: AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _brandPill(String label, {Color color = AppColors.regAccent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: color,
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
    bool available = true,
    bool sandbox = false,
  }) {
    final bool isSelected = _selectedGateway == id && available;
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Opacity(
      opacity: available ? 1 : 0.55,
      child: InkWell(
        onTap: () {
          if (!available) {
            AppSnackbar.info('$title is not available right now.');
            return;
          }
          setState(() => _selectedGateway = id);
        },
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? AppColors.regAccent
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            color: isSelected ? AppColors.regAccent.withValues(alpha: 0.05) : null,
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
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13.5)),
                        ),
                        if (sandbox) ...<Widget>[
                          const SizedBox(width: 6),
                          _brandPill('TEST', color: AppColors.warning),
                        ],
                        if (!available) ...<Widget>[
                          const SizedBox(width: 6),
                          _brandPill('Unavailable', color: AppColors.lightTextHint),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(fontSize: 11.5, color: theme.hintColor)),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: isSelected ? AppColors.regAccent : theme.hintColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCheckout() async {
    final bool wallet =
        _selectedGateway == 'easypaisa' || _selectedGateway == 'jazzcash';
    final String phone = _phoneInput.text.trim();

    if (wallet && phone.isEmpty) {
      AppSnackbar.error('Please enter your mobile account number.');
      return;
    }
    if (wallet && !_validWalletNumber(phone)) {
      AppSnackbar.error('Enter a valid mobile number, e.g. 03001234567.');
      return;
    }

    final PaymentGatewayInfo? info = _selectedInfo;
    if (info != null && !info.available) {
      AppSnackbar.error('${info.label} is not available right now.');
      return;
    }

    _controller.selectedGateway.value = _selectedGateway;

    final CheckoutResult? result = await _controller.checkout(
      packageId: widget.plan.id,
      easypaisaPhone: _selectedGateway == 'easypaisa' ? phone : null,
      jazzcashPhone: _selectedGateway == 'jazzcash' ? phone : null,
    );

    if (!mounted || result == null) return;

    // The backend refused to start the card checkout (keys missing, Stripe
    // unreachable) — say so instead of opening a page that does not exist.
    if (result.unavailableReason != null) {
      AppSnackbar.error(result.unavailableReason!);
      return;
    }

    // Hand off to the app-level context: the sheet is about to close and the
    // hosted payment page / confirmation dialogs must outlive it.
    final BuildContext host = Get.context ?? context;
    Navigator.of(context).pop();
    await PaymentFlow.start(host, result, onPaid: _refreshAfterPayment);
  }

  /// Called once the server says the money arrived.
  void _refreshAfterPayment() {
    _controller.loadCurrentPackage(silent: true);
    _controller.loadPlans(silent: true);
    _controller.loadHistory(silent: true);
  }
}
