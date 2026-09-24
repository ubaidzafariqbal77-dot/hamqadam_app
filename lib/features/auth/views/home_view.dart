import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_strings.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/chat_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/biometric_auth_service.dart';
import '../../../core/services/push_readiness_service.dart';
import '../../../core/widgets/push_readiness_dialog.dart';
import '../../../models/chat_model.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/premium_bottom_nav.dart';
import '../../chat/views/chat_inbox_view.dart';
import '../../discover/views/discover_view.dart';
import '../../discover/widgets/search_filter_bottom_sheet.dart';
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
import '../../proposals/views/proposals_view.dart';

/// Authenticated app shell: premium gradient AppBar, floating bottom navigation
/// and a luxury navigation drawer.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  /// External tab switching — a saved search "Apply" lands the member back on
  /// the Discover tab with its filter active, from anywhere in the app.
  static final ValueNotifier<int> tabRequest = ValueNotifier<int>(0);

  /// Jumps the shell to [index]: 0 Discover, 1 Matches, 2 Chat, 3 Profile.
  static void goToTab(int index) => tabRequest.value = index;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final AuthController _auth = Get.find<AuthController>();
  int _index = 0;

  static const List<_TabItem> _tabs = <_TabItem>[
    _TabItem('Discover', Icons.search_rounded, Icons.search_rounded, 'Find your match'),
    _TabItem('Matches', Icons.favorite_outline_rounded, Icons.favorite_rounded, 'Your matches & likes'),
    _TabItem('Chat', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Conversations'),
    _TabItem('Profile', Icons.person_outline_rounded, Icons.person_rounded, 'Your profile'),
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
    });
  }

  void _onTabRequest() {
    final int requested = HomeView.tabRequest.value;
    if (requested != _index && requested >= 0 && requested < _tabs.length) {
      setState(() => _index = requested);
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
      extendBody: true,
      // The Chat tab draws its own reference header (a large serif "Chat
      // Conversations" title on the blush canvas), so the shell's gradient bar
      // is suppressed there and the inbox supplies the drawer control instead.
      appBar: _index == 2
          ? null
          : PremiumAppBar(
              title: tab.label,
              subtitle: tab.subtitle,
              actions: _index == 0
                  ? <Widget>[
                      IconButton(
                        icon: const Icon(Icons.tune_rounded, color: Colors.white),
                        tooltip: 'Filter Profiles',
                        onPressed: () => SearchFilterBottomSheet.show(context),
                      ),
                    ]
                  : _index == 3
                      ? <Widget>[
                          IconButton(
                            icon: const Icon(Icons.remove_red_eye_outlined,
                                color: Colors.white),
                            tooltip: 'Profile Views',
                            onPressed: () =>
                                Get.to<void>(() => const ProfileViewsView()),
                          ),
                        ]
                      : null,
            ),
      drawer: _AppDrawer(auth: _auth, currentTab: _index),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (Widget child, Animation<double> a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey<int>(_index),
          child: _bodyFor(tab),
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
          onTap: (int i) => setState(() => _index = i),
          items: <PremiumNavItem>[
            const PremiumNavItem(icon: Icons.search_rounded, label: 'Discover'),
            const PremiumNavItem(
                icon: Icons.favorite_outline_rounded,
                activeIcon: Icons.favorite_rounded,
                label: 'Matches'),
            PremiumNavItem(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Chat',
                badge: unread),
            const PremiumNavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile'),
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
                  colors: AppColors.brandGradient,
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
            Text(tab.label, style: AppTextStyles.headline),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tab.subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Coming soon',
              style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
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
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color cardColor = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color hairline =
        (dark ? AppColors.darkBorder : AppColors.lightDivider).withValues(alpha: 0.7);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.84,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _header(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                children: <Widget>[
                  _group(
                    context,
                    cardColor: cardColor,
                    hairline: hairline,
                    label: 'MEMBERSHIP & PAYMENTS',
                    entries: <_DrawerEntry>[
                      _DrawerEntry(Icons.workspace_premium_outlined, 'Membership Plans',
                          () => Get.to<void>(() => const MembershipPlansView())),
                      _DrawerEntry(Icons.receipt_long_outlined, 'Payment History & Invoices',
                          () => Get.to<void>(() => const PaymentHistoryView())),
                      _DrawerEntry(Icons.monetization_on_outlined, 'Coin & Feature Usage',
                          () => Get.to<void>(() => const CoinUsageView())),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _group(
                    context,
                    cardColor: cardColor,
                    hairline: hairline,
                    label: 'MY ACTIVITY',
                    entries: <_DrawerEntry>[
                      _DrawerEntry(Icons.mail_outline_rounded, 'Proposals / Rishtay',
                          () => Get.to<void>(() => const ProposalsView())),
                      _DrawerEntry(Icons.bookmark_added_outlined, 'Shortlisted Profiles',
                          () => Get.to<void>(() => const ShortlistView())),
                      _DrawerEntry(Icons.favorite_border_rounded, 'Manage Interests',
                          () => Get.to<void>(() => const InterestsView())),
                      _DrawerEntry(Icons.bookmarks_outlined, 'Saved Searches',
                          () => Get.toNamed<void>(AppRoutes.savedSearches)),
                      _DrawerEntry(Icons.notifications_none_rounded, 'Notifications',
                          () => Get.to<void>(() => const NotificationsView())),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _group(
                    context,
                    cardColor: cardColor,
                    hairline: hairline,
                    label: 'FAMILY & COMMUNITY',
                    entries: <_DrawerEntry>[
                      _DrawerEntry(Icons.family_restroom_rounded, 'Family & Wali Mode',
                          () => Get.toNamed<void>(AppRoutes.family)),
                      _DrawerEntry(Icons.videocam_outlined, 'Webinars',
                          () => Get.toNamed<void>(AppRoutes.webinars)),
                      _DrawerEntry(Icons.support_rounded, 'Expert Advice',
                          () => Get.toNamed<void>(AppRoutes.expertQuestions)),
                      _DrawerEntry(Icons.forum_outlined, 'Community Forums',
                          () => Get.toNamed<void>(AppRoutes.forums)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _group(
                    context,
                    cardColor: cardColor,
                    hairline: hairline,
                    label: 'ACCOUNT',
                    entries: <_DrawerEntry>[
                      _DrawerEntry(Icons.edit_outlined, 'Edit Profile',
                          () => Get.to<void>(() => const EditProfileView())),
                      _DrawerEntry(Icons.playlist_add_check_rounded, 'Complete your profile',
                          () => Get.toNamed<void>(AppRoutes.profileCompletion)),
                      _DrawerEntry(Icons.verified_user_outlined, 'Verification',
                          () => Get.to<void>(() => const AiVerificationView())),
                      _DrawerEntry(Icons.fingerprint_rounded, 'Fingerprint Login',
                          () => _fingerprintSettings(context)),
                      _DrawerEntry(Icons.support_agent_rounded, 'Help Center', _helpTileTap),
                      _DrawerEntry(Icons.logout_rounded, 'Logout', () => _confirmLogout(context)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _moreRow(context, cardColor),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                '${AppStrings.appName} • v1.0.0',
                style: AppTextStyles.caption.copyWith(color: theme.hintColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Header ---------------------------------------------------------------

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.xl),
          bottomRight: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Obx(() {
        final String name = auth.user.value?.fullName.trim().isNotEmpty == true
            ? auth.user.value!.fullName
            : 'HamQadam Member';
        final String email = auth.user.value?.email ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'H',
                      style: AppTextStyles.title.copyWith(color: Colors.white),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 13),
                      SizedBox(width: 5),
                      Text(
                        'Member',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.title.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (email.isNotEmpty) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption
                    .copyWith(color: Colors.white.withValues(alpha: 0.85)),
              ),
            ],
          ],
        );
      }),
    );
  }

  // ---- Group card -----------------------------------------------------------

  Widget _group(
    BuildContext context, {
    required Color cardColor,
    required Color hairline,
    required String label,
    required List<_DrawerEntry> entries,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 2),
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: Theme.of(context).hintColor,
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
                letterSpacing: 1.4,
              ),
            ),
          ),
          for (int i = 0; i < entries.length; i++) ...<Widget>[
            if (i > 0)
              Divider(height: 1, thickness: 0.6, indent: 54, color: hairline),
            _tile(context, entries[i]),
          ],
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, _DrawerEntry e) {
    const Color iconColor = AppColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: () {
          Navigator.of(context).pop();
          e.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 11),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(e.icon, color: iconColor, size: AppDimensions.iconSm + 2),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  e.label,
                  style: AppTextStyles.bodyStrong,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Theme.of(context).hintColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Session utilities tucked into one quiet row so the destructive ones stay
  /// out of the tap-path of daily actions.
  Widget _moreRow(BuildContext context, Color cardColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.6),
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: (Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkBorder
                  : AppColors.lightDivider)
              .withValues(alpha: 0.7),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: () => _sessionMenu(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 13),
            child: Row(
              children: <Widget>[
                Icon(Icons.settings_suggest_outlined,
                    size: 20, color: Theme.of(context).hintColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Session & account settings', style: AppTextStyles.caption),
                ),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: Theme.of(context).hintColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sessionMenu(BuildContext context) async {
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final Offset pos = box.localToGlobal(Offset(box.size.width - 16, box.size.height - 120));
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
              Text('Deactivate account', style: TextStyle(color: AppColors.error)),
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

  void _helpTileTap() => HelpChatView.open();

  /// Turn fingerprint login ON from the drawer.
  ///
  /// The password is never kept in memory between sessions, so the member
  /// confirms it once here: enter password → live fingerprint scan proves the
  /// phone's owner → credentials are saved for future fingerprint logins.
  Future<void> _enableFingerprintFlow(BuildContext sheetCtx, BiometricAuthService bio) async {
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
                email.isEmpty ? 'Signed in without an email — use the login screen instead.' : email,
                style: AppTextStyles.caption.copyWith(color: Theme.of(dlgCtx).hintColor),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                obscureText: true,
                autofillHints: const <String>[AutofillHints.password],
                textInputAction: TextInputAction.done,
                onChanged: (String v) => typedPassword = v,
                validator: (String? v) =>
                    (v == null || v.isEmpty) ? 'Enter your current password' : null,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dlgCtx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dlgCtx, formKey.currentState?.validate() ?? false),
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
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
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
                      color: AppColors.primary.withValues(alpha: 0.10),
                    ),
                    child: const Icon(Icons.fingerprint_rounded,
                        color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Fingerprint Login', style: AppTextStyles.title),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (!canUse)
                Text(
                  'This device has no fingerprint scanner set up. Add a fingerprint in your phone\'s security settings first.',
                  style: AppTextStyles.body.copyWith(color: Theme.of(ctx).hintColor, height: 1.45),
                )
              else ...<Widget>[
                Text(
                  enabled
                      ? 'Fingerprint login is ON. After logging out you can sign back in with your fingerprint.'
                      : 'Turn on to sign back in with your fingerprint after logging out.',
                  style: AppTextStyles.body.copyWith(color: Theme.of(ctx).hintColor, height: 1.45),
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
    if (await _confirm(context, 'Logout', 'Are you sure you want to log out?', 'Logout')) {
      await auth.logout();
    }
  }

  Future<void> _confirmLogoutAll(BuildContext context) async {
    if (await _confirm(
        context, 'Logout all devices', 'This signs you out on every device.', 'Logout all')) {
      await auth.logoutAllDevices();
    }
  }

  Future<void> _confirmDeactivate(BuildContext context) async {
    if (await _confirm(
      context,
      'Deactivate account',
      'Your profile will be deactivated and hidden. You can reactivate by contacting support. Continue?',
      'Deactivate',
      danger: true,
    )) {
      await auth.deactivateAccount();
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String message, String confirmLabel,
      {bool danger = false}) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(AppStrings.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: danger ? AppColors.error : AppColors.primary),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}
