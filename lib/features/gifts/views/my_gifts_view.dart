import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/gift_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../models/gift_model.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/state_widgets.dart';
import 'gift_detail_view.dart';

/// Profile → My Gifts. Received | Sent tabs — the permanent gift location,
/// independent of notifications.
class MyGiftsView extends StatefulWidget {
  const MyGiftsView({super.key});

  @override
  State<MyGiftsView> createState() => _MyGiftsViewState();
}

class _MyGiftsViewState extends State<MyGiftsView> with SingleTickerProviderStateMixin {
  final GiftController _controller = Get.find<GiftController>();
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadReceived();
      _controller.loadSent();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.roseCanvas,
      appBar: const PremiumAppBar(
        title: 'My Gifts',
        subtitle: 'Gifts you received and sent',
      ),
      body: Column(
        children: <Widget>[
          // Received | Sent segmented tabs (rose recipe).
          Container(
            margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.roseFieldBorder),
            ),
            child: TabBar(
              controller: _tabs,
              indicator: BoxDecoration(
                color: AppColors.regAccent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.fieldLabelRose,
              labelStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const <Tab>[Tab(text: 'Received'), Tab(text: 'Sent')],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: <Widget>[
                _GiftList(state: _controller.receivedState, emptyTitle: 'No gifts received yet', isReceived: true),
                _GiftList(state: _controller.sentState, emptyTitle: "You haven't sent any gifts yet", isReceived: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftList extends StatelessWidget {
  const _GiftList({required this.state, required this.emptyTitle, required this.isReceived});

  final Rx<ApiState<List<GiftTransactionModel>>> state;
  final String emptyTitle;
  final bool isReceived;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ApiState<List<GiftTransactionModel>> s = state.value;

      if (s.status == ApiStatus.loading) {
        return const Center(child: CircularProgressIndicator(color: AppColors.regAccent));
      }

      if (s.status == ApiStatus.serverError || s.status == ApiStatus.noInternet) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(s.message ?? 'Something went wrong.', style: AppTextStyles.caption),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.regAccent),
                onPressed: () => isReceived ? Get.find<GiftController>().loadReceived() : Get.find<GiftController>().loadSent(),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }

      if (s.status == ApiStatus.empty || (s.data?.isEmpty ?? true)) {
        return EmptyStateWidget(
          title: emptyTitle,
          message: isReceived
              ? 'When someone sends you a gift, it will appear here.'
              : 'Send a gift from any profile to see it here.',
        );
      }

      final List<GiftTransactionModel> items = s.data ?? <GiftTransactionModel>[];

      return RefreshIndicator(
        color: AppColors.regAccent,
        onRefresh: () async {
          final GiftController c = Get.find<GiftController>();
          if (isReceived) {
            await c.loadReceived();
          } else {
            await c.loadSent();
          }
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (BuildContext ctx, int index) {
            final GiftTransactionModel t = items[index];
            return _GiftTile(
              transaction: t,
              isReceived: isReceived,
              onTap: () => Get.to<void>(() => GiftDetailView(transactionId: t.id)),
            );
          },
        ),
      );
    });
  }
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({required this.transaction, required this.isReceived, this.onTap});

  final GiftTransactionModel transaction;
  final bool isReceived;
  final VoidCallback? onTap;

  String _when(DateTime? date) {
    if (date == null) return '';
    final DateTime local = date.toLocal();
    final DateTime now = DateTime.now();
    if (now.difference(local).inDays == 0) {
      return 'Today, ${local.hour % 12 == 0 ? 12 : local.hour % 12}:${local.minute.toString().padLeft(2, '0')} ${local.hour >= 12 ? 'PM' : 'AM'}';
    }
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final GiftModel? gift = transaction.gift;
    final String counterpart = isReceived ? transaction.senderName : transaction.receiverName;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgAll,
      child: Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.roseFieldBorder),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: AppRadius.mdAll,
            child: gift != null
                ? Image.asset(gift.thumbnail, width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.card_giftcard_rounded, color: AppColors.regAccent, size: 32))
                : const Icon(Icons.card_giftcard_rounded, color: AppColors.regAccent, size: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(gift?.name ?? 'Gift', style: AppTextStyles.bodyStrong.copyWith(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  isReceived ? 'From $counterpart' : 'To $counterpart',
                  style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
                ),
                if (transaction.message != null && transaction.message!.isNotEmpty)
                  Text(
                    transaction.message!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.monetization_on_rounded, size: 13, color: AppColors.gold),
                  const SizedBox(width: 2),
                  Text('${transaction.coins}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.gold)),
                ],
              ),
              const SizedBox(height: 2),
              Text(_when(transaction.createdAt), style: AppTextStyles.caption.copyWith(fontSize: 11, color: Theme.of(context).hintColor)),
            ],
          ),
        ],
      ),
      ),
    );
  }
}
