import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../controllers/payment_controller.dart';

import '../../../core/api/api_response.dart';
import '../../../models/payment_model.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/state_widgets.dart';
import '../../../widgets/surface_card.dart';

/// Screen showing coin purchase summary and paginated feature usage log.
class CoinUsageView extends StatefulWidget {
  const CoinUsageView({super.key});

  @override
  State<CoinUsageView> createState() => _CoinUsageViewState();
}

class _CoinUsageViewState extends State<CoinUsageView> {
  late final PaymentController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = Get.find<PaymentController>();
    _controller.loadUsage();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _controller.loadMoreUsage();
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
        title: 'Coin Usage',
        subtitle: 'Feature-wise coin breakdown',
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _controller.loadUsage(),
          ),
        ],
      ),
      body: Obx(() {
        final ApiState<PaymentUsagePage> s = _controller.usageState.value;

        switch (s.status) {
          case ApiStatus.initial:
          case ApiStatus.loading:
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          case ApiStatus.noInternet:
            return NoInternetWidget(onRetry: () => _controller.loadUsage());
          case ApiStatus.unauthorized:
          case ApiStatus.serverError:
          case ApiStatus.validationError:
            return ErrorStateWidget(
              message: s.message,
              onRetry: () => _controller.loadUsage(),
            );
          case ApiStatus.empty:
            return EmptyStateWidget(
              title: 'No coin usage',
              message: 'You have not used any coins yet.',
              onRefresh: () => _controller.loadUsage(),
            );
          case ApiStatus.success:
            final PaymentUsagePage page = s.data!;
            final List<PaymentUsageItem> items = page.items;
            final PaymentUsageSummary summary = page.summary;

            if (items.isEmpty) {
              return EmptyStateWidget(
                title: 'No coin usage',
                message: 'No coin transactions found.',
                onRefresh: () => _controller.loadUsage(),
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => _controller.loadUsage(silent: true),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: items.length + 2, // +1 summary header +1 loading footer
                itemBuilder: (BuildContext context, int index) {
                  // 0 = Summary card
                  if (index == 0) {
                    return _SummaryCard(summary: summary);
                  }

                  // Last = Loading indicator
                  final int itemIndex = index - 1;
                  if (itemIndex >= items.length) {
                    if (_controller.isLoadingMoreUsage.value) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _UsageRow(item: items[itemIndex]),
                  );
                },
              ),
            );
        }
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary Card
// ---------------------------------------------------------------------------
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final PaymentUsageSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'COIN BALANCE OVERVIEW',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10.5,
              letterSpacing: 1,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              _coinStat('${summary.purchasedCoins}', 'Purchased', Icons.add_circle_rounded, Colors.white),
              const SizedBox(width: AppSpacing.xs),
              _coinStat('${summary.usedCoins}', 'Spent', Icons.remove_circle_rounded, Colors.orangeAccent),
              const SizedBox(width: AppSpacing.xs),
              _coinStat('${summary.remainingCoins}', 'Remaining', Icons.savings_rounded, Colors.greenAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coinStat(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Usage Row
// ---------------------------------------------------------------------------
class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.item});
  final PaymentUsageItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateFormat df = DateFormat('dd MMM yyyy, hh:mm a');

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          // Feature Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _iconColor(item.feature).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconFor(item.feature), color: _iconColor(item.feature), size: 18),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.featureLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                if (item.note != null && item.note!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    item.note!,
                    style: TextStyle(fontSize: 11.5, color: theme.hintColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (item.createdAt != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    df.format(item.createdAt!),
                    style: TextStyle(fontSize: 10.5, color: theme.hintColor),
                  ),
                ],
              ],
            ),
          ),

          // Coin amount chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.monetization_on_rounded, size: 13, color: Colors.red),
                const SizedBox(width: 4),
                Text(
                  '−${item.amount}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String feature) {
    switch (feature) {
      case 'interest':
        return Icons.favorite_rounded;
      case 'shortlist':
        return Icons.bookmark_rounded;
      case 'profile_viewer_view':
        return Icons.visibility_rounded;
      case 'contact_view':
        return Icons.contact_phone_rounded;
      case 'gallery_image_view':
        return Icons.photo_rounded;
      default:
        return Icons.monetization_on_rounded;
    }
  }

  Color _iconColor(String feature) {
    switch (feature) {
      case 'interest':
        return AppColors.primary;
      case 'shortlist':
        return AppColors.gold;
      case 'profile_viewer_view':
        return Colors.teal;
      case 'contact_view':
        return Colors.green;
      case 'gallery_image_view':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
