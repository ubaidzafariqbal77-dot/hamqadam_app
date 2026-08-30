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
import '../widgets/invoice_detail_sheet.dart';

/// Full screen displaying member's payment transactions, subscriptions, and downloadable invoices.
class PaymentHistoryView extends StatefulWidget {
  const PaymentHistoryView({super.key});

  @override
  State<PaymentHistoryView> createState() => _PaymentHistoryViewState();
}

class _PaymentHistoryViewState extends State<PaymentHistoryView> {
  late final PaymentController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = Get.find<PaymentController>();
    _controller.loadHistory();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _controller.loadMoreHistory();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PremiumAppBar(
        title: 'Payment History',
        subtitle: 'Invoices & transactions',
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _controller.loadHistory(),
          ),
        ],
      ),
      body: Obx(() {
        final ApiState<PaymentHistoryPage> s = _controller.historyState.value;

        switch (s.status) {
          case ApiStatus.initial:
          case ApiStatus.loading:
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          case ApiStatus.noInternet:
            return NoInternetWidget(onRetry: () => _controller.loadHistory());
          case ApiStatus.unauthorized:
          case ApiStatus.serverError:
          case ApiStatus.validationError:
            return ErrorStateWidget(
              message: s.message,
              onRetry: () => _controller.loadHistory(),
            );
          case ApiStatus.empty:
            return EmptyStateWidget(
              title: 'No payment history',
              message: s.message?.isNotEmpty == true
                  ? s.message!
                  : 'You have not made any payments or subscription purchases yet.',
              onRefresh: () => _controller.loadHistory(),
            );
          case ApiStatus.success:
            final List<PaymentHistoryItem> list = s.data?.items ?? <PaymentHistoryItem>[];
            if (list.isEmpty) {
              return EmptyStateWidget(
                title: 'No payment history',
                message: 'No transactions found.',
                onRefresh: () => _controller.loadHistory(),
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => _controller.loadHistory(silent: true),
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: list.length + (_controller.isLoadingMoreHistory.value ? 1 : 0),
                separatorBuilder: (BuildContext context, int index) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (BuildContext context, int index) {
                  if (index >= list.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  }

                  final PaymentHistoryItem item = list[index];
                  return _TransactionCard(
                    item: item,
                    onTap: () => InvoiceDetailSheet.show(context, item),
                  );
                },
              ),
            );
        }
      }),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.item,
    required this.onTap,
  });

  final PaymentHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool paid = item.isPaid;
    final DateFormat dateFormat = DateFormat('dd MMM yyyy');

    return SurfaceCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header: Package name & Status pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.package?.name ?? 'Membership Plan',
                      style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: paid ? AppColors.success.withValues(alpha: 0.12) : Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      paid ? 'PAID' : item.paymentStatus.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: paid ? AppColors.success : Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Invoice Number
              Text(
                'Inv: ${item.invoiceNumber}',
                style: TextStyle(fontSize: 12, color: theme.hintColor),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Bottom info: Date, Method, Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (item.createdAt != null)
                        Text(
                          dateFormat.format(item.createdAt!),
                          style: TextStyle(fontSize: 11.5, color: theme.hintColor),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        item.paymentMethod.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      Text(
                        '${item.currency} ${item.payableAmount.toStringAsFixed(0)}',
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: paid ? AppColors.primary : Colors.amber.shade800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 18, color: theme.hintColor),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
