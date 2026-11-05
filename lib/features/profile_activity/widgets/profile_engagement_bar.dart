import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../controllers/appreciation_controller.dart';
import '../../../controllers/shortlist_controller.dart';
import '../../payments/widgets/custom_coins_sheet.dart';

/// Shortlist · Like · Super Like — three separate, labelled actions (spec 13.2).
/// Send Interest / Proposal / Why This Match? stay where they already are.
class ProfileEngagementBar extends StatefulWidget {
  const ProfileEngagementBar({
    super.key,
    required this.userId,
    required this.name,
    this.compact = false,
  });

  final int userId;
  final String name;

  /// Smaller pills for list cards.
  final bool compact;

  @override
  State<ProfileEngagementBar> createState() => _ProfileEngagementBarState();
}

class _ProfileEngagementBarState extends State<ProfileEngagementBar> {
  AppreciationController? get _ctrl =>
      Get.isRegistered<AppreciationController>() ? Get.find<AppreciationController>() : null;
  ShortlistController? get _shortlist =>
      Get.isRegistered<ShortlistController>() ? Get.find<ShortlistController>() : null;

  @override
  void initState() {
    super.initState();
    _ctrl?.ensureStatus(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final AppreciationController? ctrl = _ctrl;
    final ShortlistController? shortlist = _shortlist;
    if (ctrl == null) return const SizedBox.shrink();

    return Obx(() {
      final int id = widget.userId;
      final bool shortlisted = shortlist?.isShortlisted(id) == true;
      final bool liked = ctrl.isLiked(id);
      final bool superLiked = ctrl.isSuperLiked(id);
      final bool busy = ctrl.isBusy(id);
      return Row(
        children: <Widget>[
          Expanded(
            child: _Pill(
              compact: widget.compact,
              icon: shortlisted ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              label: shortlisted ? 'Shortlisted' : 'Shortlist',
              color: AppColors.primaryDark,
              active: shortlisted,
              onTap: shortlist == null || shortlist.isBusy(id)
                  ? null
                  : () => shortlist.toggleShortlist(id, displayName: widget.name),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _Pill(
              compact: widget.compact,
              icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              label: liked ? 'Liked' : 'Like',
              color: const Color(0xFFE0446A),
              active: liked,
              onTap: busy ? null : () => ctrl.toggleLike(id),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: widget.compact ? 1 : 2,
            child: _Pill(
              compact: widget.compact,
              icon: Icons.star_rounded,
              label: superLiked
                  ? 'Super Liked'
                  : widget.compact
                      ? 'Super Like'
                      : 'Super Like · ${ctrl.superLikeCost.value} Coins',
              color: AppColors.gold,
              active: superLiked,
              premium: true,
              onTap: busy || superLiked
                  ? null
                  : () => SuperLikeConfirmDialog.show(context, userId: id, name: widget.name),
            ),
          ),
        ],
      );
    });
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
    this.compact = false,
    this.premium = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final bool compact;
  final bool premium;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color fill = active ? color.withValues(alpha: 0.14) : Colors.white;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 34 : 42),
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: compact ? 6 : 9),
            decoration: BoxDecoration(
              color: fill,
              gradient: premium && !active
                  ? const LinearGradient(colors: <Color>[Color(0xFFFFF7E6), Color(0xFFFBE3EC)])
                  : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: active ? 0.6 : 0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: compact ? 15 : 18, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11.5 : 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.roseTitleInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Spec 13.9 F — cost + balance shown before any deduction; Add Coins when short.
class SuperLikeConfirmDialog {
  const SuperLikeConfirmDialog._();

  static Future<void> show(BuildContext context, {required int userId, required String name}) async {
    final AppreciationController ctrl = Get.find<AppreciationController>();
    await ctrl.ensureStatus(userId, force: true);
    if (!context.mounted) return;
    final int cost = ctrl.superLikeCost.value;
    final int balance = ctrl.coinBalance;
    final bool enough = balance >= cost;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: <Widget>[
            Icon(Icons.star_rounded, color: AppColors.gold, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text('Send a Super Like?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Show $name that you have special interest.'),
            const SizedBox(height: 14),
            Text('Cost: $cost Coins', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Your Wallet Balance: $balance Coins'),
            if (!enough) ...<Widget>[
              const SizedBox(height: 10),
              const Text(
                'Insufficient coins. Please add coins to continue.',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryDark),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (enough) {
                ctrl.superLike(userId, quotedCost: cost);
              } else {
                CustomCoinsSheet.show(context);
              }
            },
            child: Text(enough ? 'Confirm Super Like – $cost Coins' : 'Add Coins'),
          ),
        ],
      ),
    );
  }
}
