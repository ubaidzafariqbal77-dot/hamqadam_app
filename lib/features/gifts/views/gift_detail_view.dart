import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/gift_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../models/gift_model.dart';
import '../../../widgets/premium_app_bar.dart';
import 'gift_selection_sheet.dart';

/// One gift, full detail. The heavy Lottie animation loads only here — lists
/// stay on thumbnails.
class GiftDetailView extends StatefulWidget {
  const GiftDetailView({super.key, required this.transactionId});

  final int transactionId;

  @override
  State<GiftDetailView> createState() => _GiftDetailViewState();
}

class _GiftDetailViewState extends State<GiftDetailView> {
  final GiftController _controller = Get.find<GiftController>();

  @override
  void initState() {
    super.initState();
    _controller.loadTransaction(widget.transactionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.roseCanvas,
      appBar: const PremiumAppBar(title: 'Gift Detail', subtitle: 'A moment shared with you'),
      body: Obx(() {
        final ApiState<GiftTransactionModel> s = _controller.transactionState.value;

        if (s.status == ApiStatus.loading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.regAccent));
        }

        if (s.status == ApiStatus.serverError || s.status == ApiStatus.noInternet) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(s.message ?? 'Could not load the gift.', style: AppTextStyles.caption),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.regAccent),
                  onPressed: () => _controller.loadTransaction(widget.transactionId),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }

        final GiftTransactionModel? t = s.data;
        if (t == null) {
          return const Center(child: Text('Gift not found.'));
        }

        final GiftModel? gift = t.gift;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: <Widget>[
              // The animated gift — loaded only on this screen.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.xlAll,
                  border: Border.all(color: AppColors.roseFieldBorder),
                ),
                child: gift != null
                    ? Lottie.asset(
                        gift.animatedAsset,
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                        repeat: true,
                        errorBuilder: (_, _, _) => Image.asset(
                          gift.thumbnail,
                          width: 180,
                          height: 180,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.card_giftcard_rounded, size: 96, color: AppColors.regAccent),
                        ),
                      )
                    : const Icon(Icons.card_giftcard_rounded, size: 96, color: AppColors.regAccent),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(gift?.name ?? 'Gift', style: AppTextStyles.displaySerif.copyWith(fontSize: 24)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.monetization_on_rounded, size: 16, color: AppColors.gold),
                  const SizedBox(width: 4),
                  Text('${t.coins} Coins', style: AppTextStyles.bodyStrong.copyWith(color: AppColors.gold)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.lgAll,
                  border: Border.all(color: AppColors.roseFieldBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _row('From', t.senderName),
                    _row('To', t.receiverName),
                    if (t.message != null && t.message!.isNotEmpty) _row('Message', t.message!),
                    if (t.createdAt != null)
                      _row(
                        'Date',
                        '${t.createdAt!.toLocal().day}/${t.createdAt!.toLocal().month}/${t.createdAt!.toLocal().year}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.regAccent),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                      ),
                      onPressed: () {
                        final int? otherId = t.direction == 'sent' ? t.receiverId : t.senderId;
                        if (otherId != null) {
                          Get.toNamed<void>('/public-profile/$otherId');
                        }
                      },
                      child: const Text('View Profile', style: TextStyle(color: AppColors.regAccent)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.regAccent,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                      ),
                      // Gift back = the normal send flow with the original
                      // sender pre-selected as receiver.
                      onPressed: t.senderId != null
                          ? () => showGiftSelectionSheet(context, t.senderId!)
                          : null,
                      child: const Text('Send Gift Back', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 76,
            child: Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.fieldLabelRose)),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.bodyStrong.copyWith(fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}
