import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/payment_controller.dart';
import '../../../models/payment_model.dart';
import '../../../widgets/app_snackbar.dart';

/// Everything that happens AFTER `POST /payments/checkout` returns.
///
/// Both checkout sheets need exactly the same two branches, so they share this:
///
///  * **Card (Stripe)** — the backend hands back a hosted Checkout Session URL.
///    It is opened in an in-app browser sheet (the app stays in the foreground,
///    so the timer below keeps ticking) while we poll
///    `GET /payments/checkout/{id}/status` every three seconds; the backend
///    asks Stripe directly, so `Paid` shows up the moment the card is charged.
///  * **Wallets (EasyPaisa / JazzCash)** — there is no URL, only manual
///    instructions and a reference number, so the dialog explains the transfer
///    and offers a status check.
class PaymentFlow {
  const PaymentFlow._();

  static PaymentController get _controller => Get.find<PaymentController>();

  /// Entry point. [onPaid] is called once the server confirms the money.
  static Future<void> start(
    BuildContext context,
    CheckoutResult result, {
    VoidCallback? onPaid,
  }) async {
    if (!context.mounted) return;

    // Settled already (free plan, or a coupon that covered the amount): there
    // is nothing to open, just say so.
    if ((result.paymentStatus ?? '').toLowerCase() == 'paid') {
      onPaid?.call();
      await _showPaidSuccess(context, result);
      return;
    }

    if (result.hasGatewayUrl && result.isCardCheckout) {
      final bool opened = await _openHostedCheckout(result.gatewayUrl!);
      if (!context.mounted) return;
      if (!opened) return;
      await _watchCardPayment(context, result, onPaid: onPaid);
      return;
    }

    await _showInstructions(context, result, onPaid: onPaid);
  }

  // ---- Already settled -----------------------------------------------------

  static Future<void> _showPaidSuccess(
    BuildContext context,
    CheckoutResult result,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Row(
          children: <Widget>[
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
            SizedBox(width: 8),
            Text('Payment successful'),
          ],
        ),
        content: Text(
          result.message ??
              'Your payment has been received and the plan is now active.',
          style: AppTextStyles.body.copyWith(height: 1.5),
        ),
        actions: <Widget>[
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.regAccent),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ---- Card ----------------------------------------------------------------

  static Future<bool> _openHostedCheckout(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      AppSnackbar.error('The payment page could not be opened.');
      return false;
    }

    try {
      // In-app browser (SFSafariViewController / Chrome Custom Tab): the app
      // stays in the foreground, so the status poller keeps running while the
      // member pays.
      if (await launchUrl(uri, mode: LaunchMode.inAppWebView)) return true;
      // Fall back to the external browser rather than doing nothing.
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
    } catch (e) {
      AppSnackbar.error('Could not open the secure payment page.');
      return false;
    }

    AppSnackbar.error('Could not open the secure payment page.');
    return false;
  }

  static Future<void> _watchCardPayment(
    BuildContext context,
    CheckoutResult result, {
    VoidCallback? onPaid,
  }) async {
    if (result.paymentId == null) {
      // No id to poll — fall back to the plain confirmation dialog.
      await _showInstructions(context, result, onPaid: onPaid);
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => _PaymentStatusDialog(
        paymentId: result.paymentId!,
        checkoutToken: result.checkoutToken,
        amountLabel: result.currency == null
            ? null
            : '${result.currency} ${result.amount?.toStringAsFixed(0) ?? ''}'.trim(),
        onPaid: onPaid,
      ),
    );
  }

  // ---- Wallets -------------------------------------------------------------

  static Future<void> _showInstructions(
    BuildContext context,
    CheckoutResult result, {
    VoidCallback? onPaid,
  }) async {
    final String? reference = result.data?['payment'] is Map<String, dynamic>
        ? ((result.data!['payment'] as Map<String, dynamic>)['gateway_reference']
            as String?)
        : null;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Row(
          children: <Widget>[
            Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.regAccent, size: 26),
            SizedBox(width: 8),
            Text('Payment instructions'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // The backend's own line, kept for when no written instructions
            // were configured for the wallet.
            if ((result.instructions ?? '').isEmpty &&
                (result.message ?? '').isNotEmpty) ...<Widget>[
              Text(result.message!,
                  style: AppTextStyles.body.copyWith(fontSize: 13.5)),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (result.instructions != null &&
                result.instructions!.isNotEmpty) ...<Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.roseCanvasDeep,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                      color: AppColors.roseFieldBorder.withValues(alpha: 0.9)),
                ),
                child: Text(
                  result.instructions!,
                  style: AppTextStyles.body.copyWith(
                      fontSize: 13, height: 1.5, color: AppColors.roseTitleInk),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (result.paymentCode != null) ...<Widget>[
              _kv('Payment reference', result.paymentCode!),
              const SizedBox(height: 4),
            ],
            if (result.invoiceNumber != null) ...<Widget>[
              _kv('Invoice', result.invoiceNumber!),
              const SizedBox(height: 4),
            ],
            if (reference != null && reference.isNotEmpty)
              _kv('Gateway reference', reference),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'The plan activates as soon as the payment is confirmed. You can '
              'check the status any time from Payment History.',
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.lightTextSecondary, height: 1.45),
            ),
          ],
        ),
        actions: <Widget>[
          if (result.paymentId != null)
            TextButton(
              onPressed: () async {
                final CheckoutStatusResult? st =
                    await _controller.fetchCheckoutStatus(
                  result.paymentId!,
                  checkoutToken: result.checkoutToken,
                );
                if (st == null) {
                  AppSnackbar.error('Could not check the payment status.');
                  return;
                }
                if (st.isPaid) {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  onPaid?.call();
                  AppSnackbar.success('Payment confirmed — plan activated.');
                } else {
                  AppSnackbar.info(
                      'Status: ${st.paymentStatus ?? 'pending'} — still waiting for confirmation.');
                }
              },
              child: const Text('Check status'),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.regAccent),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  static Widget _kv(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 120,
          child: Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.lightTextHint)),
        ),
        Expanded(
          child: Text(value,
              style: AppTextStyles.bodyStrong
                  .copyWith(fontSize: 13, color: AppColors.roseTitleInk)),
        ),
      ],
    );
  }
}

/// Live "waiting for the card charge" dialog: polls the status endpoint until
/// the payment settles, the member gives up, or the attempts run out.
class _PaymentStatusDialog extends StatefulWidget {
  const _PaymentStatusDialog({
    required this.paymentId,
    this.checkoutToken,
    this.amountLabel,
    this.onPaid,
  });

  final int paymentId;
  final String? checkoutToken;
  final String? amountLabel;
  final VoidCallback? onPaid;

  @override
  State<_PaymentStatusDialog> createState() => _PaymentStatusDialogState();
}

class _PaymentStatusDialogState extends State<_PaymentStatusDialog> {
  static const Duration _interval = Duration(seconds: 3);
  static const int _maxAttempts = 40; // 2 minutes

  Timer? _timer;
  int _attempts = 0;
  bool _checking = false;
  String _status = 'waiting'; // waiting | paid | failed | timeout

  /// The visual for the current state — a helper, because a switch expression
  /// cannot be spread into a widget list.
  Widget _statusArt() {
    switch (_status) {
      case 'paid':
        return const Icon(Icons.check_circle_rounded,
            color: AppColors.success, size: 56);
      case 'failed':
        return const Icon(Icons.cancel_rounded,
            color: AppColors.error, size: 56);
      case 'timeout':
        return const Icon(Icons.hourglass_bottom_rounded,
            color: AppColors.warning, size: 56);
      default:
        return const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
              strokeWidth: 3, color: AppColors.regAccent),
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_interval, (_) => _check());
    _check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking || _status == 'paid') return;
    _checking = true;
    _attempts += 1;

    final CheckoutStatusResult? st = await Get.find<PaymentController>()
        .fetchCheckoutStatus(widget.paymentId, checkoutToken: widget.checkoutToken);

    _checking = false;
    if (!mounted) return;

    if (st != null) {
      if (st.isPaid) {
        _timer?.cancel();
        setState(() => _status = 'paid');
        widget.onPaid?.call();
        return;
      }
      if (st.isFailed) {
        _timer?.cancel();
        setState(() => _status = 'failed');
        return;
      }
    }

    if (_attempts >= _maxAttempts) {
      _timer?.cancel();
      setState(() => _status = 'timeout');
    } else {
      setState(() {});
    }
  }

  Future<void> _retryNow() async {
    _attempts = 0;
    setState(() => _status = 'waiting');
    _timer = Timer.periodic(_interval, (_) => _check());
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _status == 'paid' || _status == 'failed',
      child: AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _statusArt(),
            const SizedBox(height: AppSpacing.md),
            Text(
              switch (_status) {
                'paid' => 'Payment confirmed',
                'failed' => 'Payment not completed',
                'timeout' => 'Still waiting for confirmation',
                _ => 'Confirming your payment…',
              },
              style: AppTextStyles.title.copyWith(
                color: switch (_status) {
                  'paid' => AppColors.success,
                  'failed' => AppColors.error,
                  _ => AppColors.roseTitleInk,
                },
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              switch (_status) {
                'paid' =>
                  'Your card has been charged and the plan is being applied to your account.',
                'failed' =>
                  'The payment did not go through. No amount was taken — you can try again.',
                'timeout' =>
                  'Your bank may still be processing. This usually resolves within a few minutes; keep this page open or check again shortly.',
                _ =>
                  'Complete the payment in the secure window, then come back. This page updates automatically.',
              },
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                height: 1.5,
                color: AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.amountLabel != null &&
                widget.amountLabel!.isNotEmpty &&
                _status != 'paid') ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.amountLabel!,
                style: AppTextStyles.bodyStrong.copyWith(
                    color: AppColors.regAccent, fontSize: 15),
              ),
            ],
            if (_status == 'waiting') ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Attempt $_attempts of $_maxAttempts',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.lightTextHint),
              ),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: <Widget>[
          if (_status == 'paid' || _status == 'failed')
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.regAccent),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_status == 'paid' ? 'Continue' : 'Close'),
            ),
          if (_status == 'timeout')
            TextButton(
              onPressed: _retryNow,
              child: const Text('Check again'),
            ),
          if (_status == 'timeout' || _status == 'failed')
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
        ],
      ),
    );
  }
}
