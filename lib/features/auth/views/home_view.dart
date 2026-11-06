import 'package:flutter/material.dart';
import '../../profile_activity/views/profile_activity_view.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../controllers/gift_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../controllers/verification_controller.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_strings.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/chat_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/biometric_auth_service.dart';
import '../../../core/storage/current_user_service.dart';
import '../../../core/services/push_readiness_service.dart';
import '../../../core/widgets/push_readiness_dialog.dart';
import '../../../models/chat_model.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/premium_bottom_nav.dart';
import '../../chat/views/chat_inbox_view.dart';
import '../../discover/views/discover_view.dart';
import '../../help_center/views/guest_help_view.dart';
import '../../help_center/views/help_chat_view.dart';
import '../../interests/views/interests_view.dart';
import '../../notifications/views/notifications_view.dart';
import '../../profile/views/edit_profile_view.dart';
import '../../profile/views/profile_view.dart';
import '../../profile_views/views/profile_views_view.dart';
import '../../shortlist/views/shortlist_view.dart';
import '../../verification/views/ai_verification_view.dart';
import '../../payments/views/membership_plans_view.dart';
import '../../payments/views/payment_history_view.dart';
import '../../payments/views/coin_usage_view.dart';
import '../../settings/views/change_password_view.dart';
import '../../wallet/views/wallet_view.dart';
import '../../proposals/views/proposals_view.dart';

/// Authenticated app shell: premium gradient AppBar, floating bottom navigation
/// and a luxury navigation drawer.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  /// External tab switching — a saved search "Apply" lands the member back on
  /// the Discover tab with its filter active, from anywhere in the app.
  static final ValueNotifier<int> tabRequest = ValueNotifier<int>(0);

  /// The shell Scaffold's key. The Discover tab draws its own header (the
  /// shell's AppBar is suppressed there), so its menu button opens THIS
  /// scaffold's drawer through this key.
  static final GlobalKey<ScaffoldState> shellKey = GlobalKey<ScaffoldState>();

  /// Jumps the shell to [index]: 0 Discover, 1 Matches, 2 Chat, 3 Profile.
  static void goToTab(int index) => tabRequest.value = index;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final AuthController _auth = Get.find<AuthController>();
  int _index = 0;
  final Set<int> _built = <int>{0};

  static const List<_TabItem> _tabs = <_TabItem>[
    _TabItem(
      'Discover',
      Icons.search_rounded,
      Icons.search_rounded,
      'Find your match',
    ),
    _TabItem(
      'Matches',
      Icons.favorite_outline_rounded,
      Icons.favorite_rounded,
      'Your matches & likes',
    ),
    _TabItem(
      'Chat',
      Icons.chat_bubble_outline_rounded,
      Icons.chat_bubble_rounded,
      'Conversations',
    ),
    _TabItem(
      'Profile',
      Icons.person_outline_rounded,
      Icons.person_rounded,
      'Your profile',
    ),
  ];

  /// Real screens are wired here; the rest keep the "coming soon" placeholder.
  Widget _bodyFor(_TabItem tab) {
    if (tab.label == 'Discover') return const DiscoverView();
    if (tab.label == 'Matches') return const InterestsView(embedded: true);
    if (tab.label == 'Chat') return const ChatInboxView();
    if (tab.label == 'Profile') return const ProfileView();
    return _TabBody(tab: tab);
  }

  @override
  void initState() {
    super.initState();
    HomeView.tabRequest.addListener(_onTabRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _auth.refreshUser();
      _checkPushReadiness();
      // Warm the gift cache in the background so received gifts play instantly.
      Get.find<GiftController>()
        ..loadGifts()
        ..loadReceived();
    });
  }

  void _onTabRequest() {
    final int requested = HomeView.tabRequest.value;
    if (requested != _index && requested >= 0 && requested < _tabs.length) {
      setState(() {
        _index = requested;
        _built.add(requested);
      });
    }
  }

  @override
  void dispose() {
    HomeView.tabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  /// Tells the member if this device cannot be reached while the app is closed.
  ///
  /// Here rather than at launch: by this point they are signed in and looking
  /// at the app, so the explanation has somewhere to land — and the grants it
  /// asks about are the ones that make a *closed* app ring, which only matters
  /// once there is an account to be called on.
  Future<void> _checkPushReadiness() async {
    if (!Get.isRegistered<PushReadinessService>()) return;
    final PushReadinessService service = Get.find<PushReadinessService>();
    final PushReadiness state = await service.check();
    if (!mounted || !service.shouldPrompt(state)) return;
    await PushReadinessDialog.show(state);
  }

  @override
  Widget build(BuildContext context) {
    final _TabItem tab = _tabs[_index];
    return Scaffold(
      key: HomeView.shellKey,
      backgroundColor: const Color(0xFFFAFAFA),
      // Body extends behind the bar, but the bar itself must sit FLUSH with
      // the bottom edge (the floating-gap look read as a misplaced bar).
      extendBody: true,
      // The Chat tab draws its own reference header (a large serif "Chat
      // Conversations" title on the blush canvas), and the Discover tab now
      // draws its own white reference header (serif "Discover / CHOOSE
      // FOREVER" logo, search row, pink filter chip) — so the shell's gradient
      // bar is suppressed on both and each screen supplies the drawer control
      // itself. Matches draws its header inside its own scroll view so the
      // bar, wallet and tabs scroll away together with the list.
      appBar: _index == 2 || _index == 0 || _index == 1
          ? null
          : PremiumAppBar(
              title: tab.label,
              subtitle: tab.subtitle,
              actions: _index == 3
                  ? <Widget>[
                      IconButton(
                        icon: const Icon(
                          Icons.remove_red_eye_outlined,
                          color: Color(0xFFB25C82),
                        ),
                        tooltip: 'Profile Views',
                        onPressed: () =>
                            Get.to<void>(() => const ProfileViewsView()),
                      ),
                    ]
                  : null,
            ),
      drawer: _AppDrawer(auth: _auth, currentTab: _index),
      // Tabs are built the first time they are opened and then KEPT alive
      // (IndexedStack). Rebuilding a tab on every switch re-ran its initState
      // — refetching data, flashing spinners and losing scroll position.
      body: IndexedStack(
        index: _index,
        children: List<Widget>.generate(
          _tabs.length,
          (int i) =>
              _built.contains(i) ? _bodyFor(_tabs[i]) : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: Obx(() {
        // Live unread badge on the Chat destination: the sum of unread messages
        // across threads, exactly what the inbox itself displays.
        int unread = 0;
        if (Get.isRegistered<ChatController>()) {
          final ApiState<List<ChatThread>> st =
              Get.find<ChatController>().threadsState.value;
          if (st.status == ApiStatus.success) {
            for (final ChatThread t in st.data ?? const <ChatThread>[]) {
              unread += t.unreadCount;
            }
          }
        }
        return PremiumBottomNav(
          currentIndex: _index,
          onTap: (int i) {
            setState(() {
              _index = i;
              _built.add(i);
            });
            if (_tabs[i].label == 'Profile' &&
                Get.isRegistered<ProfileController>()) {
              Get.find<ProfileController>().refreshSilently();
              if (Get.isRegistered<VerificationController>()) {
                Get.find<VerificationController>().refreshSilently();
              }
            }
          },
          items: <PremiumNavItem>[
            const PremiumNavItem(icon: Icons.search_rounded, label: 'Discover'),
            const PremiumNavItem(
              icon: Icons.favorite_outline_rounded,
              activeIcon: Icons.favorite_rounded,
              label: 'Matches',
            ),
            PremiumNavItem(
              icon: Icons.chat_bubble_outline_rounded,
              activeIcon: Icons.chat_bubble_rounded,
              label: 'Chat',
              badge: unread,
            ),
            const PremiumNavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
            ),
          ],
        );
      }),
    );
  }
}

class _TabItem {
  const _TabItem(this.label, this.icon, this.activeIcon, this.subtitle);
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String subtitle;
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.tab});
  final _TabItem tab;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.regPrimaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Icon(tab.activeIcon, size: 46, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(tab.label, style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tab.subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Coming soon',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation drawer
// ---------------------------------------------------------------------------

/// One row inside a drawer group card.
class _DrawerEntry {
  const _DrawerEntry(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.auth, required this.currentTab});
  final AuthController auth;
  final int currentTab;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.84,
      backgroundColor: const Color(0xFFFFFBFD),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          _header(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                18,
                AppSpacing.md,
                18,
                AppSpacing.sm,
              ),
              children: <Widget>[
                _group(
                  context,
                  label: 'MEMBERSHIP & PAYMENTS',
                  entries: <_DrawerEntry>[
                    _DrawerEntry(
                      Iconsax.wallet_3,
                      'Wallet',
                      () => Get.to<void>(() => const WalletView()),
                    ),
                    _DrawerEntry(
                      Iconsax.crown_1,
                      'Membership Plans',
                      () => Get.to<void>(() => const MembershipPlansView()),
                    ),
                    _DrawerEntry(
                      Iconsax.receipt_2,
                      'Payment History & Invoices',
                      () => Get.to<void>(() => const PaymentHistoryView()),
                    ),
                    _DrawerEntry(
                      Iconsax.coin_1,
                      'Coin & Feature Usage',
                      () => Get.to<void>(() => const CoinUsageView()),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _group(
                  context,
                  label: 'MY ACTIVITY',
                  entries: <_DrawerEntry>[
                    _DrawerEntry(
                      Iconsax.sms,
                      'Proposals / Rishtay',
                      () => Get.to<void>(() => const ProposalsView()),
                    ),
                    _DrawerEntry(
                      Iconsax.archive_tick,
                      'Shortlisted Profiles',
                      () => Get.to<void>(() => const ShortlistView()),
                    ),
                    _DrawerEntry(
                      Iconsax.heart,
                      'Manage Interests',
                      () => Get.to<void>(() => const InterestsView()),
                    ),
                    _DrawerEntry(
                      Iconsax.star_1,
                      'Profile Activity (Likes / Super Likes)',
                      () => Get.to<void>(() => const ProfileActivityView()),
                    ),
                    _DrawerEntry(
                      Iconsax.eye,
                      'Profile Views',
                      () => Get.to<void>(() => const ProfileViewsView()),
                    ),
                    _DrawerEntry(
                      Iconsax.save_2,
                      'Saved Searches',
                      () => Get.toNamed<void>(AppRoutes.savedSearches),
                    ),
                    _DrawerEntry(
                      Iconsax.notification,
                      'Notifications',
                      () => Get.to<void>(() => const NotificationsView()),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _group(
                  context,
                  label: 'FAMILY & COMMUNITY',
                  entries: <_DrawerEntry>[
                    _DrawerEntry(
                      Iconsax.people,
                      'Family & Wali Mode',
                      () => Get.toNamed<void>(AppRoutes.family),
                    ),
                    _DrawerEntry(
                      Iconsax.video,
                      'Webinars',
                      () => Get.toNamed<void>(AppRoutes.webinars),
                    ),
                    _DrawerEntry(
                      Iconsax.message_question,
                      'Expert Advice',
                      () => Get.toNamed<void>(AppRoutes.expertQuestions),
                    ),
                    _DrawerEntry(
                      Iconsax.messages_2,
                      'Community Forums',
                      () => Get.toNamed<void>(AppRoutes.forums),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _group(
                  context,
                  label: 'ACCOUNT',
                  entries: <_DrawerEntry>[
                    _DrawerEntry(
                      Iconsax.edit_2,
                      'Edit Profile',
                      () => Get.to<void>(() => const EditProfileView()),
                    ),
                    _DrawerEntry(
                      Iconsax.gift,
                      'My Gifts',
                      () => Get.toNamed<void>(AppRoutes.myGifts),
                    ),
                    _DrawerEntry(
                      Iconsax.task_square,
                      'Complete your profile',
                      () => Get.toNamed<void>(AppRoutes.profileCompletion),
                    ),
                    _DrawerEntry(
                      Iconsax.shield_tick,
                      'Verification',
                      () => Get.to<void>(() => const AiVerificationView()),
                    ),
                    _DrawerEntry(
                      Iconsax.finger_scan,
                      'Fingerprint Login',
                      () => _fingerprintSettings(context),
                    ),
                    _DrawerEntry(
                      Iconsax.lock_1,
                      'Change Password',
                      () => Get.to<void>(() => const ChangePasswordView()),
                    ),
                    _DrawerEntry(
                      Iconsax.headphone,
                      'Help Center',
                      _helpTileTap,
                    ),
                    _DrawerEntry(
                      Iconsax.logout,
                      'Logout',
                      () => _confirmLogout(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _moreRow(context),
              ],
            ),
          ),
          // Footer: brand mark + version.
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              10,
              AppSpacing.md,
              MediaQuery.paddingOf(context).bottom + 10,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.favorite_rounded,
                  size: 13,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 6),
                Text(
                  '${AppStrings.appName}  •  v1.0.32',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryDark.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Header ---------------------------------------------------------------

  Widget _header(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    Widget glassChip({
      required IconData icon,
      required String label,
      VoidCallback? onTap,
    }) {
      final Widget chip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: AppColors.primaryInk, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primaryInk,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
      if (onTap == null) return chip;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: onTap,
          child: chip,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: PremiumBarBackground()),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 14, 16, 20),
            child: Obx(() {
              final String name =
                  auth.user.value?.fullName.trim().isNotEmpty == true
                  ? auth.user.value!.fullName
                  : 'HamQadam Member';
              final String email = auth.user.value?.email ?? '';
              final String? photo = auth.user.value?.photoUrl;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      // Avatar inside a white + rose double ring.
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: <Color>[
                              Colors.white,
                              AppColors.primaryDark,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.primaryInk.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.primaryLight,
                            backgroundImage: photo != null
                                ? NetworkImage(photo)
                                : null,
                            child: photo == null
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : 'H',
                                    style: AppTextStyles.displaySerif.copyWith(
                                      color: AppColors.primaryInk,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.displaySerif.copyWith(
                                color: AppColors.primaryInk,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                            if (email.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primaryInk.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.white.withValues(alpha: 0.6),
                        shape: CircleBorder(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(
                              Icons.close_rounded,
                              color: AppColors.primaryInk,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      glassChip(
                        icon: Icons.workspace_premium_rounded,
                        label: 'Member',
                      ),
                      const Spacer(),
                      // Straight to the Profile tab; "Edit Profile" below
                      // opens the editor instead.
                      glassChip(
                        icon: Icons.person_outline_rounded,
                        label: 'View profile',
                        onTap: () {
                          Navigator.of(context).pop();
                          HomeView.goToTab(3);
                        },
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ---- Group card -----------------------------------------------------------

  Widget _group(
    BuildContext context, {
    required String label,
    required List<_DrawerEntry> entries,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Caps label above the card, in the rose the registration screens print
        // their field labels in.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            0,
            AppSpacing.xs,
            7,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[AppColors.primary, AppColors.primaryDark],
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            // Warm white (not plain) + hairline rose border + soft two-layer
            // shadow: the premium card recipe the reference drawer uses.
            color: Colors.white,
            borderRadius: AppRadius.xlAll,
            border: Border.all(
              color: AppColors.roseFieldBorder.withValues(alpha: 0.55),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFB4487B).withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < entries.length; i++) ...<Widget>[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 0.6,
                    indent: 62,
                    endIndent: 14,
                    color: AppColors.roseFieldBorder.withValues(alpha: 0.4),
                  ),
                _tile(context, entries[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, _DrawerEntry e) {
    // Logout is the one destructive row: it keeps the error tint.
    final bool danger = e.label == 'Logout';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        splashColor: AppColors.primary.withValues(alpha: 0.18),
        highlightColor: AppColors.primaryLight.withValues(alpha: 0.5),
        onTap: () {
          Navigator.of(context).pop();
          e.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: <Widget>[
              // Brand-pastel squircle with an ink glyph.
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: danger
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[Color(0xFFFFF7FA), Color(0xFFFBE3EC)],
                        ),
                  color: danger
                      ? AppColors.error.withValues(alpha: 0.10)
                      : null,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  boxShadow: danger
                      ? null
                      : <BoxShadow>[
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(
                              alpha: 0.18,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                            spreadRadius: -2,
                          ),
                        ],
                ),
                child: Icon(
                  e.icon,
                  color: danger ? AppColors.error : AppColors.primaryDark,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.label,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: danger ? AppColors.error : AppColors.roseTitleInk,
                  ),
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: danger
                      ? AppColors.error.withValues(alpha: 0.08)
                      : AppColors.primaryLight,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: danger ? AppColors.error : AppColors.primaryDark,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Session utilities tucked into one quiet row so the destructive ones stay
  /// out of the tap-path of daily actions.
  Widget _moreRow(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: AppRadius.xlAll,
        border: Border.all(
          color: AppColors.roseFieldBorder.withValues(alpha: 0.85),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1AB4487B),
            blurRadius: 30,
            offset: Offset(0, 10),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.xlAll,
          onTap: () => _sessionMenu(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[Color(0xFFFFF7FA), Color(0xFFFBE3EC)],
                    ),
                    border: Border.all(color: const Color(0xFFF8D3E0)),
                  ),
                  child: const Icon(
                    Iconsax.setting_2,
                    size: AppDimensions.iconSm + 2,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Session & account settings',
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.lightTextHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sessionMenu(BuildContext context) async {
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final Offset pos = box.localToGlobal(
      Offset(box.size.width - 16, box.size.height - 120),
    );
    await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      items: <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'logoutAll',
          child: Row(
            children: <Widget>[
              Icon(Icons.devices_other_rounded, size: 18),
              SizedBox(width: 10),
              Text('Logout all devices'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'deactivate',
          child: Row(
            children: <Widget>[
              Icon(Icons.no_accounts_rounded, size: 18, color: AppColors.error),
              SizedBox(width: 10),
              Text('Delete Account', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    ).then((String? value) {
      if (value == 'logoutAll') _confirmLogoutAll(context);
      if (value == 'deactivate') _confirmDeactivate(context);
    });
  }

  // ---- Actions --------------------------------------------------------------

  void _helpTileTap() {
    // Signed-in members get the live Help Center chat; a visitor without a
    // session gets the guest form (name / email / description).
    if (Get.isRegistered<CurrentUserService>() &&
        Get.find<CurrentUserService>().hasUser) {
      HelpChatView.open();
    } else {
      GuestHelpView.open();
    }
  }

  /// Turn fingerprint login ON from the drawer.
  ///
  /// The password is never kept in memory between sessions, so the member
  /// confirms it once here: enter password → live fingerprint scan proves the
  /// phone's owner → credentials are saved for future fingerprint logins.
  Future<void> _enableFingerprintFlow(
    BuildContext sheetCtx,
    BiometricAuthService bio,
  ) async {
    // No TextEditingController: the dialog's exit animation can still be
    // running when the awaited future resolves, and the field inside reads
    // its controller during that window. Disposing right after the await
    // throws "A TextEditingController was used after being disposed".
    // The typed password is captured via onChanged instead.
    String typedPassword = '';
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final String email = auth.user.value?.email ?? '';

    String confirmedPassword = '';
    final bool? confirmed = await showDialog<bool>(
      context: sheetCtx,
      builder: (BuildContext dlgCtx) => AlertDialog(
        title: const Text('Confirm your password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                email.isEmpty
                    ? 'Signed in without an email — use the login screen instead.'
                    : email,
                style: AppTextStyles.caption.copyWith(
                  color: Theme.of(dlgCtx).hintColor,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                obscureText: true,
                autofillHints: const <String>[AutofillHints.password],
                textInputAction: TextInputAction.done,
                onChanged: (String v) => typedPassword = v,
                validator: (String? v) => (v == null || v.isEmpty)
                    ? 'Enter your current password'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dlgCtx,
              formKey.currentState?.validate() ?? false,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed == true) confirmedPassword = typedPassword;
    if (confirmed != true || email.isEmpty || confirmedPassword.isEmpty) return;

    // Live scan: the person enabling this must prove a fingerprint that is
    // enrolled on this phone, right now.
    final bool verified = await bio.verifyOnly();
    if (!verified) return;

    await bio.enable(email: email, password: confirmedPassword);
    AppSnackbar.success('Fingerprint login enabled — use it after logout.');
    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
  }

  /// Manage fingerprint login from the drawer. When the device has no
  /// biometrics the sheet says so plainly; otherwise the member can turn the
  /// feature on (verifying with a live fingerprint first) or off.
  Future<void> _fingerprintSettings(BuildContext context) async {
    if (!Get.isRegistered<BiometricAuthService>()) {
      AppSnackbar.info('Fingerprint login is not available on this device.');
      return;
    }
    final BiometricAuthService bio = Get.find<BiometricAuthService>();
    final bool canUse = await bio.canUse();
    final bool enabled = canUse ? await bio.isEnabled() : false;
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.regAccent.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      color: AppColors.regAccent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Fingerprint Login',
                      style: AppTextStyles.title,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (!canUse)
                Text(
                  'This device has no fingerprint scanner set up. Add a fingerprint in your phone\'s security settings first.',
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(ctx).hintColor,
                    height: 1.45,
                  ),
                )
              else ...<Widget>[
                Text(
                  enabled
                      ? 'Fingerprint login is ON. After logging out you can sign back in with your fingerprint.'
                      : 'Turn on to sign back in with your fingerprint after logging out.',
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(ctx).hintColor,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!enabled)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.fingerprint_rounded, size: 22),
                      label: const Text('Turn On'),
                      onPressed: () => _enableFingerprintFlow(ctx, bio),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.lock_open_rounded, size: 20),
                      label: const Text('Turn Off'),
                      onPressed: () async {
                        await bio.disable();
                        if (ctx.mounted) Navigator.pop(ctx);
                        AppSnackbar.info('Fingerprint login turned off.');
                      },
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    if (await _confirm(
      context,
      'Logout',
      'Are you sure you want to log out?',
      'Logout',
    )) {
      await auth.logout();
    }
  }

  Future<void> _confirmLogoutAll(BuildContext context) async {
    if (await _confirm(
      context,
      'Logout all devices',
      'This signs you out on every device.',
      'Logout all',
    )) {
      await auth.logoutAllDevices();
    }
  }

  Future<void> _confirmDeactivate(BuildContext context) async {
    if (await _confirm(
      context,
      'Delete Account',
      'Your account will be deleted and your personal data removed: profile, photos, chats, gifts and wallet are erased permanently. This cannot be undone. Continue?',
      'Delete',
      danger: true,
    )) {
      await auth.deactivateAccount();
    }
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String message,
    String confirmLabel, {
    bool danger = false,
  }) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: danger ? AppColors.error : AppColors.regAccent,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}
