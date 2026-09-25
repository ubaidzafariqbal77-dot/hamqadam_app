import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/interest_controller.dart';
import '../../../controllers/shortlist_controller.dart';
import '../../../core/api/api_response.dart';

import '../../../models/interest_model.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/skeleton.dart';
import '../../../widgets/state_widgets.dart';
import '../../../widgets/surface_card.dart';
import '../../discover/widgets/public_profile_detail_sheet.dart';

/// Express-interest screen: what came in, what went out, and the coin balance.
///
/// Sending costs coins; accepting, rejecting and withdrawing are free. The cost
/// is admin-configurable, so it is always read from the server rather than
/// assumed.
///
/// Runs in two contexts: embedded under the shell's gradient "Matches" header
/// (HomeView tab) or standalone with its own header (pushed from the drawer or
/// a push notification). [embedded] suppresses the duplicated app bar that used
/// to stack a second pink header under the shell's.
class InterestsView extends StatelessWidget {
  const InterestsView({super.key, this.embedded = false});

  /// True when hosted inside the home shell (which already draws the header).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final InterestController c = Get.find<InterestController>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: embedded ? null : _ownAppBar(c),
        backgroundColor: embedded ? Colors.transparent : AppColors.roseCanvas,
        body: Column(
          children: <Widget>[
            const _CoinWalletCard(),
            Material(
              color: Theme.of(context).cardColor,
              child: Obx(
                () => TabBar(
                  labelColor: AppColors.regAccent,
                  unselectedLabelColor: Theme.of(context).hintColor,
                  indicatorColor: AppColors.regAccent,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  labelStyle: AppTextStyles.bodyStrong.copyWith(fontWeight: FontWeight.w800),
                  unselectedLabelStyle: AppTextStyles.body,
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

  PreferredSizeWidget _ownAppBar(InterestController c) => PremiumAppBar(
        title: 'Interests',
        subtitle: 'Proposals sent and received',
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: c.refreshAll,
          ),
        ],
      );
}

/// Coin wallet card. Reads the cost from the server; never hardcodes it.
///
/// Designed as a real wallet summary — balance, unit cost and remaining sends
/// with distinct weights — instead of the old one-line warning strip.
class _CoinWalletCard extends StatelessWidget {
  const _CoinWalletCard();

  @override
  Widget build(BuildContext context) {
    final InterestController c = Get.find<InterestController>();
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final InterestCoinBalance b = c.coinBalance.value;
      final bool low = !b.canSend;
      final Color tone = low ? AppColors.warning : AppColors.regAccent;

      return Container(
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: tone.withValues(alpha: dark ? 0.45 : 0.30),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: tone.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 6),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            // Coin medallion.
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tone.withValues(alpha: dark ? 0.18 : 0.10),
              ),
              child: Icon(Icons.monetization_on_rounded, color: tone, size: 22),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Balance + context.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Text(
                        '${b.remainingInterest}',
                        style: AppTextStyles.title.copyWith(
                          color: tone,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        b.remainingInterest == 1 ? 'coin' : 'coins',
                        style: AppTextStyles.caption.copyWith(
                          color: Theme.of(context).hintColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '· ${b.costPerInterest} per interest',
                        style: AppTextStyles.caption
                            .copyWith(color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    low
                        ? 'Not enough to send an interest — top up to continue.'
                        : '${b.affordable} more ${b.affordable == 1 ? 'interest' : 'interests'} you can send',
                    style: AppTextStyles.caption.copyWith(
                      color: low ? tone : Theme.of(context).hintColor,
                      fontWeight: low ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
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
          return const SkeletonList();
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
                  color: AppColors.regAccent,
                  onRefresh: reload,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xxxl),
                    // One extra row for the "load more" button when paginated.
                    itemCount: page.interests.length + (page.hasMore ? 1 : 0),
                    itemBuilder: (BuildContext context, int i) {
                      if (i >= page.interests.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: received
                                  ? controller.loadMoreReceived
                                  : controller.loadMoreSent,
                              icon: const Icon(Icons.expand_more_rounded, size: 18),
                              label: const Text('Load more'),
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
                showCheckmark: false,
                labelStyle: AppTextStyles.caption.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? Colors.white : Theme.of(context).hintColor,
                ),
                selectedColor: AppColors.regAccent,
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
    final ShortlistController shortlistCtrl = Get.find<ShortlistController>();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InkWell(
              onTap: () {
                if (m != null && m.id > 0) {
                  PublicProfileDetailSheet.show(
                    context,
                    profileId: m.id,
                    name: m.displayName,
                    photo: m.photoUrl,
                  );
                }
              },
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _Avatar(url: m?.photoUrl, initial: m?.initial ?? 'H'),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // "Sara Khan, 26" — name joined with the age, the way
                        // the reference card draws its headline.
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                m?.displayName ?? 'HamQadam Member',
                                style: AppTextStyles.bodyStrong.copyWith(
                                  fontSize: 15.5,
                                  color: AppColors.roseTitleInk,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if ((m?.age ?? 0) > 0) ...<Widget>[
                              const SizedBox(width: 5),
                              Text(
                                ', ${m!.age}',
                                style: AppTextStyles.bodyStrong.copyWith(
                                  fontSize: 15.5,
                                  color: AppColors.roseTitleInk,
                                ),
                              ),
                            ],
                            if (m?.isVerified ?? false) ...<Widget>[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Status + Shortlisted chips, exactly as before but
                        // sitting under the headline like the reference chips.
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            StatusPill(
                              label: interest.statusLabel ?? _fallbackLabel(interest),
                              color: _statusColor(context, interest),
                            ),
                            if (m != null && m.id > 0)
                              Obx(() {
                                final bool isShortlisted = shortlistCtrl.isShortlisted(m.id);
                                if (!isShortlisted) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(Icons.bookmark_rounded, size: 11, color: AppColors.gold),
                                      SizedBox(width: 2),
                                      Text(
                                        'Shortlisted',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.gold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (m != null && m.id > 0)
                    Obx(() {
                      final bool isShort = shortlistCtrl.isShortlisted(m.id);
                      final bool isBusy = shortlistCtrl.isBusy(m.id);
                      return IconButton(
                        icon: isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                              )
                            : Icon(
                                isShort ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                                color: isShort ? AppColors.gold : Theme.of(context).hintColor,
                                size: 22,
                              ),
                        tooltip: isShort ? 'Remove from Shortlist' : 'Add to Shortlist',
                        onPressed: () => shortlistCtrl.toggleShortlist(m.id, displayName: m.displayName),
                      );
                    }),
                ],
              ),
            ),
            // The reference card's detail lines: city, education, profession
            // and income, each with its little glyph — only the lines the API
            // actually filled in are drawn.
            if (_hasDetailLines(m))
              ..._detailLines(m),

            if ((interest.initialNote ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              // The note reads as a quoted message, not bare body text.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkSurfaceAlt
                      : AppColors.lightSurfaceAlt,
                  borderRadius: AppRadius.smAll,
                  border: Border(
                    left: BorderSide(
                      color: AppColors.regAccent.withValues(alpha: 0.5),
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  interest.initialNote!,
                  style: AppTextStyles.body.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
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
                      // The Accept pill keeps the theme's regAccent fill via
                      // FilledButtonThemeData, so no per-widget color here.
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
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.lock_open_rounded, size: 13, color: AppColors.success),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Accepted — you can now chat with each other.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.success),
                      ),
                    ),
                  ],
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

  /// True when the API sent at least one of the reference card's detail
  /// lines — older cached payloads (and members with an empty profile) carry
  /// none, and drawing an empty section would be worse than hiding it.
  static bool _hasDetailLines(InterestMember? m) =>
      m != null &&
      ((m.city ?? '').isNotEmpty ||
          (m.education ?? '').isNotEmpty ||
          (m.profession ?? '').isNotEmpty ||
          (m.income ?? '').isNotEmpty);

  /// The reference card's glyph lines: 📍 city, 🎓 education, 💼 profession,
  /// 💰 income — a quiet ink row under the headline.
  List<Widget> _detailLines(InterestMember? m) {
    final List<Widget> rows = <Widget>[];
    void add(IconData icon, String? text) {
      final String value = (text ?? '').trim();
      if (value.isEmpty) return;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 13, color: AppColors.chatTimeInk),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: AppColors.chatPreviewInk,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    add(Icons.location_on_outlined, m?.city);
    add(Icons.school_outlined, m?.education);
    add(Icons.work_outline_rounded, m?.profession);
    add(Icons.payments_outlined, m?.income);
    return rows;
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
    color: AppColors.regAccent.withValues(alpha: 0.14),
    child: Center(
      child: Text(initial, style: AppTextStyles.subtitle.copyWith(color: AppColors.regAccent)),
    ),
  );
}
