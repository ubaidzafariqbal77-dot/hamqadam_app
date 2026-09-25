import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/payment_controller.dart';
import '../../../models/payment_model.dart';
import '../../../widgets/app_snackbar.dart';
import 'payment_flow.dart';

/// Modal bottom sheet for buying custom coins: shows the admin-configured
/// per-coin price, takes an integer coin count, and checks out through the
/// same gateways as subscription payments.
class CustomCoinsSheet extends StatefulWidget {
  const CustomCoinsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => const CustomCoinsSheet(),
    );
  }

  @override
  State<CustomCoinsSheet> createState() => _CustomCoinsSheetState();
}

class _CustomCoinsSheetState extends State<CustomCoinsSheet> {
  final PaymentController _controller = Get.find<PaymentController>();
  final TextEditingController _coinsInput = TextEditingController();
  final TextEditingController _phoneInput = TextEditingController();

  String _selectedGateway = 'stripe'; // 'stripe' | 'easypaisa' | 'jazzcash'

  static const List<int> _quickAmounts = <int>[50, 100, 250, 500];

  @override
  void initState() {
    super.initState();
    if (_controller.coinPricing.value.unitPrice <= 0) {
      _controller.loadCoinPricing();
    }
  }

  @override
  void dispose() {
    _coinsInput.dispose();
    _phoneInput.dispose();
    super.dispose();
  }

  int? get _coins {
    final String raw = _coinsInput.text.trim();
    if (raw.isEmpty) return null;
    final int? value = int.tryParse(raw);
    if (value == null || value < 1) return null;
    // Reject decimals like "10.5" explicitly (int.tryParse already does).
    return value;
  }

  double get _total {
    final int? coins = _coins;
    if (coins == null) return 0;
    return coins * _controller.coinPricing.value.unitPrice.toDouble();
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
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
                    'Buy Custom Coins',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Per-coin price banner
              Obx(() {
                final CoinPricing pricing = _controller.coinPricing.value;
                return Container(
                  width: double.infinity,
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
                          const Text(
                            'Price per coin',
                            style: TextStyle(color: Colors.white70, fontSize: 12.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${pricing.currency} ${pricing.unitPrice.toStringAsFixed(2)}',
                            style: AppTextStyles.title.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.monetization_on_rounded, color: Colors.white70, size: 44),
                    ],
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.lg),
              Text(
                'How many coins do you need?',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Coins input
              TextField(
                controller: _coinsInput,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                maxLength: 7,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'e.g. 100',
                  labelText: 'Coins (whole numbers only)',
                  prefixIcon: const Icon(Icons.monetization_on_rounded, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Quick amounts
              Wrap(
                spacing: 8,
                children: _quickAmounts.map((int amount) {
                  final bool isActive = _coins == amount;
                  return ActionChip(
                    label: Text('$amount'),
                    labelStyle: TextStyle(
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive ? Colors.white : null,
                      fontSize: 12.5,
                    ),
                    backgroundColor: isActive ? AppColors.regAccent : null,
                    side: BorderSide(
                      color: isActive ? AppColors.regAccent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    onPressed: () {
                      _coinsInput.text = '$amount';
                      setState(() {});
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: AppSpacing.md),

              // Total row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.regAccent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.regAccent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Total Payable',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Obx(() {
                      return Text(
                        '${_controller.coinPricing.value.currency} ${_total.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.regAccent,
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              Text(
                'Select Payment Method',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Gateways
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

              // Checkout Button
              Obx(() {
                final bool busy = _controller.isCheckingOut.value;
                final bool valid = _coins != null;
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
                    onPressed: (busy || !valid) ? null : () => _handleCheckout(),
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            valid ? 'Pay ${_controller.coinPricing.value.currency} ${_total.toStringAsFixed(2)}' : 'Enter Coins to Continue',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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
    final bool isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _selectedGateway = id),
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
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11.5, color: theme.hintColor)),
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
    );
  }

  Future<void> _handleCheckout() async {
    final int? coins = _coins;
    if (coins == null) {
      AppSnackbar.error('Please enter a whole number of coins (no decimals).');
      return;
    }

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

    _controller.selectedGateway.value = _selectedGateway;

    final CheckoutResult? result = await _controller.checkoutCustomCoins(
      coins: coins,
      easypaisaPhone: _selectedGateway == 'easypaisa' ? phone : null,
      jazzcashPhone: _selectedGateway == 'jazzcash' ? phone : null,
    );

    if (!mounted || result == null) return;

    if (result.unavailableReason != null) {
      AppSnackbar.error(result.unavailableReason!);
      return;
    }

    // Hand off to the app-level context: the sheet closes and the hosted card
    // page / confirmation dialogs must outlive it.
    final BuildContext host = Get.context ?? context;
    Navigator.of(context).pop();
    await PaymentFlow.start(host, result, onPaid: _refreshAfterPayment);
  }

  /// Called once the server says the coins were paid for.
  void _refreshAfterPayment() {
    _controller.loadCurrentPackage(silent: true);
    _controller.loadHistory(silent: true);
  }

  /// Pakistani mobile numbers in any of the shapes people type them.
  static bool _validWalletNumber(String value) {
    final String digits = value.replaceAll(RegExp(r'[\s\-()]'), '');
    return RegExp(r'^(?:\+92|0092|92|0)?3\d{9}$').hasMatch(digits);
  }
}
