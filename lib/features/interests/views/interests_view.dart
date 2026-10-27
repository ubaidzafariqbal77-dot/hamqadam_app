import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/interest_controller.dart';
import '../../../controllers/shortlist_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../models/chat_model.dart';
import '../../../models/interest_model.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/skeleton.dart';
import '../../../widgets/state_widgets.dart';
import '../../chat/views/chat_conversation_view.dart';
import '../../discover/widgets/public_profile_detail_sheet.dart';

// Local aliases for the app's own palette (pastel pink brand, ink foreground,
// white canvas) so this screen matches every other screen.
const Color _rose = AppColors.primaryInk; // readable ink on the pastel
const Color _roseSoft = AppColors.primary; // brand pastel pink
const Color _blush = AppColors.primaryLight; // soft pink tint
const Color _ink = AppColors.roseTitleInk;
const Color _muted = AppColors.lightTextSecondary;
const Color _line = AppColors.lightDivider;
const LinearGradient _brand = LinearGradient(
  colors: AppColors.brandGradient,
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Express-interest screen: what came in, what went out, and the coin balance.
///
/// Sending costs coins; accepting, rejecting and withdrawing are free. The cost
/// is admin-configurable, so it is always read from the server rather than
/// assumed.
///
/// Runs in two contexts: embedded under the shell's header (HomeView tab) or
/// standalone with its own header (pushed from the drawer or a push
/// notification). [embedded] suppresses the duplicated app bar.
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
        backgroundColor: embedded
            ? Colors.transparent
            : AppColors.lightBackground,
        body: Column(
          children: <Widget>[
            const _CoinWalletCard(),
            _SegmentedTabs(controller: c),
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

// ---------------------------------------------------------------------------
// Wallet hero
// ---------------------------------------------------------------------------

/// Coin wallet. Reads the cost from the server; never hardcodes it.
class _CoinWalletCard extends StatelessWidget {
  const _CoinWalletCard();

  @override
  Widget build(BuildContext context) {
    final InterestController c = Get.find<InterestController>();
    return Obx(() {
      final InterestCoinBalance b = c.coinBalance.value;
      final bool low = !b.canSend;
      final LinearGradient gradient = low
          ? const LinearGradient(
              colors: <Color>[Color(0xFFF6DDA8), Color(0xFFEFC775)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : _brand;

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: (low ? AppColors.warning : _roseSoft).withValues(
                alpha: 0.35,
              ),
              blurRadius: 22,
              offset: const Offset(0, 12),
              spreadRadius: -8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: <Widget>[
              // Soft decorative discs.
              Positioned(right: -26, top: -30, child: _disc(120, 0.10)),
              Positioned(right: 40, bottom: -46, child: _disc(96, 0.08)),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _rose.withValues(alpha: 0.10),
                        border: Border.all(
                          color: _rose.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(
                        Icons.stars_rounded,
                        color: _rose,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'YOUR COINS',
                            style: AppTextStyles.caption.copyWith(
                              color: _rose.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${b.remainingInterest}',
                            style: const TextStyle(
                              color: _rose,
                              fontSize: 30,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            low
                                ? 'Not enough to send an interest — top up to continue.'
                                : '${b.affordable} ${b.affordable == 1 ? 'interest' : 'interests'} available',
                            style: AppTextStyles.caption.copyWith(
                              color: _rose,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _rose.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _rose.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        '${b.costPerInterest} / interest',
                        style: const TextStyle(
                          color: _rose,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _disc(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha * 2.2),
    ),
  );
}

// ---------------------------------------------------------------------------
// Segmented Received / Sent tabs
// ---------------------------------------------------------------------------

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.controller});

  final InterestController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.roseFieldBorder),
      ),
      child: Obx(
        () => TabBar(
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.regPrimaryGradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.chatPillInk,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: <Widget>[
            Tab(
              height: 38,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.inbox_rounded, size: 15),
                  const SizedBox(width: 5),
                  const Flexible(
                    child: Text('Received', overflow: TextOverflow.ellipsis),
                  ),
                  if (controller.pendingReceived > 0) ...<Widget>[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${controller.pendingReceived}',
                        style: const TextStyle(
                          color: AppColors.primaryInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(
              height: 38,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.send_rounded, size: 15),
                  SizedBox(width: 5),
                  Flexible(
                    child: Text('Sent', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------

class _InterestList extends StatelessWidget {
  const _InterestList({required this.controller, required this.received});

  final InterestController controller;
  final bool received;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ApiState<InterestPage> s = received
          ? controller.received.value
          : controller.sent.value;
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
                child: _EmptyState(
                  received: received,
                  message: s.message ?? '',
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
                  color: _rose,
                  onRefresh: reload,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
                    // One extra row for the "load more" button when paginated.
                    itemCount: page.interests.length + (page.hasMore ? 1 : 0),
                    itemBuilder: (BuildContext context, int i) {
                      if (i >= page.interests.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: _rose,
                              ),
                              onPressed: received
                                  ? controller.loadMoreReceived
                                  : controller.loadMoreSent,
                              icon: const Icon(
                                Icons.expand_more_rounded,
                                size: 18,
                              ),
                              label: const Text('Load more'),
                            ),
                          ),
                        );
                      }
                      return _InterestTile(
                        controller: controller,
                        interest: page.interests[i],
                      );
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.received,
    required this.message,
    required this.onRefresh,
  });

  final bool received;
  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _rose,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 110),
        children: <Widget>[
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _blush,
              ),
              child: Icon(
                received ? Icons.favorite_border_rounded : Icons.send_rounded,
                size: 42,
                color: _rose,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            received ? 'No interests received yet' : 'No interests sent yet',
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(
              color: _ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            // Shortlisting a profile (the heart on a Discover card) does NOT
            // create an interest — only an Express Interest does.
            received
                ? 'When someone expresses interest in you, it will appear here. '
                      'Tap "Send Interest" on a Discover profile to start a connection.'
                : (message.isEmpty
                      ? 'Find someone you like on Discover and send an interest to begin.'
                      : message),
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: _muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status filter chips
// ---------------------------------------------------------------------------

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.controller, required this.received});

  final InterestController controller;
  final bool received;

  static const List<({String? value, String label, IconData icon})> _options =
      <({String? value, String label, IconData icon})>[
        (value: null, label: 'All', icon: Icons.layers_rounded),
        (
          value: InterestStatusFilter.pending,
          label: 'Pending',
          icon: Icons.hourglass_top_rounded,
        ),
        (
          value: InterestStatusFilter.accepted,
          label: 'Accepted',
          icon: Icons.check_circle_rounded,
        ),
        (
          value: InterestStatusFilter.rejected,
          label: 'Declined',
          icon: Icons.cancel_rounded,
        ),
        (
          value: InterestStatusFilter.withdrawn,
          label: 'Withdrawn',
          icon: Icons.undo_rounded,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final String? active = received
          ? controller.receivedFilter.value
          : controller.sentFilter.value;
      return SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _options.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (BuildContext context, int i) {
            final o = _options[i];
            final bool selected = active == o.value;
            return GestureDetector(
              onTap: () => received
                  ? controller.loadReceived(status: o.value)
                  : controller.loadSent(status: o.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  gradient: selected ? _brand : null,
                  color: selected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected ? Colors.transparent : _line,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(o.icon, size: 14, color: selected ? _rose : _muted),
                    const SizedBox(width: 6),
                    Text(
                      o.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: selected ? _rose : _ink,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Interest card
// ---------------------------------------------------------------------------

class _InterestTile extends StatelessWidget {
  const _InterestTile({required this.controller, required this.interest});

  final InterestController controller;
  final InterestModel interest;

  @override
  Widget build(BuildContext context) {
    final InterestMember? m = interest.member;
    final ShortlistController shortlistCtrl = Get.find<ShortlistController>();
    final _Tone tone = _toneFor(interest);

    final List<String> facts = <String>[
      if ((m?.age ?? 0) > 0) '${m!.age} yrs',
      if ((m?.city ?? '').trim().isNotEmpty) m!.city!.trim(),
      if ((m?.profession ?? '').trim().isNotEmpty) m!.profession!.trim(),
      if ((m?.education ?? '').trim().isNotEmpty) m!.education!.trim(),
    ];

    void openProfile() {
      if (m != null && m.id > 0) {
        PublicProfileDetailSheet.show(
          context,
          profileId: m.id,
          name: m.displayName,
          photo: m.photoUrl,
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFB4487B).withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        onTap: openProfile,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Top row: avatar + details + time.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _RefAvatar(url: m?.photoUrl, initial: m?.initial ?? 'H'),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                m?.displayName ?? 'HamQadam Member',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyStrong.copyWith(
                                  fontSize: 15,
                                  color: AppColors.roseTitleInk,
                                ),
                              ),
                            ),
                            if (m?.isVerified ?? false) ...<Widget>[
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: AppColors.success,
                              ),
                            ],
                          ],
                        ),
                        if ((m?.code ?? '').trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${m!.code}',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color: AppColors.chatTimeInk,
                            ),
                          ),
                        ],
                        if (facts.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            facts.join('  •  '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (interest.createdAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.roseCanvas,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _timeAgo(interest.createdAt!),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.chatTimeInk,
                        ),
                      ),
                    ),
                ],
              ),

              // Status + shortlist + match, one tidy row.
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        _StatusBadge(
                          tone: tone,
                          label:
                              interest.statusLabel ?? _fallbackLabel(interest),
                        ),
                        if ((m?.compatibilityPercentage ?? 0) > 0)
                          _MiniBadge(
                            icon: Icons.favorite_rounded,
                            label: '${m!.compatibilityPercentage}% match',
                            color: AppColors.primaryInk,
                          ),
                      ],
                    ),
                  ),
                  if (m != null && m.id > 0)
                    Obx(() {
                      final bool isShort = shortlistCtrl.isShortlisted(m.id);
                      final bool isBusy = shortlistCtrl.isBusy(m.id);
                      return InkResponse(
                        radius: 20,
                        onTap: () => shortlistCtrl.toggleShortlist(
                          m.id,
                          displayName: m.displayName,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: isBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.gold,
                                  ),
                                )
                              : Icon(
                                  isShort
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_outline_rounded,
                                  color: isShort
                                      ? AppColors.gold
                                      : AppColors.chatTimeInk,
                                  size: 22,
                                ),
                        ),
                      );
                    }),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.roseFieldBorder),
              const SizedBox(height: 8),
              _Actions(
                controller: controller,
                interest: interest,
                member: m,
                onShowInterest: () => _showMessageSheet(context, interest, m),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _timeAgo(DateTime date) {
    final Duration diff = DateTime.now().difference(date.toLocal());
    if (diff.inMinutes < 60) {
      return diff.inMinutes <= 1 ? 'Just now' : '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final DateTime d = date.toLocal();
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String _fallbackLabel(InterestModel i) {
    if (i.isPending) return 'Pending';
    if (i.isAccepted) return 'Accepted';
    if (i.isRejected) return 'Declined';
    if (i.isWithdrawn) return 'Withdrawn';
    return 'Closed';
  }

  static _Tone _toneFor(InterestModel i) {
    if (i.isAccepted)
      return const _Tone(
        AppColors.success,
        AppColors.successSoft,
        Icons.check_circle_rounded,
      );
    if (i.isRejected)
      return const _Tone(
        AppColors.error,
        Color(0xFFFBE9E8),
        Icons.cancel_rounded,
      );
    if (i.isPending)
      return const _Tone(
        AppColors.warning,
        Color(0xFFFBF0DA),
        Icons.hourglass_top_rounded,
      );
    return const _Tone(
      AppColors.chatTimeInk,
      AppColors.lightSurfaceAlt,
      Icons.undo_rounded,
    );
  }
}

/// The round gradient-ringed avatar from the Profile Views cards.
class _RefAvatar extends StatelessWidget {
  const _RefAvatar({required this.url, required this.initial});

  final String? url;
  final String initial;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
    );
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: AppColors.regPrimaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.regAccent.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: url != null
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback(),
              )
            : fallback(),
      ),
    );
  }
}

class _Tone {
  const _Tone(this.color, this.bg, this.icon);
  final Color color;
  final Color bg;
  final IconData icon;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.tone, required this.label});

  final _Tone tone;
  final String label;

  @override
  Widget build(BuildContext context) {
    final String text = label.isEmpty
        ? label
        : label[0].toUpperCase() + label.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(tone.icon, size: 12, color: tone.color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: tone.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// Full message in a bottom-sheet popup, with who it is from and when.
void _showMessageSheet(
  BuildContext context,
  InterestModel interest,
  InterestMember? m,
) {
  final String name = m?.displayName ?? 'HamQadam Member';
  final DateTime? at = interest.createdAt?.toLocal();
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final String when = at == null
      ? ''
      : '${at.day} ${months[at.month - 1]} ${at.year}';
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
      ),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  _Avatar(
                    url: m?.photoUrl,
                    initial: m?.initial ?? 'H',
                    verified: m?.isVerified ?? false,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          interest.isSent ? 'You wrote to' : 'Message from',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        if (when.isNotEmpty)
                          Text(
                            when,
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFFFFF7FA), Color(0xFFFDEBF2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.format_quote_rounded,
                      size: 28,
                      color: _roseSoft,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (interest.initialNote ?? '').trim(),
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _RefOutlineButton(
                      icon: Icons.person_outline_rounded,
                      label: 'Full Profile',
                      onPressed: m == null || m.id <= 0
                          ? null
                          : () {
                              Navigator.of(ctx).pop();
                              PublicProfileDetailSheet.show(
                                context,
                                profileId: m.id,
                                name: m.displayName,
                                photo: m.photoUrl,
                              );
                            },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RefGradientButton(
                      icon: Icons.check_rounded,
                      label: 'Close',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

class _Actions extends StatelessWidget {
  const _Actions({
    required this.controller,
    required this.interest,
    required this.member,
    required this.onShowInterest,
  });

  final InterestController controller;
  final InterestModel interest;
  final InterestMember? member;
  final VoidCallback onShowInterest;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool busy = controller.isBusy(interest.id);

      // Primary / secondary actions that depend on where the interest stands.
      final List<Widget> trailing = <Widget>[];
      if (interest.canRespond) {
        trailing
          ..add(
            Expanded(
              child: _RefOutlineButton(
                icon: Icons.close_rounded,
                label: 'Decline',
                onPressed: busy ? null : () => _act(context, 'reject'),
              ),
            ),
          )
          ..add(const SizedBox(width: 8))
          ..add(
            Expanded(
              child: _RefGradientButton(
                icon: Icons.favorite_rounded,
                label: 'Accept',
                busy: busy,
                onPressed: busy ? null : () => _act(context, 'accept'),
              ),
            ),
          );
      } else if (interest.canChat) {
        trailing.add(
          Expanded(
            child: _RefGradientButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Chat',
              onPressed: member == null || member!.id <= 0
                  ? null
                  : () => _openChat(context),
            ),
          ),
        );
      } else if (interest.canWithdraw) {
        trailing.add(
          Expanded(
            child: _RefOutlineButton(
              icon: Icons.undo_rounded,
              label: 'Withdraw',
              onPressed: busy ? null : () => _confirmWithdraw(context),
            ),
          ),
        );
      }

      return Row(
        children: <Widget>[
          Expanded(
            flex: interest.canRespond ? 3 : 1,
            child: _RefOutlineButton(
              icon: Icons.favorite_border_rounded,
              label: 'Show Interest',
              onPressed: onShowInterest,
            ),
          ),
          if (trailing.isNotEmpty) ...<Widget>[
            const SizedBox(width: 8),
            Expanded(
              flex: interest.canRespond ? 5 : 1,
              child: Row(children: trailing),
            ),
          ],
        ],
      );
    });
  }

  Future<void> _openChat(BuildContext context) async {
    final InterestMember m = member!;
    final ChatController chat = Get.find<ChatController>();
    final ChatThread? thread = await chat.findExistingThreadWithUser(m.id);
    if (thread != null && thread.id > 0) {
      ChatConversationView.open(thread);
    } else {
      AppSnackbar.info('Opening your chat… please try again in a moment.');
    }
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
      action == 'accept'
          ? 'Interest accepted. You can now chat.'
          : 'Interest declined.',
    );
  }

  /// Withdrawing does NOT refund the coins, so it is worth confirming.
  Future<void> _confirmWithdraw(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Withdraw interest?'),
        content: const Text(
          'The other member has already been notified, and the coins you spent '
          'are not refunded.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _roseSoft,
              foregroundColor: _rose,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Withdraw'),
          ),
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
}

/// Secondary action: white pill, hairline border — the Profile Views "Full
/// Profile" button.
class _RefOutlineButton extends StatelessWidget {
  const _RefOutlineButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16, color: AppColors.regAccent),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5, color: AppColors.regAccent),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: AppColors.roseFieldBorder, width: 1.4),
        backgroundColor: Colors.white,
      ),
      onPressed: onPressed,
    );
  }
}

/// Primary action: the muted pink gradient of the Profile Views "Chat" button.
class _RefGradientButton extends StatelessWidget {
  const _RefGradientButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null && !busy ? 0.55 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.regPrimaryGradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.regAccent.withValues(alpha: 0.38),
              blurRadius: 14,
              offset: const Offset(0, 6),
              spreadRadius: -3,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (busy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else ...<Widget>[
                    Icon(icon, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.button.copyWith(
                          fontSize: 12.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar
// ---------------------------------------------------------------------------

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.initial,
    required this.verified,
  });

  final String? url;
  final String initial;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    const double size = 68;
    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: size + 6,
            height: size + 6,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: _brand,
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(
                child: url != null
                    ? Image.network(
                        url!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fallback(),
                      )
                    : _fallback(),
              ),
            ),
          ),
          if (verified)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  size: 20,
                  color: AppColors.info,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback() => Container(
    decoration: const BoxDecoration(color: _blush),
    child: Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: _rose,
        ),
      ),
    ),
  );
}
