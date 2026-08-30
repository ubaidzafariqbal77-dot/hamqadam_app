import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_strings.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/payment_controller.dart';
import '../../../models/payment_model.dart';
import '../../../widgets/app_snackbar.dart';

/// Full-detail invoice modal showing breakdown of transaction, validity, taxes/discount, and payment method.
class InvoiceDetailSheet extends StatelessWidget {
  const InvoiceDetailSheet({super.key, required this.invoice});

  final PaymentHistoryItem invoice;

  static Future<void> show(BuildContext context, PaymentHistoryItem invoice) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => InvoiceDetailSheet(invoice: invoice),
    );
  }

  static Future<void> showById(BuildContext context, int paymentId) async {
    final PaymentController ctrl = Get.find<PaymentController>();
    final PaymentHistoryItem? item = await ctrl.fetchInvoice(paymentId);
    if (item != null && context.mounted) {
      show(context, item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final DateFormat dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
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

              // Header with HamQadam logo/title and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppStrings.appName,
                        style: AppTextStyles.title.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'OFFICIAL PAYMENT INVOICE',
                        style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),

              // Invoice Number & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('INVOICE NUMBER', style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: invoice.invoiceNumber));
                              AppSnackbar.info('Invoice number copied.');
                            },
                            child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _statusBadge(invoice),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Payment Code & Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  if (invoice.paymentCode.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('PAYMENT CODE', style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(invoice.paymentCode, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  if (invoice.createdAt != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text('DATE ISSUED', style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(dateFormat.format(invoice.createdAt!), style: const TextStyle(fontSize: 12.5)),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Package Details Box
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'PACKAGE & SUBSCRIPTION',
                      style: TextStyle(fontSize: 10.5, letterSpacing: 0.8, fontWeight: FontWeight.bold, color: theme.hintColor),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          invoice.package?.name ?? 'Subscription Package',
                          style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                        ),
                        Text(
                          '${invoice.currency} ${invoice.amount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    if (invoice.package != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        '${invoice.package!.validityDays} Days Validity • ${invoice.package!.features.coins} Coins Included',
                        style: TextStyle(fontSize: 12, color: theme.hintColor),
                      ),
                    ],
                    if (invoice.subscriptionEndsAt != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          const Icon(Icons.event_available_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Active Until: ${DateFormat('dd MMM yyyy').format(invoice.subscriptionEndsAt!)}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Financial breakdown
              _summaryRow('Subtotal', '${invoice.currency} ${invoice.amount.toStringAsFixed(0)}'),
              if (invoice.discountAmount > 0)
                _summaryRow(
                  'Discount',
                  '- ${invoice.currency} ${invoice.discountAmount.toStringAsFixed(0)}',
                  color: AppColors.success,
                ),
              const SizedBox(height: 4),
              const Divider(),
              const SizedBox(height: 4),
              _summaryRow(
                'Total Paid',
                '${invoice.currency} ${invoice.payableAmount.toStringAsFixed(0)}',
                isBold: true,
                fontSize: 16,
              ),

              const SizedBox(height: AppSpacing.md),

              // Payment Method Info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.payment_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('Payment Method', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            invoice.paymentMethod.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (invoice.paidAt != null)
                      Text(
                        DateFormat('dd/MM/yyyy').format(invoice.paidAt!),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Close / Done button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close Invoice'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(PaymentHistoryItem item) {
    final bool paid = item.isPaid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: paid ? AppColors.success.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            paid ? Icons.check_circle_rounded : Icons.pending_rounded,
            size: 14,
            color: paid ? AppColors.success : Colors.amber.shade800,
          ),
          const SizedBox(width: 4),
          Text(
            paid ? 'PAID' : item.paymentStatus.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: paid ? AppColors.success : Colors.amber.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? color, double fontSize = 13.5}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
