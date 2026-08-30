import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_strings.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/theme_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/premium_bottom_nav.dart';
import '../../chat/views/chat_inbox_view.dart';
import '../../discover/views/discover_view.dart';
import '../../discover/widgets/search_filter_bottom_sheet.dart';
import '../../interests/views/interests_view.dart';
import '../../profile/views/edit_profile_view.dart';
import '../../profile/views/profile_view.dart';
import '../../profile_views/views/profile_views_view.dart';
import '../../shortlist/views/shortlist_view.dart';
import '../../payments/views/membership_plans_view.dart';
import '../../payments/views/payment_history_view.dart';
import '../../payments/views/coin_usage_view.dart';
import '../../proposals/views/proposals_view.dart';




/// Authenticated app shell: premium gradient AppBar, floating bottom navigation
/// and a luxury navigation drawer.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

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
    if (tab.label == 'Matches') return const InterestsView();
    if (tab.label == 'Chat') return const ChatInboxView();
    if (tab.label == 'Profile') return const ProfileView();
    return _TabBody(tab: tab);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _auth.refreshUser());
  }

  @override
  Widget build(BuildContext context) {
    final _TabItem tab = _tabs[_index];
    return Scaffold(
      extendBody: true,
      appBar: PremiumAppBar(
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
                      icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.white),
                      tooltip: 'Profile Views',
                      onPressed: () => Get.to<void>(() => const ProfileViewsView()),
                    ),
                  ]
                : null,
      ),
      drawer: _AppDrawer(auth: _auth),
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
      bottomNavigationBar: PremiumBottomNav(
        currentIndex: _index,
        onTap: (int i) => setState(() => _index = i),
        items: _tabs
            .map((_TabItem t) => PremiumNavItem(icon: t.icon, activeIcon: t.activeIcon, label: t.label))
            .toList(),
      ),
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

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.auth});
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: <Widget>[
          _header(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              children: <Widget>[
                _sectionLabel(context, 'MEMBERSHIP & PAYMENTS'),
                _tile(context, Icons.workspace_premium_outlined, 'Membership Plans',
                    () => Get.to<void>(() => const MembershipPlansView())),
                _tile(context, Icons.receipt_long_outlined, 'Payment History & Invoices',
                    () => Get.to<void>(() => const PaymentHistoryView())),
                _tile(context, Icons.monetization_on_outlined, 'Coin & Feature Usage',
                    () => Get.to<void>(() => const CoinUsageView())),
                const SizedBox(height: AppSpacing.sm),
                _sectionLabel(context, 'ACCOUNT'),
                _tile(context, Icons.mail_outline_rounded, 'Proposals / Rishtay',
                    () => Get.to<void>(() => const ProposalsView())),
                _tile(context, Icons.bookmark_added_outlined, 'Shortlisted Profiles',
                    () => Get.to<void>(() => const ShortlistView())),
                _tile(context, Icons.favorite_border_rounded, 'Manage Interests',
                    () => Get.to<void>(() => const InterestsView())),

                _tile(context, Icons.edit_outlined, 'Edit Profile',


                    () => Get.to<void>(() => const EditProfileView())),
                _tile(context, Icons.playlist_add_check_rounded, 'Complete your profile',
                    () => Get.toNamed<void>(AppRoutes.profileCompletion)),
                _tile(context, Icons.verified_user_outlined, 'Verification',
                    () => _soon(context)),
                _tile(context, Icons.privacy_tip_outlined, 'Privacy & Settings',
                    () => _soon(context)),
                _tile(context, Icons.notifications_none_rounded, 'Notifications', () => _soon(context)),
                _tile(context, Icons.brightness_6_rounded, 'Theme', () => _themePicker(context)),
                const SizedBox(height: AppSpacing.sm),
                _sectionLabel(context, 'SESSION'),
                _tile(context, Icons.logout_rounded, 'Logout', () => _confirmLogout(context)),
                _tile(context, Icons.devices_other_rounded, 'Logout all devices',
                    () => _confirmLogoutAll(context)),
                _tile(context, Icons.no_accounts_rounded, 'Deactivate account',
                    () => _confirmDeactivate(context), danger: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              '${AppStrings.appName} • v1.0.0',
              style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.of(context).padding.top + AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomRight: Radius.circular(AppRadius.xl)),
      ),
      child: Obx(() {
        final String name = auth.user.value?.fullName.trim().isNotEmpty == true
            ? auth.user.value!.fullName
            : 'HamQadam Member';
        final String email = auth.user.value?.email ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
              ),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'H',
                  style: AppTextStyles.display.copyWith(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(name, style: AppTextStyles.title.copyWith(color: Colors.white)),
            if (email.isNotEmpty)
              Text(email, style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.85))),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                  Text('Member', style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: Theme.of(context).hintColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    final Color color = danger ? AppColors.error : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: () {
            Navigator.of(context).pop();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 11),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(icon, color: color, size: AppDimensions.iconSm + 2),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyStrong.copyWith(color: danger ? AppColors.error : null),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Theme.of(context).hintColor, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _soon(BuildContext context) =>
      Get.snackbar('Coming soon', 'This section is on the way.', snackPosition: SnackPosition.BOTTOM);

  void _themePicker(BuildContext context) {
    final ThemeController theme = Get.find<ThemeController>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
              child: Text('Appearance', style: AppTextStyles.title),
            ),
            Obx(() => Column(
                  children: <Widget>[
                    _themeOption(ctx, theme, ThemeMode.light, 'Light', Icons.light_mode_rounded),
                    _themeOption(ctx, theme, ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
                    _themeOption(ctx, theme, ThemeMode.system, 'System default', Icons.brightness_auto_rounded),
                  ],
                )),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(BuildContext ctx, ThemeController theme, ThemeMode mode, String label, IconData icon) {
    final bool selected = theme.mode.value == mode;
    return ListTile(
      leading: Icon(icon, color: selected ? AppColors.primary : null),
      title: Text(label, style: AppTextStyles.body),
      trailing: selected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
      onTap: () {
        theme.setMode(mode);
        Navigator.of(ctx).pop();
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    if (await _confirm(context, 'Logout', 'Are you sure you want to log out?', 'Logout')) {
      await auth.logout();
    }
  }

  Future<void> _confirmLogoutAll(BuildContext context) async {
    if (await _confirm(context, 'Logout all devices', 'This signs you out on every device.', 'Logout all')) {
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
