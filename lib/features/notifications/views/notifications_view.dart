import 'package:flutter/material.dart';
import '../../../features/profile_activity/views/profile_activity_view.dart';
import '../../../models/appreciation_model.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/notification_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../features/gifts/views/gift_detail_view.dart';
import '../../../features/chat/views/chat_conversation_view.dart';
import '../../../features/chat/views/chat_inbox_view.dart';
import '../../../features/help_center/views/help_chat_view.dart';
import '../../../features/interests/views/interests_view.dart';
import '../../../features/payments/views/coin_usage_view.dart';
import '../../../features/payments/views/membership_plans_view.dart';
import '../../../features/profile_views/views/profile_views_view.dart';
import '../../../features/proposals/views/proposals_view.dart';
import '../../../models/chat_model.dart';
import '../../../models/notification_model.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/skeleton.dart';
import '../../../widgets/state_widgets.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final NotificationController _controller = Get.find<NotificationController>();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.fetchNotifications(refresh: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _controller.fetchNotifications();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── icon ──────────────────────────────────────────────────────────────────
  Widget _buildIcon(NotificationModel notif) {
    final String lower = notif.type.toLowerCase();

    // Premium tile: Iconsax glyph in white on a soft two-tone gradient
    // squircle, tinted per category so the list scans at a glance.
    const List<Color> rose = <Color>[Color(0xFFF7A8C4), Color(0xFFB25C82)];
    const List<Color> berry = <Color>[Color(0xFFD98BB0), Color(0xFF8E3D60)];
    const List<Color> violet = <Color>[Color(0xFFC9B6F2), Color(0xFF7E5BC9)];
    const List<Color> gold = <Color>[Color(0xFFF8D88A), Color(0xFFD99A2B)];
    const List<Color> mint = <Color>[Color(0xFF9BE3C3), Color(0xFF2F9E73)];
    const List<Color> sky = <Color>[Color(0xFFA8D4F7), Color(0xFF3E83C9)];
    const List<Color> coral = <Color>[Color(0xFFF8B2A8), Color(0xFFD9534F)];

    IconData icon = Iconsax.notification;
    List<Color> g = rose;

    if (notif.isChatMessage) {
      icon = Iconsax.message_text_1;
      g = berry;
    } else if (lower.contains('gift')) {
      icon = Iconsax.gift;
      g = rose;
    } else if (lower.contains('interest') || lower.contains('mutual')) {
      icon = Iconsax.heart;
      g = rose;
    } else if (lower.contains('proposal')) {
      icon = Iconsax.sms_tracking;
      g = berry;
    } else if (lower.contains('shortlist')) {
      icon = Iconsax.archive_tick;
      g = violet;
    } else if (lower.contains('view')) {
      icon = Iconsax.eye;
      g = sky;
    } else if (lower.contains('coin') || lower.contains('bonus') || lower.contains('credit')) {
      icon = Iconsax.coin_1;
      g = gold;
    } else if (lower.contains('payment') || lower.contains('package') || lower.contains('plan') || lower.contains('subscription')) {
      icon = Iconsax.crown_1;
      g = gold;
    } else if (lower.contains('call')) {
      icon = Iconsax.call_slash;
      g = coral;
    } else if (lower.contains('match')) {
      icon = Iconsax.profile_2user;
      g = rose;
    } else if (lower.contains('referral') || lower.contains('achievement')) {
      icon = Iconsax.cup;
      g = gold;
    } else if (lower.contains('verification') || lower.contains('identity')) {
      icon = Iconsax.shield_tick;
      g = mint;
    } else if (lower.contains('support') || lower.contains('ticket')) {
      icon = Iconsax.headphone;
      g = sky;
    } else if (lower.contains('family') || lower.contains('guardian')) {
      icon = Iconsax.people;
      g = violet;
    } else if (lower.contains('wallet') || lower.contains('refund')) {
      icon = Iconsax.wallet_3;
      g = gold;
    } else if (lower.contains('security') || lower.contains('login') || lower.contains('device')) {
      icon = Iconsax.security_safe;
      g = coral;
    } else if (lower.contains('profile')) {
      icon = Iconsax.user;
      g = berry;
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: g,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: g.last.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 5),
            spreadRadius: -3,
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          // Soft top-left gloss.
          Positioned(
            top: 3,
            left: 5,
            child: Container(
              width: 18,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Center(child: Icon(icon, color: Colors.white, size: 21)),
        ],
      ),
    );
  }

  // ── navigation on tap ─────────────────────────────────────────────────────
  void _handleNotificationTap(NotificationModel notif) {
    // One tap = the notification is read on the server, whatever it is.
    _controller.markAsRead(notif.id, silent: true);

    // Telemetry: backend also wants to know the member actually opened it.
    _controller.recordClick(notif.id);

    final String type = notif.type.toLowerCase();

    // 0. Gift notifications → the gift's detail screen.
    if (type.contains('gift')) {
      final int? txnId = notif.infoId;
      if (txnId != null && txnId > 0) {
        Get.to<void>(() => GiftDetailView(transactionId: txnId));
      } else {
        Get.toNamed<void>(AppRoutes.myGifts);
      }
      return;
    }

    // 1. Chat messages — routed into the conversation thread.
    if (notif.isChatMessage) {
      _openChatFromNotif(notif);
      return;
    }

    // Like / Super Like → Profile Activity → Received.
    if (type.contains('super_like')) {
      Get.to(() => const ProfileActivityView(initialType: AppreciationType.superLike));
      return;
    }
    if (type.contains('profile_like') || type.contains('mutual_like')) {
      Get.to(() => const ProfileActivityView());
      return;
    }

    // 2. Proposals
    if (type.contains('proposal')) {
      Get.to(() => const ProposalsView());
      return;
    }

    // 3. Interests
    if (type.contains('interest') || type.contains('mutual')) {
      Get.to(() => const InterestsView());
      return;
    }

    // 4. Profile Views
    if (type.contains('profile_view') || type.contains('view_profile') || type.contains('view')) {
      Get.to(() => const ProfileViewsView());
      return;
    }

    // 5. Coins / Free Coins Bonus
    if (type.contains('coin') || type.contains('bonus') || type.contains('credit')) {
      Get.to(() => const CoinUsageView());
      return;
    }

    // 6. Payments / Packages
    if (type.contains('payment') || type.contains('package') || type.contains('plan') || type.contains('subscription')) {
      Get.to(() => const MembershipPlansView());
      return;
    }

    // 7. Support / Help Center tickets
    if (type.contains('support') || type.contains('help') || type.contains('ticket')) {
      Get.to(() => const HelpChatView());
      return;
    }

    // 8. Verification / identity outcomes
    if (type.contains('verification') || type.contains('identity')) {
      Get.toNamed<void>(AppRoutes.aiVerification);
      return;
    }

    // 9. Matches / AI matches
    if (type.contains('match')) {
      Get.toNamed<void>(AppRoutes.interestMatches);
      return;
    }

    // 10. Rewards / achievements / referrals
    if (type.contains('reward') || type.contains('achievement') || type.contains('referral')) {
      Get.toNamed<void>(AppRoutes.home);
      return;
    }

    // 11. Family / guardian
    if (type.contains('family') || type.contains('guardian')) {
      Get.toNamed<void>(AppRoutes.family);
      return;
    }

    // 12. Wallet refund / wallet
    if (type.contains('wallet') || type.contains('refund')) {
      Get.to(() => const MembershipPlansView());
      return;
    }

    // 13. Security / login / device
    if (type.contains('security') || type.contains('login') || type.contains('device')) {
      Get.toNamed<void>(AppRoutes.home);
      return;
    }

    // Fallback: land on the notifications list for anything unknown.
    Get.to(() => const NotificationsView());
  }

  /// Chat notifications carry the thread id in [NotificationModel.infoId] and
  /// the sender's user id in [NotificationModel.notifyBy]. Match either against
  /// the already-loaded threads; failing that, land on the inbox.
  void _openChatFromNotif(NotificationModel notif) {
    if (Get.isRegistered<ChatController>()) {
      final ChatController chatCtrl = Get.find<ChatController>();
      final List<ChatThread> threads = chatCtrl.threadsState.value.data ?? <ChatThread>[];

      ChatThread? thread;
      final int? infoId = notif.infoId;
      final int? notifyBy = notif.notifyBy;

      if (infoId != null) {
        thread = threads.cast<ChatThread?>().firstWhere(
          (t) => t?.id == infoId,
          orElse: () => null,
        );
      }
      if (thread == null && notifyBy != null) {
        thread = threads.cast<ChatThread?>().firstWhere(
          (t) => t?.participant.id == notifyBy,
          orElse: () => null,
        );
      }

      if (thread != null) {
        ChatConversationView.open(thread);
        return;
      }
    }

    Get.to(() => const ChatInboxView());
  }

  // ── date formatter ────────────────────────────────────────────────────────
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 6) return '${date.day}/${date.month}/${date.year}';
    if (diff.inDays > 0) return diff.inDays == 1 ? 'Yesterday' : '${diff.inDays} days ago';
    if (diff.inHours > 0) return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return diff.inMinutes == 1 ? '1 minute ago' : '${diff.inMinutes} minutes ago';
    return 'Just now';
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.roseCanvas,
      appBar: PremiumAppBar(
        title: 'Notifications',
        subtitle: 'Updates about your activity',
        actions: <Widget>[
          // Always available: on the Unread tab it is the whole point of the
          // screen, and on All it still clears older rows a refresh will show.
          Obx(() {
            final bool busy = _controller.isLoading.value;
            return TextButton(
              onPressed: busy ? null : _controller.markAllAsRead,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Mark all read'),
            );
          }),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildTabs(context),
          Expanded(
            child: Obx(() {
              if (_controller.isLoading.value && _controller.notifications.isEmpty) {
                return _buildSkeleton(context);
              }

              if (!_controller.isLoading.value && _controller.notifications.isEmpty) {
                return _controller.showUnreadOnly.value
                    ? const EmptyStateWidget(
                        title: 'All Caught Up',
                        message:
                            'You have no unread notifications. New interests, proposals and activity will show up here.',
                      )
                    : const EmptyStateWidget(
                        title: 'No Notifications',
                        message:
                            'You are all caught up. Activity about your profile, interests and messages will appear here.',
                      );
              }

              return RefreshIndicator(
                color: AppColors.regAccent,
                onRefresh: () => _controller.fetchNotifications(refresh: true),
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl,
                  ),
                  itemCount: _controller.notifications.length +
                      (_controller.isLoadingMore.value ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    if (index == _controller.notifications.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.regAccent,
                          ),
                        ),
                      );
                    }
                    final notif = _controller.notifications[index];
                    return _NotificationCard(
                      notif: notif,
                      icon: _buildIcon(notif),
                      timeLabel: notif.createdAt != null
                          ? _formatDate(notif.createdAt!)
                          : null,
                      onTap: () => _handleNotificationTap(notif),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── All | Unread segmented tabs ───────────────────────────────────────────
  Widget _buildTabs(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.roseFieldBorder),
      ),
      child: Obx(() {
        final bool unreadSelected = _controller.showUnreadOnly.value;
        return Row(
          children: <Widget>[
            _buildTab(
              context,
              label: 'All',
              selected: !unreadSelected,
              onTap: () => _controller.setUnreadOnly(false),
            ),
            _buildTab(
              context,
              label: _controller.unreadCount.value > 0
                  ? 'Unread (${_controller.unreadCount.value})'
                  : 'Unread',
              selected: unreadSelected,
              onTap: () => _controller.setUnreadOnly(true),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTab(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.regAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : AppColors.fieldLabelRose,
            ),
          ),
        ),
      ),
    );
  }

  // ── skeleton feed while the first page loads ──────────────────────────────
  Widget _buildSkeleton(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.roseFieldBorder),
        ),
        child: const Row(
          children: <Widget>[
            Skeleton(height: 44, circle: true),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Skeleton(width: 150, height: 13),
                  SizedBox(height: 8),
                  Skeleton(width: double.infinity, height: 11),
                  SizedBox(height: 6),
                  Skeleton(width: 80, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One notification as a quiet white card (rose recipe); unread rows carry a
/// brand wash, a rose dot and a bolder title. Chat rows read as inbox previews.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notif,
    required this.icon,
    required this.onTap,
    this.timeLabel,
  });

  final NotificationModel notif;
  final Widget icon;
  final String? timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = Theme.of(context).textTheme.titleLarge?.color ?? AppColors.roseTitleInk;
    final bool isChat = notif.isChatMessage;

    final Widget card = Material(
      color: notif.isRead
          ? Colors.white
          : AppColors.regAccent.withValues(alpha: dark ? 0.10 : 0.05),
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: AppColors.roseFieldBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              icon,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            notif.title.capitalizeFirst ?? notif.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyStrong.copyWith(
                              color: titleColor,
                              fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          timeLabel ?? '',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        if (!notif.isRead) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.regAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notif.message,
                      maxLines: isChat ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        height: 1.4,
                        fontStyle: isChat ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (isChat) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Theme.of(context).hintColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (dark) return card;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: AppRadius.lgAll,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x1AB4487B), // #B4487B @ 10%
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: card,
    );
  }
}
