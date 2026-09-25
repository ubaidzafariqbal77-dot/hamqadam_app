import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/gift_controller.dart';
import '../../../models/gift_model.dart';

/// Opens the send-gift flow for [receiverId]. Loads the catalog and balance
/// from the backend, shows thumbnails (never the heavy animations), a
/// confirmation step, and the insufficient-coins state that routes to the
/// existing coin purchase screen.
Future<void> showGiftSelectionSheet(BuildContext context, int receiverId) async {
  final GiftController controller = Get.isRegistered<GiftController>()
      ? Get.find<GiftController>()
      : Get.put(GiftController(Get.find()));

  await controller.loadGifts();
  await controller.refreshBalance();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
    builder: (BuildContext ctx) => _GiftSelectionSheet(controller: controller, receiverId: receiverId),
  );
}

class _GiftSelectionSheet extends StatefulWidget {
  const _GiftSelectionSheet({required this.controller, required this.receiverId});

  final GiftController controller;
  final int receiverId;

  @override
  State<_GiftSelectionSheet> createState() => _GiftSelectionSheetState();
}

class _GiftSelectionSheetState extends State<_GiftSelectionSheet> {
  GiftModel? _selected;

  Future<void> _confirmAndSend() async {
    final GiftModel? gift = _selected;
    if (gift == null) return;

    final int balance = widget.controller.coinBalance.value;
    final bool enough = balance >= gift.coins;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Text('Send Gift'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Image.asset(gift.thumbnail, width: 56, height: 56, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(gift.name, style: AppTextStyles.bodyStrong),
                      Text('${gift.coins} Coins', style: AppTextStyles.caption.copyWith(color: AppColors.regAccent)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Your Balance: $balance Coins', style: AppTextStyles.caption),
            Text(
              'After Sending: ${balance - gift.coins} Coins',
              style: AppTextStyles.caption.copyWith(color: enough ? AppColors.success : AppColors.error),
            ),
            if (!enough) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Insufficient Coins — you need ${gift.coins} coins and you have $balance.',
                style: AppTextStyles.caption.copyWith(color: AppColors.error),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
          if (enough)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.regAccent),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Send Gift', style: TextStyle(color: Colors.white)),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: () {
                Navigator.of(dialogCtx).pop(false);
                // Existing coin/package purchase flow — no new payment system.
                Get.toNamed<void>('/coins/purchase');
              },
              child: const Text('Buy Coins', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );

    if (confirmed != true) return;

    final SendGiftResult? result = await widget.controller.sendGift(
      receiverId: widget.receiverId,
      gift: gift,
      currentBalance: balance,
    );

    if (result != null && mounted) {
      Navigator.of(context).pop(); // close the sheet on success
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text('Send a Gift', style: AppTextStyles.title)),
                Obx(() => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.monetization_on_rounded, size: 16, color: AppColors.gold),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.controller.coinBalance.value}',
                          style: AppTextStyles.bodyStrong.copyWith(color: AppColors.gold),
                        ),
                      ],
                    )),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Gifts are bought with your existing coins. The final deduction happens securely on the server.',
              style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: Obx(() {
                if (widget.controller.gifts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No gifts available right now.',
                        style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: widget.controller.gifts.length,
                  itemBuilder: (BuildContext gridCtx, int index) {
                    final GiftModel gift = widget.controller.gifts[index];
                    final bool selected = _selected?.id == gift.id;
                    final bool affordable = widget.controller.coinBalance.value >= gift.coins;

                    return InkWell(
                      borderRadius: AppRadius.mdAll,
                      onTap: () => setState(() => _selected = gift),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.regAccent.withValues(alpha: 0.10) : Colors.white,
                          borderRadius: AppRadius.mdAll,
                          border: Border.all(
                            color: selected ? AppColors.regAccent : AppColors.roseFieldBorder,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              child: Image.asset(
                                gift.thumbnail,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.card_giftcard_rounded, color: AppColors.regAccent),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              gift.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 11.5),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Icon(Icons.monetization_on_rounded, size: 12, color: AppColors.gold),
                                const SizedBox(width: 2),
                                Text(
                                  '${gift.coins}',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 11,
                                    color: affordable ? AppColors.gold : AppColors.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: Obx(() {
                final GiftController c = widget.controller;
                final bool busy = c.isSending.value;
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.regAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                  ),
                  // Disabled while sending → double-click protection.
                  onPressed: (_selected == null || busy) ? null : _confirmAndSend,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _selected == null
                              ? 'Select a Gift'
                              : 'Send ${_selected!.name} — ${_selected!.coins} Coins',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
