import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/interest_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../models/interest_model.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/state_widgets.dart';
import '../../../widgets/surface_card.dart';

/// Express-interest screen: what came in, what went out, and the coin balance.
///
/// Sending costs coins; accepting, rejecting and withdrawing are free. The cost
/// is admin-configurable, so it is always read from the server rather than
/// assumed.
class InterestsView extends StatelessWidget {
  const InterestsView({super.key});

  @override
  Widget build(BuildContext context) {
    final InterestController c = Get.find<InterestController>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PremiumAppBar(
          title: 'Interests',
          subtitle: 'Proposals sent and received',
          actions: <Widget>[
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: c.refreshAll,
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            const _CoinBar(),
            Material(
              color: Theme.of(context).cardColor,
              child: Obx(
                () => TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Theme.of(context).hintColor,
                  indicatorColor: AppColors.primary,
                  tabs: <Widget>[
                    Tab(
                      // The pending count is the number that matters — it is
                      // what the member has to act on.
                      text: c.pendingReceived > 0 ? 'Received (${c.pendingReceived})' : 'Received',
                    ),
                    const Tab(text: 'Sent'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _InterestList(controller: c, received: true),
                  _InterestList(controller: c, received: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coin wallet strip. Reads the cost from the server; never hardcodes it.
class _CoinBar extends StatelessWidget {
  const _CoinBar();

  @override
  Widget build(BuildContext context) {
    final InterestController c = Get.find<InterestController>();
    return Obx(() {
      final InterestCoinBalance b = c.coinBalance.value;
      final bool low = !b.canSend;
      final Color color = low ? AppColors.warning : AppColors.primary;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        color: color.withValues(alpha: 0.08),
        child: Row(
          children: <Widget>[
            Icon(Icons.monetization_on_rounded, color: color, size: AppDimensions.iconMd),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                low
                    ? 'You need ${b.costPerInterest} coin(s) per interest and have ${b.remainingInterest}.'
                    : '${b.remainingInterest} coins  ·  ${b.costPerInterest} per interest  ·  ${b.affordable} left to send',
                style: AppTextStyles.caption.copyWith(color: color),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _InterestList extends StatelessWidget {
  const _InterestList({required this.controller, required this.received});

  final InterestController controller;
  final bool received;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ApiState<InterestPage> s = received ? controller.received.value : controller.sent.value;
      final Future<void> Function() reload = received
          ? () => controller.loadReceived(keepFilter: true)
          : () => controller.loadSent(keepFilter: true);

      switch (s.status) {
        case ApiStatus.initial:
        case ApiStatus.loading:
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        case ApiStatus.noInternet:
          return NoInternetWidget(onRetry: reload);
        case ApiStatus.unauthorized:
        case ApiStatus.serverError:
        case ApiStatus.validationError:
          return ErrorStateWidget(message: s.message, onRetry: reload);
        case ApiStatus.empty:
          return Column(
            children: <Widget>[
              _FilterRow(controller: controller, received: received),
              Expanded(
                child: EmptyStateWidget(
                  title: received ? 'No interests received' : 'No interests sent',
                  message: s.message,
                  onRefresh: reload,
                ),
              ),
            ],
          );
        case ApiStatus.success:
          final InterestPage page = s.data!;
          return Column(
            children: <Widget>[
              _FilterRow(controller: controller, received: received),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: reload,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    // One extra row for the "load more" button when paginated.
                    itemCount: page.interests.length + (page.hasMore ? 1 : 0),
                    itemBuilder: (BuildContext context, int i) {
                      if (i >= page.interests.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Center(
                            child: TextButton(
                              onPressed: received
                                  ? controller.loadMoreReceived
                                  : controller.loadMoreSent,
                              child: const Text('Load more'),
                            ),
                          ),
                        );
                      }
                      return _InterestTile(controller: controller, interest: page.interests[i]);
                    },
                  ),
                ),
              ),
            ],
          );
      }
    });
  }
}

/// Status filter chips. Values match what the API accepts.
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.controller, required this.received});

  final InterestController controller;
  final bool received;

  static const List<({String? value, String label})> _options = <({String? value, String label})>[
    (value: null, label: 'All'),
    (value: InterestStatusFilter.pending, label: 'Pending'),
    (value: InterestStatusFilter.accepted, label: 'Accepted'),
    (value: InterestStatusFilter.rejected, label: 'Rejected'),
    (value: InterestStatusFilter.withdrawn, label: 'Withdrawn'),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final String? active = received
          ? controller.receivedFilter.value
          : controller.sentFilter.value;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        child: Row(
          children: _options.map((({String? value, String label}) o) {
            final bool selected = active == o.value;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(o.label),
                selected: selected,
                onSelected: (_) => received
                    ? controller.loadReceived(status: o.value)
                    : controller.loadSent(status: o.value),
              ),
            );
          }).toList(),
        ),
      );
    });
  }
}

class _InterestTile extends StatelessWidget {
  const _InterestTile({required this.controller, required this.interest});

  final InterestController controller;
  final InterestModel interest;

  @override
  Widget build(BuildContext context) {
    final InterestMember? m = interest.member;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _Avatar(url: m?.photoUrl, initial: m?.initial ?? 'H'),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              m?.displayName ?? 'HamQadam Member',
                              style: AppTextStyles.bodyStrong,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (m?.isVerified ?? false) ...<Widget>[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      StatusPill(
                        label: interest.statusLabel ?? _fallbackLabel(interest),
                        color: _statusColor(context, interest),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if ((interest.initialNote ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(interest.initialNote!, style: AppTextStyles.body),
            ],
            if (interest.canRespond || interest.canWithdraw) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Obx(() {
                final bool busy = controller.isBusy(interest.id);
                if (interest.canRespond) {
                  return Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : () => _act(context, 'reject'),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy ? null : () => _act(context, 'accept'),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Accept'),
                        ),
                      ),
                    ],
                  );
                }
                return Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: busy ? null : () => _confirmWithdraw(context),
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('Withdraw'),
                  ),
                );
              }),
            ],
            if (interest.canChat)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Accepted — you can now chat with each other.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.success),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _act(BuildContext context, String action) async {
    final String? error = action == 'accept'
        ? await controller.accept(interest.id)
        : await controller.reject(interest.id);
    if (error != null) {
      AppSnackbar.error(error);
      return;
    }
    AppSnackbar.success(
      action == 'accept' ? 'Interest accepted. You can now chat.' : 'Interest rejected.',
    );
  }

  /// Withdrawing does NOT refund the coins, so it is worth confirming.
  Future<void> _confirmWithdraw(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Withdraw interest?'),
        content: const Text(
          'The other member has already been notified, and the coins you spent '
          'are not refunded.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (ok != true) return;
    final String? error = await controller.withdraw(interest.id);
    if (error != null) {
      AppSnackbar.error(error);
      return;
    }
    AppSnackbar.info('Interest withdrawn.');
  }

  String _fallbackLabel(InterestModel i) {
    if (i.isPending) return 'Pending';
    if (i.isAccepted) return 'Accepted';
    if (i.isRejected) return 'Rejected';
    if (i.isWithdrawn) return 'Withdrawn';
    return 'Closed';
  }

  Color _statusColor(BuildContext context, InterestModel i) {
    if (i.isAccepted) return AppColors.success;
    if (i.isRejected) return AppColors.error;
    if (i.isPending) return AppColors.info;
    return Theme.of(context).hintColor;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.initial});

  final String? url;
  final String initial;

  @override
  Widget build(BuildContext context) {
    const double size = 48;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _fallback())
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => ColoredBox(
    color: AppColors.primary.withValues(alpha: 0.12),
    child: Center(
      child: Text(initial, style: AppTextStyles.subtitle.copyWith(color: AppColors.primary)),
    ),
  );
}
